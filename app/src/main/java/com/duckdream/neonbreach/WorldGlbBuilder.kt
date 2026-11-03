package com.duckdream.neonbreach

import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.*

/** Runtime terrain, lane surfaces and a shallow river. Environment props are CC0 glTF instances loaded by FilamentGameRenderer. */
internal object WorldGlbBuilder {
    private data class Part(val name:String, val material:Int,
        val tx:Float = 0f, val ty:Float = 0f, val tz:Float = 0f,
        val p:MutableList<Float> = ArrayList(),
        val n:MutableList<Float> = ArrayList(),
        val ix:MutableList<Int> = ArrayList()) {
        fun vertex(x:Float,y:Float,z:Float,nx:Float,ny:Float,nz:Float):Int {
            val id=p.size/3
            p.add(x);p.add(y);p.add(z);n.add(nx);n.add(ny);n.add(nz)
            return id
        }
        fun tri(a:Int,b:Int,c:Int){ix.add(a);ix.add(b);ix.add(c)}
    }

    private val parts=ArrayList<Part>()
    private lateinit var terrain:Part
    private lateinit var trail:Part

    private fun part(name:String,mat:Int)=Part(name,mat).also{parts.add(it)}
    private fun h(x:Float,z:Float):Float {
        val westRidge = 2.35f * exp(-((x + 24f).pow(2)) / 44f) * (0.58f + 0.42f * cos(z * 0.075f))
        val eastRidge = 2.18f * exp(-((x - 24f).pow(2)) / 48f) * (0.58f + 0.42f * cos(z * 0.07f))
        val southHighland = 1.55f * exp(-((z + 27f).pow(2)) / 36f) * exp(-(x.pow(2)) / 420f)
        val northHighland = 1.55f * exp(-((z - 27f).pow(2)) / 36f) * exp(-(x.pow(2)) / 420f)
        val jungleKnolls = 0.78f * exp(-((abs(x) - 8.5f).pow(2)) / 8.5f) * exp(-((abs(z) - 14f).pow(2)) / 42f)
        val riverDistance = abs(z - riverCenterZ(x))
        val riverBed = -0.58f * exp(-(riverDistance * riverDistance) / 8.5f)
        val riverBank = 0.72f * exp(-((riverDistance - 2.55f).pow(2)) / 1.9f)
        val rolling = 0.26f*sin(x*0.18f)*cos(z*0.14f)+0.16f*sin((x+z)*0.29f)
        val shelf = 0.52f * exp(-((abs(x) - 18.5f).pow(2)) / 5.5f) * exp(-((abs(z) - 13f).pow(2)) / 110f)
        return rolling + westRidge + eastRidge + southHighland + northHighland +
            jungleKnolls + riverBed + riverBank + shelf
    }

