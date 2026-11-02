package com.duckdream.neonbreach

import android.app.Activity
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.os.Bundle
import android.util.Log
import android.view.Choreographer
import android.view.Gravity
import android.view.MotionEvent
import android.view.SurfaceView
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import kotlin.math.hypot

class MainActivity : Activity() {
    private enum class AppState {
        BOOT, DEVICE_PROBE, VULKAN_INIT, GLES_FALLBACK, ASSET_LOADING,
        MENU, RUNNING, PAUSED, RESULT, RECOVERY
    }

    companion object {
        private const val TAG = "ProjectArena"
        private val HEROES = arrayOf(
            "LYRA / SUPORTE",
            "BASTION / DEFESA",
            "KAIRO / MOBILIDADE"
        )
        private val HERO_DESCRIPTIONS = arrayOf(
            "Pulso mais frequente e escudo confiável para apoiar a disputa das rotas.",
            "Escudo mais longo e pulso de maior alcance para segurar a linha de frente.",
            "Impulso mais longo e recarga curta para mudar de rota rapidamente."
        )
    }

    init { System.loadLibrary("arena_sim") }

    private lateinit var root: FrameLayout
    private lateinit var surface: SurfaceView
    private lateinit var renderer: FilamentGameRenderer
    private lateinit var objectiveProgress: ProgressBar
    private lateinit var objectiveLabel: TextView
    private lateinit var stateLabel: TextView
    private lateinit var matchLabel: TextView
    private lateinit var tacticalMap: TacticalMapView
    private lateinit var abilityHint: TextView
    private lateinit var healthLabel: TextView
    private lateinit var dashActionButton: TextView
    private lateinit var pulseActionButton: TextView
    private lateinit var shieldActionButton: TextView
    private lateinit var attackActionButton: TextView
    private var abilityFeedbackUntilNanos = 0L
    private var screenLayer: View? = null
    private var state = AppState.BOOT
    private var moveX = 0f
    private var moveZ = 0f
    private var lastFrameNanos = 0L
    private var loopActive = false
    private var selectedHero = 0
    private var lastSnapshot = FloatArray(94)

    private external fun nativeReset()
    private external fun nativeSelectHero(hero: Int)
    private external fun nativeActivateDash(inputX: Float, inputZ: Float): Boolean
    private external fun nativeCastPulse(): Boolean
    private external fun nativeActivateShield(): Boolean
    private external fun nativeBasicAttack(): Boolean
    private external fun nativeStep(inputX: Float, inputZ: Float, deltaTime: Float): FloatArray

