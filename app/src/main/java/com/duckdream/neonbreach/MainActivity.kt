package com.duckdream.neonbreach

import android.app.Activity
import android.content.res.ColorStateList
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Typeface
import android.content.Context
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.media.AudioManager
import android.media.ToneGenerator
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.opengl.GLSurfaceView
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.SeekBar
import android.widget.TextView

class MainActivity : Activity() {
    private lateinit var root: FrameLayout
    private lateinit var gameView: GameSurface
    private var currentLayer: View? = null
    private var currentScreen = Screen.MENU
    private var hasSession = false
    private var backgroundedDuringGame = false
    private var hapticsEnabled = true
    private var selectedOperative = 0
    private var soundEnabled = true
    private var touchSensitivity = 1.0f
    private var toneGenerator: ToneGenerator? = null

    private lateinit var objectiveText: TextView
    private lateinit var relayStatus: TextView
    private lateinit var threatStatus: TextView
    private lateinit var progressText: TextView
    private lateinit var interactButton: TextView
    private lateinit var dodgeButton: DodgeControlButton
    private lateinit var fireButton: FireControlButton

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

    private enum class Screen { MENU, OPERATIVES, SETTINGS, PLAYING, PAUSED, RESULT }

    private val cyan = Color.rgb(72, 220, 232)
    private val amber = Color.rgb(255, 166, 75)
    private val white = Color.rgb(246, 241, 222)
    private val muted = Color.rgb(180, 174, 149)
    private val panel = Color.argb(220, 18, 23, 14)
    private val prefs by lazy { getSharedPreferences("neon_breach_settings", MODE_PRIVATE) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        hapticsEnabled = prefs.getBoolean("haptics", true)
        selectedOperative = prefs.getInt("operative", 0).coerceIn(0, 1)
        soundEnabled = prefs.getBoolean("sound_enabled", true)
        touchSensitivity = prefs.getFloat("touch_sensitivity", 1.0f).coerceIn(0.5f, 1.5f)
        toneGenerator = try { ToneGenerator(AudioManager.STREAM_MUSIC, 55) } catch (_: RuntimeException) { null }
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
        gameView.setOperative(selectedOperative)
        gameView.setTouchSensitivity(touchSensitivity)
        gameView.setGameSoundEnabled(soundEnabled)
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
        toneGenerator?.release()
        toneGenerator = null
        super.onDestroy()
    }

    @Deprecated("Deprecated in Android API; handled for in-game navigation")
    override fun onBackPressed() {
        when (currentScreen) {
            Screen.PLAYING -> showPause()
            Screen.PAUSED -> resumeMission()
            Screen.OPERATIVES -> showMainMenu(hasSession)
            Screen.SETTINGS -> showMainMenu(hasSession)
            Screen.RESULT -> showMainMenu(false)
            Screen.MENU -> super.onBackPressed()
        }
    }

    private fun operativeName(): String = if (selectedOperative == 0) "NEON-VANGUARD" else "STELLAR-REAPER"

