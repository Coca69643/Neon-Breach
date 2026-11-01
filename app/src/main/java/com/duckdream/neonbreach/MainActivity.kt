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
    }

    init { System.loadLibrary("arena_sim") }

    private lateinit var root: FrameLayout
    private lateinit var surface: SurfaceView
    private lateinit var renderer: FilamentGameRenderer
    private lateinit var objectiveProgress: ProgressBar
    private lateinit var objectiveLabel: TextView
    private lateinit var stateLabel: TextView
    private lateinit var matchLabel: TextView
    private lateinit var laneLabel: TextView
    private lateinit var tacticalMap: TacticalMapView
    private var screenLayer: View? = null
    private var state = AppState.BOOT
    private var moveX = 0f
    private var moveZ = 0f
    private var lastFrameNanos = 0L
    private var loopActive = false
    private var selectedHero = 0
    private var lastSnapshot = FloatArray(36)

    private external fun nativeReset()
    private external fun nativeSelectHero(hero: Int)
    private external fun nativeActivateDash(): Boolean
    private external fun nativeCastPulse(): Boolean
    private external fun nativeActivateShield(): Boolean
    private external fun nativeStep(inputX: Float, inputZ: Float, deltaTime: Float): FloatArray

    private val frameCallback = object : Choreographer.FrameCallback {
        override fun doFrame(frameTimeNanos: Long) {
            if (!loopActive || isFinishing || isDestroyed) return
            val dt = if (lastFrameNanos == 0L) 1f / 60f
                else ((frameTimeNanos - lastFrameNanos) / 1_000_000_000.0).toFloat().coerceIn(0f, 0.05f)
            lastFrameNanos = frameTimeNanos

            if (state == AppState.RUNNING) {
                val result = nativeStep(moveX, moveZ, dt)
                if (result.size >= 36) {
                    lastSnapshot = result
                    renderer.update(result[0], result[1], result[2], result[34], result[35], dt)
                    renderer.updateBots(result, dt)
                    tacticalMap.setSnapshot(result)

                    val time = result[4].toInt().coerceAtLeast(0)
                    matchLabel.text = String.format("%02d:%02d   •   LOCAL 5v5", time / 60, time % 60)
                    val blue = result[5].toInt()
                    val red = result[6].toInt()
                    stateLabel.text = "AZUL " + blue + "  :  " + red + " VERMELHO"
                    val left = (result[12] * 100f).toInt()
                    val mid = (result[13] * 100f).toInt()
                    val right = (result[14] * 100f).toInt()
                    laneLabel.text = "OESTE " + signed(left) + "   CENTRO " + signed(mid) + "   LESTE " + signed(right)
                    val average = ((result[12] + result[13] + result[14]) / 6f + 0.5f)
                    objectiveProgress.progress = (average * 100f).toInt().coerceIn(0, 100)
                    objectiveLabel.text = when {
                        result[15] > 0.5f -> "DUAS ROTAS CONQUISTADAS"
                        result[15] < -0.5f -> "BASE AZUL SUPERADA"
                        result[7] > 0.0f -> "BARREIRA ATIVA  •  " + result[7].toInt() + "s"
                        result[8] > 0.0f -> "PULSO EM RECARGA  •  " + result[8].toInt() + "s"
                        else -> "CONTROLE AS ROTAS E AVANCE COM OS BOTS"
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
        if (::renderer.isInitialized) renderer.setOverviewCamera(true)
        val layer = FrameLayout(this).apply {
            setBackgroundColor(Color.argb(45, 7, 17, 23))
        }
        val left = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_VERTICAL
        }
        left.addView(label("DUCK DREAM STUDIOS  /  0.4.0", 10f, Color.rgb(190, 223, 224), true))
        left.addView(label("PROJETO ARENA", 32f, Color.WHITE, true).apply {
            setPadding(0, dp(8), 0, dp(4))
        })
        left.addView(label("MOBA 3D  •  PARTIDAS LOCAIS 5v5", 11f, Color.rgb(204, 229, 224)))
        left.addView(actionButton("HERÓI: " + HEROES[selectedHero]) {
            selectedHero = (selectedHero + 1) % HEROES.size
            showMenu()
        }, LinearLayout.LayoutParams(dp(270), dp(46)).apply { topMargin = dp(23) })
        left.addView(actionButton("JOGAR CONTRA BOTS") { startMatch() },
            LinearLayout.LayoutParams(dp(270), dp(52)).apply { topMargin = dp(12) })
        left.addView(actionButton("REGRAS DA PARTIDA") {
            showNotice("Partida 5v5 totalmente offline. Controle uma das três rotas, acompanhe seus quatro aliados e interrompa o avanço adversário com habilidades de ressonância.")
        }, LinearLayout.LayoutParams(dp(270), dp(46)).apply { topMargin = dp(10) })
        left.addView(label("SEM LOGIN  •  SEM SERVIDOR  •  SEM INTERNET", 9f, Color.LTGRAY).apply {
            setPadding(0, dp(18), 0, 0)
        })
        layer.addView(left, FrameLayout.LayoutParams(dp(310), -2, Gravity.START or Gravity.CENTER_VERTICAL).apply {
            marginStart = dp(32)
        })
        val footer = label("VULKAN / GLES  •  C++20  •  IA LOCAL", 9f, Color.WHITE, true)
        layer.addView(footer, FrameLayout.LayoutParams(-2, -2, Gravity.BOTTOM or Gravity.END).apply {
            marginEnd = dp(18)
            bottomMargin = dp(12)
        })
        replaceLayer(layer)
    }

    private fun startMatch() {
        nativeSelectHero(selectedHero)
        nativeReset()
        moveX = 0f
        moveZ = 0f
        lastSnapshot = FloatArray(36)
        transition(AppState.RUNNING)
        showHud()
    }

    private fun showHud() {
        if (::renderer.isInitialized) renderer.setOverviewCamera(false)
        val layer = FrameLayout(this)
        val top = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(12), dp(8), dp(12), dp(8))
            background = android.graphics.drawable.GradientDrawable().apply {
                setColor(Color.argb(188, 12, 29, 35))
                cornerRadius = dp(8).toFloat()
                setStroke(dp(1), Color.argb(170, 132, 192, 187))
            }
        }
        matchLabel = label("00:00   •   LOCAL 5v5", 10f, Color.rgb(176, 222, 213), true)
        objectiveLabel = label("CONTROLE AS TRÊS ROTAS", 12f, Color.WHITE, true)
        laneLabel = label("OESTE 0   CENTRO 0   LESTE 0", 9f, Color.rgb(207, 227, 221), true)
        top.addView(matchLabel)
        top.addView(objectiveLabel)
        top.addView(laneLabel)
        objectiveProgress = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = 100
            progress = 50
            progressTintList = android.content.res.ColorStateList.valueOf(Color.rgb(82, 202, 174))
            progressBackgroundTintList = android.content.res.ColorStateList.valueOf(Color.argb(110, 220, 230, 220))
        }
        top.addView(objectiveProgress, LinearLayout.LayoutParams(dp(285), dp(5)).apply {
            topMargin = dp(6)
        })
        layer.addView(top, FrameLayout.LayoutParams(dp(325), -2, Gravity.TOP or Gravity.CENTER_HORIZONTAL).apply {
            topMargin = dp(10)
        })

        stateLabel = label("AZUL 0  :  0 VERMELHO", 9f, Color.WHITE, true)
        layer.addView(stateLabel, FrameLayout.LayoutParams(-2, -2, Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL).apply {
            bottomMargin = dp(8)
        })

        tacticalMap = TacticalMapView(this)
        layer.addView(tacticalMap, FrameLayout.LayoutParams(dp(154), dp(116), Gravity.TOP or Gravity.END).apply {
            topMargin = dp(10)
            marginEnd = dp(70)
        })

        layer.addView(actionButton("Ⅱ") { pauseMatch() },
            FrameLayout.LayoutParams(dp(46), dp(42), Gravity.TOP or Gravity.END).apply {
                marginEnd = dp(12)
                topMargin = dp(10)
            })

        val stick = TouchStick(this) { x, z ->
            moveX = x
            moveZ = z
        }
        layer.addView(stick, FrameLayout.LayoutParams(dp(138), dp(138), Gravity.BOTTOM or Gravity.START).apply {
            marginStart = dp(18)
            bottomMargin = dp(18)
        })

        layer.addView(actionButton("IMPULSO") {
            stateLabel.text = if (nativeActivateDash()) "IMPULSO ATIVADO" else "IMPULSO EM RECARGA"
        }, FrameLayout.LayoutParams(dp(112), dp(50), Gravity.BOTTOM or Gravity.END).apply {
            marginEnd = dp(18)
            bottomMargin = dp(22)
        })
        layer.addView(actionButton("PULSO") {
            stateLabel.text = if (nativeCastPulse()) "PULSO DE RESSONÂNCIA" else "PULSO EM RECARGA"
        }, FrameLayout.LayoutParams(dp(108), dp(50), Gravity.BOTTOM or Gravity.END).apply {
            marginEnd = dp(142)
            bottomMargin = dp(22)
        })
        layer.addView(actionButton("BARREIRA") {
            stateLabel.text = if (nativeActivateShield()) "BARREIRA ATIVADA" else "BARREIRA EM RECARGA"
        }, FrameLayout.LayoutParams(dp(112), dp(42), Gravity.BOTTOM or Gravity.END).apply {
            marginEnd = dp(18)
            bottomMargin = dp(80)
        })
        tacticalMap.setSnapshot(lastSnapshot)
        replaceLayer(layer)
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
        if (::renderer.isInitialized) renderer.setOverviewCamera(true)
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
        if (::renderer.isInitialized) renderer.setOverviewCamera(true)
        val layer = FrameLayout(this).apply {
            setBackgroundColor(Color.argb(190, 7, 18, 24))
        }
        val box = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
        }
        box.addView(label(if (won) "VITÓRIA AZUL" else "VITÓRIA VERMELHA", 28f, Color.WHITE, true))
        box.addView(label("A partida local 5v5 terminou.", 13f, Color.rgb(211, 234, 230)).apply {
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
    private val towerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.rgb(208, 192, 139)
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
    private var snapshot = FloatArray(36)

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

        for (laneX in floatArrayOf(-12f, 0f, 12f)) {
            canvas.drawLine(px(laneX), py(-22f), px(laneX), py(22f), lanePaint)
            canvas.drawRect(px(laneX) - 3f, py(-11f) - 3f, px(laneX) + 3f, py(-11f) + 3f, towerPaint)
            canvas.drawRect(px(laneX) - 3f, py(11f) - 3f, px(laneX) + 3f, py(11f) + 3f, towerPaint)
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
