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

/** Vector key art for the landscape HUB; no runtime network or bitmap dependency. */
internal class ArenaMenuArtworkView(context: Context) : View(context) {
    private val p = Paint(Paint.ANTI_ALIAS_FLAG or Paint.DITHER_FLAG)

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val scale = height.coerceAtLeast(1) / 900f
        canvas.save()
        canvas.scale(scale, scale)
        val w = width / scale
        val h = 900f

        p.shader = LinearGradient(0f, 0f, 0f, h,
            intArrayOf(Color.rgb(17, 37, 53), Color.rgb(48, 77, 78),
                Color.rgb(144, 105, 72), Color.rgb(23, 40, 34)),
            floatArrayOf(0f, .43f, .76f, 1f), Shader.TileMode.CLAMP)
        canvas.drawRect(0f, 0f, w, h, p)
        p.shader = RadialGradient(w * .71f, 330f, 350f,
            intArrayOf(Color.argb(160, 240, 183, 106), Color.argb(35, 222, 158, 94), Color.TRANSPARENT),
            floatArrayOf(0f, .48f, 1f), Shader.TileMode.CLAMP)
        canvas.drawRect(0f, 0f, w, h, p)
        p.shader = null
        p.color = Color.rgb(243, 197, 126)
        canvas.drawCircle(w * .71f, 330f, 77f, p)

        polygon(canvas, Color.rgb(64, 86, 81),
            0f, 430f, w*.12f, 310f, w*.22f, 382f, w*.34f, 280f,
            w*.46f, 382f, w*.60f, 296f, w*.74f, 378f, w*.87f, 270f, w, 390f, w, 700f, 0f, 700f)
        polygon(canvas, Color.rgb(37, 67, 58),
            0f, 570f, w*.14f, 470f, w*.28f, 515f, w*.42f, 410f,
            w*.57f, 510f, w*.73f, 398f, w*.88f, 490f, w, 430f, w, h, 0f, h)

        val river = Path().apply {
            moveTo(w*.69f, 440f)
            cubicTo(w*.62f, 545f, w*.82f, 600f, w*.68f, 700f)
            cubicTo(w*.57f, 785f, w*.65f, 840f, w*.53f, h)
            lineTo(w*.73f, h)
            cubicTo(w*.79f, 835f, w*.75f, 770f, w*.84f, 690f)
            cubicTo(w*.92f, 600f, w*.76f, 535f, w*.78f, 440f)
            close()
        }
        p.color = Color.rgb(35, 78, 79)
        canvas.drawPath(river, p)
        p.style = Paint.Style.STROKE
        p.strokeWidth = 4f
        p.strokeCap = Paint.Cap.ROUND
        p.color = Color.argb(95, 194, 184, 139)
        val riverLine = Path().apply {
            moveTo(w*.73f, 465f)
            cubicTo(w*.66f, 560f, w*.83f, 620f, w*.72f, 710f)
            cubicTo(w*.64f, 790f, w*.69f, 845f, w*.62f, h)
        }
        canvas.drawPath(riverLine, p)
        p.style = Paint.Style.FILL

        drawRoad(canvas, w*.30f, 900f, w*.47f, 640f, w*.49f, 500f)
        drawRoad(canvas, w*.48f, 900f, w*.58f, 660f, w*.60f, 500f)
        drawRoad(canvas, w*.90f, 900f, w*.78f, 670f, w*.70f, 500f)

        drawCitadel(canvas, w*.80f, 465f)
        for (i in 0..8) {
            val x = w * (.035f + i * .073f)
            drawPine(canvas, x, 690f + (i%3)*30f, .75f + (i%4)*.15f,
                if (i%2==0) Color.rgb(20,47,37) else Color.rgb(27,58,42))
        }
        for (i in 0..6) {
            drawPine(canvas, w*(.78f+i*.034f), 670f+(i%3)*35f, .72f+(i%2)*.18f, Color.rgb(17,42,34))
        }
        drawHero(canvas, w*.48f, 605f, 1.18f)

        polygon(canvas, Color.rgb(17, 35, 29),
            0f, 800f, w*.13f, 742f, w*.26f, 795f, w*.40f, 765f,
            w*.53f, h, 0f, h)
        polygon(canvas, Color.rgb(20, 39, 31),
            w*.73f, 770f, w*.84f, 720f, w, 770f, w, h, w*.66f, h)
        for (i in 0..17) {
            val x = w*((i*.137f+.04f)%1f)
            val y = 820f+(i%4)*16f
            p.color = if(i%2==0) Color.rgb(78,75,57) else Color.rgb(48,62,47)
            canvas.drawOval(RectF(x-22f,y,x+30f,y+13f),p)
        }