    private val frameCallback = object : Choreographer.FrameCallback {
        override fun doFrame(frameTimeNanos: Long) {
            if (!loopActive || isFinishing || isDestroyed) return
            val dt = if (lastFrameNanos == 0L) 1f / 60f
                else ((frameTimeNanos - lastFrameNanos) / 1_000_000_000.0).toFloat().coerceIn(0f, 0.05f)
            lastFrameNanos = frameTimeNanos

            if (state == AppState.RUNNING) {
                val result = nativeStep(moveX, moveZ, dt)
                if (result.size >= 94) {
                    lastSnapshot = result
                    renderer.update(result[0], result[1], result[2], result[34], result[35], dt)
                    renderer.updateBots(result, dt)
                    renderer.updateCreeps(result, dt)
                    renderer.updateEffects(result)
                    renderer.updateStructures(result)
                    tacticalMap.setSnapshot(result)
                    healthLabel.text = "VIDA  ${result[72].toInt().coerceIn(0, 100)}%  •  GOLPE MANUAL"
                    dashActionButton.text = abilityButtonText("IMPULSO", result[9])
                    pulseActionButton.text = abilityButtonText("PULSO", result[8])
                    shieldActionButton.text = abilityButtonText("ESCUDO", result[60])
                    attackActionButton.text = abilityButtonText("GOLPE", result[81])
                    dashActionButton.alpha = if (result[9] > 0.05f) 0.62f else 1f
                    pulseActionButton.alpha = if (result[8] > 0.05f) 0.62f else 1f
                    shieldActionButton.alpha = if (result[60] > 0.05f) 0.62f else 1f
                    attackActionButton.alpha = if (result[81] > 0.05f) 0.62f else 1f
                    if (System.nanoTime() > abilityFeedbackUntilNanos) {
                        abilityHint.text = when {
                            result[7] > 0.05f -> "ESCUDO ATIVO • reduz dano recebido"
                            result[61] > 0.05f -> "PULSO • atingiu heróis e tropas próximas"
                            result[62] > 0.05f -> "IMPULSO • reposicionamento direcional"
                            else -> "GOLPE seleciona o alvo próximo • tropas pressionam torres"
                        }
                    }

                    val time = result[4].toInt().coerceAtLeast(0)
                    matchLabel.text = String.format("%02d:%02d   •   LOCAL 5v5", time / 60, time % 60)
                    val blue = result[5].toInt()
                    val red = result[6].toInt()
                    stateLabel.text = "BAIXAS AZUIS " + blue + "  :  " + red + " VERMELHAS"
                    val enemyTowersDown = (0..2).count { result[76 + it] <= 0.0f }
                    val towerProgress = ((780f - result[76]) / 780f +
                        (780f - result[77]) / 780f + (780f - result[78]) / 780f) / 3f
                    val coreProgress = 1f - result[80] / 1600f
                    val siegeProgress = if (enemyTowersDown < 3) {
                        towerProgress * 0.75f
                    } else {
                        0.75f + coreProgress * 0.25f
                    }
                    objectiveProgress.progress = (siegeProgress.coerceIn(0f, 1f) * 100f).toInt()
                    objectiveLabel.text = if (enemyTowersDown < 3) {
                        "DERRUBE AS TORRES VERMELHAS  •  $enemyTowersDown/3"
                    } else {
                        "NÚCLEO VERMELHO  •  ${(result[80] / 16f).toInt().coerceIn(0, 100)}%"
                    }
                    if (result[15] > 0.5f) showResult(true)
                    else if (result[15] < -0.5f) showResult(false)
                }
            }

            try {
                renderer.render(frameTimeNanos)
            } catch (error: Throwable) {
                Log.e(TAG, "Frame failed; simulation paused", error)
                enterRecovery("O renderer encontrou uma falha recuperável.")
                return
            }
            Choreographer.getInstance().postFrameCallback(this)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
            )

        root = FrameLayout(this)
        surface = SurfaceView(this)
        root.addView(surface, FrameLayout.LayoutParams(-1, -1))
        setContentView(root)

        transition(AppState.DEVICE_PROBE)
        try {
            transition(AppState.VULKAN_INIT)
            transition(AppState.ASSET_LOADING)
            renderer = FilamentGameRenderer(this, surface)
            if (renderer.backendName == "OPENGL_ES") transition(AppState.GLES_FALLBACK)
            showMenu()
            root.post { renderer.resize(surface.width, surface.height) }
            startRenderLoop()
        } catch (error: Throwable) {
            Log.e(TAG, "Startup failed", error)
            enterRecovery("Não foi possível inicializar o renderer 3D.")
        }
    }

    private fun transition(next: AppState) {
        Log.i(TAG, "State: $state -> $next")
        state = next
    }

    private fun startRenderLoop() {
        if (loopActive) return
        loopActive = true
        lastFrameNanos = 0L
        Choreographer.getInstance().postFrameCallback(frameCallback)
    }

    private fun stopRenderLoop() {
        loopActive = false
        Choreographer.getInstance().removeFrameCallback(frameCallback)
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density + 0.5f).toInt()

