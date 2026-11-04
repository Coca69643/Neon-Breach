package com.duckdream.neonbreach

import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.*

/** Four offline terrain materials; each albedo/normal pair is embedded into the world GLB. */
internal data class TerrainTextureSet(val albedo: List<ByteArray>, val normal: List<ByteArray>) {
    init {
        require(albedo.size == 4 && normal.size == 4) {
            "Terrain requires grass, moss, soil and rock albedo/normal maps"
        }
        require((albedo + normal).all { it.isNotEmpty() }) { "Terrain texture maps cannot be empty" }
    }
}

/** Runtime terrain, lane surfaces and a shallow river. Environment props are CC0 glTF instances loaded by FilamentGameRenderer. */
internal object WorldGlbBuilder {
    private data class Part(val name:String, val material:Int,
        val tx:Float = 0f, val ty:Float = 0f, val tz:Float = 0f,
        val p:MutableList<Float> = ArrayList(),
        val n:MutableList<Float> = ArrayList(),
        val uv:MutableList<Float> = ArrayList(),
        val ix:MutableList<Int> = ArrayList()) {
        fun vertex(x:Float,y:Float,z:Float,nx:Float,ny:Float,nz:Float):Int {
            val id=p.size/3
            val scale = ArenaMapDefinition.WORLD_SCALE
            val scaledNx = nx / scale
            val scaledNz = nz / scale
            val normalLength = sqrt(scaledNx * scaledNx + ny * ny + scaledNz * scaledNz).coerceAtLeast(0.00001f)
            p.add(x * scale);p.add(y);p.add(z * scale)
            n.add(scaledNx / normalLength);n.add(ny / normalLength);n.add(scaledNz / normalLength)
            if (material == 0 || material == 1 || material == 2 || material == 9 || material == 10) {
                val tileSize = 3.8f
                val u = x / tileSize
                val v = z / tileSize
                uv.add(u)
                uv.add(v)
            }
            return id
        }
        fun tri(a:Int,b:Int,c:Int){ix.add(a);ix.add(b);ix.add(c)}
    }

    private val parts=ArrayList<Part>()
    private lateinit var terrain:Part
    private lateinit var trail:Part

    private fun part(name:String,mat:Int)=Part(name,mat).also{parts.add(it)}
    private fun riverNearest(x: Float, z: Float): FloatArray {
        var bestDistance = Float.POSITIVE_INFINITY
        var bestWidth = ArenaWorld17Generated.river.first().halfWidth
        for (index in 0 until ArenaWorld17Generated.river.lastIndex) {
            val a = ArenaWorld17Generated.river[index]
            val b = ArenaWorld17Generated.river[index + 1]
            val dx = b.position.x - a.position.x
            val dz = b.position.z - a.position.z
            val denominator = (dx * dx + dz * dz).coerceAtLeast(0.0001f)
            val t = (((x - a.position.x) * dx + (z - a.position.z) * dz) / denominator).coerceIn(0f, 1f)
            val px = a.position.x + dx * t
            val pz = a.position.z + dz * t
            val distance = (x - px).pow(2) + (z - pz).pow(2)
            if (distance < bestDistance) {
                bestDistance = distance
                bestWidth = a.halfWidth + (b.halfWidth - a.halfWidth) * t
            }
        }
        return floatArrayOf(sqrt(bestDistance), bestWidth)
    }