        p.shader = RadialGradient(w*.52f, 450f, max(w,h)*.78f,
            intArrayOf(Color.TRANSPARENT, Color.argb(60,4,12,15), Color.argb(185,4,11,14)),
            floatArrayOf(.40f,.76f,1f), Shader.TileMode.CLAMP)
        canvas.drawRect(0f,0f,w,h,p)
        p.shader = null
        canvas.restore()
    }

    private fun polygon(c: Canvas, color: Int, vararg xy: Float) {
        if (xy.size < 6) return
        val path = Path().apply {
            moveTo(xy[0],xy[1])
            var i=2
            while(i+1<xy.size){lineTo(xy[i],xy[i+1]);i+=2}
            close()
        }
        p.shader=null;p.style=Paint.Style.FILL;p.color=color
        c.drawPath(path,p)
    }

    private fun drawRoad(c: Canvas,x0:Float,y0:Float,x1:Float,y1:Float,x2:Float,y2:Float) {
        val path=Path().apply {
            moveTo(x0,y0)
            cubicTo(x0*.92f+x1*.08f,y0-120f,x1,y1+80f,x1,y1)
            quadraticTo(x2-40f,y2+55f,x2,y2)
        }
        p.style=Paint.Style.STROKE;p.strokeCap=Paint.Cap.ROUND
        p.color=Color.argb(115,190,158,105);p.strokeWidth=24f;c.drawPath(path,p)
        p.color=Color.argb(100,65,62,45);p.strokeWidth=2.5f;c.drawPath(path,p)
        p.style=Paint.Style.FILL
    }

    private fun drawPine(c:Canvas,x:Float,base:Float,s:Float,color:Int) {
        p.color=Color.rgb(49,38,28);c.drawRect(x-4f*s,base-38f*s,x+4f*s,base,p)
        polygon(c,color,x,base-155f*s,x-48f*s,base-65f*s,x-22f*s,base-72f*s,
            x-56f*s,base-12f*s,x+56f*s,base-12f*s,x+22f*s,base-72f*s,x+48f*s,base-65f*s)
    }

    private fun drawCitadel(c:Canvas,x:Float,b:Float) {
        val stone=Color.rgb(65,65,54)
        p.color=Color.rgb(25,34,31);c.drawRect(x-160f,b-122f,x+145f,b+8f,p)
        p.color=stone
        c.drawRect(x-140f,b-178f,x-78f,b+15f,p)
        c.drawRect(x+66f,b-190f,x+124f,b+15f,p)
        c.drawRect(x-95f,b-118f,x+80f,b+16f,p)
        polygon(c,Color.rgb(36,47,43),x-150f,b-178f,x-109f,b-226f,x-68f,b-178f)
        polygon(c,Color.rgb(36,47,43),x+56f,b-190f,x+95f,b-242f,x+134f,b-190f)
        p.color=Color.rgb(112,99,71)
        for(i in 0..5)c.drawRect(x-148f+i*47f,b-136f,x-125f+i*47f,b-111f,p)
        p.color=Color.rgb(17,27,26)
        c.drawRoundRect(RectF(x-110f,b-80f,x-82f,b-3f),8f,8f,p)
        c.drawRoundRect(RectF(x+84f,b-92f,x+108f,b-3f),8f,8f,p)
        p.color=Color.rgb(152,81,48);c.drawRect(x+94f,b-243f,x+97f,b-285f,p)
        polygon(c,Color.rgb(187,116,66),x+97f,b-284f,x+137f,b-269f,x+97f,b-254f)
    }

    private fun drawHero(c:Canvas,x:Float,b:Float,s:Float) {
        p.color=Color.rgb(26,42,40)
        val cloak=Path().apply {
            moveTo(x-42f*s,b-210f*s)
            cubicTo(x-112f*s,b-170f*s,x-95f*s,b-30f*s,x-145f*s,b+52f*s)
            lineTo(x+96f*s,b+52f*s)
            cubicTo(x+48f*s,b-42f*s,x+66f*s,b-166f*s,x+34f*s,b-210f*s)
            close()
        }
        c.drawPath(cloak,p)
        p.color=Color.rgb(73,86,72)
        c.drawRoundRect(RectF(x-49f*s,b-230f*s,x+49f*s,b-70f*s),22f*s,22f*s,p)
        c.drawCircle(x,b-270f*s,42f*s,p)
        polygon(c,Color.rgb(33,44,40),x-48f*s,b-264f*s,x,b-338f*s,x+49f*s,b-264f*s)
        p.color=Color.rgb(106,106,79)
        c.drawRoundRect(RectF(x-64f*s,b-220f*s,x+64f*s,b-166f*s),18f*s,18f*s,p)
        p.color=Color.rgb(178,145,91)
        c.drawRect(x-34f*s,b-154f*s,x+34f*s,b-143f*s,p)
        polygon(c,Color.rgb(178,145,91),x-12f*s,b-211f*s,x+12f*s,b-211f*s,x+19f*s,b-173f*s,x-18f*s,b-173f*s)
        p.color=Color.rgb(24,34,32)
        c.drawRoundRect(RectF(x-42f*s,b-72f*s,x-10f*s,b+68f*s),9f,9f,p)
        c.drawRoundRect(RectF(x+11f*s,b-72f*s,x+43f*s,b+68f*s),9f,9f,p)
    }
}