    internal fun heightAt(x: Float, z: Float): Float = h(x, z)
    internal fun normalAt(x: Float, z: Float): FloatArray {
        val e = 0.08f
        val dx = (h(x + e, z) - h(x - e, z)) / (2f * e)
        val dz = (h(x, z + e) - h(x, z - e)) / (2f * e)
        val length = sqrt(dx * dx + 1f + dz * dz)
        return floatArrayOf(-dx / length, 1f / length, -dz / length)
    }
    private fun norm(x:Float,z:Float):FloatArray {
        val e=0.04f
        val dx=(h(x+e,z)-h(x-e,z))/(2f*e)
        val dz=(h(x,z+e)-h(x,z-e))/(2f*e)
        val l=sqrt(dx*dx+1f+dz*dz)
        return floatArrayOf(-dx/l,1f/l,-dz/l)
    }
    private fun tri(part:Part,a:FloatArray,b:FloatArray,c:FloatArray,
                    na:FloatArray?=null,nb:FloatArray?=null,nc:FloatArray?=null) {
        val ux=b[0]-a[0];val uy=b[1]-a[1];val uz=b[2]-a[2]
        val vx=c[0]-a[0];val vy=c[1]-a[1];val vz=c[2]-a[2]
        var nx=uy*vz-uz*vy;var ny=uz*vx-ux*vz;var nz=ux*vy-uy*vx
        val l=sqrt(nx*nx+ny*ny+nz*nz).coerceAtLeast(0.00001f)
        nx/=l;ny/=l;nz/=l
        val ia=part.vertex(a[0],a[1],a[2],na?.get(0)?:nx,na?.get(1)?:ny,na?.get(2)?:nz)
        val ib=part.vertex(b[0],b[1],b[2],nb?.get(0)?:nx,nb?.get(1)?:ny,nb?.get(2)?:nz)
        val ic=part.vertex(c[0],c[1],c[2],nc?.get(0)?:nx,nc?.get(1)?:ny,nc?.get(2)?:nz)
        part.tri(ia,ib,ic)
    }
    private fun quad(p:Part,a:FloatArray,b:FloatArray,c:FloatArray,d:FloatArray) {
        // Input order is left-near, left-far, right-near, right-far; keep the top face CCW.
        tri(p,a,b,c);tri(p,b,d,c)
    }
    private fun triOutward(p: Part, a: FloatArray, b: FloatArray, c: FloatArray,
                           cx: Float, cy: Float, cz: Float) {
        val ux=b[0]-a[0]; val uy=b[1]-a[1]; val uz=b[2]-a[2]
        val vx=c[0]-a[0]; val vy=c[1]-a[1]; val vz=c[2]-a[2]
        val nx=uy*vz-uz*vy; val ny=uz*vx-ux*vz; val nz=ux*vy-uy*vx
        val mx=(a[0]+b[0]+c[0])/3f-cx
        val my=(a[1]+b[1]+c[1])/3f-cy
        val mz=(a[2]+b[2]+c[2])/3f-cz
        if (nx*mx+ny*my+nz*mz >= 0f) tri(p,a,b,c) else tri(p,a,c,b)
    }
    private fun triUp(p: Part, a: FloatArray, b: FloatArray, c: FloatArray) {
        val ux=b[0]-a[0]; val uz=b[2]-a[2]
        val vx=c[0]-a[0]; val vz=c[2]-a[2]
        val normalY=uz*vx-ux*vz
        if (normalY >= 0f) tri(p,a,b,c) else tri(p,a,c,b)
    }
    private fun box(p: Part, x: Float, y: Float, z: Float, sx: Float, sy: Float, sz: Float) {
        val hx=sx*0.5f; val hy=sy*0.5f; val hz=sz*0.5f
        val v=arrayOf(
            floatArrayOf(x-hx,y-hy,z-hz), floatArrayOf(x+hx,y-hy,z-hz),
            floatArrayOf(x+hx,y-hy,z+hz), floatArrayOf(x-hx,y-hy,z+hz),
            floatArrayOf(x-hx,y+hy,z-hz), floatArrayOf(x+hx,y+hy,z-hz),
            floatArrayOf(x+hx,y+hy,z+hz), floatArrayOf(x-hx,y+hy,z+hz)
        )
        val faces=arrayOf(
            intArrayOf(0,1,2,3), intArrayOf(4,7,6,5), intArrayOf(0,4,5,1),
            intArrayOf(1,5,6,2), intArrayOf(2,6,7,3), intArrayOf(3,7,4,0)
        )
        faces.forEach { face ->
            triOutward(p,v[face[0]],v[face[1]],v[face[2]],x,y,z)
            triOutward(p,v[face[0]],v[face[2]],v[face[3]],x,y,z)
        }
    }
    private fun boulder(p: Part, x: Float, z: Float, rx: Float, ry: Float, rz: Float, seed: Float) {
        val centerY=h(x,z)+ry*0.54f
        val top=floatArrayOf(x+sin(seed)*rx*0.12f,centerY+ry,z+cos(seed)*rz*0.12f)
        val bottom=floatArrayOf(x,centerY-ry*0.72f,z)
        val ring=Array(8) { i ->
            val a=2f*PI.toFloat()*i/8f+seed
            val wobble=0.78f+0.18f*sin(a*3f+seed)
            floatArrayOf(x+cos(a)*rx*wobble,centerY+sin(a*2.1f+seed)*ry*0.22f,z+sin(a)*rz*wobble)
        }
        for(i in ring.indices) {
            val next=(i+1)%ring.size
            triOutward(p,top,ring[i],ring[next],x,centerY,z)
            triOutward(p,bottom,ring[next],ring[i],x,centerY,z)
        }
    }
    private fun groundDisc(p: Part, x: Float, z: Float, rx: Float, rz: Float, lift: Float) {
        val cy=h(x,z)+lift
        val center=floatArrayOf(x,cy,z)
        val segments=36
        for(i in 0 until segments) {
            val a0=2f*PI.toFloat()*i/segments
            val a1=2f*PI.toFloat()*(i+1)/segments
            val ax=x+cos(a0)*rx; val az=z+sin(a0)*rz
            val bx=x+cos(a1)*rx; val bz=z+sin(a1)*rz
            val a=floatArrayOf(ax,h(ax,az)+lift,az)
            val b=floatArrayOf(bx,h(bx,bz)+lift,bz)
            triUp(p,center,a,b)
        }
    }
    private fun shrine(p: Part, x: Float, z: Float, scale: Float, broken: Boolean) {
        val base=h(x,z)+0.12f
        box(p,x,base+0.18f*scale,z,5.2f*scale,0.36f*scale,4.8f*scale)
        box(p,x,base+0.47f*scale,z,4.5f*scale,0.22f*scale,4.1f*scale)
        val corners=listOf(
            -1.72f to -1.48f, 1.72f to -1.48f,
            -1.72f to 1.48f, 1.72f to 1.48f
        )
        corners.forEachIndexed { index, point ->
            if (broken && index==3) return@forEachIndexed
            val px=x+point.first*scale
            val pz=z+point.second*scale
            box(p,px,base+1.45f*scale,pz,0.42f*scale,1.9f*scale,0.42f*scale)
        }
        box(p,x,base+2.52f*scale,z,4.25f*scale,0.38f*scale,0.58f*scale)
        if (!broken) box(p,x,base+2.52f*scale,z,0.58f*scale,0.38f*scale,3.65f*scale)
        else box(p,x-0.52f*scale,base+2.26f*scale,z+0.82f*scale,1.5f*scale,0.28f*scale,0.62f*scale)
        boulder(p,x+0.15f*scale,z+0.12f*scale,0.62f*scale,0.48f*scale,0.55f*scale,0.7f)
    }
    private lateinit var grassLight: Part
    private lateinit var grassDark: Part
    private lateinit var cliffs: Part
    private lateinit var earth: Part
    private lateinit var rock: Part

