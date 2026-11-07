package com.duckdream.projectarena.poc;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.RadialGradient;
import android.graphics.RectF;
import android.graphics.Shader;
import android.graphics.Typeface;
import android.view.MotionEvent;
import android.view.View;

/**
 * Static, low-cost 2D city menu artwork.
 * Canvas work happens only when Android invalidates the view.
 */
final class NativeMenuView extends View {
    interface OnEnterScene {
        void onEnter();
    }

    private static final float DESIGN_W = 1600f;
    private static final float DESIGN_H = 900f;
    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final OnEnterScene onEnterScene;
    private final RectF enterBounds = new RectF(1040f, 660f, 1390f, 738f);
    private float scale = 1f;
    private float offsetX;
    private float offsetY;

    NativeMenuView(Context context, OnEnterScene onEnterScene) {
        super(context);
        this.onEnterScene = onEnterScene;
        setFocusable(true);
        setContentDescription("Menu de demonstração do renderizador nativo do Project Arena");
    }

    @Override
    protected void onSizeChanged(int width, int height, int oldWidth, int oldHeight) {
        super.onSizeChanged(width, height, oldWidth, oldHeight);
        scale = Math.max(width / DESIGN_W, height / DESIGN_H);
        offsetX = (width - DESIGN_W * scale) * 0.5f;
        offsetY = (height - DESIGN_H * scale) * 0.5f;
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        canvas.save();
        canvas.translate(offsetX, offsetY);
        canvas.scale(scale, scale);

        drawSky(canvas);
        drawAtmosphere(canvas);
        drawFarDistrict(canvas);
        drawMidDistrict(canvas);
        drawCommandTower(canvas);
        drawStreet(canvas);
        drawForeground(canvas);
        drawTypography(canvas);
        drawVignette(canvas);

        canvas.restore();
    }

    private void drawSky(Canvas canvas) {
        paint.setShader(new LinearGradient(
                0f, 0f, 0f, DESIGN_H,
                new int[] {0xFF101C2A, 0xFF243C4A, 0xFF66716F, 0xFF1A2934},
                new float[] {0f, 0.44f, 0.72f, 1f},
                Shader.TileMode.CLAMP
        ));
        canvas.drawRect(0f, 0f, DESIGN_W, DESIGN_H, paint);
        paint.setShader(null);

        paint.setColor(0x66D3DFDC);
        for (int i = 0; i < 26; i++) {
            float x = 58f + ((i * 173f) % 1480f);
            float y = 50f + ((i * 71f) % 300f);
            canvas.drawCircle(x, y, (i % 4 == 0) ? 2.2f : 1.1f, paint);
        }
    }

    private void drawAtmosphere(Canvas canvas) {
        paint.setShader(new RadialGradient(
                1120f, 330f, 540f,
                new int[] {0x668EBEB6, 0x2281A9A8, 0x00121D29},
                null,
                Shader.TileMode.CLAMP
        ));
        canvas.drawCircle(1120f, 330f, 540f, paint);
        paint.setShader(null);

        paint.setColor(0x33E8D6AE);
        canvas.drawCircle(1280f, 214f, 104f, paint);
        paint.setColor(0x1CE8D6AE);
        canvas.drawCircle(1280f, 214f, 145f, paint);

        paint.setColor(0x18E2ECE7);
        paint.setStyle(Paint.Style.STROKE);
        paint.setStrokeWidth(3f);
        Path cloud = new Path();
        cloud.moveTo(120f, 250f);
        cloud.cubicTo(250f, 210f, 340f, 230f, 450f, 260f);
        cloud.moveTo(630f, 180f);
        cloud.cubicTo(730f, 150f, 820f, 166f, 930f, 195f);
        cloud.moveTo(980f, 290f);
        cloud.cubicTo(1090f, 260f, 1170f, 270f, 1240f, 298f);
        canvas.drawPath(cloud, paint);
        paint.setStyle(Paint.Style.FILL);
    }

    private void drawFarDistrict(Canvas canvas) {
        drawBlockLayer(canvas, 0x55314350, 0x66485D66, 580f, 0.70f, 34);
        drawBlockLayer(canvas, 0x88334450, 0x997C827A, 660f, 0.86f, 26);
    }

