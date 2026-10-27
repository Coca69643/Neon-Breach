package com.duckdream.neonbreach

import android.app.Activity
import android.opengl.GLSurfaceView
import android.os.Bundle
import android.view.MotionEvent
import android.view.View

class MainActivity : Activity() {
    private lateinit var gameView: GameSurface

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_FULLSCREEN or
            View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
            View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
            View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
        )
        gameView = GameSurface(this)
        setContentView(gameView)
    }

    override fun onPause() {
        if (::gameView.isInitialized) gameView.onPause()
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        if (::gameView.isInitialized) gameView.onResume()
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

        override fun onTouchEvent(event: MotionEvent): Boolean {
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN, MotionEvent.ACTION_POINTER_DOWN -> {
                    startPointer(event, event.actionIndex)
                }
                MotionEvent.ACTION_MOVE -> {
                    for (i in 0 until event.pointerCount) {
                        val id = event.getPointerId(i)
                        val x = event.getX(i)
                        val y = event.getY(i)
                        when (id) {
                            movePointerId -> sendTouch(1, x, y)
                            aimPointerId -> sendTouch(4, x, y)
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
                    queueEvent { nativeTouch(6, 0f, 0f, width.toFloat(), height.toFloat()) }
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
            val x = event.getX(index)
            val y = event.getY(index)
            when (id) {
                movePointerId -> {
                    sendTouch(2, x, y)
                    movePointerId = INVALID_POINTER
                }
                aimPointerId -> {
                    sendTouch(5, x, y)
                    aimPointerId = INVALID_POINTER
                }
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

    private external fun nativeSurfaceCreated()
    private external fun nativeSurfaceChanged(width: Int, height: Int)
    private external fun nativeDrawFrame()

    companion object {
        init { System.loadLibrary("neonbreach") }
    }
}