    private fun label(text: String, size: Float, color: Int = Color.WHITE, bold: Boolean = false): TextView =
        TextView(this).apply {
            this.text = text
            textSize = size
            setTextColor(color)
            typeface = android.graphics.Typeface.create(
                "sans-serif",
                if (bold) android.graphics.Typeface.BOLD else android.graphics.Typeface.NORMAL
            )
            setShadowLayer(5f, 0f, 2f, Color.argb(160, 0, 0, 0))
        }

    private fun actionButton(text: String, onClick: () -> Unit): TextView =
        label(text, 13f, Color.rgb(238, 248, 230), true).apply {
            gravity = Gravity.CENTER
            setPadding(dp(14), dp(10), dp(14), dp(10))
            background = android.graphics.drawable.GradientDrawable().apply {
                setColor(Color.argb(220, 24, 48, 42))
                cornerRadius = dp(8).toFloat()
                setStroke(dp(1), Color.rgb(142, 207, 186))
            }
            isClickable = true
            isFocusable = true
            setOnClickListener { onClick() }
        }

    private fun replaceLayer(view: View) {
        screenLayer?.let { root.removeView(it) }
        screenLayer = view
        root.addView(view, FrameLayout.LayoutParams(-1, -1))
    }

    private fun showMenu() {
        transition(AppState.MENU)
        if (::renderer.isInitialized) renderer.setMinionsVisible(false)
        if (::renderer.isInitialized) {
            renderer.setOverviewCamera(true)
            renderer.setHeroAppearance(selectedHero)
        }

        // Preserve the existing menu composition: title and hero at the upper-left,
        // the live arena as the background, and the primary action at bottom-center.
        val layer = FrameLayout(this).apply {
            setBackgroundColor(Color.argb(10, 5, 12, 18))
            isFocusable = true
        }
        val title = label("ARENA", 17f, Color.WHITE, true).apply {
            setShadowLayer(8f, 0f, 3f, Color.BLACK)
        }
        layer.addView(title, FrameLayout.LayoutParams(-2, -2, Gravity.TOP or Gravity.START).apply {
            marginStart = dp(24)
            topMargin = dp(18)
        })

        val hero = label(HEROES[selectedHero], 10f, Color.rgb(203, 230, 226), true).apply {
            setShadowLayer(6f, 0f, 2f, Color.BLACK)
        }
        layer.addView(hero, FrameLayout.LayoutParams(-2, -2, Gravity.TOP or Gravity.START).apply {
            marginStart = dp(24)
            topMargin = dp(43)
        })

        val description = label(HERO_DESCRIPTIONS[selectedHero], 9.5f, Color.rgb(232, 239, 225)).apply {
            maxLines = 2
            setShadowLayer(5f, 0f, 2f, Color.BLACK)
        }
        layer.addView(description, FrameLayout.LayoutParams(dp(430), -2, Gravity.TOP or Gravity.START).apply {
            marginStart = dp(24)
            topMargin = dp(63)
        })

        val selectorHint = label("SELECIONE SEU HERÓI", 8f, Color.rgb(183, 205, 194), true)
        layer.addView(selectorHint, FrameLayout.LayoutParams(-2, -2, Gravity.TOP or Gravity.START).apply {
            marginStart = dp(24)
            topMargin = dp(94)
        })

        val selectedNumber = label("", 9f, Color.WHITE, true).apply {
            gravity = Gravity.CENTER
        }
        fun refreshHeroSelection() {
            hero.text = HEROES[selectedHero]
            description.text = HERO_DESCRIPTIONS[selectedHero]
            selectedNumber.text = "%02d / %02d".format(selectedHero + 1, HEROES.size)
            renderer.setHeroAppearance(selectedHero)
            nativeSelectHero(selectedHero)
        }
        val previousHero = actionButton("‹") {
            selectedHero = (selectedHero + HEROES.size - 1) % HEROES.size
            refreshHeroSelection()
        }.apply {
            textSize = 20f
            contentDescription = "Herói anterior"
        }
        layer.addView(previousHero, FrameLayout.LayoutParams(dp(42), dp(38), Gravity.TOP or Gravity.START).apply {
            marginStart = dp(24)
            topMargin = dp(111)
        })
        layer.addView(selectedNumber, FrameLayout.LayoutParams(dp(68), dp(38), Gravity.TOP or Gravity.START).apply {
            marginStart = dp(70)
            topMargin = dp(111)
        })
        val nextHero = actionButton("›") {
            selectedHero = (selectedHero + 1) % HEROES.size
            refreshHeroSelection()
        }.apply {
            textSize = 20f
            contentDescription = "Próximo herói"
        }
        layer.addView(nextHero, FrameLayout.LayoutParams(dp(42), dp(38), Gravity.TOP or Gravity.START).apply {
            marginStart = dp(142)
            topMargin = dp(111)
        })
        refreshHeroSelection()

        val matchInfo = label("PARTIDA LOCAL 5v5  •  TRÊS ROTAS  •  CERCO AO NÚCLEO",
            8.5f, Color.rgb(226, 235, 221), true).apply {
            gravity = Gravity.CENTER
            setShadowLayer(6f, 0f, 2f, Color.BLACK)
        }
        layer.addView(matchInfo, FrameLayout.LayoutParams(-2, dp(24), Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL).apply {
            bottomMargin = dp(62)
        })

        val play = actionButton("INICIAR PARTIDA") { startMatch() }
        layer.addView(play, FrameLayout.LayoutParams(dp(190), dp(42), Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL).apply {
            bottomMargin = dp(18)
        })
        replaceLayer(layer)
    }