    private void drawBlockLayer(Canvas canvas, int bodyColor, int alternateColor,
                                float baseline, float heightScale, int count) {
        float x = -18f;
        for (int i = 0; i < count; i++) {
            float width = 32f + ((i * 19f) % 48f);
            float height = (70f + ((i * 47f) % 185f)) * heightScale;
            float gap = 7f + ((i * 11f) % 15f);
            paint.setColor((i % 5 == 0) ? alternateColor : bodyColor);
            canvas.drawRect(x, baseline - height, x + width, baseline, paint);

            if (i % 3 == 0) {
                paint.setColor(0x335E9FA0);
                canvas.drawRect(x + width * 0.42f, baseline - height - 15f,
                        x + width * 0.58f, baseline - height + 2f, paint);
            }

            if (i % 4 == 0) {
                paint.setColor(0x44D8C99D);
                canvas.drawRect(x + 4f, baseline - height + 12f,
                        x + 8f, baseline - height + 40f, paint);
            }
            x += width + gap;
        }
    }

    private void drawMidDistrict(Canvas canvas) {
        drawBuilding(canvas, 110f, 520f, 112f, 220f, 0xCC1C303B, 0x667EB4B2);
        drawBuilding(canvas, 275f, 554f, 138f, 185f, 0xCC263943, 0x557CB4AD);
        drawBuilding(canvas, 438f, 512f, 104f, 228f, 0xCC35434A, 0x557BB1AE);
        drawBuilding(canvas, 610f, 540f, 150f, 202f, 0xCC203541, 0x6686BDB2);
        drawBuilding(canvas, 850f, 532f, 118f, 210f, 0xCC273943, 0x558CBDB3);
        drawBuilding(canvas, 1370f, 515f, 144f, 225f, 0xCC243641, 0x5588B4AB);
        drawBuilding(canvas, 1510f, 557f, 118f, 185f, 0xCC263640, 0x557DB4AA);
    }

    private void drawBuilding(Canvas canvas, float x, float base, float width, float height,
                              int body, int accent) {
        paint.setColor(body);
        canvas.drawRect(x, base - height, x + width, base, paint);
        paint.setColor(accent);
        canvas.drawRect(x + 8f, base - height + 9f, x + 13f, base - 8f, paint);
        paint.setColor(0x557DA5A6);
        canvas.drawRect(x + width - 18f, base - height + 10f,
                x + width - 12f, base - 10f, paint);

        paint.setColor(0x997B8D8B);
        canvas.drawRect(x - 4f, base - height - 7f,
                x + width + 4f, base - height, paint);

        for (float wy = base - height + 27f; wy < base - 16f; wy += 34f) {
            for (float wx = x + 25f; wx < x + width - 12f; wx += 29f) {
                paint.setColor(((int) (wx + wy) % 3 == 0) ? 0x99D6C99D : 0x667DA7A5);
                canvas.drawRect(wx, wy, wx + 10f, wy + 15f, paint);
            }
        }
    }

    private void drawCommandTower(Canvas canvas) {
        paint.setColor(0xEE1A2D39);
        canvas.drawRect(1050f, 276f, 1322f, 612f, paint);
        paint.setColor(0xEE263F4A);
        canvas.drawRect(1080f, 238f, 1292f, 612f, paint);
        paint.setColor(0xFF314E56);
        canvas.drawRect(1114f, 186f, 1258f, 612f, paint);

        paint.setColor(0xFF8ABDB1);
        canvas.drawRect(1110f, 183f, 1260f, 194f, paint);
        paint.setColor(0xAAE9D4A2);
        canvas.drawRect(1180f, 140f, 1190f, 185f, paint);

        paint.setShader(new LinearGradient(
                1120f, 250f, 1250f, 570f,
                new int[] {0x9984C2B5, 0x3384C2B5, 0x0084C2B5},
                null,
                Shader.TileMode.CLAMP
        ));
        canvas.drawRect(1120f, 250f, 1250f, 570f, paint);
        paint.setShader(null);

        paint.setColor(0x9976AFA8);
        canvas.drawRect(1141f, 238f, 1146f, 590f, paint);
        canvas.drawRect(1225f, 238f, 1230f, 590f, paint);

        paint.setColor(0x66E8D6AE);
        for (int floor = 0; floor < 9; floor++) {
            float y = 276f + floor * 34f;
            canvas.drawRect(1157f, y, 1210f, y + 7f, paint);
        }
    }