    private fun playGameTone(tone: Int = ToneGenerator.TONE_PROP_BEEP, durationMs: Int = 55) {
        if (soundEnabled) toneGenerator?.startTone(tone, durationMs)
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

    private fun menuCommandButton(label: String, accent: Boolean = false, onClick: () -> Unit): TextView {
        return text(if (accent) "▸  $label" else "›  $label", 12f, if (accent) cyan else white, true).apply {
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(10), dp(5), dp(8), dp(5))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(4).toFloat()
                setColor(if (accent) Color.argb(112, 12, 50, 58) else Color.argb(28, 18, 31, 36))
                setStroke(dp(1), if (accent) Color.argb(190, 42, 207, 221) else Color.argb(76, 132, 157, 164))
            }
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
        // Keep the environment visible; actions remain in a compact left-side column.
        val layer = overlay(Color.argb(78, 8, 12, 16))
        val left = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, dp(4), 0, dp(4))
        }
        addVertical(left, text("DUCK DREAM STUDIOS", 10f, cyan, true), 8)
        addVertical(left, text("NEON BREACH", 32f, white, true), 1)
        addVertical(left, View(this).apply { setBackgroundColor(cyan) }, 8, dp(176), dp(2))
        addVertical(left, text("PROTOCOLO DE CONTENÇÃO", 11f, muted, true), 8)
        addVertical(left, text("OPERADOR  ${operativeName()}", 12f, amber, true), 10)
        addVertical(left, menuCommandButton("INICIAR OPERAÇÃO", true) { startNewMission() }, 6, dp(181), dp(35))
        val continueBtn = menuCommandButton("CONTINUAR") { continueMission() }
        continueBtn.isEnabled = hasSession
        continueBtn.alpha = if (hasSession) 1f else 0.40f
        addVertical(left, continueBtn, 6, dp(181), dp(33))
        addVertical(left, menuCommandButton("ESCOLHER OPERADOR") { showOperativeSelect() }, 6, dp(181), dp(33))
        addVertical(left, menuCommandButton("CONFIGURAÇÕES") { showSettings() }, 6, dp(181), dp(33))
        addVertical(left, text("SITE ORION-9  •  0.5", 9f, muted, true), 10)
        layer.addView(left, FrameLayout.LayoutParams(dp(225), -2, Gravity.START or Gravity.CENTER_VERTICAL).apply {
            marginStart = dp(28)
        })
        attachLayer(layer)
    }

    private fun showOperativeSelect() {
        currentScreen = Screen.OPERATIVES
        gameView.setGameMode(if (hasSession) 6 else 0)
        val layer = overlay(Color.argb(112, 4, 10, 15))
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(8), dp(6), dp(8), dp(6))
        }
        addVertical(content, text("SELECIONE SEU OPERADOR", 25f, white, true), 5)
        addVertical(content, text("Duas identidades de combate com padrões de disparo diferentes.", 12f, muted), 14)
        val names = arrayOf("NEON-VANGUARD", "STELLAR-REAPER")
        val roles = arrayOf("TIRO DUPLO", "DISPARO EM CONE")
        val descriptions = arrayOf(
            "Armadura azul-neon. Velocidade padrão e dois projéteis paralelos por rajada.",
            "Armadura dourada. Movimento 20% mais rápido e três projéteis em leque."
        )
        val stats = arrayOf("AZUL #00E5FF\nVELOCIDADE 100%", "DOURADO #FFD600\nVELOCIDADE 120%")
        val row = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER }
        for (index in names.indices) {
            val selected = index == selectedOperative
            val card = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER_HORIZONTAL
                setPadding(dp(10), dp(10), dp(10), dp(10))
                background = GradientDrawable().apply {
                    cornerRadius = dp(12).toFloat()
                    setColor(Color.argb(if (selected) 202 else 142, 13, 24, 31))
                    setStroke(dp(if (selected) 2 else 1), if (selected) cyan else Color.argb(100, 147, 166, 169))
                }
            }
            addVertical(card, actionButton(if (selected) "✓  ${names[index]}" else names[index], selected) {
                selectedOperative = index
                prefs.edit().putInt("operative", selectedOperative).apply()
                gameView.setOperative(selectedOperative)
                playGameTone(ToneGenerator.TONE_PROP_ACK, 60)
                showOperativeSelect()
            }, 7, dp(225), dp(45))
            addVertical(card, text(roles[index], 12f, amber, true), 8)
            addVertical(card, text(descriptions[index], 12f, white), 8)
            addVertical(card, text(stats[index], 10f, muted, true), 0)
            row.addView(card, LinearLayout.LayoutParams(0, -2, 1f).apply { setMargins(dp(6), 0, dp(6), 0) })
        }
        addVertical(content, row, 14)
        addVertical(content, actionButton("VOLTAR", true) { showMainMenu(hasSession) }, 4, dp(250), dp(42))
        layer.addView(content, FrameLayout.LayoutParams(dp(540), -2, Gravity.CENTER))
        attachLayer(layer)
    }

    private fun showSettings() {
        currentScreen = Screen.SETTINGS
        gameView.setGameMode(3)
        val layer = overlay(Color.argb(190, 8, 13, 18))
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(8), dp(6), dp(8), dp(6))
        }
        addVertical(content, text("CONFIGURAÇÕES", 28f, white, true), 4)
        addVertical(content, text("ÁUDIO E CONTROLES", 13f, cyan, true), 8)
        addVertical(content, text("ESQUERDA — MOVIMENTO\nARRASTE O LADO DIREITO — MIRA\nMANTENHA ATIRAR PRESSIONADO — DISPARO CONTÍNUO", 11f, muted), 10)

        val soundLabel = if (soundEnabled) "SOM DE JOGO: LIGADO" else "SOM DE JOGO: DESLIGADO"
        addVertical(content, actionButton(soundLabel, soundEnabled) {
            soundEnabled = !soundEnabled
            prefs.edit().putBoolean("sound_enabled", soundEnabled).apply()
            gameView.setGameSoundEnabled(soundEnabled)
            if (soundEnabled) playGameTone(ToneGenerator.TONE_PROP_ACK, 70)
            showSettings()
        }, 8, dp(330), dp(46))

        val sensitivityLabel = text("SENSIBILIDADE DO TOQUE: ${(touchSensitivity * 100f).toInt()}%", 13f, white, true)
        addVertical(content, sensitivityLabel, 12)
        val sensitivity = SeekBar(this).apply {
            max = 100
            progress = ((touchSensitivity - 0.5f) * 100f).toInt().coerceIn(0, 100)
            progressTintList = ColorStateList.valueOf(cyan)
            thumbTintList = ColorStateList.valueOf(cyan)
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                    touchSensitivity = 0.5f + progress / 100f
                    sensitivityLabel.text = "SENSIBILIDADE DO TOQUE: ${(touchSensitivity * 100f).toInt()}%"
                    gameView.setTouchSensitivity(touchSensitivity)
                }
                override fun onStartTrackingTouch(seekBar: SeekBar?) = Unit
                override fun onStopTrackingTouch(seekBar: SeekBar?) {
                    prefs.edit().putFloat("touch_sensitivity", touchSensitivity).apply()
                }
            })
        }
        addVertical(content, sensitivity, 4, dp(330), dp(42))
        addVertical(content, text("Faixa ajustável de 50% a 150%. A escolha fica salva entre sessões.", 11f, muted), 8)

        val hapticLabel = if (hapticsEnabled) "VIBRAÇÃO DE INTERFACE: LIGADA" else "VIBRAÇÃO DE INTERFACE: DESLIGADA"
        addVertical(content, actionButton(hapticLabel, hapticsEnabled) {
            hapticsEnabled = !hapticsEnabled
            prefs.edit().putBoolean("haptics", hapticsEnabled).apply()
            showSettings()
        }, 12, dp(330), dp(44))
        addVertical(content, actionButton("VOLTAR") { showMainMenu(hasSession) }, 8, dp(330), dp(44))
        layer.addView(content, FrameLayout.LayoutParams(dp(360), -2, Gravity.CENTER))
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
        val hudColor = Color.argb(198, 236, 239, 225)
        val hudMuted = Color.argb(164, 188, 195, 185)
        val left = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, 0, 0, 0)
            isClickable = false
        }
        addVertical(left, text("NEON BREACH  /  SITE ORION-9", 10f, Color.argb(210, 72, 220, 232), true), 3)
        addVertical(left, text("OPERADOR  ${operativeName()}", 9f, Color.argb(190, 255, 183, 112), true), 5)
        relayStatus = text("RELÉS  0 / 3", 10f, hudColor, true)
        addVertical(left, relayStatus, 2)
        threatStatus = text("AMEAÇAS  4", 9f, hudMuted, true)
        addVertical(left, threatStatus, 2)
        progressText = text("SETOR 1  •  0 / 24", 9f, Color.argb(190, 255, 183, 112), true)
        addVertical(left, progressText, 0)
        layer.addView(left, FrameLayout.LayoutParams(dp(235), -2, Gravity.START or Gravity.TOP).apply {
            marginStart = dp(18); topMargin = dp(13)
        })

        objectiveText = text("RESTAURE OS RELÉS DE CONTENÇÃO", 10f, hudColor, true).apply {
            gravity = Gravity.CENTER
            alpha = 0.88f
            setPadding(dp(5), dp(4), dp(5), dp(4))
            isClickable = false
        }
        layer.addView(objectiveText, FrameLayout.LayoutParams(dp(300), -2, Gravity.TOP or Gravity.CENTER_HORIZONTAL).apply {
            topMargin = dp(14)
        })

        val pause = text("Ⅱ", 16f, hudColor, true).apply {
            gravity = Gravity.CENTER
            alpha = 0.86f
            isClickable = true
            isFocusable = true
            contentDescription = "Pausar"
            setOnClickListener { showPause() }
        }
        layer.addView(pause, FrameLayout.LayoutParams(dp(38), dp(38), Gravity.END or Gravity.TOP).apply {
            marginEnd = dp(16); topMargin = dp(10)
        })

        val joystick = VirtualJoystick(this)
        layer.addView(joystick, FrameLayout.LayoutParams(dp(150), dp(150), Gravity.START or Gravity.BOTTOM).apply {
            marginStart = dp(20); bottomMargin = dp(16)
        })

        // Open outline glyphs preserve the hit area without opaque circles or button plates.
        fireButton = FireControlButton(this)
        layer.addView(fireButton, FrameLayout.LayoutParams(dp(76), dp(76), Gravity.END or Gravity.BOTTOM).apply {
            marginEnd = dp(18); bottomMargin = dp(12)
        })
        dodgeButton = DodgeControlButton(this).apply {
            setOnClickListener {
                if (hapticsEnabled) performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                gameView.dodge()
            }
        }
        layer.addView(dodgeButton, FrameLayout.LayoutParams(dp(76), dp(76), Gravity.END or Gravity.BOTTOM).apply {
            marginEnd = dp(108); bottomMargin = dp(12)
        })

        interactButton = text("INTERAGIR", 10f, Color.argb(190, 72, 220, 232), true).apply {
            gravity = Gravity.CENTER
            alpha = 0.82f
            setPadding(dp(7), dp(4), dp(7), dp(4))
            isClickable = true
            isFocusable = true
            setOnClickListener {
                if (hapticsEnabled) performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                gameView.interact()
                updateHud(gameView.snapshot())
            }
        }
        layer.addView(interactButton, FrameLayout.LayoutParams(dp(174), dp(28), Gravity.END or Gravity.BOTTOM).apply {
            marginEnd = dp(23); bottomMargin = dp(100)
        })
        return layer
    }

    private inner class FireControlButton(context: Context) : View(context) {
        private val iconPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = dp(2).toFloat()
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }
        private val detailPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = dp(1).toFloat()
            strokeCap = Paint.Cap.ROUND
        }
        private val labelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textAlign = Paint.Align.CENTER
            textSize = dp(9).toFloat()
            typeface = Typeface.create("sans-serif-condensed", Typeface.BOLD)
        }
        private var activePointerId = -1
        private var trackingPointer = false
        private var firingVisual = false

        init {
            isClickable = true
            isFocusable = true
            contentDescription = "Atirar. Mantenha pressionado para disparo contínuo."
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val cx = width * 0.5f
            val cy = height * 0.40f
            val accent = if (firingVisual) Color.rgb(255, 214, 0) else Color.rgb(0, 229, 255)
            iconPaint.color = if (isEnabled) accent else Color.argb(75, 190, 200, 200)
            detailPaint.color = Color.argb(if (firingVisual) 230 else 175, 232, 241, 236)
            labelPaint.color = Color.argb(if (firingVisual) 245 else 185, 246, 249, 235)

            canvas.save()
            canvas.rotate(-38f, cx, cy)
            val barrel = RectF(cx - dp(5).toFloat(), cy - dp(13).toFloat(),
                cx + dp(5).toFloat(), cy + dp(6).toFloat())
            canvas.drawRoundRect(barrel, dp(2).toFloat(), dp(2).toFloat(), iconPaint)
            canvas.drawLine(cx, cy + dp(6).toFloat(), cx, cy + dp(13).toFloat(), iconPaint)
            canvas.drawLine(cx - dp(5).toFloat(), cy + dp(1).toFloat(),
                cx - dp(10).toFloat(), cy + dp(1).toFloat(), detailPaint)
            canvas.drawLine(cx + dp(5).toFloat(), cy - dp(8).toFloat(),
                cx + dp(9).toFloat(), cy - dp(8).toFloat(), detailPaint)
            canvas.drawLine(cx - dp(2).toFloat(), cy - dp(17).toFloat(),
                cx + dp(2).toFloat(), cy - dp(17).toFloat(), detailPaint)
            canvas.restore()

            canvas.drawText("ATIRAR", cx, height - dp(8).toFloat(), labelPaint)
        }

        override fun onTouchEvent(event: MotionEvent): Boolean {
            if (event.pointerCount == 0) {
                endHold()
                return true
            }
            val index = event.actionIndex.coerceIn(0, event.pointerCount - 1)
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    activePointerId = event.getPointerId(index)
                    trackingPointer = true
                    if (hapticsEnabled) performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                    updateHold(event.getX(index), event.getY(index))
                    return true
                }
                MotionEvent.ACTION_MOVE -> {
                    if (trackingPointer) {
                        val pointerIndex = event.findPointerIndex(activePointerId)
                        if (pointerIndex >= 0) updateHold(event.getX(pointerIndex), event.getY(pointerIndex))
                    }
                    return true
                }
                MotionEvent.ACTION_POINTER_UP -> {
                    if (event.getPointerId(index) == activePointerId) endHold()
                    return true
                }
                MotionEvent.ACTION_UP -> {
                    val ownsPointer = trackingPointer && event.getPointerId(index) == activePointerId
                    val inside = ownsPointer && isInside(event.getX(index), event.getY(index))
                    endHold()
                    if (inside) performClick()
                    return true
                }
                MotionEvent.ACTION_CANCEL, MotionEvent.ACTION_OUTSIDE -> {
                    endHold()
                    return true
                }
            }
            return true
        }

        private fun isInside(x: Float, y: Float): Boolean =
            x >= 0f && y >= 0f && x <= width.toFloat() && y <= height.toFloat()

        private fun updateHold(x: Float, y: Float) {
            val shouldFire = isInside(x, y)
            if (firingVisual != shouldFire) {
                firingVisual = shouldFire
                if (shouldFire) playGameTone(ToneGenerator.TONE_PROP_BEEP, 55)
                gameView.setFiring(shouldFire)
            }
            isPressed = shouldFire
            invalidate()
        }

        private fun endHold() {
            trackingPointer = false
            activePointerId = -1
            if (firingVisual) gameView.setFiring(false)
            firingVisual = false
            isPressed = false
            invalidate()
        }

        override fun performClick(): Boolean {
            super.performClick()
            return true
        }
    }

    private inner class DodgeControlButton(context: Context) : View(context) {
        private val iconPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = dp(2).toFloat()
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }
        private val labelPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textAlign = Paint.Align.CENTER
            textSize = dp(9).toFloat()
            typeface = Typeface.create("sans-serif-condensed", Typeface.BOLD)
        }

        init {
            isClickable = true
            isFocusable = true
            contentDescription = "Esquiva"
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val cx = width * 0.5f
            val cy = height * 0.40f
            iconPaint.color = if (isEnabled) Color.rgb(0, 229, 255) else Color.argb(78, 190, 200, 200)
            labelPaint.color = Color.argb(if (isEnabled) 205 else 95, 232, 241, 236)

            val dash = Path().apply {
                moveTo(cx - dp(15).toFloat(), cy + dp(8).toFloat())
                lineTo(cx - dp(5).toFloat(), cy - dp(8).toFloat())
                lineTo(cx + dp(4).toFloat(), cy - dp(1).toFloat())
                lineTo(cx + dp(14).toFloat(), cy - dp(16).toFloat())
            }
            canvas.drawPath(dash, iconPaint)
            canvas.drawLine(cx - dp(17).toFloat(), cy + dp(2).toFloat(),
                cx - dp(11).toFloat(), cy - dp(7).toFloat(), iconPaint)
            canvas.drawLine(cx + dp(7).toFloat(), cy - dp(16).toFloat(),
                cx + dp(14).toFloat(), cy - dp(16).toFloat(), iconPaint)
            canvas.drawLine(cx + dp(14).toFloat(), cy - dp(16).toFloat(),
                cx + dp(14).toFloat(), cy - dp(9).toFloat(), iconPaint)
            canvas.drawText("ESQUIVA", cx, height - dp(8).toFloat(), labelPaint)
        }

        override fun performClick(): Boolean {
            super.performClick()
            return true
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
        if (currentScreen != Screen.PLAYING || !::relayStatus.isInitialized) return
        val mode = snapshot and 7
        val relayMask = (snapshot ushr 10) and 7
        val enemiesLeft = (snapshot ushr 13) and 7
        val eliminations = (snapshot ushr 20) and 31
        val sector = (snapshot ushr 25) and 7
        val nearRelay = (snapshot and (1 shl 16)) != 0
        val nearPod = (snapshot and (1 shl 18)) != 0
        val nearHazard = (snapshot and (1 shl 19)) != 0
        val dodgeReady = (snapshot and (1 shl 17)) != 0
        val relaysDone = Integer.bitCount(relayMask)
        relayStatus.text = "RELÉS  $relaysDone / 3"
        threatStatus.text = "AMEAÇAS  $enemiesLeft"
        progressText.text = "SETOR ${sector + 1}  •  $eliminations / 24"
        objectiveText.text = when {
            nearHazard -> "ALERTA  /  EVITE A ÁREA"
            relaysDone < 3 -> "RESTAURE OS RELÉS"
            enemiesLeft > 0 -> "CONTENHA AS AMEAÇAS"
            else -> "EXTRAÇÃO  /  ALCANCE O PAD"
        }
        interactButton.text = when {
            nearPod -> "KIT MÉDICO"
            nearRelay -> "RESTAURAR RELÉ"
            else -> "SEM ALVO DE INTERAÇÃO"
        }
        interactButton.isEnabled = nearRelay || nearPod
        interactButton.alpha = if (nearRelay || nearPod) 0.95f else 0.38f
        interactButton.setTextColor(if (nearRelay || nearPod) Color.argb(230, 0, 229, 255) else Color.argb(105, 210, 220, 215))
        dodgeButton.isEnabled = dodgeReady
        dodgeButton.alpha = if (dodgeReady) 1f else 0.52f
        dodgeButton.invalidate()
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
        addVertical(content, text(if (victory) "EXTRAÇÃO CONCLUÍDA" else "OPERAÇÃO INTERROMPIDA", 29f,
            if (victory) Color.rgb(72, 220, 232) else Color.rgb(255, 81, 97), true), 8)
        addVertical(content, text(if (victory) "Os relés foram restaurados e a zona está segura." else "A equipe perdeu capacidade operacional. Reavalie a rota.", 14f, muted), 20)
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
        fun setOperative(index: Int) { queueEvent { nativeSetOperative(index.coerceIn(0, 1)) } }
        fun setTouchSensitivity(value: Float) { queueEvent { nativeSetTouchSensitivity(value.coerceIn(0.5f, 1.5f)) } }
        fun setGameSoundEnabled(enabled: Boolean) { queueEvent { nativeSetSoundEnabled(enabled) } }

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
        private external fun nativeSetOperative(index: Int)
        private external fun nativeSetTouchSensitivity(sensitivity: Float)
        private external fun nativeSetSoundEnabled(enabled: Boolean)

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
