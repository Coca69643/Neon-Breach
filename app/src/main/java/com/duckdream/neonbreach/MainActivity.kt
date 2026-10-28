package com.duckdream.neonbreach

import android.app.Activity
import android.content.res.ColorStateList
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.content.Context
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.opengl.GLSurfaceView
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView

class MainActivity : Activity() {
    private lateinit var root: FrameLayout
    private lateinit var gameView: GameSurface
    private var currentLayer: View? = null
    private var currentScreen = Screen.MENU
    private var hasSession = false
    private var backgroundedDuringGame = false
    private var hapticsEnabled = true

    private lateinit var healthBar: ProgressBar
    private lateinit var healthValue: TextView
    private lateinit var objectiveText: TextView
    private lateinit var relayStatus: TextView
    private lateinit var threatStatus: TextView
    private lateinit var interactButton: TextView
    private lateinit var dodgeButton: TextView
    private lateinit var fireButton: TextView

    private val uiHandler = Handler(Looper.getMainLooper())
    private val pollState = object : Runnable {
        override fun run() {
            if (isFinishing || isDestroyed) return
            if (currentScreen == Screen.PLAYING) {
                updateHud(gameView.snapshot())
            }
            uiHandler.postDelayed(this, 180L)
        }
    }

    private enum class Screen { MENU, SETTINGS, PLAYING, PAUSED, RESULT }