    private fun startMatch() {
        nativeSelectHero(selectedHero)
        nativeReset()
        moveX = 0f
        moveZ = 0f
        lastSnapshot = FloatArray(94)
        transition(AppState.RUNNING)
        showHud()
    }

    private fun showHud() {
        if (::renderer.isInitialized) {
            renderer.setOverviewCamera(false)
            renderer.setMinionsVisible(true)
        }
        val layer = FrameLayout(this)
        val top = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(9), dp(6), dp(9), dp(6))
            background = android.graphics.drawable.GradientDrawable().apply {
                setColor(Color.argb(170, 10, 22, 29))
                cornerRadius = dp(7).toFloat()
            }
        }
        matchLabel = label("00:00", 10f, Color.WHITE, true)
        objectiveLabel = label("DERRUBE AS TORRES • DESTRUA O NÚCLEO", 10f, Color.rgb(192, 235, 221), true)
        healthLabel = label("VIDA  100%  •  GOLPE MANUAL", 8f, Color.rgb(173, 220, 194), true)
        abilityHint = label("GOLPE atinge alvos próximos • tropas avançam em ondas", 8f, Color.rgb(244, 217, 148), true)
        top.addView(matchLabel)
        top.addView(objectiveLabel)
        top.addView(healthLabel)
        top.addView(abilityHint)
        objectiveProgress = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = 100
            progress = 50
            progressTintList = android.content.res.ColorStateList.valueOf(Color.rgb(82, 202, 174))
            progressBackgroundTintList = android.content.res.ColorStateList.valueOf(Color.argb(100, 220, 230, 220))
        }
        top.addView(objectiveProgress, LinearLayout.LayoutParams(dp(220), dp(4)).apply {
            topMargin = dp(4)
        })
        layer.addView(top, FrameLayout.LayoutParams(dp(250), -2, Gravity.TOP or Gravity.START).apply {
            topMargin = dp(10)
            marginStart = dp(10)
        })

        stateLabel = label("BAIXAS AZUIS 0  :  0 VERMELHAS", 9f, Color.WHITE, true)
        layer.addView(stateLabel, FrameLayout.LayoutParams(-2, -2, Gravity.TOP or Gravity.CENTER_HORIZONTAL).apply {
            topMargin = dp(12)
        })

        tacticalMap = TacticalMapView(this)
        layer.addView(tacticalMap, FrameLayout.LayoutParams(dp(112), dp(84), Gravity.TOP or Gravity.END).apply {
            topMargin = dp(10)
            marginEnd = dp(58)
        })

        layer.addView(actionButton("Ⅱ") { pauseMatch() },
            FrameLayout.LayoutParams(dp(38), dp(38), Gravity.TOP or Gravity.END).apply {
                marginEnd = dp(10)
                topMargin = dp(10)
            })

        val stick = TouchStick(this) { x, z ->
            moveX = x
            moveZ = z
        }
        layer.addView(stick, FrameLayout.LayoutParams(dp(116), dp(116), Gravity.BOTTOM or Gravity.START).apply {
            marginStart = dp(14)
            bottomMargin = dp(14)
        })

        dashActionButton = actionButton("IMPULSO") {
            val activated = nativeActivateDash(moveX, moveZ)
            showAbilityFeedback(if (activated) "IMPULSO • avanço na direção do joystick" else "IMPULSO • aguarde a recarga")
        }
        layer.addView(dashActionButton, FrameLayout.LayoutParams(dp(108), dp(44), Gravity.BOTTOM or Gravity.END).apply {
            marginEnd = dp(12)
            bottomMargin = dp(16)
        })

        pulseActionButton = actionButton("PULSO") {
            val activated = nativeCastPulse()
            showAbilityFeedback(if (activated) "PULSO • 38 de dano em rivais próximos" else "PULSO • aproxime-se de um rival")
        }
        layer.addView(pulseActionButton, FrameLayout.LayoutParams(dp(104), dp(44), Gravity.BOTTOM or Gravity.END).apply {
            marginEnd = dp(128)
            bottomMargin = dp(16)
        })

        shieldActionButton = actionButton("ESCUDO") {
            val activated = nativeActivateShield()
            showAbilityFeedback(if (activated) "ESCUDO • reduz dano recebido por 3 segundos" else "ESCUDO • aguarde a recarga")
        }
        layer.addView(shieldActionButton, FrameLayout.LayoutParams(dp(108), dp(38), Gravity.BOTTOM or Gravity.END).apply {
            marginEnd = dp(12)
            bottomMargin = dp(68)
        })

        attackActionButton = actionButton("GOLPE") {
            val hit = nativeBasicAttack()
            showAbilityFeedback(if (hit) "GOLPE • alvo atingido" else "GOLPE • aproxime-se de um rival ou estrutura")
        }
        layer.addView(attackActionButton, FrameLayout.LayoutParams(dp(108), dp(38), Gravity.BOTTOM or Gravity.END).apply {
            marginEnd = dp(12)
            bottomMargin = dp(114)
        })
        tacticalMap.setSnapshot(lastSnapshot)
        replaceLayer(layer)
    }

    private fun abilityButtonText(name: String, cooldown: Float): String =
        if (cooldown > 0.05f) "$name  ${kotlin.math.ceil(cooldown).toInt()}s" else name

    private fun showAbilityFeedback(message: String) {
        abilityHint.text = message
        abilityFeedbackUntilNanos = System.nanoTime() + 1_600_000_000L
    }

    private fun signed(value: Int): String = when {
        value > 0 -> "+$value%"
        value < 0 -> "$value%"
        else -> "0%"
    }

    private fun pauseMatch() {
        if (state != AppState.RUNNING) return
        moveX = 0f
        moveZ = 0f
        transition(AppState.PAUSED)
        val layer = FrameLayout(this).apply {
            setBackgroundColor(Color.argb(170, 7, 17, 23))
        }
        val box = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(22), dp(20), dp(22), dp(20))
        }
        box.addView(label("PARTIDA PAUSADA", 26f, Color.WHITE, true).apply {
            gravity = Gravity.CENTER
            textAlignment = View.TEXT_ALIGNMENT_CENTER
        })
        box.addView(actionButton("CONTINUAR") {
            transition(AppState.RUNNING)
            showHud()
        }, LinearLayout.LayoutParams(dp(220), dp(48)).apply { topMargin = dp(18) })
        box.addView(actionButton("VOLTAR AO MENU") { showMenu() },
            LinearLayout.LayoutParams(dp(220), dp(48)).apply { topMargin = dp(10) })
        layer.addView(box, FrameLayout.LayoutParams(dp(500), -2, Gravity.CENTER))
        replaceLayer(layer)
    }

    private fun showResult(won: Boolean) {
        if (state != AppState.RUNNING) return
        moveX = 0f
        moveZ = 0f
        transition(AppState.RESULT)
        val layer = FrameLayout(this).apply {
            setBackgroundColor(Color.argb(190, 7, 18, 24))
        }
        val box = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
        }
        box.addView(label(if (won) "VITÓRIA AZUL" else "VITÓRIA VERMELHA", 28f, Color.WHITE, true))
        box.addView(label("O núcleo de uma equipe foi destruído.", 13f, Color.rgb(211, 234, 230)).apply {
            gravity = Gravity.CENTER
            setPadding(dp(12), dp(10), dp(12), dp(16))
        })
        box.addView(actionButton("NOVA PARTIDA") { startMatch() },
            LinearLayout.LayoutParams(dp(220), dp(48)))
        box.addView(actionButton("MENU PRINCIPAL") { showMenu() },
            LinearLayout.LayoutParams(dp(220), dp(48)).apply { topMargin = dp(10) })
        layer.addView(box, FrameLayout.LayoutParams(-1, -1))
        replaceLayer(layer)
    }

    private fun showNotice(message: String) {
        val layer = FrameLayout(this).apply {
            setBackgroundColor(Color.argb(192, 7, 18, 24))
        }
        val box = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
        }
        box.addView(label(message, 14f, Color.WHITE).apply {
            gravity = Gravity.CENTER
            setPadding(dp(30), dp(10), dp(30), dp(18))
        })
        box.addView(actionButton("VOLTAR") { showMenu() },
            LinearLayout.LayoutParams(dp(180), dp(46)))
        layer.addView(box, FrameLayout.LayoutParams(-1, -1))
        replaceLayer(layer)
    }

    private fun enterRecovery(message: String) {
        stopRenderLoop()
        transition(AppState.RECOVERY)
        val layer = FrameLayout(this).apply {
            setBackgroundColor(Color.rgb(14, 22, 29))
        }
        val box = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
        }
        box.addView(label("RECUPERAÇÃO", 26f, Color.WHITE, true))
        box.addView(label(message, 13f, Color.LTGRAY).apply {
            gravity = Gravity.CENTER
            setPadding(dp(28), dp(12), dp(28), dp(18))
        })
        box.addView(actionButton("REINICIAR TELA") { recreate() },
            LinearLayout.LayoutParams(dp(220), dp(48)))
        layer.addView(box, FrameLayout.LayoutParams(-1, -1))
        replaceLayer(layer)
    }

    override fun onPause() {
        if (state == AppState.RUNNING) pauseMatch()
        stopRenderLoop()
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        if (::renderer.isInitialized && state != AppState.RECOVERY) startRenderLoop()
    }

    override fun onDestroy() {
        stopRenderLoop()
        if (::renderer.isInitialized) renderer.destroy()
        super.onDestroy()
    }

    @Deprecated("Legacy back navigation")
    override fun onBackPressed() {
        when (state) {
            AppState.RUNNING -> pauseMatch()
            AppState.PAUSED -> {
                transition(AppState.RUNNING)
                showHud()
            }
            AppState.MENU, AppState.RESULT -> super.onBackPressed()
            else -> super.onBackPressed()
        }
    }
}

