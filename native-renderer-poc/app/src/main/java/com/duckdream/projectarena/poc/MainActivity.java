package com.duckdream.projectarena.poc;

import android.app.Activity;
import android.opengl.GLSurfaceView;
import android.os.Bundle;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.widget.FrameLayout;
import android.widget.TextView;

/**
 * Standalone Android host for the engine-free renderer spike.
 * The first screen is a native Canvas menu; the scene is raw OpenGL ES 2.0.
 */
public final class MainActivity extends Activity {
    private GLSurfaceView sceneSurface;
    private CitySceneRenderer sceneRenderer;
    private boolean sceneVisible;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Window window = getWindow();
        window.setStatusBarColor(0xFF101A23);
        window.setNavigationBarColor(0xFF101A23);
        window.getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
        );
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        showMenu();
    }

    private void showMenu() {
        if (sceneSurface != null) {
            sceneSurface.onPause();
            sceneSurface = null;
            sceneRenderer = null;
        }
        sceneVisible = false;
        setContentView(new NativeMenuView(this, this::showScene));
    }

    private void showScene() {
        sceneVisible = true;
        sceneRenderer = new CitySceneRenderer();

        sceneSurface = new GLSurfaceView(this);
        sceneSurface.setEGLContextClientVersion(2);
        sceneSurface.setPreserveEGLContextOnPause(true);
        sceneSurface.setRenderer(sceneRenderer);
        sceneSurface.setRenderMode(GLSurfaceView.RENDERMODE_WHEN_DIRTY);
        sceneSurface.setOnTouchListener(new View.OnTouchListener() {
            private float previousX;
            private float previousY;

            @Override
            public boolean onTouch(View view, MotionEvent event) {
                switch (event.getActionMasked()) {
                    case MotionEvent.ACTION_DOWN:
                        previousX = event.getX();
                        previousY = event.getY();
                        return true;
                    case MotionEvent.ACTION_MOVE:
                        if (sceneRenderer != null) {
                            float dx = event.getX() - previousX;
                            float dy = event.getY() - previousY;
                            previousX = event.getX();
                            previousY = event.getY();
                            sceneRenderer.orbit(dx, dy);
                            sceneSurface.requestRender();
                        }
                        return true;
                    case MotionEvent.ACTION_UP:
                    case MotionEvent.ACTION_CANCEL:
                        return true;
                    default:
                        return true;
                }
            }
        });

        FrameLayout root = new FrameLayout(this);
        root.addView(sceneSurface, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
        ));

        TextView hint = new TextView(this);
        hint.setText("CENA NATIVA 3D  ·  ARRASTE PARA ORBITAR  ·  TOQUE PARA VOLTAR");
        hint.setTextColor(0xFFE8E3D4);
        hint.setTextSize(11);
        hint.setLetterSpacing(0.08f);
        hint.setShadowLayer(5f, 0f, 1f, 0xCC000000);
        hint.setPadding(18, 12, 18, 12);
        hint.setOnClickListener(view -> showMenu());
        FrameLayout.LayoutParams hintParams = new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.TOP | Gravity.START
        );
        root.addView(hint, hintParams);
        setContentView(root);
        sceneSurface.requestRender();
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (sceneVisible && sceneSurface != null) {
            sceneSurface.onResume();
            sceneSurface.requestRender();
        }
    }

    @Override
    protected void onPause() {
        if (sceneSurface != null) {
            sceneSurface.onPause();
        }
        super.onPause();
    }

    @Override
    public void onBackPressed() {
        if (sceneVisible) {
            showMenu();
            return;
        }
        super.onBackPressed();
    }
}