    private val cyan = Color.rgb(190, 217, 134)
    private val white = Color.rgb(246, 241, 222)
    private val muted = Color.rgb(180, 174, 149)
    private val panel = Color.argb(220, 18, 23, 14)
    private val prefs by lazy { getSharedPreferences("neon_breach_settings", MODE_PRIVATE) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        hapticsEnabled = prefs.getBoolean("haptics", true)
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_FULLSCREEN or
            View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
            View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
            View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
        )
        root = FrameLayout(this)
        gameView = GameSurface(this)
        root.addView(gameView, FrameLayout.LayoutParams(-1, -1))
        setContentView(root)
        showMainMenu(false)
        uiHandler.postDelayed(pollState, 180L)
    }

    override fun onPause() {
        if (::gameView.isInitialized) {
            if (currentScreen == Screen.PLAYING) {
                backgroundedDuringGame = true
                gameView.setGameMode(2)
            }
            gameView.onPause()
        }
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        if (::gameView.isInitialized) gameView.onResume()
        if (backgroundedDuringGame && currentScreen == Screen.PLAYING) {
            backgroundedDuringGame = false
            showPause()
        }
    }

    override fun onDestroy() {
        uiHandler.removeCallbacks(pollState)
        super.onDestroy()
    }

    @Deprecated("Deprecated in Android API; handled for in-game navigation")
    override fun onBackPressed() {
        when (currentScreen) {
            Screen.PLAYING -> showPause()
            Screen.PAUSED -> resumeMission()
            Screen.SETTINGS -> showMainMenu(hasSession)
            Screen.RESULT -> showMainMenu(false)
            Screen.MENU -> super.onBackPressed()
        }
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density + 0.5f).toInt()

    private fun text(value: String, size: Float, color: Int = white, bold: Boolean = false): TextView {
        return TextView(this).apply {
            text = value
            textSize = size
            setTextColor(color)
            typeface = Typeface.create("sans-serif-condensed", if (bold) Typeface.BOLD else Typeface.NORMAL)
            setLineSpacing(0f, 1.06f)
            includeFontPadding = true
        }
    }

    private fun buttonBackground(accent: Boolean, enabled: Boolean = true): GradientDrawable {
        val strokeColor = if (accent) cyan else Color.rgb(91, 102, 69)
        val fill = if (accent) Color.argb(220, 48, 59, 30) else Color.argb(205, 27, 30, 20)
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(12).toFloat()
            setColor(if (enabled) fill else Color.argb(90, 24, 26, 18))
            setStroke(dp(1), if (enabled) strokeColor else Color.rgb(58, 61, 48))
        }
    }

    private fun actionButton(label: String, accent: Boolean = false, onClick: () -> Unit): TextView {
        return text(label, 15f, if (accent) cyan else white, true).apply {
            gravity = Gravity.CENTER
            setPadding(dp(12), dp(10), dp(12), dp(10))
            background = buttonBackground(accent)
            isClickable = true
            isFocusable = true
            setOnClickListener {
                if (hapticsEnabled) performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                onClick()
            }
        }
    }

    private fun addVertical(parent: LinearLayout, child: View, bottom: Int = 0, width: Int = -1, height: Int = -2) {
        parent.addView(child, LinearLayout.LayoutParams(width, height).apply {
            if (bottom > 0) bottomMargin = dp(bottom)
        })
    }

    private fun overlay(dim: Int, blockTouches: Boolean = true): FrameLayout {
        return FrameLayout(this).apply {
            setBackgroundColor(dim)
            isClickable = blockTouches
            isFocusable = blockTouches
        }
    }

    private fun attachLayer(layer: View) {
        currentLayer?.let { root.removeView(it) }
        currentLayer = layer
        root.addView(layer, FrameLayout.LayoutParams(-1, -1))
    }

    private fun showMainMenu(preserveMission: Boolean) {
        currentScreen = Screen.MENU
        gameView.setGameMode(if (preserveMission && hasSession) 6 else 0)
        // Keep the living terrain visible; the menu sits over the world instead of a full opaque card.
        val layer = overlay(Color.argb(86, 12, 16, 8))
        val left = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, dp(4), 0, dp(4))
        }
        addVertical(left, text("DUCK DREAM STUDIOS", 10f, cyan, true), 8)
        addVertical(left, text("NEON BREACH", 32f, white, true), 1)
        addVertical(left, text("EXPLORE. ENCONTRE SEU CAMINHO.", 11f, muted, true), 14)
        addVertical(left, actionButton("INICIAR EXPEDIÇÃO", true) { startNewMission() }, 7, dp(226), dp(43))
        val continueBtn = actionButton("CONTINUAR") { continueMission() }
        continueBtn.isEnabled = hasSession
        continueBtn.alpha = if (hasSession) 1f else 0.40f
        addVertical(left, continueBtn, 7, dp(226), dp(41))
        addVertical(left, actionButton("OPÇÕES") { showSettings() }, 7, dp(226), dp(41))
        addVertical(left, text("FRONTEIRA SELVAGEM  •  0.10.0", 9f, muted, true), 12)
        layer.addView(left, FrameLayout.LayoutParams(dp(252), -2, Gravity.START or Gravity.CENTER_VERTICAL).apply {
            marginStart = dp(28)
        })

        val right = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.START
            setPadding(dp(5), dp(6), dp(5), dp(6))
            isClickable = true
            setOnClickListener { }
        }
        addVertical(right, text("UM LUGAR ESQUECIDO", 12f, cyan, true), 8)
        addVertical(right, text("Ruínas cobertas pela mata.\nCriaturas que não ficam paradas.\nRecursos escondidos pela trilha.", 13f, white), 15)
        addVertical(right, text("3 MARCADORES\n4 CRIATURAS\n2 BROTOS RESTAURADORES", 10f, muted, true), 0)
        layer.addView(right, FrameLayout.LayoutParams(dp(205), -2, Gravity.END or Gravity.CENTER_VERTICAL).apply {
            marginEnd = dp(27)
        })
        attachLayer(layer)
    }

    private fun showSettings() {
        currentScreen = Screen.SETTINGS
        gameView.setGameMode(3)
        val layer = overlay(Color.argb(190, 12, 16, 8))
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(6), dp(4), dp(6), dp(4))
        }
        addVertical(content, text("CONFIGURAÇÕES", 30f, white, true), 4)
        addVertical(content, text("CONTROLES", 13f, cyan, true), 8)
        addVertical(content, text("ESQUERDA  —  MOVIMENTO\nDIREITA  —  MIRA E DISPARO\nAPROXIME-SE DE UM MARCADOR OU BROTO E INTERAJA.", 15f, white), 18)
        val hapticLabel = if (hapticsEnabled) "VIBRAÇÃO DE INTERFACE: LIGADA" else "VIBRAÇÃO DE INTERFACE: DESLIGADA"
        val haptics = actionButton(hapticLabel, hapticsEnabled) {
            hapticsEnabled = !hapticsEnabled
            prefs.edit().putBoolean("haptics", hapticsEnabled).apply()
            showSettings()
        }
        addVertical(content, haptics, 22, dp(330), dp(48))
        addVertical(content, actionButton("VOLTAR") { showMainMenu(hasSession) }, 10, dp(330), dp(46))
        layer.addView(content, FrameLayout.LayoutParams(dp(350), -2, Gravity.CENTER))
        attachLayer(layer)
    }

    private fun startNewMission() {
        hasSession = true
        gameView.startNewMission()
        showGame()
    }

    private fun continueMission() {
        if (!hasSession) return
        showGame()
    }

    private fun showGame() {
        currentScreen = Screen.PLAYING
        gameView.setGameMode(1)
        attachLayer(createHudLayer())
        updateHud(gameView.snapshot())
    }

    private fun showPause() {
        if (currentScreen != Screen.PLAYING) return
        currentScreen = Screen.PAUSED
        hasSession = true
        gameView.setGameMode(2)
        val layer = overlay(Color.argb(168, 12, 16, 8))
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(8), dp(4), dp(8), dp(4))
        }
        addVertical(content, text("PAUSA", 27f, white, true), 6)
        addVertical(content, text("A expedição continua daqui quando voltar.", 13f, muted), 18)
        addVertical(content, actionButton("RETOMAR", true) { resumeMission() }, 8, dp(270), dp(46))
        addVertical(content, actionButton("REINICIAR OPERAÇÃO") { startNewMission() }, 8, dp(270), dp(46))
        addVertical(content, actionButton("VOLTAR AO MENU") {
            gameView.setGameMode(6)
            showMainMenu(true)
        }, 8, dp(270), dp(46))
        layer.addView(content, FrameLayout.LayoutParams(-2, -2, Gravity.CENTER))
        attachLayer(layer)
    }

    private fun resumeMission() {
        if (!hasSession) return
        showGame()
    }

    private fun createHudLayer(): View {
        val layer = overlay(Color.TRANSPARENT, false)
        val left = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(13), dp(9), dp(13), dp(9))
            background = GradientDrawable().apply {
                cornerRadius = dp(11).toFloat()
                setColor(Color.argb(170, 20, 25, 14))
                setStroke(dp(1), Color.argb(140, 109, 128, 68))
            }
            isClickable = true
            setOnClickListener { }
        }
        addVertical(left, text("NEON BREACH  /  FRONTEIRA", 12f, cyan, true), 5)
        val healthRow = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL }
        healthValue = text("100%", 12f, white, true)
        healthRow.addView(text("VITALIDADE", 11f, muted, true), LinearLayout.LayoutParams(0, -2, 1f))
        healthRow.addView(healthValue, LinearLayout.LayoutParams(-2, -2))
        addVertical(left, healthRow, 3)
        healthBar = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = 100
            progress = 100
            progressTintList = ColorStateList.valueOf(cyan)
            progressBackgroundTintList = ColorStateList.valueOf(Color.rgb(30, 47, 58))
        }
        addVertical(left, healthBar, 7, dp(245), dp(10))
        relayStatus = text("MARCADORES  0 / 3", 12f, white, true)
        addVertical(left, relayStatus, 3)
        threatStatus = text("CRIATURAS  0 / 4 CONTIDAS", 11f, muted, true)
        addVertical(left, threatStatus, 0)
        layer.addView(left, FrameLayout.LayoutParams(dp(275), -2, Gravity.START or Gravity.TOP).apply {
            marginStart = dp(15); topMargin = dp(13)
        })

        objectiveText = text("ENCONTRE OS MARCADORES", 12f, white, true).apply {
            gravity = Gravity.CENTER
            setPadding(dp(12), dp(8), dp(12), dp(8))
            background = GradientDrawable().apply {
                cornerRadius = dp(11).toFloat()
                setColor(Color.argb(184, 24, 29, 16))
                setStroke(dp(1), Color.argb(145, 109, 128, 68))
            }
            isClickable = true
            setOnClickListener { }
        }
        layer.addView(objectiveText, FrameLayout.LayoutParams(dp(335), -2, Gravity.TOP or Gravity.CENTER_HORIZONTAL).apply { topMargin = dp(14) })
        val pause = actionButton("Ⅱ  PAUSAR") { showPause() }
        layer.addView(pause, FrameLayout.LayoutParams(dp(112), dp(42), Gravity.END or Gravity.TOP).apply {
            marginEnd = dp(16); topMargin = dp(14)
        })

        val joystick = VirtualJoystick(this)
        layer.addView(joystick, FrameLayout.LayoutParams(dp(150), dp(150), Gravity.START or Gravity.BOTTOM).apply {
            marginStart = dp(20); bottomMargin = dp(16)
        })
        fireButton = holdButton("DISPARAR", true, onDown = { gameView.setFiring(true) }, onUp = { gameView.setFiring(false) })
        layer.addView(fireButton, FrameLayout.LayoutParams(dp(132), dp(58), Gravity.END or Gravity.BOTTOM).apply {
            marginEnd = dp(20); bottomMargin = dp(18)
        })
        dodgeButton = actionButton("ESQUIVA") { gameView.dodge() }.apply { textSize = 13f }
        layer.addView(dodgeButton, FrameLayout.LayoutParams(dp(104), dp(46), Gravity.END or Gravity.BOTTOM).apply {
            marginEnd = dp(164); bottomMargin = dp(24)
        })
        interactButton = actionButton("INTERAGIR", true) {
            gameView.interact()
            updateHud(gameView.snapshot())
        }.apply { isEnabled = false; alpha = 0.62f }
        layer.addView(interactButton, FrameLayout.LayoutParams(dp(208), dp(42), Gravity.END or Gravity.BOTTOM).apply {
            marginEnd = dp(20); bottomMargin = dp(88)
        })
        return layer
    }

    private fun holdButton(label: String, accent: Boolean, onDown: () -> Unit, onUp: () -> Unit): TextView {
        return text(label, 15f, if (accent) cyan else white, true).apply {
            gravity = Gravity.CENTER
            setPadding(dp(12), dp(10), dp(12), dp(10))
            background = buttonBackground(accent)
            isClickable = true
            isFocusable = true
            setOnClickListener { }
            setOnTouchListener { view, event ->
                when (event.actionMasked) {
                    MotionEvent.ACTION_DOWN -> {
                        if (hapticsEnabled) view.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                        onDown()
                        true
                    }
                    MotionEvent.ACTION_UP -> { onUp(); view.performClick(); true }
                    MotionEvent.ACTION_CANCEL, MotionEvent.ACTION_OUTSIDE -> { onUp(); true }
                    else -> true
                }
            }
        }
    }

    private inner class VirtualJoystick(context: Context) : View(context) {
        private val baseFill = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.argb(145, 4, 16, 28) }
        private val baseStroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(220, 190, 217, 134); style = Paint.Style.STROKE; strokeWidth = dp(2).toFloat()
        }
        private val innerStroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.argb(110, 135, 194, 210); style = Paint.Style.STROKE; strokeWidth = dp(1).toFloat()
        }
        private val knobFill = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.argb(220, 82, 106, 53) }
        private val knobStroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.rgb(160, 241, 250); style = Paint.Style.STROKE; strokeWidth = dp(2).toFloat()
        }
        private var pointerId = -1
        private var knobX = 0f
        private var knobY = 0f
        init { isClickable = true; contentDescription = "Joystick de movimento" }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val cx = width * 0.5f; val cy = height * 0.5f; val radius = minOf(width, height) * 0.43f
            canvas.drawCircle(cx, cy, radius, baseFill)
            canvas.drawCircle(cx, cy, radius, baseStroke)
            canvas.drawCircle(cx, cy, radius * 0.58f, innerStroke)
            canvas.drawCircle(cx + knobX, cy + knobY, radius * 0.34f, knobFill)
            canvas.drawCircle(cx + knobX, cy + knobY, radius * 0.34f, knobStroke)
        }

        override fun onTouchEvent(event: MotionEvent): Boolean {
            val cx = width * 0.5f; val cy = height * 0.5f; val radius = minOf(width, height) * 0.43f * 0.70f
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    pointerId = event.getPointerId(event.actionIndex)
                    gameView.controlTouch(0, cx, cy)
                    updateStick(event.getX(event.actionIndex), event.getY(event.actionIndex), cx, cy, radius)
                    return true
                }
                MotionEvent.ACTION_MOVE -> {
                    val index = event.findPointerIndex(pointerId)
                    if (index >= 0) updateStick(event.getX(index), event.getY(index), cx, cy, radius)
                    return true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    gameView.controlTouch(2, cx + knobX, cy + knobY)
                    pointerId = -1; knobX = 0f; knobY = 0f; invalidate(); performClick()
                    return true
                }
                MotionEvent.ACTION_POINTER_UP -> {
                    if (event.getPointerId(event.actionIndex) == pointerId) {
                        gameView.controlTouch(2, cx + knobX, cy + knobY)
                        pointerId = -1; knobX = 0f; knobY = 0f; invalidate()
                    }
                    return true
                }
            }
            return true
        }

        private fun updateStick(x: Float, y: Float, cx: Float, cy: Float, radius: Float) {
            var dx = x - cx; var dy = y - cy
            val distance = kotlin.math.sqrt(dx * dx + dy * dy)
            if (distance > radius && distance > 0f) { dx = dx / distance * radius; dy = dy / distance * radius }
            knobX = dx; knobY = dy
            gameView.controlTouch(1, cx + knobX, cy + knobY)
            invalidate()
        }
        override fun performClick(): Boolean { super.performClick(); return true }
    }

    private fun updateHud(snapshot: Int) {
        if (currentScreen != Screen.PLAYING || !::healthBar.isInitialized) return
        val mode = snapshot and 7
        val health = (snapshot ushr 3) and 127
        val relayMask = (snapshot ushr 10) and 7
        val enemiesLeft = (snapshot ushr 13) and 7
        val nearRelay = (snapshot and (1 shl 16)) != 0
        val nearPod = (snapshot and (1 shl 18)) != 0
        val dodgeReady = (snapshot and (1 shl 17)) != 0
        val relaysDone = Integer.bitCount(relayMask)
        healthBar.progress = health.coerceIn(0, 100)
        healthBar.progressTintList = ColorStateList.valueOf(if (health <= 28) Color.rgb(255, 67, 82) else cyan)
        healthValue.text = "$health%"
        relayStatus.text = "MARCADORES  $relaysDone / 3"
        threatStatus.text = "CRIATURAS  ${4 - enemiesLeft} / 4 CONTIDAS"
        objectiveText.text = when {
            relaysDone < 3 -> "EXPLORE A ÁREA  /  ATIVE OS MARCADORES"
            enemiesLeft > 0 -> "A TRILHA ESTÁ BLOQUEADA  /  CRIATURAS NA ÁREA"
            else -> "CAMINHO ABERTO  /  SIGA AS PEDRAS CLARAS"
        }
        interactButton.text = when {
            nearPod -> "COLHER SEIVA"
            nearRelay -> "ATIVAR MARCADOR"
            else -> "APROXIME-SE"
        }
        interactButton.isEnabled = nearRelay || nearPod
        interactButton.alpha = if (nearRelay || nearPod) 1f else 0.62f
        interactButton.background = buttonBackground(true, nearRelay || nearPod)
        dodgeButton.text = if (dodgeReady) "ESQUIVA" else "RECARGA"
        dodgeButton.isEnabled = dodgeReady
        dodgeButton.alpha = if (dodgeReady) 1f else 0.48f
        dodgeButton.background = buttonBackground(dodgeReady, dodgeReady)
        if (mode == 4 || mode == 5) showResult(mode == 4)
    }

    private fun showResult(victory: Boolean) {
        if (currentScreen != Screen.PLAYING) return
        currentScreen = Screen.RESULT
        hasSession = false
        val layer = overlay(Color.argb(190, 12, 16, 8))
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(8), dp(4), dp(8), dp(4))
        }
        addVertical(content, text(if (victory) "EXPEDIÇÃO CONCLUÍDA" else "EXPEDIÇÃO INTERROMPIDA", 29f,
            if (victory) Color.rgb(61, 244, 170) else Color.rgb(255, 81, 97), true), 8)
        addVertical(content, text(if (victory) "A trilha está aberta. Você chegou ao destino." else "A vitalidade acabou. Tente outra rota.", 14f, muted), 20)
        addVertical(content, actionButton(if (victory) "NOVA OPERAÇÃO" else "TENTAR NOVAMENTE", true) { startNewMission() }, 8, dp(280), dp(48))
        addVertical(content, actionButton("MENU PRINCIPAL") { showMainMenu(false) }, 8, dp(280), dp(46))
        layer.addView(content, FrameLayout.LayoutParams(-2, -2, Gravity.CENTER))
        attachLayer(layer)
    }

    private class GameSurface(context: android.content.Context) : GLSurfaceView(context) {
        private val renderer = NativeRenderer()
        private var movePointerId = INVALID_POINTER
        private var aimPointerId = INVALID_POINTER

        init {
            setEGLContextClientVersion(3)
            preserveEGLContextOnPause = false
            setRenderer(renderer)
            renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY
            isFocusable = true
            isFocusableInTouchMode = true
        }

        fun setGameMode(mode: Int) {
            queueEvent { renderer.setGameModeOnGlThread(mode) }
        }

        fun startNewMission() {
            queueEvent { renderer.startNewMissionOnGlThread() }
        }

        fun interact() {
            queueEvent { nativeTouch(7, 0f, 0f, width.toFloat(), height.toFloat()) }
        }
        fun controlTouch(action: Int, x: Float, y: Float) = sendTouch(action, x, y)
        fun setFiring(active: Boolean) = sendTouch(if (active) 8 else 9, 0f, 0f)
        fun dodge() = sendTouch(10, 0f, 0f)

        fun snapshot(): Int = renderer.readSnapshot()

        override fun onTouchEvent(event: MotionEvent): Boolean {
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN, MotionEvent.ACTION_POINTER_DOWN -> startPointer(event, event.actionIndex)
                MotionEvent.ACTION_MOVE -> {
                    for (i in 0 until event.pointerCount) {
                        val id = event.getPointerId(i)
                        when (id) {
                            movePointerId -> sendTouch(1, event.getX(i), event.getY(i))
                            aimPointerId -> sendTouch(4, event.getX(i), event.getY(i))
                        }
                    }
                }
                MotionEvent.ACTION_POINTER_UP, MotionEvent.ACTION_UP -> {
                    finishPointer(event, event.actionIndex)
                    if (event.actionMasked == MotionEvent.ACTION_UP) {
                        movePointerId = INVALID_POINTER
                        aimPointerId = INVALID_POINTER
                    }
                }
                MotionEvent.ACTION_CANCEL -> {
                    movePointerId = INVALID_POINTER
                    aimPointerId = INVALID_POINTER
                    sendTouch(6, 0f, 0f)
                }
            }
            return true
        }

        private fun startPointer(event: MotionEvent, index: Int) {
            val id = event.getPointerId(index)
            val x = event.getX(index)
            val y = event.getY(index)
            if (x < width * 0.50f && movePointerId == INVALID_POINTER) {
                movePointerId = id
                sendTouch(0, x, y)
            } else if (aimPointerId == INVALID_POINTER) {
                aimPointerId = id
                sendTouch(3, x, y)
            } else if (movePointerId == INVALID_POINTER) {
                movePointerId = id
                sendTouch(0, x, y)
            }
        }

        private fun finishPointer(event: MotionEvent, index: Int) {
            val id = event.getPointerId(index)
            when (id) {
                movePointerId -> { sendTouch(2, event.getX(index), event.getY(index)); movePointerId = INVALID_POINTER }
                aimPointerId -> { sendTouch(5, event.getX(index), event.getY(index)); aimPointerId = INVALID_POINTER }
            }
        }

        private fun sendTouch(action: Int, x: Float, y: Float) {
            val w = width.toFloat()
            val h = height.toFloat()
            queueEvent { nativeTouch(action, x, y, w, h) }
        }

        private external fun nativeTouch(action: Int, x: Float, y: Float, w: Float, h: Float)

        companion object {
            private const val INVALID_POINTER = -1
            init { System.loadLibrary("neonbreach") }
        }
    }

}

private class NativeRenderer : GLSurfaceView.Renderer {
        override fun onSurfaceCreated(
            gl: javax.microedition.khronos.opengles.GL10?,
            config: javax.microedition.khronos.egl.EGLConfig?
        ) = nativeSurfaceCreated()

        override fun onSurfaceChanged(
            gl: javax.microedition.khronos.opengles.GL10?,
            width: Int,
            height: Int
        ) = nativeSurfaceChanged(width, height)

        override fun onDrawFrame(gl: javax.microedition.khronos.opengles.GL10?) = nativeDrawFrame()

        fun setGameModeOnGlThread(mode: Int) = nativeSetMode(mode)
        fun startNewMissionOnGlThread() = nativeStartNewMission()
        fun readSnapshot(): Int = nativeGetSnapshot()

        private external fun nativeSurfaceCreated()
        private external fun nativeSurfaceChanged(width: Int, height: Int)
        private external fun nativeDrawFrame()
        private external fun nativeSetMode(mode: Int)
        private external fun nativeStartNewMission()
        private external fun nativeGetSnapshot(): Int

        companion object {
            init { System.loadLibrary("neonbreach") }
        }
}