private class TacticalMapView(context: android.content.Context) : View(context) {
    private val backgroundPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.argb(210, 10, 27, 31)
        style = Paint.Style.FILL
    }
    private val lanePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.argb(140, 148, 188, 183)
        style = Paint.Style.STROKE
        strokeWidth = 3f
    }
    private val blueTowerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.rgb(94, 163, 205)
        style = Paint.Style.FILL
    }
    private val redTowerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.rgb(216, 117, 91)
        style = Paint.Style.FILL
    }
    private val destroyedTowerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.rgb(76, 83, 80)
        style = Paint.Style.FILL
    }
    private val bluePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.rgb(73, 210, 190)
        style = Paint.Style.FILL
    }
    private val redPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.rgb(230, 117, 95)
        style = Paint.Style.FILL
    }
    private val playerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        style = Paint.Style.FILL
    }
    private var snapshot = FloatArray(94)

    fun setSnapshot(values: FloatArray) {
        snapshot = values.copyOf()
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val left = 5f
        val top = 5f
        val right = width - 5f
        val bottom = height - 5f
        canvas.drawRoundRect(left, top, right, bottom, 10f, 10f, backgroundPaint)

        fun px(x: Float): Float = left + 9f + (x + 24f) / 48f * (right - left - 18f)
        fun py(z: Float): Float = top + 9f + (24f - z) / 48f * (bottom - top - 18f)

        for ((lane, laneX) in floatArrayOf(-12f, 0f, 12f).withIndex()) {
            canvas.drawLine(px(laneX), py(-22f), px(laneX), py(22f), lanePaint)
            val blueAlive = snapshot.size >= 94 && snapshot[73 + lane] > 0f
            val redAlive = snapshot.size >= 94 && snapshot[76 + lane] > 0f
            canvas.drawCircle(px(laneX), py(-12.2f), 3.5f,
                if (blueAlive) blueTowerPaint else destroyedTowerPaint)
            canvas.drawCircle(px(laneX), py(12.2f), 3.5f,
                if (redAlive) redTowerPaint else destroyedTowerPaint)
        }

        if (snapshot.size >= 34) {
            for (index in 0 until 9) {
                val x = snapshot[16 + index * 2]
                val z = snapshot[17 + index * 2]
                val paint = if (index < 4) bluePaint else redPaint
                canvas.drawCircle(px(x), py(z), 3.6f, paint)
            }
            canvas.drawCircle(px(snapshot[0]), py(snapshot[2]), 5f, playerPaint)
        }
    }
}