    private fun h(x: Float, z: Float): Float {
        var ridge = 0f
        var valleyControl = 0f
        for (control in ArenaWorld17Generated.elevationControls) {
            val dx = x - control.position.x
            val dz = z - control.position.z
            val influence = exp(-(dx * dx + dz * dz) /
                (control.radius * control.radius * 0.50f).coerceAtLeast(0.001f))
            if (control.height >= 0f) ridge = max(ridge, control.height * influence)
            else valleyControl += control.height * influence
        }
        val river = riverNearest(x, z)
        val channel = -ArenaWorld17Generated.RIVER_VALLEY_DEPTH_M *
            exp(-(river[0] * river[0]) /
                (river[1] * river[1] * 1.60f).coerceAtLeast(0.001f))
        val broadPhase = (ArenaWorld17Generated.BROAD_NOISE_SEED % 97) * 0.013f
        val detailPhase = (ArenaWorld17Generated.DETAIL_NOISE_SEED % 97) * 0.013f
        val broadNoise = ArenaWorld17Generated.BROAD_NOISE_AMPLITUDE_M * (
            0.58f * sin((x + broadPhase) * 0.031f) * cos((z - broadPhase) * 0.027f) +
                0.42f * sin((x + z) * 0.019f + broadPhase)
            )
        val detailNoise = ArenaWorld17Generated.DETAIL_NOISE_AMPLITUDE_M *
            sin(x * 0.19f + z * 0.13f + detailPhase) *
            cos(z * 0.17f - x * 0.11f - detailPhase)
        return (ridge + valleyControl + channel + broadNoise + detailNoise)
            .coerceIn(ArenaWorld17Generated.MIN_HEIGHT_M, ArenaWorld17Generated.MAX_HEIGHT_M)
    }

    internal fun heightAt(x: Float, z: Float): Float = h(x, z)

    internal fun normalAt(x: Float, z: Float): FloatArray {
        val e = 0.12f
        val dx = (h(x + e, z) - h(x - e, z)) / (2f * e)
        val dz = (h(x, z + e) - h(x, z - e)) / (2f * e)
        val length = sqrt(dx * dx + 1f + dz * dz)
        return floatArrayOf(-dx / length, 1f / length, -dz / length)
    }

