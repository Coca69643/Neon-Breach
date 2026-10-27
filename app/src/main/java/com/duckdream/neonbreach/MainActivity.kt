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
        window.decorView.systemUiVisibility = (View.SYSTEM_UI_FLAG_FULLSCREEN or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or View.SYSTEM_UI_FLAG_LAYOUT_STABLE or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN)
        gameView = GameSurface(this)
        setContentView(gameView)
    }
    override fun onPause() { super.onPause(); if (::gameView.isInitialized) gameView.onPause() }
    override fun onResume() { super.onResume(); if (::gameView.isInitialized) gameView.onResume() }
    private class GameSurface : GLSurfaceView {
        private val renderer: NativeRenderer
        private var downX = 0f; private var downY = 0f
        constructor(context: android.content.Context) : super(context) {
            setEGLContextClientVersion(3)
            renderer = NativeRenderer()
            setRenderer(renderer)
            renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY
            isFocusable = true
        }
        override fun onTouchEvent(event: MotionEvent): Boolean {
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> { downX = event.x; downY = event.y; queueEvent { nativeTouch(0, downX, downY, width.toFloat(), height.toFloat()) }; return true }
                MotionEvent.ACTION_MOVE -> { val x=event.x; val y=event.y; queueEvent { nativeTouch(1, x, y, width.toFloat(), height.toFloat()) }; return true }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> { queueEvent { nativeTouch(2, event.x, event.y, width.toFloat(), height.toFloat()) }; return true }
            }
            return true
        }
        private external fun nativeTouch(action: Int, x: Float, y: Float, w: Float, h: Float)
        companion object { init { System.loadLibrary("neonbreach") } }
    }
}

private class NativeRenderer : GLSurfaceView.Renderer {
    override fun onSurfaceCreated(gl: javax.microedition.khronos.opengles.GL10?, config: javax.microedition.khronos.egl.EGLConfig?) = nativeSurfaceCreated()
    override fun onSurfaceChanged(gl: javax.microedition.khronos.opengles.GL10?, width: Int, height: Int) = nativeSurfaceChanged(width, height)
    override fun onDrawFrame(gl: javax.microedition.khronos.opengles.GL10?) = nativeDrawFrame()
    private external fun nativeSurfaceCreated()
    private external fun nativeSurfaceChanged(width: Int, height: Int)
    private external fun nativeDrawFrame()
    companion object { init { System.loadLibrary("neonbreach") } }
}
