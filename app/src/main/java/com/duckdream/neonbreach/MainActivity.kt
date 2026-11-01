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
        init { System.loadLibrary("arena_sim") }
    }

    private lateinit var root: FrameLayout
    private lateinit var surface: SurfaceView
    private lateinit var renderer: FilamentGameRenderer
    private var screenLayer: View? = null
    private var state = AppState.BOOT
    private var moveX = 0f
    private var moveZ = 0f
    private var lastFrameNanos = 0L
    private var loopActive = false

    private lateinit var objectiveProgress: ProgressBar
    private lateinit var objectiveLabel: TextView
    private lateinit var stateLabel: TextView

    private external fun nativeReset()
    private external fun nativeActivateDash(): Boolean
    private external fun nativeStep(inputX: Float, inputZ: Float, deltaTime: Float): FloatArray

    private val frameCallback = object : Choreographer.FrameCallback {
        override fun doFrame(frameTimeNanos: Long) {
            if (!loopActive || isFinishing || isDestroyed) return
            val dt = if (lastFrameNanos == 0L) 1f / 60f
                else ((frameTimeNanos - lastFrameNanos) / 1_000_000_000.0).toFloat().coerceIn(0f, 0.05f)
            lastFrameNanos = frameTimeNanos

            if (state == AppState.RUNNING) {
                val result = nativeStep(moveX, moveZ, dt)
                if (result.size >= 7) {
                    renderer.update(result[0], result[1], result[2], result[3], dt)
                    val percent = (result[4] * 100f).toInt().coerceIn(0, 100)
                    objectiveProgress.progress = percent
                    objectiveLabel.text = when {
                        result[6] > 0.5f -> "FAROL CONECTADO"
                        percent > 0 -> "SINTONIZANDO O FAROL  •  $percent%"
                        else -> "CAPTURE O FAROL CENTRAL"
                    }
                    if (result[6] > 0.5f) showResult()
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

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density + 0.5f).toInt()

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
        label(text, 15f, Color.rgb(238, 248, 230), true).apply {
            gravity = Gravity.CENTER
            setPadding(dp(22), dp(12), dp(22), dp(12))
            background = android.graphics.drawable.GradientDrawable().apply {
                setColor(Color.argb(218, 27, 49, 38))
                cornerRadius = dp(7).toFloat()
                setStroke(dp(1), Color.rgb(155, 203, 149))
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
        if (!::renderer.isInitialized) return
        transition(AppState.MENU)
        val layer = FrameLayout(this)
        layer.setBackgroundColor(Color.argb(42, 7, 18, 16))

        val left = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_VERTICAL
        }
        left.addView(label("DUCK DREAM STUDIOS  /  PROTÓTIPO 0.1", 10f, Color.rgb(206, 224, 194), true))
        left.addView(label("PROJETO ARENA", 30f, Color.WHITE, true).apply {
            setPadding(0, dp(8), 0, dp(4))
        })
        left.addView(label("CONTROLE DE TERRITÓRIO  •  3D MOBILE", 11f, Color.rgb(210, 229, 209)))
        left.addView(actionButton("JOGAR") { startMatch() }, LinearLayout.LayoutParams(dp(210), dp(48)).apply {
            topMargin = dp(25)
        })
        left.addView(actionButton("CONFIGURAÇÕES") { showNotice("Controles táteis e qualidade gráfica serão configuráveis na próxima etapa.") },
            LinearLayout.LayoutParams(dp(210), dp(48)).apply { topMargin = dp(10) })
        left.addView(label("NOME E IDENTIDADE VISUAL PROVISÓRIOS", 9f, Color.LTGRAY).apply {
            setPadding(0, dp(18), 0, 0)
        })
        layer.addView(left, FrameLayout.LayoutParams(dp(320), -2, Gravity.START or Gravity.CENTER_VERTICAL).apply {
            marginStart = dp(32)
        })

        val footer = label("VULKAN PRIMEIRO  •  FALLBACK GLES  •  C++20", 9f, Color.WHITE, true)
        layer.addView(footer, FrameLayout.LayoutParams(-2, -2, Gravity.BOTTOM or Gravity.END).apply {
            marginEnd = dp(18); bottomMargin = dp(12)
        })
        replaceLayer(layer)
    }

    private fun startMatch() {
        nativeReset()
        moveX = 0f
        moveZ = 0f
        transition(AppState.RUNNING)
        showHud()
    }

    private fun showHud() {
        val layer = FrameLayout(this)
        val top = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(15), dp(9), dp(15), dp(9))
            background = android.graphics.drawable.GradientDrawable().apply {
                setColor(Color.argb(175, 14, 27, 22))
                cornerRadius = dp(7).toFloat()
                setStroke(dp(1), Color.argb(150, 170, 203, 160))
            }
        }
        top.addView(label("OBJETIVO PRINCIPAL", 9f, Color.rgb(177, 213, 165), true))
        objectiveLabel = label("CAPTURE O FAROL CENTRAL", 12f, Color.WHITE, true)
        top.addView(objectiveLabel)
        objectiveProgress = ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = 100
            progress = 0
            progressTintList = android.content.res.ColorStateList.valueOf(Color.rgb(95, 210, 170))
            progressBackgroundTintList = android.content.res.ColorStateList.valueOf(Color.argb(100, 220, 230, 220))
        }
        top.addView(objectiveProgress, LinearLayout.LayoutParams(dp(250), dp(5)).apply { topMargin = dp(7) })
        layer.addView(top, FrameLayout.LayoutParams(dp(285), -2, Gravity.TOP or Gravity.CENTER_HORIZONTAL).apply {
            topMargin = dp(12)
        })

        stateLabel = label("MOVIMENTO  •  IMPULSO DISPONÍVEL", 9f, Color.WHITE, true)
        layer.addView(stateLabel, FrameLayout.LayoutParams(-2, -2, Gravity.TOP or Gravity.START).apply {
            marginStart = dp(16); topMargin = dp(17)
        })

        val pause = actionButton("Ⅱ") { pauseMatch() }
        layer.addView(pause, FrameLayout.LayoutParams(dp(48), dp(42), Gravity.TOP or Gravity.END).apply {
            marginEnd = dp(16); topMargin = dp(12)
        })

        val stick = TouchStick(this) { x, z ->
            moveX = x
            moveZ = z
            if (::stateLabel.isInitialized) {
                stateLabel.text = if (hypot(x, z) > 0.1f) "DESLOCAMENTO ATIVO" else "MOVIMENTO  •  IMPULSO DISPONÍVEL"
            }
        }
        layer.addView(stick, FrameLayout.LayoutParams(dp(142), dp(142), Gravity.BOTTOM or Gravity.START).apply {
            marginStart = dp(20); bottomMargin = dp(18)
        })

        val dash = actionButton("IMPULSO") {
            if (nativeActivateDash()) {
                stateLabel.text = "IMPULSO ATIVADO"
                itScaleFeedback(stateLabel)
            } else {
                stateLabel.text = "IMPULSO RECARREGANDO"
            }
        }
        layer.addView(dash, FrameLayout.LayoutParams(dp(116), dp(54), Gravity.BOTTOM or Gravity.END).apply {
            marginEnd = dp(28); bottomMargin = dp(34)
        })
        replaceLayer(layer)
    }

    private fun itScaleFeedback(view: View) {
        view.animate().cancel()
        view.scaleX = 1f
        view.scaleY = 1f
        view.animate().scaleX(1.05f).scaleY(1.05f).setDuration(90).withEndAction {
            view.animate().scaleX(1f).scaleY(1f).setDuration(110).start()
        }.start()
    }

    private fun pauseMatch() {
        if (state != AppState.RUNNING) return
        moveX = 0f; moveZ = 0f
        transition(AppState.PAUSED)
        val layer = FrameLayout(this).apply { setBackgroundColor(Color.argb(160, 7, 16, 14)) }
        val box = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
        }
        box.addView(label("PAUSADO", 27f, Color.WHITE, true))
        box.addView(actionButton("CONTINUAR") {
            transition(AppState.RUNNING)
            showHud()
        }, LinearLayout.LayoutParams(dp(210), dp(48)).apply { topMargin = dp(18) })
        box.addView(actionButton("VOLTAR AO MENU") { showMenu() },
            LinearLayout.LayoutParams(dp(210), dp(48)).apply { topMargin = dp(10) })
        layer.addView(box, FrameLayout.LayoutParams(-1, -1))
        replaceLayer(layer)
    }

    private fun showResult() {
        if (state != AppState.RUNNING) return
        moveX = 0f; moveZ = 0f
        transition(AppState.RESULT)
        val layer = FrameLayout(this).apply { setBackgroundColor(Color.argb(180, 7, 18, 15)) }
        val box = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; gravity = Gravity.CENTER }
        box.addView(label("OBJETIVO CONCLUÍDO", 27f, Color.WHITE, true))
        box.addView(label("O farol foi conectado. A área está sob controle da equipe.", 13f, Color.rgb(210, 235, 212)).apply {
            gravity = Gravity.CENTER
            setPadding(dp(12), dp(10), dp(12), dp(16))
        })
        box.addView(actionButton("JOGAR NOVAMENTE") { startMatch() },
            LinearLayout.LayoutParams(dp(220), dp(48)))
        box.addView(actionButton("MENU PRINCIPAL") { showMenu() },
            LinearLayout.LayoutParams(dp(220), dp(48)).apply { topMargin = dp(10) })
        layer.addView(box, FrameLayout.LayoutParams(-1, -1))
        replaceLayer(layer)
    }

    private fun showNotice(message: String) {
        val layer = FrameLayout(this).apply { setBackgroundColor(Color.argb(190, 7, 18, 15)) }
        val box = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; gravity = Gravity.CENTER }
        box.addView(label(message, 14f, Color.WHITE).apply { gravity = Gravity.CENTER; setPadding(dp(30), dp(10), dp(30), dp(18)) })
        box.addView(actionButton("VOLTAR") { showMenu() }, LinearLayout.LayoutParams(dp(180), dp(46)))
        layer.addView(box, FrameLayout.LayoutParams(-1, -1))
        replaceLayer(layer)
    }

    private fun enterRecovery(message: String) {
        stopRenderLoop()
        transition(AppState.RECOVERY)
        val layer = FrameLayout(this).apply { setBackgroundColor(Color.rgb(14, 22, 20)) }
        val box = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; gravity = Gravity.CENTER }
        box.addView(label("RECUPERAÇÃO", 26f, Color.WHITE, true))
        box.addView(label(message, 13f, Color.LTGRAY).apply {
            gravity = Gravity.CENTER
            setPadding(dp(28), dp(12), dp(28), dp(18))
        })
        box.addView(actionButton("REINICIAR A TELA") {
            recreate()
        }, LinearLayout.LayoutParams(dp(220), dp(48)))
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
            AppState.PAUSED -> { transition(AppState.RUNNING); showHud() }
            AppState.MENU, AppState.RESULT -> super.onBackPressed()
            else -> super.onBackPressed()
        }
    }
}

private class TouchStick(
    context: android.content.Context,
    private val onMove: (Float, Float) -> Unit
) : View(context) {
    private val basePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.argb(105, 20, 39, 31)
        style = Paint.Style.FILL
    }
    private val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.argb(205, 203, 231, 192)
        style = Paint.Style.STROKE
        strokeWidth = 3.2f
    }
    private val knobPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.argb(220, 176, 220, 166)
        style = Paint.Style.FILL
    }
    private var active = false
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
                active = true
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
                active = false
                dx = 0f; dy = 0f
                onMove(0f, 0f)
                invalidate()
                performClick()
                return true
            }
        }
        return active
    }

    override fun performClick(): Boolean {
        super.performClick()
        return true
    }
}