private class TouchStick(
    context: android.content.Context,
    private val onMove: (Float, Float) -> Unit
) : View(context) {
    private val basePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.argb(105, 20, 39, 45)
        style = Paint.Style.FILL
    }
    private val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.argb(205, 203, 231, 226)
        style = Paint.Style.STROKE
        strokeWidth = 3.2f
    }
    private val knobPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.argb(220, 124, 210, 195)
        style = Paint.Style.FILL
    }
    private var dx = 0f
    private var dy = 0f

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val cx = width * 0.5f
        val cy = height * 0.5f
        val radius = minOf(width, height) * 0.43f
        canvas.drawCircle(cx, cy, radius, basePaint)
        canvas.drawCircle(cx, cy, radius, ringPaint)
        canvas.drawCircle(cx + dx * radius * 0.72f, cy + dy * radius * 0.72f, radius * 0.34f, knobPaint)
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        val cx = width * 0.5f
        val cy = height * 0.5f
        val radius = minOf(width, height) * 0.43f
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_MOVE -> {
                val x = (event.x - cx) / (radius * 0.72f)
                val y = (event.y - cy) / (radius * 0.72f)
                val length = hypot(x, y).coerceAtLeast(1f)
                dx = x / length
                dy = y / length
                onMove(dx, dy)
                invalidate()
                return true
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                dx = 0f
                dy = 0f
                onMove(0f, 0f)
                invalidate()
                performClick()
                return true
            }
        }
        return true
    }

    override fun performClick(): Boolean {
        super.performClick()
        return true
    }
}