    private fun insideIsland(x: Float, z: Float): Boolean {
        val angle = atan2(z / 31f, x / 35f)
        val edge = 1f + 0.035f * sin(angle * 5f) + 0.020f * sin(angle * 9f + 1.4f) + 0.012f * cos(angle * 13f)
        val radius = sqrt((x / 35f).pow(2) + (z / 31f).pow(2))
        return radius <= edge
    }

    private val riverProfile = arrayOf(
        floatArrayOf(-34f,1.1f), floatArrayOf(-28f,0.55f), floatArrayOf(-21f,0.05f),
        floatArrayOf(-15f,-0.45f), floatArrayOf(-9f,-0.22f), floatArrayOf(-3f,0.25f),
        floatArrayOf(4f,0.38f), floatArrayOf(10f,0.02f), floatArrayOf(16f,-0.38f),
        floatArrayOf(23f,-0.18f), floatArrayOf(29f,0.22f), floatArrayOf(34f,0.8f)
    )

    private fun riverCenterZ(x: Float): Float {
        val points = riverProfile
        for (i in 0 until points.lastIndex) {
            if (x <= points[i + 1][0]) {
                val t = ((x - points[i][0]) / (points[i + 1][0] - points[i][0])).coerceIn(0f, 1f)
                return points[i][1] + (points[i + 1][1] - points[i][1]) * t
            }
        }
        return points.last()[1]
    }