    private void drawStreet(Canvas canvas) {
        paint.setColor(0xBB111D26);
        Path avenue = new Path();
        avenue.moveTo(635f, 618f);
        avenue.lineTo(967f, 618f);
        avenue.lineTo(1600f, 900f);
        avenue.lineTo(0f, 900f);
        avenue.close();
        canvas.drawPath(avenue, paint);

        paint.setColor(0x777D9996);
        Path leftWalk = new Path();
        leftWalk.moveTo(603f, 618f);
        leftWalk.lineTo(634f, 618f);
        leftWalk.lineTo(750f, 900f);
        leftWalk.lineTo(610f, 900f);
        leftWalk.close();
        canvas.drawPath(leftWalk, paint);

        Path rightWalk = new Path();
        rightWalk.moveTo(968f, 618f);
        rightWalk.lineTo(997f, 618f);
        rightWalk.lineTo(1030f, 900f);
        rightWalk.lineTo(890f, 900f);
        rightWalk.close();
        canvas.drawPath(rightWalk, paint);

        paint.setColor(0x55E1CFA1);
        paint.setStrokeWidth(4f);
        canvas.drawLine(801f, 680f, 800f, 900f, paint);
        paint.setStrokeWidth(1f);

        paint.setColor(0xAA8CB9AF);
        canvas.drawRect(647f, 616f, 954f, 624f, paint);
    }

    private void drawForeground(Canvas canvas) {
        paint.setColor(0xFF101A22);
        canvas.drawRect(0f, 850f, DESIGN_W, DESIGN_H, paint);

        paint.setShader(new LinearGradient(
                0f, 800f, 0f, 900f,
                new int[] {0x00101A22, 0xF0101A22},
                null,
                Shader.TileMode.CLAMP
        ));
        canvas.drawRect(0f, 800f, DESIGN_W, 900f, paint);
        paint.setShader(null);
    }

    private void drawTypography(Canvas canvas) {
        paint.setTypeface(Typeface.create("sans-serif-condensed", Typeface.BOLD));
        paint.setTextSize(24f);
        paint.setTextScaleX(1.04f);
        paint.setColor(0xFF9BC7BB);
        canvas.drawText("DUCK DREAM STUDIOS  /  MOBILE SYSTEMS", 92f, 106f, paint);

        paint.setTypeface(Typeface.create("sans-serif", Typeface.BOLD));
        paint.setTextSize(86f);
        paint.setTextScaleX(1.02f);
        paint.setColor(0xFFF0E8D4);
        canvas.drawText("PROJECT", 92f, 620f, paint);
        paint.setTextSize(104f);
        paint.setColor(0xFF94C9B9);
        canvas.drawText("ARENA", 92f, 724f, paint);

        paint.setTypeface(Typeface.create("sans-serif-medium", Typeface.NORMAL));
        paint.setTextSize(19f);
        paint.setTextScaleX(1.02f);
        paint.setColor(0xFFD0D7D1);
        canvas.drawText("CITY CONTROL  ·  NATIVE RENDERER STUDY", 98f, 770f, paint);

        paint.setShader(new LinearGradient(
                enterBounds.left, enterBounds.top, enterBounds.right, enterBounds.bottom,
                new int[] {0xFF8BBFB1, 0xFF557F7E},
                null,
                Shader.TileMode.CLAMP
        ));
        canvas.drawRoundRect(enterBounds, 8f, 8f, paint);
        paint.setShader(null);

        paint.setTypeface(Typeface.create("sans-serif", Typeface.BOLD));
        paint.setTextSize(22f);
        paint.setTextScaleX(1.02f);
        paint.setColor(0xFF10232B);
        canvas.drawText("ENTRAR NA CENA  >", 1080f, 708f, paint);

        paint.setTypeface(Typeface.create("sans-serif", Typeface.NORMAL));
        paint.setTextSize(14f);
        paint.setTextScaleX(1.02f);
        paint.setColor(0xFF9AAEAC);
        canvas.drawText("PROVA DE CONCEITO  ·  SEM ENGINE DE JOGO", 1040f, 790f, paint);
    }

    private void drawVignette(Canvas canvas) {
        paint.setShader(new RadialGradient(
                800f, 420f, 920f,
                new int[] {0x00000000, 0x1F000000, 0xAA071019},
                new float[] {0.55f, 0.86f, 1f},
                Shader.TileMode.CLAMP
        ));
        canvas.drawRect(0f, 0f, DESIGN_W, DESIGN_H, paint);
        paint.setShader(null);
    }

    @Override
    public boolean onTouchEvent(MotionEvent event) {
        if (event.getActionMasked() == MotionEvent.ACTION_UP) {
            float x = (event.getX() - offsetX) / scale;
            float y = (event.getY() - offsetY) / scale;
            if (enterBounds.contains(x, y)) {
                if (onEnterScene != null) onEnterScene.onEnter();
            }
            performClick();
            return true;
        }
        return true;
    }

    @Override
    public boolean performClick() {
        super.performClick();
        return true;
    }
}