    private fun norm(x: Float, z: Float): FloatArray {
        val e = 0.12f
        val dx = (h(x + e, z) - h(x - e, z)) / (2f * e)
        val dz = (h(x, z + e) - h(x, z - e)) / (2f * e)
        val length = sqrt(dx * dx + 1f + dz * dz)
        return floatArrayOf(-dx / length, 1f / length, -dz / length)
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

    private fun insideIsland(x: Float, z: Float): Boolean =
        x in -ArenaWorld17Generated.HALF_WIDTH_M..ArenaWorld17Generated.HALF_WIDTH_M &&
            z in -ArenaWorld17Generated.HALF_DEPTH_M..ArenaWorld17Generated.HALF_DEPTH_M

    private fun terrainMesh() {
        val countX = ArenaWorld17Generated.TERRAIN_VERTICES_X
        val countZ = ArenaWorld17Generated.TERRAIN_VERTICES_Z
        val halfX = ArenaWorld17Generated.HALF_WIDTH_M
        val halfZ = ArenaWorld17Generated.HALF_DEPTH_M
        val cellX = (halfX * 2f) / (countX - 1)
        val cellZ = (halfZ * 2f) / (countZ - 1)
        val terrainParts = listOf(terrain, grassLight, grassDark, earth, rock)
        val vertexCache = Array(terrainParts.size) { IntArray(countX * countZ) { -1 } }

        fun vertex(partIndex: Int, ix: Int, iz: Int): Int {
            val cache = vertexCache[partIndex]
            val key = iz * countX + ix
            val existing = cache[key]
            if (existing >= 0) return existing
            val x = -halfX + ix * cellX
            val z = -halfZ + iz * cellZ
            val normal = norm(x, z)
            val created = terrainParts[partIndex].vertex(
                x, h(x, z), z, normal[0], normal[1], normal[2]
            )
            cache[key] = created
            return created
        }

        for (iz in 0 until countZ - 1) {
            val z0 = -halfZ + iz * cellZ
            val z1 = z0 + cellZ
            for (ix in 0 until countX - 1) {
                val x0 = -halfX + ix * cellX
                val x1 = x0 + cellX
                val cx = (x0 + x1) * 0.5f
                val cz = (z0 + z1) * 0.5f
                if (!insideIsland(cx, cz)) continue
                val river = riverNearest(cx, cz)
                if (river[0] < river[1] + 0.72f) continue

                val fieldNoise = sin(cx * 0.071f + cos(cz * 0.043f)) +
                    0.55f * cos(cz * 0.058f - cx * 0.037f)
                val slope = sqrt(
                    ((h(x1, cz) - h(x0, cz)) / cellX).pow(2) +
                        ((h(cx, z1) - h(cx, z0)) / cellZ).pow(2)
                )
                var laneDistance = Float.POSITIVE_INFINITY
                for (lane in ArenaMapDefinition.lanes) {
                    for (segment in 0 until lane.points.lastIndex) {
                        val a = lane.points[segment]
                        val b = lane.points[segment + 1]
                        val dx = b.x - a.x
                        val dz = b.z - a.z
                        val denominator = (dx * dx + dz * dz).coerceAtLeast(0.0001f)
                        val t = (((cx - a.x) * dx + (cz - a.z) * dz) / denominator).coerceIn(0f, 1f)
                        laneDistance = min(laneDistance, hypot(cx - (a.x + dx * t), cz - (a.z + dz * t)) - lane.width * 0.5f)
                    }
                }
                val campDistance = ArenaMapDefinition.camps.minOf { hypot(cx - it.position.x, cz - it.position.z) }
                val inJunglePocket = campDistance < 15.0f &&
                    ArenaWorld17Generated.jungles.any { region ->
                        var inside = false
                        for (i in region.boundary.indices) {
                            val a = region.boundary[i]
                            val q = region.boundary[(i + 1) % region.boundary.size]
                            if ((a.z > cz) != (q.z > cz) && cx < (q.x - a.x) * (cz - a.z) / (q.z - a.z) + a.x) inside = !inside
                        }
                        inside
                    }
                val material = when {
                    slope > 0.72f -> 4
                    inJunglePocket -> if (fieldNoise > 0.15f) 1 else 2
                    laneDistance < 2.2f -> 3
                    river[0] < river[1] + 3.2f -> 3
                    fieldNoise > 0.55f -> 0
                    else -> 3
                }

                val a = vertex(material, ix, iz)
                val b = vertex(material, ix, iz + 1)
                val c = vertex(material, ix + 1, iz)
                val d = vertex(material, ix + 1, iz + 1)
                val target = terrainParts[material]
                target.tri(a, b, c)
                target.tri(c, b, d)
            }
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

    private fun ribbon(p: Part, points: List<FloatArray>, width: Float, lift: Float, segments: Int = 180) {
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
        for (i in 0..segments) {
            val t = i / segments.toFloat()
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

    private fun buildRiverChannel(
        water: Part,
        shallows: Part,
        sandbanks: Part,
        centerline: List<ArenaMapDefinition.RiverPoint>
    ) {
        fun sample(t: Float): FloatArray {
            val f = t.coerceIn(0f, 0.99999f) * (centerline.size - 1)
            val index = floor(f).toInt()
            val u = f - index
            val p0 = centerline[(index - 1).coerceAtLeast(0)]
            val p1 = centerline[index]
            val p2 = centerline[(index + 1).coerceAtMost(centerline.lastIndex)]
            val p3 = centerline[(index + 2).coerceAtMost(centerline.lastIndex)]
            fun cat(a: Float, b: Float, c: Float, d: Float): Float =
                0.5f * ((2f * b) + (-a + c) * u +
                    (2f * a - 5f * b + 4f * c - d) * u * u +
                    (-a + 3f * b - 3f * c + d) * u * u * u)
            return floatArrayOf(
                cat(p0.x, p1.x, p2.x, p3.x),
                cat(p0.z, p1.z, p2.z, p3.z),
                cat(p0.halfWidth, p1.halfWidth, p2.halfWidth, p3.halfWidth).coerceIn(4.5f, 8.5f)
            )
        }

        var previousWaterLeft: FloatArray? = null
        var previousWaterRight: FloatArray? = null
        var previousShallowInnerLeft: FloatArray? = null
        var previousShallowOuterLeft: FloatArray? = null
        var previousShallowInnerRight: FloatArray? = null
        var previousShallowOuterRight: FloatArray? = null
        var previousBankInnerLeft: FloatArray? = null
        var previousBankOuterLeft: FloatArray? = null
        var previousBankInnerRight: FloatArray? = null
        var previousBankOuterRight: FloatArray? = null

        fun addBand(part: Part, previousInner: FloatArray, inner: FloatArray,
                    previousOuter: FloatArray, outer: FloatArray) {
            triUp(part, previousInner, inner, outer)
            triUp(part, previousInner, outer, previousOuter)
        }

        for (index in 0..180) {
            val t = index / 180f
            val center = sample(t)
            val before = sample((t - 0.003f).coerceAtLeast(0f))
            val after = sample((t + 0.003f).coerceAtMost(1f))
            val dx = after[0] - before[0]
            val dz = after[1] - before[1]
            val tangentLength = sqrt(dx * dx + dz * dz).coerceAtLeast(0.0001f)
            val sideX = -dz / tangentLength
            val sideZ = dx / tangentLength
            val x = center[0]
            val z = center[1]
            val width = center[2]
            val surfaceY = h(x, z) + 0.54f +
                0.014f * sin(x * 0.53f + z * 1.7f) +
                0.009f * cos(x * 0.81f - z * 2.2f)

            fun waterEdge(offset: Float, ripple: Float): FloatArray =
                floatArrayOf(x + sideX * offset, surfaceY + ripple, z + sideZ * offset)
            fun bankEdge(offset: Float): FloatArray {
                val px = x + sideX * offset
                val pz = z + sideZ * offset
                return floatArrayOf(px, h(px, pz) + 0.025f, pz)
            }

            val waterLeft = waterEdge(width, 0f)
            val waterRight = waterEdge(-width, 0f)
            val shallowInnerLeft = waterEdge(width * 0.68f, 0.012f)
            val shallowOuterLeft = waterEdge(width, 0.012f)
            val shallowInnerRight = waterEdge(-width * 0.68f, 0.012f)
            val shallowOuterRight = waterEdge(-width, 0.012f)
            val bankInnerLeft = bankEdge(width + 0.025f)
            val bankOuterLeft = bankEdge(width + 0.82f)
            val bankInnerRight = bankEdge(-width - 0.025f)
            val bankOuterRight = bankEdge(-width - 0.82f)

            if (previousWaterLeft != null && previousWaterRight != null) {
                quad(water, previousWaterLeft!!, waterLeft, previousWaterRight!!, waterRight)
                addBand(shallows, previousShallowInnerLeft!!, shallowInnerLeft,
                    previousShallowOuterLeft!!, shallowOuterLeft)
                addBand(shallows, previousShallowInnerRight!!, shallowInnerRight,
                    previousShallowOuterRight!!, shallowOuterRight)
                addBand(sandbanks, previousBankInnerLeft!!, bankInnerLeft,
                    previousBankOuterLeft!!, bankOuterLeft)
                addBand(sandbanks, previousBankInnerRight!!, bankInnerRight,
                    previousBankOuterRight!!, bankOuterRight)
            }
            previousWaterLeft = waterLeft
            previousWaterRight = waterRight
            previousShallowInnerLeft = shallowInnerLeft
            previousShallowOuterLeft = shallowOuterLeft
            previousShallowInnerRight = shallowInnerRight
            previousShallowOuterRight = shallowOuterRight
            previousBankInnerLeft = bankInnerLeft
            previousBankOuterLeft = bankOuterLeft
            previousBankInnerRight = bankInnerRight
            previousBankOuterRight = bankOuterRight
        }
    }

    private fun floatBytes(v:List<Float>)=ByteBuffer.allocate(v.size*4).order(ByteOrder.LITTLE_ENDIAN).apply{v.forEach{putFloat(it)}}.array()
    private fun intBytes(v:List<Int>)=ByteBuffer.allocate(v.size*4).order(ByteOrder.LITTLE_ENDIAN).apply{v.forEach{putInt(it)}}.array()
    private fun align(out:ByteArrayOutputStream){while(out.size()%4!=0)out.write(0)}

    fun build(terrainTextures: TerrainTextureSet? = null):ByteArray {
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
        val masonry=part("ruined_masonry",14)
        val shrineStone=part("objective_shrine",15)
        val ocean=part("surrounding_water",16)
        val riverShallows=part("river_shallows",17)
        val riverSandbanks=part("river_sandbanks",18)
        val riverGlints=part("river_flow_glints",19)
        terrainMesh()
        ringMesh(pulse,0.88f,1.08f)
        ringMesh(shield,0.98f,1.15f)

        // Primary lanes are blended into the packed-earth terrain mask, not bright ribbons.
        ArenaMapDefinition.validate()

        // Narrow organic tracks connect each neutral clearing to its nearest route.
        ArenaMapDefinition.camps.forEach { camp ->
            val z = camp.position.z
            val lane = (0..2).minByOrNull {
                kotlin.math.abs(ArenaMapDefinition.laneCenterX(it, z) - camp.position.x)
            } ?: 1
            val targetX = ArenaMapDefinition.laneCenterX(lane, z)
            val midpointX = (camp.position.x + targetX) * 0.5f
            ribbon(
                earth,
                listOf(
                    floatArrayOf(camp.position.x, z),
                    floatArrayOf(midpointX, z + 0.55f),
                    floatArrayOf(targetX, z)
                ),
                0.72f, 0.09f, 36
            )
        }

        buildRiverChannel(water, riverShallows, riverSandbanks, ArenaMapDefinition.riverCenterline)


        // Low, asymmetrical shoals are anchored to three bends in the canonical river spline.
        listOf(3, 6, 9).forEachIndexed { index, pointIndex ->
            val point = ArenaWorld17Generated.river[pointIndex].position
            groundDisc(
                riverSandbanks, point.x, point.z,
                1.15f + index * 0.16f, 0.56f + index * 0.08f, 0.70f
            )
        }

        // Forest clearings, camps and river sanctuaries are modeled as world geometry.
        ArenaMapDefinition.camps.forEachIndexed { index, camp ->
            val x = camp.position.x
            val z = camp.position.z
            groundDisc(earth,x,z,3.4f,2.8f,0.035f)
            groundDisc(earth,x,z,2.35f,1.85f,0.075f)
            // Textured rocks, ferns and mushrooms are baked into the static nature GLBs.
        }
        // Subtle stone edging keeps the camp footprint readable without flag markers.
        ArenaMapDefinition.camps.forEach { camp ->
            ringMeshAt(campMarks,camp.position.x,camp.position.z,2.05f,2.22f)
        }

        // Distinct objective arenas: raised stone dais, broken arches and exposed rock.
        ArenaMapDefinition.objectives.forEachIndexed { index, objective ->
            val x = objective.position.x
            val z = objective.position.z
            groundDisc(rock,x,z,5.15f,4.25f,0.045f)
            ringMeshAt(objectiveMarks,x,z,4.12f,4.32f)
            shrine(shrineStone,x,z,0.92f,index == 0)
        }

        // Groundcover and rocks are supplied by two offline, texture-backed GLBs.

        // Fortified courtyards are softly integrated into the terrain at the canonical base anchors.
        ArenaWorld17Generated.bases.forEach { base ->
            groundDisc(masonry, base.position.x, base.position.z, 8.6f, 7.4f, 0.16f)
        }

        // Connected mainland battlefield; no island moat or coastline mesh.

        val bin=ByteArrayOutputStream();val views=StringBuilder();val accessors=StringBuilder()
        val meshes=StringBuilder();val nodes=StringBuilder();var vi=0;var ai=0
        parts.forEachIndexed { index,p ->
            if(p.ix.isEmpty()) return@forEachIndexed
            align(bin);val po=bin.size();val pb=floatBytes(p.p);bin.write(pb)
            align(bin);val no=bin.size();val nb=floatBytes(p.n);bin.write(nb)
            align(bin);val io=bin.size();val ib=intBytes(p.ix);bin.write(ib)
            val hasUv = p.uv.size == (p.p.size / 3) * 2
            var uo = 0
            var ub = ByteArray(0)
            if (hasUv) {
                align(bin);uo=bin.size();ub=floatBytes(p.uv);bin.write(ub)
            }
            if(views.isNotEmpty())views.append(',')
            views.append("{\"buffer\":0,\"byteOffset\":$po,\"byteLength\":${pb.size},\"target\":34962}")
            views.append(",{\"buffer\":0,\"byteOffset\":$no,\"byteLength\":${nb.size},\"target\":34962}")
            views.append(",{\"buffer\":0,\"byteOffset\":$io,\"byteLength\":${ib.size},\"target\":34963}")
            if (hasUv) views.append(",{\"buffer\":0,\"byteOffset\":$uo,\"byteLength\":${ub.size},\"target\":34962}")
            val xs=p.p.filterIndexed{i,_->i%3==0};val ys=p.p.filterIndexed{i,_->i%3==1};val zs=p.p.filterIndexed{i,_->i%3==2}
            val mn=listOf(xs.minOrNull()?:0f,ys.minOrNull()?:0f,zs.minOrNull()?:0f)
            val mx=listOf(xs.maxOrNull()?:0f,ys.maxOrNull()?:0f,zs.maxOrNull()?:0f)
            if(accessors.isNotEmpty())accessors.append(',')
            accessors.append("{\"bufferView\":$vi,\"componentType\":5126,\"count\":${p.p.size/3},\"type\":\"VEC3\",\"min\":[${mn.joinToString()}],\"max\":[${mx.joinToString()}]}")
            accessors.append(",{\"bufferView\":${vi+1},\"componentType\":5126,\"count\":${p.n.size/3},\"type\":\"VEC3\"}")
            accessors.append(",{\"bufferView\":${vi+2},\"componentType\":5125,\"count\":${p.ix.size},\"type\":\"SCALAR\"}")
            if (hasUv) accessors.append(",{\"bufferView\":${vi+3},\"componentType\":5126,\"count\":${p.uv.size/2},\"type\":\"VEC2\"}")
            if(meshes.isNotEmpty())meshes.append(',')
            val uvAttribute = if (hasUv) ",\"TEXCOORD_0\":${ai+3}" else ""
            meshes.append("{\"name\":\"" + p.name + "\",\"primitives\":[{\"attributes\":{\"POSITION\":$ai,\"NORMAL\":${ai+1}$uvAttribute},\"indices\":${ai+2},\"material\":${p.material}}]}")
            if(nodes.isNotEmpty())nodes.append(',')
            nodes.append("{\"name\":\"" + p.name + "\",\"mesh\":" + index + ",\"translation\":[" + p.tx + "," + p.ty + "," + p.tz + "]}")
            vi += if (hasUv) 4 else 3
            ai += if (hasUv) 4 else 3
        }
        val imageViews = ArrayList<Int>()
        if (terrainTextures != null) {
            val allImages = terrainTextures.albedo + terrainTextures.normal
            for (image in allImages) {
                align(bin)
                val offset = bin.size()
                bin.write(image)
                if (views.isNotEmpty()) views.append(',')
                views.append("{\"buffer\":0,\"byteOffset\":$offset,\"byteLength\":${image.size}}")
                imageViews.add(vi++)
            }
        }
        val names=listOf("Old meadow","Sunlit grass","Deep grass","Limestone road","Roadside stone","River water","Island rock","Pulse aura","Shield aura","Packed earth","Exposed stone","Neutral camp markers","River objective markers","Forest soil","Ruined masonry","Objective shrine","Surrounding water","River shallows","River sandbanks","Water shimmer")
        val colors=listOf(
            listOf(0.96f,1.0f,0.88f,1f),
            listOf(1.0f,1.0f,0.90f,1f),
            listOf(0.88f,0.96f,0.78f,1f),
            listOf(0.30f,0.245f,0.17f,1f),
            listOf(0.13f,0.11f,0.075f,1f),
            listOf(0.035f,0.22f,0.27f,1f),
            listOf(0.105f,0.10f,0.085f,1f),
            listOf(0.07f,0.39f,0.72f,1f),
            listOf(0.72f,0.50f,0.12f,1f),
            listOf(1.0f,0.98f,0.92f,1f),
            listOf(1.0f,1.0f,1.0f,1f),
            listOf(0.18f,0.15f,0.10f,1f),
            listOf(0.26f,0.22f,0.15f,1f),
            listOf(0.07f,0.11f,0.05f,1f),
            listOf(0.22f,0.23f,0.19f,1f),
            listOf(0.34f,0.30f,0.22f,1f),
            listOf(0.02f,0.06f,0.09f,1f),
            listOf(0.075f,0.36f,0.39f,1f),
            listOf(0.48f,0.36f,0.22f,1f),
            listOf(0.40f,0.78f,0.72f,1f))
        check(names.size == colors.size && parts.size == names.size && parts.size == 20) {
            "World GLB terrain palette mismatch: parts=" + parts.size + ", names=" + names.size + ", colors=" + colors.size
        }
        val materials=names.mapIndexed{i,name->
            val roughness=when(i){5->0.22f;17->0.30f;19->0.18f;7,8->0.42f;else->0.88f}
            val textureSlot = when(i){0,1->0;2->1;9->2;10->3;else->-1}
            val pbr = "{\"baseColorFactor\":[${colors[i].joinToString()}],\"metallicFactor\":0.0,\"roughnessFactor\":$roughness" +
                (if (terrainTextures != null && textureSlot >= 0) ",\"baseColorTexture\":{\"index\":$textureSlot}" else "") + "}"
            val normal = if (terrainTextures != null && textureSlot >= 0) ",\"normalTexture\":{\"index\":${textureSlot + 4},\"scale\":0.68}" else ""
            "{\"name\":\"$name\",\"pbrMetallicRoughness\":$pbr$normal}"
        }.joinToString(",")
        align(bin);val payload=bin.toByteArray()
        val nodeIds=parts.indices.filter{parts[it].ix.isNotEmpty()}.joinToString(",")
        val imagesJson = if (terrainTextures == null) "" else {
            val names = listOf("grass_albedo","moss_albedo","soil_albedo","rock_albedo",
                "grass_normal","moss_normal","soil_normal","rock_normal")
            "\"images\":[" + names.mapIndexed { index, imageName ->
                "{\"name\":\"$imageName\",\"bufferView\":${imageViews[index]},\"mimeType\":\"image/png\"}"
            }.joinToString(",") + "],"
        }
        val texturesJson = if (terrainTextures == null) "" else {
            "\"textures\":[" + (0..7).joinToString(",") { index -> "{\"sampler\":0,\"source\":$index}" } + "]," +
                "\"samplers\":[{\"magFilter\":9729,\"minFilter\":9987,\"wrapS\":10497,\"wrapT\":10497}],"
        }
        val json="""{"asset":{"version":"2.0","generator":"DuckDreamStudios-World-0.16"},"scene":0,"scenes":[{"nodes":[$nodeIds]}],"nodes":[$nodes],"meshes":[$meshes],"materials":[$materials],$imagesJson$texturesJson"buffers":[{"byteLength":${payload.size}}],"bufferViews":[$views],"accessors":[$accessors]}"""
        val raw=json.toByteArray(Charsets.UTF_8);val pad=(4-raw.size%4)%4;val jsonBytes=raw+ByteArray(pad){0x20}
        val binPad=(4-payload.size%4)%4;val total=12+8+jsonBytes.size+8+payload.size+binPad
        return ByteBuffer.allocate(total).order(ByteOrder.LITTLE_ENDIAN).apply{
            put(byteArrayOf(0x67,0x6c,0x54,0x46));putInt(2);putInt(total)
            putInt(jsonBytes.size);putInt(0x4E4F534A);put(jsonBytes)
            putInt(payload.size+binPad);putInt(0x004E4942);put(payload);repeat(binPad){put(0)}
        }.array()
    }
}