    private fun terrainMesh() {
        val steps = 136
        val size = 76f
        val start = -38f
        val cell = size / steps
        for (zi in 0 until steps) {
            val z0 = start + zi * cell
            val z1 = z0 + cell
            for (xi in 0 until steps) {
                val x0 = start + xi * cell
                val x1 = x0 + cell
                val cx = (x0 + x1) * 0.5f
                val cz = (z0 + z1) * 0.5f
                if (!insideIsland(cx, cz)) continue
                // Carve a river bed into the terrain; water is no longer hidden below the meadow mesh.
                if (abs(cz - riverCenterZ(cx)) < 2.05f && abs(cx) < 33.5f) continue
                val noise = sin(cx * 0.43f + cz * 0.17f) + cos(cz * 0.31f - cx * 0.12f)
                val part = when {
                    abs(cx) > 17f && abs(cz) < 23f && noise > -0.25f -> rock
                    abs(cx) > 18f && noise < -0.35f -> earth
                    noise > 0.72f -> grassLight
                    sin(cx * 0.21f - cz * 0.33f) + cos(cx * 0.37f + cz * 0.28f) < -0.86f -> grassDark
                    else -> terrain
                }
                val p00 = floatArrayOf(x0, h(x0, z0), z0)
                val p10 = floatArrayOf(x1, h(x1, z0), z0)
                val p01 = floatArrayOf(x0, h(x0, z1), z1)
                val p11 = floatArrayOf(x1, h(x1, z1), z1)
                tri(part, p00, p01, p10, norm(x0,z0), norm(x0,z1), norm(x1,z0))
                tri(part, p10, p01, p11, norm(x1,z0), norm(x0,z1), norm(x1,z1))
            }
        }
        val segments = 220
        for (i in 0 until segments) {
            val a0 = 2f * PI.toFloat() * i / segments
            val a1 = 2f * PI.toFloat() * (i + 1) / segments
            fun edgePoint(angle: Float): FloatArray {
                val wobble = 1f + 0.035f * sin(angle * 5f) + 0.020f * sin(angle * 9f + 1.4f) + 0.012f * cos(angle * 13f)
                val x = 35f * wobble * cos(angle)
                val z = 31f * wobble * sin(angle)
                return floatArrayOf(x, h(x,z) - 0.02f, z)
            }
            val topA = edgePoint(a0)
            val topB = edgePoint(a1)
            val bottomA = floatArrayOf(topA[0] * 1.025f, -3.8f, topA[2] * 1.025f)
            val bottomB = floatArrayOf(topB[0] * 1.025f, -3.8f, topB[2] * 1.025f)
            tri(cliffs, topA, bottomA, topB)
            tri(cliffs, topB, bottomA, bottomB)
        }
    }

    private fun ringMesh(p: Part, innerRadius: Float, outerRadius: Float) {
        val segments = 64
        for (i in 0 until segments) {
            val a0 = 2f * PI.toFloat() * i / segments
            val a1 = 2f * PI.toFloat() * (i + 1) / segments
            val ia = floatArrayOf(innerRadius * cos(a0), 0.09f, innerRadius * sin(a0))
            val oa = floatArrayOf(outerRadius * cos(a0), 0.09f, outerRadius * sin(a0))
            val ib = floatArrayOf(innerRadius * cos(a1), 0.09f, innerRadius * sin(a1))
            val ob = floatArrayOf(outerRadius * cos(a1), 0.09f, outerRadius * sin(a1))
            triUp(p, ia, oa, ib)
            triUp(p, oa, ob, ib)
        }
    }

    private fun ringMeshAt(p: Part, centerX: Float, centerZ: Float, innerRadius: Float, outerRadius: Float) {
        val segments = 48
        for (i in 0 until segments) {
            val a0 = 2f * PI.toFloat() * i / segments
            val a1 = 2f * PI.toFloat() * (i + 1) / segments
            fun point(radius: Float, angle: Float): FloatArray {
                val x = centerX + radius * cos(angle)
                val z = centerZ + radius * sin(angle)
                return floatArrayOf(x, h(x, z) + 0.13f, z)
            }
            val ia = point(innerRadius, a0)
            val oa = point(outerRadius, a0)
            val ib = point(innerRadius, a1)
            val ob = point(outerRadius, a1)
            tri(p, ia, oa, ib)
            tri(p, oa, ob, ib)
        }
    }

