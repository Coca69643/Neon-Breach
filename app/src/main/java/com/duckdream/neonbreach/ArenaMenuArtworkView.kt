package com.duckdream.neonbreach

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.view.View
import kotlin.math.max

/**
 * Hand-authored fantasy key art for the HUB. Kept as vector drawing so the
 * menu remains crisp at different landscape resolutions without a large bitmap.
 */
internal class ArenaMenuArtworkView(context: Context) : View(context) {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.DITHER_FLAG)

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val scale = height.coerceAtLeast(1) / 900f
        canvas.save()
        canvas.scale(scale, scale)
        val w = width / scale
        val h = 900f

        paint.shader = LinearGradient(
            0f, 0f, 0f, h,
            intArrayOf(Color.rgb(19, 42, 57), Color.rgb(45, 78, 83),
                Color.rgb(151, 117, 81), Color.rgb(33, 43, 40)),
            floatArrayOf(0f, 0.42f, 0.78f, 1f), Shader.TileMode.CLAMP
        )
        canvas.drawRect(0f, 0f, w, h, paint)
        paint.shader = null

        val sunX = w * 0.70f
        val sunY = 345f
        paint.shader = RadialGradient(
            sunX, sunY, 330f,
            intArrayOf(Color.argb(185, 241, 190, 113), Color.argb(45, 229, 174, 109), Color.TRANSPARENT),
            floatArrayOf(0f, 0.45f, 1f), Shader.TileMode.CLAMP
        )
        canvas.drawRect(0f, 0f, w, h, paint)
        paint.shader = null
        paint.color = Color.rgb(242, 200, 132)
        canvas.drawCircle(sunX, sunY, 83f, paint)
        paint.color = Color.argb(55, 255, 235, 190)
        canvas.drawCircle(sunX, sunY, 104f, paint)

        // Distant mountain chain and a nearer ridge frame the valley.
        polygon(canvas, Color.rgb(61, 86, 84),
            0f, 430f, w * .10f, 320f, w * .19f, 380f, w * .31f, 280f,
            w * .43f, 385f, w * .56f, 300f, w * .70f, 365f,
            w * .84f, 265f, w, 390f, w, 610f, 0f, 610f)
        polygon(canvas, Color.rgb(40, 68, 63),
            0f, 520f, w * .13f, 430f, w * .24f, 475f, w * .36f, 380f,
            w * .48f, 470f, w * .60f, 390f, w * .73f, 470f,
            w * .87f, 370f, w, 450f, w, 735f, 0f, 735f)
        polygon(canvas, Color.rgb(31, 56, 47),
            0f, 615f, w * .12f, 540f, w * .25f, 590f, w * .40f, 495f,
            w * .55f, 585f, w * .70f, 500f, w * .86f, 580f,
            w, 520f, w, h, 0f, h)

        // River valley winds from the distant fortress toward the foreground.
        val river = Path().apply {
            moveTo(w * .69f, 444f)
            cubicTo(w * .63f, 545f, w * .79f, 603f, w * .66f, 690f)
            cubicTo(w * .55f, 765f, w * .62f, 827f, w * .50f, h)
            lineTo(w * .70f, h)
            cubicTo(w * .77f, 828f, w * .72f, 758f, w * .82f, 690f)
            cubicTo(w * .91f, 605f, w * .74f, 540f, w * .77f, 444f)
            close()
        }
        paint.color = Color.rgb(37, 83, 82)
        canvas.drawPath(river, paint)
        val riverHighlight = Path().apply {
            moveTo(w * .73f, 455f)
            cubicTo(w * .68f, 555f, w * .84f, 620f, w * .71f, 700f)
            cubicTo(w * .62f, 780f, w * .68f, 840f, w * .59f, h)
        }
        paint.color = Color.argb(90, 177, 184, 138)
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 5f
        paint.strokeCap = Paint.Cap.ROUND
        canvas.drawPath(riverHighlight, paint)
        paint.style = Paint.Style.FILL

        // Three old roads lead through the valley to the citadel.
        drawRoad(canvas, w * .32f, 900f, w * .48f, 650f, w * .48f, 495f)
        drawRoad(canvas, w * .48f, 900f, w * .56f, 670f, w * .59f, 500f)
        drawRoad(canvas, w * .88f, 900f, w * .76f, 690f, w * .69f, 505f)

        // Pine silhouettes are deliberately varied in height and spacing.
        for (i in 0..8) {
            val x = w * (0.035f + i * 0.073f)
            val y = 655f + (i % 3) * 34f
            drawPine(canvas, x, y, 0.78f + (i % 4) * 0.16f,
                if (i % 2 == 0) Color.rgb(21, 48, 39) else Color.rgb(27, 58, 43))
        }
        for (i in 0..7) {
            val x = w * (0.76f + i * 0.034f)
            val y = 625f + (i % 4) * 40f
            drawPine(canvas, x, y, 0.70f + (i % 3) * 0.19f, Color.rgb(19, 44, 36))
        }

        drawCitadel(canvas, w * .78f, 465f, 1.0f)

        // Hero silhouette is the menu's focal point, not a tiny live-match pawn.
        drawHeroSilhouette(canvas, w * .47f, 600f, 1.24f)

        // Foreground banks and layered stones close the composition.
        polygon(canvas, Color.rgb(18, 37, 31),
            0f, 790f, w * .14f, 735f, w * .27f, 798f, w * .39f, 760f,
            w * .48f, 820f, w * .55f, h, 0f, h)
        polygon(canvas, Color.rgb(22, 42, 34),
            w * .72f, 760f, w * .83f, 715f, w, 760f, w, h, w * .66f, h)
        for (i in 0..18) {
            val x = w * ((i * 0.137f + 0.04f) % 1f)
            val y = 815f + (i % 4) * 18f
            paint.color = if (i % 2 == 0) Color.rgb(77, 77, 59) else Color.rgb(49, 63, 48)
            canvas.drawOval(RectF(x - 26f, y, x + 34f, y + 16f), paint)
        }

        // Gentle dark vignette keeps the UI legible without panel slabs.
        paint.shader = RadialGradient(
            w * .52f, h * .48f, max(w, h) * .76f,
            intArrayOf(Color.TRANSPARENT, Color.argb(45, 5, 13, 17), Color.argb(180, 5, 12, 16)),
            floatArrayOf(0.42f, 0.78f, 1f), Shader.TileMode.CLAMP
        )
        canvas.drawRect(0f, 0f, w, h, paint)
        paint.shader = null
        paint.color = Color.argb(42, 9, 16, 16)
        canvas.drawRect(0f, 0f, w, 150f, paint)
        canvas.restore()
    }

    private fun polygon(canvas: Canvas, color: Int, vararg points: Float) {
        if (points.size < 6) return
        val path = Path().apply {
            moveTo(points[0], points[1])
            var i = 2
            while (i + 1 < points.size) {
                lineTo(points[i], points[i + 1])
                i += 2
            }
            close()
        }
        paint.shader = null
        paint.style = Paint.Style.FILL
        paint.color = color
        canvas.drawPath(path, paint)
    }

    private fun drawRoad(canvas: Canvas, x0: Float, y0: Float, x1: Float, y1: Float, x2: Float, y2: Float) {
        val path = Path().apply {
            moveTo(x0, y0)
            cubicTo(x0 * .92f + x1 * .08f, y0 - 120f, x1, y1 + 80f, x1, y1)
            quadraticTo(x2 - 40f, y2 + 55f, x2, y2)
        }
        paint.color = Color.argb(115, 194, 165, 112)
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 26f
        paint.strokeCap = Paint.Cap.ROUND
        canvas.drawPath(path, paint)
        paint.color = Color.argb(115, 73, 69, 48)
        paint.strokeWidth = 3f
        canvas.drawPath(path, paint)
        paint.style = Paint.Style.FILL
    }

    private fun drawPine(canvas: Canvas, x: Float, base: Float, scale: Float, color: Int) {
        paint.color = Color.rgb(49, 39, 30)
        canvas.drawRect(x - 5f * scale, base - 45f * scale, x + 5f * scale, base, paint)
        paint.color = color
        polygon(canvas, color, x, base - 158f * scale, x - 48f * scale, base - 68f * scale,
            x - 23f * scale, base - 73f * scale, x - 58f * scale, base - 15f * scale,
            x + 58f * scale, base - 15f * scale, x + 23f * scale, base - 73f * scale,
            x + 48f * scale, base - 68f * scale)
        polygon(canvas, Color.rgb(
            Color.red(color) / 2, (Color.green(color) * .72f).toInt(),
            Color.blue(color) / 2
        ), x, base - 146f * scale, x + 48f * scale, base - 15f * scale,
            x + 4f * scale, base - 15f * scale)
    }

    private fun drawCitadel(canvas: Canvas, x: Float, base: Float, scale: Float) {
        val stone = Color.rgb(58, 61, 53)
        val lightStone = Color.rgb(104, 94, 70)
        paint.color = Color.rgb(24, 33, 31)
        canvas.drawRect(x - 160f * scale, base - 122f * scale,
            x + 144f * scale, base + 5f * scale, paint)
        paint.color = stone
        canvas.drawRect(x - 142f * scale, base - 176f * scale,
            x - 78f * scale, base + 15f * scale, paint)
        canvas.drawRect(x + 64f * scale, base - 188f * scale,
            x + 122f * scale, base + 15f * scale, paint)
        canvas.drawRect(x - 94f * scale, base - 115f * scale,
            x + 78f * scale, base + 16f * scale, paint)
        paint.color = lightStone
        canvas.drawRect(x - 132f * scale, base - 164f * scale,
            x - 122f * scale, base - 8f * scale, paint)
        canvas.drawRect(x + 78f * scale, base - 178f * scale,
            x + 88f * scale, base - 8f * scale, paint)
        polygon(canvas, Color.rgb(39, 48, 44),
            x - 151f * scale, base - 176f * scale, x - 109f * scale, base - 226f * scale,
            x - 68f * scale, base - 176f * scale)
        polygon(canvas, Color.rgb(39, 48, 44),
            x + 56f * scale, base - 188f * scale, x + 93f * scale, base - 239f * scale,
            x + 130f * scale, base - 188f * scale)
        for (i in 0..5) {
            paint.color = if (i % 2 == 0) lightStone else stone
            canvas.drawRect(x - 150f * scale + i * 47f * scale, base - 136f * scale,
                x - 126f * scale + i * 47f * scale, base - 111f * scale, paint)
        }
        paint.color = Color.rgb(17, 27, 27)
        canvas.drawRoundRect(RectF(x - 111f * scale, base - 79f * scale,
            x - 82f * scale, base - 4f * scale), 10f, 10f, paint)
        canvas.drawRoundRect(RectF(x + 84f * scale, base - 91f * scale,
            x + 108f * scale, base - 4f * scale), 9f, 9f, paint)
        paint.color = Color.rgb(150, 77, 48)
        canvas.drawRect(x + 93f * scale, base - 240f * scale,
            x + 96f * scale, base - 286f * scale, paint)
        polygon(canvas, Color.rgb(183, 112, 67),
            x + 96f * scale, base - 285f * scale,
            x + 136f * scale, base - 269f * scale,
            x + 96f * scale, base - 255f * scale)
    }

    private fun drawHeroSilhouette(canvas: Canvas, x: Float, base: Float, scale: Float) {
        val cloak = Color.rgb(27, 42, 41)
        val armor = Color.rgb(79, 91, 76)
        val highlight = Color.rgb(171, 145, 93)
        val cape = Path().apply {
            moveTo(x - 42f * scale, base - 210f * scale)
            cubicTo(x - 116f * scale, base - 172f * scale,
                x - 94f * scale, base - 38f * scale, x - 150f * scale, base + 48f * scale)
            lineTo(x + 94f * scale, base + 48f * scale)
            cubicTo(x + 47f * scale, base - 45f * scale,
                x + 68f * scale, base - 160f * scale, x + 34f * scale, base - 211f * scale)
            close()
        }
        paint.color = cloak
        canvas.drawPath(cape, paint)
        paint.color = Color.rgb(45, 57, 50)
        canvas.drawOval(RectF(x - 82f * scale, base - 30f * scale,
            x + 83f * scale, base + 38f * scale), paint)
        paint.color = armor
        canvas.drawRoundRect(RectF(x - 47f * scale, base - 226f * scale,
            x + 48f * scale, base - 70f * scale), 22f * scale, 22f * scale, paint)
        paint.color = Color.rgb(96, 101, 79)
        canvas.drawRoundRect(RectF(x - 63f * scale, base - 215f * scale,
            x + 63f * scale, base - 167f * scale), 20f * scale, 20f * scale, paint)
        paint.color = armor
        canvas.drawCircle(x, base - 267f * scale, 43f * scale, paint)
        paint.color = Color.rgb(34, 44, 42)
        polygon(canvas, Color.rgb(34, 44, 42),
            x - 47f * scale, base - 263f * scale, x, base - 337f * scale,
            x + 49f * scale, base - 263f * scale)
        paint.color = highlight
        canvas.drawRect(x - 34f * scale, base - 155f * scale,
            x + 34f * scale, base - 143f * scale, paint)
        polygon(canvas, highlight,
            x - 12f * scale, base - 211f * scale, x + 12f * scale, base - 211f * scale,
            x + 19f * scale, base - 172f * scale, x - 18f * scale, base - 172f * scale)
        paint.color = Color.rgb(24, 34, 33)
        canvas.drawRoundRect(RectF(x - 42f * scale, base - 72f * scale,
            x - 10f * scale, base + 65f * scale), 10f, 10f, paint)
        canvas.drawRoundRect(RectF(x + 11f * scale, base - 72f * scale,
            x + 43f * scale, base + 65f * scale), 10f, 10f, paint)
        paint.color = Color.rgb(129, 105, 71)
        canvas.drawRect(x - 75f * scale, base - 218f * scale,
            x - 52f * scale, base - 160f * scale, paint)
        canvas.drawRect(x + 52f * scale, base - 218f * scale,
            x + 75f * scale, base - 160f * scale, paint)
    }
}
