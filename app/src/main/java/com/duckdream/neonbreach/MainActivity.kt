package com.duckdream.neonbreach

import android.app.Activity
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
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
        private val HERO_NAMES = arrayOf("LYRA", "BASTION", "KAIRO")
        private val HERO_ROLES = arrayOf("SUPORTE", "DEFENSOR", "MOBILIDADE")
        private val HERO_SUMMARIES = arrayOf(
            "Mantém a equipe de pé e ajuda a abrir espaço nas lutas.",
            "Segura a linha de frente e aguenta mais tempo sob pressão.",
            "Entra e sai dos confrontos com deslocamento mais rápido."
        )
        private val HERO_ABILITY_NAMES = arrayOf("AURA", "IMPACTO", "ONDA")
        private val HERO_ABILITY_DETAILS = arrayOf(
            "Recupera aliados próximos e enfraquece rivais dentro da área.",
            "Causa dano em área maior e mantém o escudo ativo por mais tempo.",
            "Pulso de recarga curta e impulso com maior velocidade."
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
    private lateinit var levelGoldLabel: TextView
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
    private var sensitivityIndex = 1
    private val sensitivityLevels = floatArrayOf(0.78f, 1.0f, 1.22f)
    private var lastSnapshot = FloatArray(320)

    private external fun nativeReset()
    private external fun nativeSelectHero(hero: Int)
    private external fun nativeActivateDash(inputX: Float, inputZ: Float): Boolean
    private external fun nativeCastPulse(): Boolean
    private external fun nativeActivateShield(): Boolean
    private external fun nativeBasicAttack(): Boolean
    private external fun nativeBuyItem(item: Int): Boolean
    private external fun nativeUpgradeSkill(): Boolean
    private external fun nativeStep(inputX: Float, inputZ: Float, deltaTime: Float): FloatArray

    private val frameCallback = object : Choreographer.FrameCallback {
        override fun doFrame(frameTimeNanos: Long) {
            if (!loopActive || isFinishing || isDestroyed) return
            val dt = if (lastFrameNanos == 0L) 1f / 60f
                else ((frameTimeNanos - lastFrameNanos) / 1_000_000_000.0).toFloat().coerceIn(0f, 0.05f)
            lastFrameNanos = frameTimeNanos

            if (state == AppState.RUNNING) {
                val result = nativeStep(moveX, moveZ, dt)
                if (result.size >= 320) {
                    lastSnapshot = result
                    renderer.updatePlayerSignals(result)
                    renderer.update(result[0], result[1], result[2], result[34], result[35], dt)
                    renderer.updateBots(result, dt)
                    renderer.updateCreeps(result, dt)
                    renderer.updateEffects(result)
                    renderer.updateStructures(result)
                    tacticalMap.setSnapshot(result)
                    healthLabel.text = if (result[95] > 0.01f) {
                        "RETORNO  ${kotlin.math.ceil(result[95]).toInt()}s  •  QUEDAS ${result[94].toInt()}"
                    } else {
                        "VIDA  ${result[72].toInt().coerceIn(0, result[100].toInt())}/${result[100].toInt()}  •  QUEDAS ${result[94].toInt()}"
                    }
                    val xpNeed = result[99].toInt().coerceAtLeast(1)
                    levelGoldLabel.text = "NV ${result[96].toInt()}  •  XP ${result[97].toInt()}/$xpNeed  •  OURO ${result[98].toInt()}"
                    dashActionButton.text = abilityButtonText("IMPULSO", result[9])
                    pulseActionButton.text = abilityButtonText(activeAbilityName(), result[8])
                    shieldActionButton.text = abilityButtonText("ESCUDO", result[60])
                    attackActionButton.text = abilityButtonText("GOLPE", result[81])
                    dashActionButton.alpha = if (result[9] > 0.05f) 0.62f else 1f
                    pulseActionButton.alpha = if (result[8] > 0.05f) 0.62f else 1f
                    shieldActionButton.alpha = if (result[60] > 0.05f) 0.62f else 1f
                    attackActionButton.alpha = if (result[81] > 0.05f) 0.62f else 1f
                    if (System.nanoTime() > abilityFeedbackUntilNanos) {
                        abilityHint.text = when {
                            result[95] > 0.01f -> "RETORNO À BASE • aguarde antes de voltar ao combate"
                            result[7] > 0.05f -> "ESCUDO ATIVO • reduz dano recebido"
                            result[61] > 0.05f -> "${activeAbilityName()} • habilidade acionada"
                            result[62] > 0.05f -> "IMPULSO • reposicionamento direcional"
                            else -> activeAbilityHint()
                        }
                    }

                    val time = result[4].toInt().coerceAtLeast(0)
                    matchLabel.text = String.format("%02d:%02d   •   LOCAL 5v5", time / 60, time % 60)
                    val blue = result[5].toInt()
                    val red = result[6].toInt()
                    stateLabel.text = "BAIXAS AZUIS " + blue + "  :  " + red + " VERMELHAS"
                    val enemyTowersDown = (0 until 9).count { result[116 + it] <= 0.0f }
                    val towerHealth = (0 until 9).sumOf { result[116 + it].toDouble() }.toFloat()
                    val towerProgress = 1f - (towerHealth / (820f * 9f)).coerceIn(0f, 1f)
                    val coreProgress = 1f - result[80] / 2200f
                    val siegeProgress = if (enemyTowersDown < 9) towerProgress * 0.78f
                        else 0.78f + coreProgress * 0.22f
                    objectiveProgress.progress = (siegeProgress.coerceIn(0f, 1f) * 100f).toInt()
                    val neutralObjective = when {
                        result[104] > 0f -> "GUARDIÃO DO RIO ATIVO"
                        result[106] > 0f -> "SENTINELA ANCESTRAL ATIVA"
                        result[103] > 0f && result[105] > 0f ->
                            "GUARDIÃO ${kotlin.math.ceil(result[103]).toInt()}s • SENTINELA ${kotlin.math.ceil(result[105]).toInt()}s"
                        result[103] > 0f -> "GUARDIÃO DO RIO  •  ${kotlin.math.ceil(result[103]).toInt()}s"
                        else -> "SENTINELA ANCESTRAL  •  ${kotlin.math.ceil(result[105]).toInt()}s"
                    }
                    objectiveLabel.text = if (enemyTowersDown < 9) {
                        "TORRES VERMELHAS $enemyTowersDown/9  •  $neutralObjective"
                    } else {
                        "NÚCLEO VERMELHO  •  ${(result[80] / 22f).toInt().coerceIn(0, 100)}%  •  $neutralObjective"
                    }
                    if (result[15] > 0.5f) showResult(true)
                    else if (result[15] < -0.5f) showResult(false)
                }
            }

            try {
                if (state != AppState.MENU) renderer.render(frameTimeNanos)
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
        loadMenuSettings()

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

    private fun primaryActionButton(text: String, onClick: () -> Unit): TextView =
        actionButton(text, onClick).apply {
            textSize = 15f
            setTextColor(Color.rgb(28, 38, 31))
            background = android.graphics.drawable.GradientDrawable().apply {
                setColor(Color.rgb(205, 165, 91))
                cornerRadius = dp(8).toFloat()
                setStroke(dp(1), Color.rgb(239, 213, 151))
            }
        }

    private fun replaceLayer(view: View) {
        screenLayer?.let { root.removeView(it) }
        screenLayer = view
        root.addView(view, FrameLayout.LayoutParams(-1, -1))
    }

    private fun panel(): android.graphics.drawable.GradientDrawable =
        android.graphics.drawable.GradientDrawable().apply {
            setColor(Color.argb(218, 15, 29, 31))
            cornerRadius = dp(10).toFloat()
            setStroke(dp(1), Color.argb(170, 138, 180, 161))
        }

    private fun loadMenuSettings() {
        sensitivityIndex = getSharedPreferences("arena_settings", MODE_PRIVATE)
            .getInt("movement_sensitivity", 1).coerceIn(0, sensitivityLevels.lastIndex)
    }

    private fun sensitivityLabel(): String = when (sensitivityIndex) {
        0 -> "BAIXA  •  78%"
        2 -> "ALTA  •  122%"
        else -> "NORMAL  •  100%"
    }

    private fun cycleSensitivity() {
        sensitivityIndex = (sensitivityIndex + 1) % sensitivityLevels.size
        getSharedPreferences("arena_settings", MODE_PRIVATE).edit()
            .putInt("movement_sensitivity", sensitivityIndex).apply()
    }

    private fun activeAbilityName(): String = HERO_ABILITY_NAMES[selectedHero]
    private fun activeAbilityHint(): String = HERO_ABILITY_DETAILS[selectedHero]

    private fun showMenu() {
        transition(AppState.MENU)
        renderer.setMinionsVisible(false)
        renderer.setOverviewCamera(true)
        renderer.setHeroAppearance(selectedHero, ArenaMetaStore.isSkinEquipped(this, selectedHero))

        val layer = FrameLayout(this)
        layer.addView(ArenaMenuArtworkView(this), FrameLayout.LayoutParams(-1, -1))

        val header = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(24), dp(20), dp(12), dp(8))
        }
        header.addView(label("ARENA", 27f, Color.WHITE, true).apply { letterSpacing = 0.13f })
        header.addView(label("A BATALHA PELAS TRÊS ROTAS", 10f, Color.rgb(229, 207, 164), true))
        layer.addView(header, FrameLayout.LayoutParams(-2, -2, Gravity.TOP or Gravity.START))

        val accountBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        accountBar.addView(label(
            "MOEDAS ${ArenaMetaStore.coins(this@MainActivity)}   •   FRAGMENTOS ${ArenaMetaStore.shards(this@MainActivity)}",
            9f, Color.rgb(247, 219, 160), true
        ).apply { setPadding(0, 0, dp(8), 0) })
        accountBar.addView(actionButton("?") { showGuide() },
            LinearLayout.LayoutParams(dp(38), dp(36)).apply { marginEnd = dp(6) })
        accountBar.addView(actionButton("⚙") { showSettings() },
            LinearLayout.LayoutParams(dp(42), dp(36)))
        layer.addView(accountBar, FrameLayout.LayoutParams(-2, -2, Gravity.TOP or Gravity.END).apply {
            topMargin = dp(18)
            marginEnd = dp(20)
        })

        val featured = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(22), dp(6), dp(8), dp(8))
            isClickable = true
            isFocusable = true
            setOnClickListener { showHeroSelect() }
        }
        featured.addView(label("HERÓI EM DESTAQUE", 9f, Color.rgb(225, 204, 159), true))
        featured.addView(label(HERO_NAMES[selectedHero], 28f, Color.WHITE, true).apply {
            setPadding(0, dp(2), 0, 0)
        })
        featured.addView(label(HERO_ROLES[selectedHero], 10f, Color.rgb(242, 197, 118), true))
        featured.addView(label(HERO_SUMMARIES[selectedHero], 10f, Color.rgb(236, 234, 218)).apply {
            maxWidth = dp(238)
            setPadding(0, dp(5), 0, 0)
        })
        layer.addView(featured, FrameLayout.LayoutParams(dp(258), -2, Gravity.BOTTOM or Gravity.START).apply {
            bottomMargin = dp(20)
        })

        val dock = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        dock.addView(actionButton("HERÓIS") { showHeroSelect() },
            LinearLayout.LayoutParams(dp(82), dp(42)).apply { marginEnd = dp(6) })
        dock.addView(actionButton("COLEÇÃO") { showSkins() },
            LinearLayout.LayoutParams(dp(88), dp(42)).apply { marginEnd = dp(6) })
        dock.addView(actionButton("PERFIL") { showMissionsProfile() },
            LinearLayout.LayoutParams(dp(76), dp(42)).apply { marginEnd = dp(8) })
        dock.addView(primaryActionButton("JOGAR") { startMatch() },
            LinearLayout.LayoutParams(dp(126), dp(52)))
        layer.addView(dock, FrameLayout.LayoutParams(-2, -2, Gravity.BOTTOM or Gravity.END).apply {
            marginEnd = dp(20)
            bottomMargin = dp(20)
        })
        replaceLayer(layer)
    }

    private fun showHeroSelect() {
        transition(AppState.MENU)
        renderer.setMinionsVisible(false)
        renderer.setOverviewCamera(true)
        renderer.setHeroAppearance(selectedHero)

        val layer = FrameLayout(this)
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(18), dp(16), dp(18), dp(16))
            background = panel()
        }
        content.addView(label("SELEÇÃO DE HERÓI", 18f, Color.WHITE, true))
        content.addView(label("Escolha quem vai liderar a equipe azul.", 10f, Color.rgb(204, 221, 210)).apply {
            setPadding(0, dp(3), 0, dp(13))
        })
        content.addView(label(HERO_NAMES[selectedHero], 25f, Color.WHITE, true))
        content.addView(label(HERO_ROLES[selectedHero], 10f, Color.rgb(236, 194, 123), true))
        content.addView(label(HERO_SUMMARIES[selectedHero], 11f, Color.rgb(221, 229, 216)).apply {
            setPadding(0, dp(8), 0, dp(8))
        })
        content.addView(label("HABILIDADE  •  ${activeAbilityName()}", 10f, Color.rgb(173, 215, 197), true))
        content.addView(label(activeAbilityHint(), 10f, Color.rgb(221, 229, 216)).apply {
            setPadding(0, dp(3), 0, dp(12))
        })
        val controls = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        controls.addView(actionButton("‹") {
            selectedHero = (selectedHero + HERO_NAMES.size - 1) % HERO_NAMES.size
            showHeroSelect()
        }, LinearLayout.LayoutParams(dp(52), dp(42)))
        controls.addView(actionButton("›") {
            selectedHero = (selectedHero + 1) % HERO_NAMES.size
            showHeroSelect()
        }, LinearLayout.LayoutParams(dp(52), dp(42)).apply { marginStart = dp(8) })
        content.addView(controls)
        content.addView(actionButton("CONFIRMAR HERÓI") { showMenu() },
            LinearLayout.LayoutParams(dp(220), dp(42)).apply { topMargin = dp(12) })
        layer.addView(content, FrameLayout.LayoutParams(dp(300), -2, Gravity.CENTER_VERTICAL or Gravity.START).apply {
            marginStart = dp(22)
        })
        layer.addView(actionButton("VOLTAR") { showMenu() },
            FrameLayout.LayoutParams(dp(112), dp(40), Gravity.TOP or Gravity.END).apply {
                topMargin = dp(18)
                marginEnd = dp(20)
            })
        replaceLayer(layer)
    }

    private fun showGuide() {
        transition(AppState.MENU)
        val layer = FrameLayout(this)
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(18), dp(16), dp(18), dp(16))
            background = panel()
        }
        content.addView(label("COMO JOGAR", 20f, Color.WHITE, true))
        content.addView(label("A partida é vencida ao destruir o núcleo vermelho.", 11f, Color.rgb(235, 218, 170)).apply {
            setPadding(0, dp(5), 0, dp(12))
        })
        val instructions = listOf(
            "ROTAS  •  Jogue na sua rota e acompanhe o avanço das tropas.",
            "SELVA  •  Derrote acampamentos neutros para ganhar ouro e XP.",
            "OBJETIVOS  •  Dispute o Guardião do Rio e a Sentinela Ancestral.",
            "GOLPE  •  Ataca heróis, tropas, acampamentos ou estruturas próximas.",
            "PROGRESSÃO  •  Ganhe XP, suba de nível e melhore a habilidade.",
            "LOJA  •  Gaste ouro em vida/defesa, poder ou redução de recarga.",
            "CERCO  •  Use a tropa aliada para avançar pelas três torres de cada rota."
        )
        instructions.forEach { line ->
            content.addView(label(line, 10f, Color.rgb(221, 229, 216)).apply {
                setPadding(0, dp(4), 0, dp(4))
            })
        }
        content.addView(actionButton("ENTENDI") { showMenu() },
            LinearLayout.LayoutParams(dp(180), dp(42)).apply { topMargin = dp(14) })
        layer.addView(content, FrameLayout.LayoutParams(dp(450), -2, Gravity.CENTER))
        replaceLayer(layer)
    }

    private fun showSettings() {
        transition(AppState.MENU)
        val layer = FrameLayout(this)
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(18), dp(16), dp(18), dp(16))
            background = panel()
        }
        content.addView(label("AJUSTES", 20f, Color.WHITE, true))
        content.addView(label("CONTROLES", 10f, Color.rgb(236, 194, 123), true).apply {
            setPadding(0, dp(12), 0, dp(5))
        })
        val sensitivity = label("Sensibilidade do direcional: ${sensitivityLabel()}", 11f, Color.rgb(221, 229, 216))
        content.addView(sensitivity)
        content.addView(actionButton("ALTERAR SENSIBILIDADE") {
            cycleSensitivity()
            sensitivity.text = "Sensibilidade do direcional: ${sensitivityLabel()}"
        }, LinearLayout.LayoutParams(dp(250), dp(42)).apply { topMargin = dp(9) })
        content.addView(label("RENDERIZAÇÃO", 10f, Color.rgb(236, 194, 123), true).apply {
            setPadding(0, dp(14), 0, dp(5))
        })
        content.addView(label("Backend ativo: ${renderer.backendName}. O jogo ajusta a resolução dinamicamente.", 10f, Color.rgb(221, 229, 216)))
        content.addView(actionButton("VOLTAR") { showMenu() },
            LinearLayout.LayoutParams(dp(180), dp(42)).apply { topMargin = dp(16) })
        layer.addView(content, FrameLayout.LayoutParams(dp(390), -2, Gravity.CENTER))
        replaceLayer(layer)
    }

    private fun showSkins() {
        val owned = ArenaMetaStore.hasSkin(this, selectedHero)
        metaScreen("COLEÇÃO DE SKINS", "Personalização cosmética do herói", listOf(
            HERO_NAMES[selectedHero] + " • visual clássico: desbloqueado",
            "Visual alternativo: " + (if (owned) "desbloqueado" else "500 Moedas de Arena"),
            "Moedas: " + ArenaMetaStore.coins(this) + " • Fragmentos: " + ArenaMetaStore.shards(this),
            "Skins não alteram atributos de combate."
        ), listOf((
            if (owned) "EQUIPAR VISUAL ALTERNATIVO" else "COMPRAR POR 500 MOEDAS"
        ) to {
            if (owned) { ArenaMetaStore.equipSkin(this, selectedHero, true); showSkins() }
            else if (ArenaMetaStore.buySkin(this, selectedHero, 500)) showSkins()
            else showNotice("Moedas insuficientes.")
        }, "USAR VISUAL CLÁSSICO" to { ArenaMetaStore.equipSkin(this, selectedHero, false); showSkins() },
            "ABRIR LOJA" to { showShop() }))
    }

    private fun showShop() {
        metaScreen("LOJA DA ARENA", "Economia local com preços fixos", listOf(
            "Troca: 120 Fragmentos = 500 Moedas de Arena",
            "Sem caixas aleatórias e sem compras com dinheiro real.",
            "Saldo: " + ArenaMetaStore.coins(this) + " moedas • " + ArenaMetaStore.shards(this) + " fragmentos"
        ), listOf("TROCAR FRAGMENTOS" to {
            if (ArenaMetaStore.exchange(this, 120, 500)) showShop() else showNotice("Fragmentos insuficientes.")
        }))
    }

    private fun showMissionsProfile() {
        val p = ArenaMetaStore.stats(this)
        metaScreen("MISSÕES E PERFIL", "Progresso salvo localmente", listOf(
            "Nível " + p[0] + " • XP " + p[1] + "/500",
            "Partidas: " + p[2] + " • Vitórias: " + p[3],
            "Contrato: conclua 3 partidas para receber 250 moedas e 30 fragmentos.",
            "Progresso do contrato: " + (p[2] % 3) + "/3",
            "Saldo: " + ArenaMetaStore.coins(this) + " moedas • " + ArenaMetaStore.shards(this) + " fragmentos"
        ), emptyList())
    }

    private fun metaScreen(title: String, subtitle: String, rows: List<String>, actions: List<Pair<String, () -> Unit>>) {
        transition(AppState.MENU)
        renderer.setOverviewCamera(true)
        val layer = FrameLayout(this)
        val box = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(dp(20), dp(18), dp(20), dp(18)); background = panel() }
        box.addView(label(title, 21f, Color.WHITE, true))
        box.addView(label(subtitle, 10f, Color.rgb(236, 194, 123), true))
        rows.forEach { row -> box.addView(label(row, 11f, Color.rgb(225, 232, 219)).apply { setPadding(0, dp(5), 0, dp(5)) }) }
        actions.forEach { (caption, callback) -> box.addView(actionButton(caption, callback), LinearLayout.LayoutParams(dp(270), dp(40)).apply { topMargin = dp(7) }) }
        box.addView(actionButton("VOLTAR AO HUB") { showMenu() }, LinearLayout.LayoutParams(dp(270), dp(40)).apply { topMargin = dp(12) })
        layer.addView(box, FrameLayout.LayoutParams(dp(430), -2, Gravity.CENTER))
        replaceLayer(layer)
    }
    private fun startMatch() {
        nativeSelectHero(selectedHero)
        nativeReset()
        renderer.resetHeroAnimationState()
        moveX = 0f
        moveZ = 0f
        lastSnapshot = FloatArray(320)
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
        healthLabel = label("VIDA  100/100  •  QUEDAS 0", 8f, Color.rgb(173, 220, 194), true)
        levelGoldLabel = label("NV 1  •  XP 0/220  •  OURO 500", 8f, Color.rgb(245, 213, 145), true)
        abilityHint = label(activeAbilityHint(), 8f, Color.rgb(244, 217, 148), true)
        top.addView(matchLabel)
        top.addView(objectiveLabel)
        top.addView(healthLabel)
        top.addView(levelGoldLabel)
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
        layer.addView(tacticalMap, FrameLayout.LayoutParams(dp(138), dp(102), Gravity.TOP or Gravity.END).apply {
            topMargin = dp(10)
            marginEnd = dp(58)
        })

        layer.addView(actionButton("LOJA") { showMatchShop() },
            FrameLayout.LayoutParams(dp(72), dp(36), Gravity.TOP or Gravity.END).apply {
                marginEnd = dp(58)
                topMargin = dp(120)
            })
        layer.addView(actionButton("Ⅱ") { pauseMatch() },
            FrameLayout.LayoutParams(dp(38), dp(38), Gravity.TOP or Gravity.END).apply {
                marginEnd = dp(10)
                topMargin = dp(10)
            })

        val stick = TouchStick(this) { x, z ->
            val scale = sensitivityLevels[sensitivityIndex]
            moveX = (x * scale).coerceIn(-1f, 1f)
            // Touch coordinates grow downward; world +Z is toward the upper screen.
            moveZ = (-z * scale).coerceIn(-1f, 1f)
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

        pulseActionButton = actionButton(activeAbilityName()) {
            val activated = nativeCastPulse()
            if (activated) renderer.triggerAbilityGesture()
            val feedback = if (activated) activeAbilityHint() else when (selectedHero) {
                0 -> "AURA • sem aliados feridos ou rivais próximos"
                1 -> "IMPACTO • aguarde a recarga"
                else -> "ONDA • aguarde a recarga"
            }
            showAbilityFeedback(feedback)
        }
        layer.addView(pulseActionButton, FrameLayout.LayoutParams(dp(104), dp(44), Gravity.BOTTOM or Gravity.END).apply {
            marginEnd = dp(128)
            bottomMargin = dp(16)
        })

        shieldActionButton = actionButton("ESCUDO") {
            val activated = nativeActivateShield()
            if (activated) renderer.triggerGuardGesture()
            showAbilityFeedback(if (activated) "ESCUDO • reduz dano recebido por 3 segundos" else "ESCUDO • aguarde a recarga")
        }
        layer.addView(shieldActionButton, FrameLayout.LayoutParams(dp(108), dp(38), Gravity.BOTTOM or Gravity.END).apply {
            marginEnd = dp(12)
            bottomMargin = dp(68)
        })

        attackActionButton = actionButton("GOLPE") {
            val hit = nativeBasicAttack()
            if (hit) renderer.triggerActionPulse()
            showAbilityFeedback(if (hit) "GOLPE • alvo atingido" else "GOLPE • aproxime-se de um rival ou estrutura")
        }
        layer.addView(attackActionButton, FrameLayout.LayoutParams(dp(108), dp(38), Gravity.BOTTOM or Gravity.END).apply {
            marginEnd = dp(12)
            bottomMargin = dp(114)
        })
        tacticalMap.setSnapshot(lastSnapshot)
        replaceLayer(layer)
    }


    private fun showMatchShop() {
        if (state != AppState.RUNNING) return
        val layer = FrameLayout(this).apply {
            setBackgroundColor(Color.argb(176, 7, 17, 23))
        }
        val box = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(18), dp(16), dp(18), dp(16))
            background = panel()
        }
        fun refreshShop() {
            val data = nativeStep(0f, 0f, 0f)
            if (data.size >= 320) lastSnapshot = data
            val gold = lastSnapshot[98].toInt()
            val level = lastSnapshot[96].toInt()
            val skill = lastSnapshot[289].toInt()
            box.removeAllViews()
            box.addView(label("LOJA DA PARTIDA", 20f, Color.WHITE, true))
            box.addView(label("OURO $gold  •  NÍVEL $level  •  ITENS ${lastSnapshot[286].toInt()}/${lastSnapshot[287].toInt()}/${lastSnapshot[288].toInt()}", 10f, Color.rgb(242, 209, 141), true))
            box.addView(actionButton("VITALIDADE + DEFESA  •  250 OURO") {
                if (nativeBuyItem(0)) refreshShop() else showAbilityFeedback("OURO INSUFICIENTE OU LIMITE DE ITENS")
            }, LinearLayout.LayoutParams(dp(340), dp(42)).apply { topMargin = dp(8) })
            box.addView(actionButton("PODER DE COMBATE  •  300 OURO") {
                if (nativeBuyItem(1)) refreshShop() else showAbilityFeedback("OURO INSUFICIENTE OU LIMITE DE ITENS")
            }, LinearLayout.LayoutParams(dp(340), dp(42)).apply { topMargin = dp(7) })
            box.addView(actionButton("AGILIDADE / RECARGA  •  280 OURO") {
                if (nativeBuyItem(2)) refreshShop() else showAbilityFeedback("OURO INSUFICIENTE OU LIMITE DE ITENS")
            }, LinearLayout.LayoutParams(dp(340), dp(42)).apply { topMargin = dp(7) })
            val canUpgrade = level > skill && skill < 5
            box.addView(actionButton(if (canUpgrade) "MELHORAR HABILIDADE  •  PONTO DISPONÍVEL" else "HABILIDADE  •  NV $skill / 5") {
                if (nativeUpgradeSkill()) refreshShop() else showAbilityFeedback("GANHE UM NÍVEL PARA RECEBER UM PONTO")
            }, LinearLayout.LayoutParams(dp(340), dp(42)).apply { topMargin = dp(7) })
            box.addView(actionButton("VOLTAR À PARTIDA") { showHud() },
                LinearLayout.LayoutParams(dp(340), dp(42)).apply { topMargin = dp(12) })
        }
        refreshShop()
        layer.addView(box, FrameLayout.LayoutParams(-2, -2, Gravity.CENTER))
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
        ArenaMetaStore.recordMatch(this, won)
        val layer = FrameLayout(this).apply {
            setBackgroundColor(Color.argb(190, 7, 18, 24))
        }
        val box = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
        }
        box.addView(label(if (won) "VITÓRIA AZUL" else "VITÓRIA VERMELHA", 28f, Color.WHITE, true))
        box.addView(label(if (won) "RECOMPENSA  +120 MOEDAS  •  +12 FRAGMENTOS" else "RECOMPENSA  +70 MOEDAS  •  +6 FRAGMENTOS", 11f, Color.rgb(236, 194, 123), true))
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
        color = Color.argb(224, 10, 27, 31)
        style = Paint.Style.FILL
    }
    private val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.argb(175, 153, 190, 174)
        style = Paint.Style.STROKE
        strokeWidth = 1.4f
    }
    private val lanePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.argb(180, 185, 179, 143)
        style = Paint.Style.STROKE
        strokeWidth = 3.2f
    }
    private val riverPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.argb(205, 55, 122, 147)
        style = Paint.Style.STROKE
        strokeWidth = 5.5f
    }
    private val blueTowerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.rgb(104, 183, 226)
        style = Paint.Style.FILL
    }
    private val redTowerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.rgb(224, 113, 88)
        style = Paint.Style.FILL
    }
    private val destroyedTowerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.rgb(74, 82, 79)
        style = Paint.Style.FILL
    }
    private val blueMinionPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.rgb(90, 205, 195)
        style = Paint.Style.FILL
    }
    private val redMinionPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.rgb(236, 144, 104)
        style = Paint.Style.FILL
    }
    private val blueBotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.rgb(74, 162, 220)
        style = Paint.Style.FILL
    }
    private val redBotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.rgb(214, 92, 77)
        style = Paint.Style.FILL
    }
    private val campPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.rgb(216, 183, 101)
        style = Paint.Style.FILL
    }
    private val objectivePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.rgb(247, 215, 120)
        style = Paint.Style.STROKE
        strokeWidth = 2.4f
    }
    private val playerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        style = Paint.Style.FILL
    }
    private var snapshot = FloatArray(320)

    fun setSnapshot(values: FloatArray) {
        snapshot = values.copyOf()
        invalidate()
    }

    private fun laneX(lane: Int, z: Float): Float {
        val bend = kotlin.math.sin((z + 4f) * 0.105f) * 1.15f
        return when (lane) {
            0 -> -14.2f + bend
            1 -> 0.5f + kotlin.math.sin(z * 0.12f) * 0.72f
            else -> 14.2f - bend * 0.82f
        }
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val left = 4f
        val top = 4f
        val right = width - 4f
        val bottom = height - 4f
        canvas.drawRoundRect(left, top, right, bottom, 10f, 10f, backgroundPaint)

        fun px(x: Float): Float = left + 8f + (x + 34f) / 68f * (right - left - 16f)
        fun py(z: Float): Float = top + 8f + (30f - z) / 60f * (bottom - top - 16f)

        // Three distinct, curved lanes.
        for (lane in 0..2) {
            val line = Path()
            for (step in 0..30) {
                val z = -30f + step * 2f
                val x = px(laneX(lane, z))
                val y = py(z)
                if (step == 0) line.moveTo(x, y) else line.lineTo(x, y)
            }
            canvas.drawPath(line, lanePaint)
        }

        // The river links both jungles and the three lane crossings.
        val river = Path()
        val riverPoints = arrayOf(
            floatArrayOf(-34f, 1.1f), floatArrayOf(-28f, 0.55f), floatArrayOf(-21f, 0.05f),
            floatArrayOf(-15f, -0.45f), floatArrayOf(-9f, -0.22f), floatArrayOf(-3f, 0.25f),
            floatArrayOf(4f, 0.38f), floatArrayOf(10f, 0.02f), floatArrayOf(16f, -0.38f),
            floatArrayOf(23f, -0.18f), floatArrayOf(29f, 0.22f), floatArrayOf(34f, 0.8f)
        )
        riverPoints.forEachIndexed { index, point ->
            if (index == 0) river.moveTo(px(point[0]), py(point[1]))
            else river.lineTo(px(point[0]), py(point[1]))
        }
        canvas.drawPath(river, riverPaint)

        if (snapshot.size >= 320) {
            // All 18 defensive towers: three tiers per lane, mirrored by team.
            for (team in 0..1) {
                for (lane in 0..2) {
                    for (tier in 0..2) {
                        val index = team * 9 + lane * 3 + tier
                        val z = (if (team == 0) -1f else 1f) * when (tier) {
                            0 -> 8f
                            1 -> 15f
                            else -> 22f
                        }
                        val x = laneX(lane, z)
                        val alive = snapshot[107 + index] > 0f
                        val paint = if (!alive) destroyedTowerPaint else if (team == 0) blueTowerPaint else redTowerPaint
                        canvas.drawCircle(px(x), py(z), 2.5f, paint)
                    }
                }
            }

            // Neutral camps appear only while their creatures are alive.
            val campPositions = arrayOf(
                floatArrayOf(-8.2f, -14.5f), floatArrayOf(8.2f, -14.5f),
                floatArrayOf(-20.2f, -10f), floatArrayOf(20.2f, -10f),
                floatArrayOf(-8.2f, 14.5f), floatArrayOf(8.2f, 14.5f),
                floatArrayOf(-20.2f, 10f), floatArrayOf(20.2f, 10f)
            )
            campPositions.forEachIndexed { index, point ->
                if (snapshot[270 + index] > 0f) canvas.drawCircle(px(point[0]), py(point[1]), 2.4f, campPaint)
            }

            // River objective pits have a distinct marker when active.
            if (snapshot[104] > 0f) canvas.drawCircle(px(-7f), py(0.2f), 5f, objectivePaint)
            if (snapshot[106] > 0f) canvas.drawCircle(px(7f), py(0.2f), 5f, objectivePaint)

            // Minion waves and team units.
            for (index in 0 until 48) {
                if (snapshot[222 + index] <= 0f) continue
                val x = snapshot[126 + index * 2]
                val z = snapshot[127 + index * 2]
                canvas.drawCircle(px(x), py(z), 1.55f, if (index < 24) blueMinionPaint else redMinionPaint)
            }
            // Player and five-v-five AI heroes.
            for (index in 0 until 9) {
                val x = snapshot[16 + index * 2]
                val z = snapshot[17 + index * 2]
                canvas.drawCircle(px(x), py(z), 2.6f, if (index < 4) blueBotPaint else redBotPaint)
            }
            canvas.drawCircle(px(snapshot[0]), py(snapshot[2]), 3.3f, playerPaint)
        }
        canvas.drawRoundRect(left, top, right, bottom, 10f, 10f, borderPaint)
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