    private fun ribbon(p: Part, points: List<FloatArray>, width: Float, lift: Float) {
        fun sample(t: Float): FloatArray {
            val f = t.coerceIn(0f, 0.99999f) * (points.size - 1)
            val i = floor(f).toInt()
            val u = f - i
            val p0 = points[(i - 1).coerceAtLeast(0)]
            val p1 = points[i]
            val p2 = points[(i + 1).coerceAtMost(points.lastIndex)]
            val p3 = points[(i + 2).coerceAtMost(points.lastIndex)]
            fun cat(a: Float, b: Float, c: Float, d: Float): Float =
                0.5f * ((2f * b) + (-a + c) * u +
                    (2f * a - 5f * b + 4f * c - d) * u * u +
                    (-a + 3f * b - 3f * c + d) * u * u * u)
            return floatArrayOf(
                cat(p0[0], p1[0], p2[0], p3[0]),
                cat(p0[1], p1[1], p2[1], p3[1])
            )
        }
        var previousLeft: FloatArray? = null
        var previousRight: FloatArray? = null
        for (i in 0..180) {
            val t = i / 180f
            val center = sample(t)
            val before = sample((t - 0.003f).coerceAtLeast(0f))
            val after = sample((t + 0.003f).coerceAtMost(1f))
            val dx = after[0] - before[0]
            val dz = after[1] - before[1]
            val length = sqrt(dx * dx + dz * dz).coerceAtLeast(0.0001f)
            val sideX = -dz / length
            val sideZ = dx / length
            val y = h(center[0], center[1]) + lift
            val left = floatArrayOf(center[0] + sideX * width, y, center[1] + sideZ * width)
            val right = floatArrayOf(center[0] - sideX * width, y, center[1] - sideZ * width)
            if (previousLeft != null && previousRight != null) {
                quad(p, previousLeft!!, left, previousRight!!, right)
            }
            previousLeft = left
            previousRight = right
        }
    }

    private fun floatBytes(v:List<Float>)=ByteBuffer.allocate(v.size*4).order(ByteOrder.LITTLE_ENDIAN).apply{v.forEach{putFloat(it)}}.array()
    private fun intBytes(v:List<Int>)=ByteBuffer.allocate(v.size*4).order(ByteOrder.LITTLE_ENDIAN).apply{v.forEach{putInt(it)}}.array()
    private fun align(out:ByteArrayOutputStream){while(out.size()%4!=0)out.write(0)}

    fun build():ByteArray {
        parts.clear()
        terrain=part("meadow_terrain",0)
        grassLight=part("sunlit_grass",1)
        grassDark=part("deep_grass",2)
        trail=part("limestone_lane_surface",3)
        earth=part("packed_earth",9)
        rock=part("exposed_stone",10)
        val routeEdge=part("lane_edge_stone",4)
        val water=part("crossing_river",5)
        cliffs=part("island_rock_rim",6)
        val pulse=part("pulse_ring",7)
        val shield=part("shield_ring",8)
        val campMarks=part("neutral_camp_marks",11)
        val objectiveMarks=part("neutral_objective_marks",12)
        val forestFloor=part("forest_floor",13)
        val undergrowth=part("undergrowth",14)
        val masonry=part("ruined_masonry",15)
        val boulderField=part("boulder_field",16)
        val shrineStone=part("objective_shrine",17)
        val ocean=part("surrounding_water",18)
        terrainMesh()
        ringMesh(pulse,0.88f,1.08f)
        ringMesh(shield,0.98f,1.15f)

        // Three asymmetric but readable lanes; each bends independently through the battlefield.
        val west=listOf(
            floatArrayOf(-14.2f,-31f),floatArrayOf(-15.2f,-23f),floatArrayOf(-14.6f,-15f),
            floatArrayOf(-13.4f,-7f),floatArrayOf(-13.0f,0f),floatArrayOf(-13.7f,8f),
            floatArrayOf(-14.8f,16f),floatArrayOf(-14.2f,24f),floatArrayOf(-14.2f,31f)
        )
        val center=listOf(
            floatArrayOf(0.5f,-31f),floatArrayOf(0.1f,-23f),floatArrayOf(-0.1f,-15f),
            floatArrayOf(-0.25f,-7f),floatArrayOf(0.5f,0f),floatArrayOf(0.3f,8f),
            floatArrayOf(-0.2f,16f),floatArrayOf(0.4f,24f),floatArrayOf(0.5f,31f)
        )
        val east=listOf(
            floatArrayOf(14.2f,-31f),floatArrayOf(15.2f,-23f),floatArrayOf(14.6f,-15f),
            floatArrayOf(13.4f,-7f),floatArrayOf(13.0f,0f),floatArrayOf(13.7f,8f),
            floatArrayOf(14.8f,16f),floatArrayOf(14.2f,24f),floatArrayOf(14.2f,31f)
        )
        ribbon(routeEdge,west,3.18f,0.025f);ribbon(trail,west,2.42f,0.075f)
        ribbon(routeEdge,center,3.12f,0.025f);ribbon(trail,center,2.36f,0.075f)
        ribbon(routeEdge,east,3.18f,0.025f);ribbon(trail,east,2.42f,0.075f)

        // Cross-lane jungle paths link the neutral camps to lane entrances.
        ribbon(earth,listOf(floatArrayOf(-8.2f,-27f),floatArrayOf(-8.8f,-20f),floatArrayOf(-8.2f,-14.5f),floatArrayOf(-9.1f,-8f),floatArrayOf(-7f,-2f)),0.62f,0.095f)
        ribbon(earth,listOf(floatArrayOf(8.2f,-27f),floatArrayOf(8.8f,-20f),floatArrayOf(8.2f,-14.5f),floatArrayOf(9.1f,-8f),floatArrayOf(7f,-2f)),0.62f,0.095f)
        ribbon(earth,listOf(floatArrayOf(-7f,2f),floatArrayOf(-9.1f,8f),floatArrayOf(-8.2f,14.5f),floatArrayOf(-8.8f,20f),floatArrayOf(-8.2f,27f)),0.62f,0.095f)
        ribbon(earth,listOf(floatArrayOf(7f,2f),floatArrayOf(9.1f,8f),floatArrayOf(8.2f,14.5f),floatArrayOf(8.8f,20f),floatArrayOf(8.2f,27f)),0.62f,0.095f)

        val river=listOf(
            floatArrayOf(-34f,1.1f),floatArrayOf(-28f,0.55f),floatArrayOf(-21f,0.05f),
            floatArrayOf(-15f,-0.45f),floatArrayOf(-9f,-0.22f),floatArrayOf(-3f,0.25f),
            floatArrayOf(4f,0.38f),floatArrayOf(10f,0.02f),floatArrayOf(16f,-0.38f),
            floatArrayOf(23f,-0.18f),floatArrayOf(29f,0.22f),floatArrayOf(34f,0.8f)
        )
        ribbon(water,river,1.72f,0.10f)
        ribbon(earth,river,2.18f,0.035f)

        // Forest clearings, camps and river sanctuaries are modeled as world geometry.
        val camps = listOf(
            -8.2f to -14.5f, 8.2f to -14.5f,
            -20.2f to -10f, 20.2f to -10f,
            -8.2f to 14.5f, 8.2f to 14.5f,
            -20.2f to 10f, 20.2f to 10f
        )
        camps.forEachIndexed { index, point ->
            val x=point.first; val z=point.second
            groundDisc(forestFloor,x,z,3.2f,2.65f,0.035f)
            groundDisc(earth,x,z,2.35f,1.85f,0.075f)
            for(i in 0 until 7) {
                val a=2f*PI.toFloat()*i/7f+index*0.31f
                boulder(boulderField,x+cos(a)*2.65f,z+sin(a)*2.0f,0.38f,0.32f,0.34f,a)
            }
            box(masonry,x+0.25f,h(x,z)+0.42f,z,0.72f,0.78f,0.72f)
            box(masonry,x-0.42f,h(x,z)+0.24f,z+0.52f,0.48f,0.38f,0.48f)
        }
        // Subtle stone edging keeps the camp footprint readable without flag markers.
        camps.forEach { point -> ringMeshAt(campMarks,point.first,point.second,2.05f,2.22f) }

        // Distinct objective arenas: raised stone dais, broken arches and exposed rock.
        groundDisc(forestFloor,-7f,0.2f,5.15f,4.25f,0.045f)
        groundDisc(forestFloor,7f,0.2f,5.15f,4.25f,0.045f)
        ringMeshAt(objectiveMarks,-7f,0.2f,4.12f,4.32f)
        ringMeshAt(objectiveMarks,7f,0.2f,4.12f,4.32f)
        shrine(shrineStone,-7f,0.2f,0.92f,true)
        shrine(shrineStone,7f,0.2f,0.92f,false)
        for(i in 0 until 12) {
            val a=2f*PI.toFloat()*i/12f
            boulder(boulderField,-7f+cos(a)*4.55f,0.2f+sin(a)*3.75f,0.48f,0.5f,0.42f,a)
            boulder(boulderField,7f+cos(a)*4.55f,0.2f+sin(a)*3.75f,0.48f,0.5f,0.42f,a+1f)
        }

        // Additional elevation and rubble make the outer jungle and base approaches readable.
        val groves=listOf(
            -25f to -19f,-27f to -8f,-23f to 8f,-26f to 19f,
            25f to -19f,27f to -8f,23f to 8f,26f to 19f,
            -8.5f to -21f,8.5f to -21f,-8.5f to 21f,8.5f to 21f
        )
        groves.forEachIndexed { index, point ->
            groundDisc(forestFloor,point.first,point.second,2.8f,2.1f,0.02f)
            for(j in 0 until 4) {
                val a=2f*PI.toFloat()*j/4f+index*0.43f
                val rx=0.42f+(j%2)*0.22f
                boulder(boulderField,point.first+cos(a)*1.8f,point.second+sin(a)*1.4f,rx,rx*0.82f,rx,a)
            }
        }

        // Dense low-profile undergrowth fills forest gaps without transparent foliage cards.
        for(i in 0 until 56) {
            val x=when(i%4){0->-10.1f;1->-6.1f;2->6.1f;else->10.1f} + sin(i*1.71f)*0.82f
            val z= -22f + (i/4)*3.15f
            if (abs(z)>24f) continue
            if (i%8<4 && z>0f) continue
            val radius=0.30f+(i%3)*0.07f
            boulder(undergrowth,x,z,radius*1.45f,radius*0.68f,radius, i*0.31f)
        }

        // Fortified base approach walls and gatehouse paving.
        for(sign in listOf(-1f,1f)) {
            val z=sign*24.2f
            box(masonry,-7.0f,h(-7f,z)+0.72f,z,5.2f,1.35f,0.72f)
            box(masonry,7.0f,h(7f,z)+0.72f,z,5.2f,1.35f,0.72f)
            box(masonry,0f,h(0f,sign*27f)+0.09f,sign*27f,13.2f,0.18f,4.8f)
        }

        // A dark-blue water plane below the island cliffs adds a real horizon layer.
        quad(ocean,floatArrayOf(-58f,-2.55f,-52f),floatArrayOf(58f,-2.55f,-52f),
            floatArrayOf(58f,-2.55f,52f),floatArrayOf(-58f,-2.55f,52f))

        val bin=ByteArrayOutputStream();val views=StringBuilder();val accessors=StringBuilder()
        val meshes=StringBuilder();val nodes=StringBuilder();var vi=0;var ai=0
        parts.forEachIndexed { index,p ->
            if(p.ix.isEmpty()) return@forEachIndexed
            align(bin);val po=bin.size();val pb=floatBytes(p.p);bin.write(pb)
            align(bin);val no=bin.size();val nb=floatBytes(p.n);bin.write(nb)
            align(bin);val io=bin.size();val ib=intBytes(p.ix);bin.write(ib)
            if(views.isNotEmpty())views.append(',')
            views.append("{\"buffer\":0,\"byteOffset\":$po,\"byteLength\":${pb.size},\"target\":34962}")
            views.append(",{\"buffer\":0,\"byteOffset\":$no,\"byteLength\":${nb.size},\"target\":34962}")
            views.append(",{\"buffer\":0,\"byteOffset\":$io,\"byteLength\":${ib.size},\"target\":34963}")
            val xs=p.p.filterIndexed{i,_->i%3==0};val ys=p.p.filterIndexed{i,_->i%3==1};val zs=p.p.filterIndexed{i,_->i%3==2}
            val mn=listOf(xs.minOrNull()?:0f,ys.minOrNull()?:0f,zs.minOrNull()?:0f)
            val mx=listOf(xs.maxOrNull()?:0f,ys.maxOrNull()?:0f,zs.maxOrNull()?:0f)
            if(accessors.isNotEmpty())accessors.append(',')
            accessors.append("{\"bufferView\":$vi,\"componentType\":5126,\"count\":${p.p.size/3},\"type\":\"VEC3\",\"min\":[${mn.joinToString()}],\"max\":[${mx.joinToString()}]}")
            accessors.append(",{\"bufferView\":${vi+1},\"componentType\":5126,\"count\":${p.n.size/3},\"type\":\"VEC3\"}")
            accessors.append(",{\"bufferView\":${vi+2},\"componentType\":5125,\"count\":${p.ix.size},\"type\":\"SCALAR\"}")
            if(meshes.isNotEmpty())meshes.append(',')
            meshes.append("{\"name\":\"" + p.name + "\",\"primitives\":[{\"attributes\":{\"POSITION\":$ai,\"NORMAL\":${ai+1}},\"indices\":${ai+2},\"material\":${p.material}}]}")
            if(nodes.isNotEmpty())nodes.append(',')
            nodes.append("{\"name\":\"" + p.name + "\",\"mesh\":" + index + ",\"translation\":[" + p.tx + "," + p.ty + "," + p.tz + "]}")
            vi+=3;ai+=3
        }
        val names=listOf("Old meadow","Sunlit grass","Deep grass","Limestone road","Roadside stone","River water","Island rock","Pulse aura","Shield aura","Packed earth","Exposed stone","Neutral camp markers","River objective markers","Forest soil","Forest undergrowth","Ruined masonry","Field boulders","Objective shrine","Surrounding water")
        val colors=listOf(
            listOf(0.13f,0.17f,0.075f,1f),
            listOf(0.19f,0.24f,0.10f,1f),
            listOf(0.06f,0.095f,0.045f,1f),
            listOf(0.30f,0.245f,0.17f,1f),
            listOf(0.13f,0.11f,0.075f,1f),
            listOf(0.025f,0.075f,0.11f,1f),
            listOf(0.105f,0.10f,0.085f,1f),
            listOf(0.07f,0.39f,0.72f,1f),
            listOf(0.72f,0.50f,0.12f,1f),
            listOf(0.26f,0.16f,0.085f,1f),
            listOf(0.24f,0.245f,0.22f,1f),
            listOf(0.18f,0.15f,0.10f,1f),
            listOf(0.26f,0.22f,0.15f,1f),
            listOf(0.07f,0.11f,0.05f,1f),
            listOf(0.09f,0.15f,0.055f,1f),
            listOf(0.22f,0.23f,0.19f,1f),
            listOf(0.27f,0.27f,0.24f,1f),
            listOf(0.34f,0.30f,0.22f,1f),
            listOf(0.02f,0.06f,0.09f,1f))
        val materials=names.mapIndexed{i,name->
            val roughness=when(i){5->0.34f;7,8->0.42f;else->0.88f}
            "{\"name\":\"$name\",\"pbrMetallicRoughness\":{\"baseColorFactor\":[${colors[i].joinToString()}],\"metallicFactor\":0.02,\"roughnessFactor\":$roughness}}"
        }.joinToString(",")
        align(bin);val payload=bin.toByteArray()
        val nodeIds=parts.indices.filter{parts[it].ix.isNotEmpty()}.joinToString(",")
        val json="""{"asset":{"version":"2.0","generator":"DuckDreamStudios-World-0.15"},"scene":0,"scenes":[{"nodes":[$nodeIds]}],"nodes":[$nodes],"meshes":[$meshes],"materials":[$materials],"buffers":[{"byteLength":${payload.size}}],"bufferViews":[$views],"accessors":[$accessors]}"""
        val raw=json.toByteArray(Charsets.UTF_8);val pad=(4-raw.size%4)%4;val jsonBytes=raw+ByteArray(pad){0x20}
        val binPad=(4-payload.size%4)%4;val total=12+8+jsonBytes.size+8+payload.size+binPad
        return ByteBuffer.allocate(total).order(ByteOrder.LITTLE_ENDIAN).apply{
            put(byteArrayOf(0x67,0x6c,0x54,0x46));putInt(2);putInt(total)
            putInt(jsonBytes.size);putInt(0x4E4F534A);put(jsonBytes)
            putInt(payload.size+binPad);putInt(0x004E4942);put(payload);repeat(binPad){put(0)}
        }.array()
    }
}
