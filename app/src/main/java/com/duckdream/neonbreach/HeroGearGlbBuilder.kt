package com.duckdream.neonbreach

import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.*

/** Lightweight, bone-parented costume geometry. No extra textures or runtime downloads. */
internal object HeroGearGlbBuilder {
    private data class Part(
        val name: String,
        val material: Int,
        val positions: MutableList<Float> = ArrayList(),
        val normals: MutableList<Float> = ArrayList(),
        val indices: MutableList<Int> = ArrayList()
    ) {
        fun vertex(p: FloatArray, n: FloatArray): Int {
            val index = positions.size / 3
            positions.add(p[0]); positions.add(p[1]); positions.add(p[2])
            normals.add(n[0]); normals.add(n[1]); normals.add(n[2])
            return index
        }
    }

    private fun triangle(part: Part, a: FloatArray, b: FloatArray, c: FloatArray) {
        val ux=b[0]-a[0]; val uy=b[1]-a[1]; val uz=b[2]-a[2]
        val vx=c[0]-a[0]; val vy=c[1]-a[1]; val vz=c[2]-a[2]
        var nx=uy*vz-uz*vy; var ny=uz*vx-ux*vz; var nz=ux*vy-uy*vx
        val len=sqrt(nx*nx+ny*ny+nz*nz).coerceAtLeast(0.00001f)
        nx/=len; ny/=len; nz/=len
        val i0=part.vertex(a,floatArrayOf(nx,ny,nz))
        val i1=part.vertex(b,floatArrayOf(nx,ny,nz))
        val i2=part.vertex(c,floatArrayOf(nx,ny,nz))
        part.indices.add(i0);part.indices.add(i1);part.indices.add(i2)
    }

    private fun outward(part: Part, a: FloatArray, b: FloatArray, c: FloatArray,
                        cx: Float, cy: Float, cz: Float) {
        val ux=b[0]-a[0];val uy=b[1]-a[1];val uz=b[2]-a[2]
        val vx=c[0]-a[0];val vy=c[1]-a[1];val vz=c[2]-a[2]
        val nx=uy*vz-uz*vy;val ny=uz*vx-ux*vz;val nz=ux*vy-uy*vx
        val mx=(a[0]+b[0]+c[0])/3f-cx
        val my=(a[1]+b[1]+c[1])/3f-cy
        val mz=(a[2]+b[2]+c[2])/3f-cz
        if(nx*mx+ny*my+nz*mz>=0f) triangle(part,a,b,c) else triangle(part,a,c,b)
    }

    private fun box(p: Part, x: Float, y: Float, z: Float, sx: Float, sy: Float, sz: Float) {
        val hx=sx*0.5f;val hy=sy*0.5f;val hz=sz*0.5f
        val v=arrayOf(
            floatArrayOf(x-hx,y-hy,z-hz),floatArrayOf(x+hx,y-hy,z-hz),
            floatArrayOf(x+hx,y-hy,z+hz),floatArrayOf(x-hx,y-hy,z+hz),
            floatArrayOf(x-hx,y+hy,z-hz),floatArrayOf(x+hx,y+hy,z-hz),
            floatArrayOf(x+hx,y+hy,z+hz),floatArrayOf(x-hx,y+hy,z+hz)
        )
        val faces=arrayOf(
            intArrayOf(0,1,2,3),intArrayOf(4,7,6,5),intArrayOf(0,4,5,1),
            intArrayOf(1,5,6,2),intArrayOf(2,6,7,3),intArrayOf(3,7,4,0)
        )
        faces.forEach { f ->
            outward(p,v[f[0]],v[f[1]],v[f[2]],x,y,z)
            outward(p,v[f[0]],v[f[2]],v[f[3]],x,y,z)
        }
    }

    private fun plate(p: Part, x: Float, y: Float, z: Float,
                      topWidth: Float, bottomWidth: Float, height: Float, depth: Float) {
        val t=height*0.5f;val b=-t;val front=z+depth*0.5f;val back=z-depth*0.5f
        val v=arrayOf(
            floatArrayOf(x-topWidth,y+t,front),floatArrayOf(x+topWidth,y+t,front),
            floatArrayOf(x+bottomWidth,y+b,front),floatArrayOf(x-bottomWidth,y+b,front),
            floatArrayOf(x-topWidth,y+t,back),floatArrayOf(x+topWidth,y+t,back),
            floatArrayOf(x+bottomWidth,y+b,back),floatArrayOf(x-bottomWidth,y+b,back)
        )
        val faces=arrayOf(
            intArrayOf(0,1,2,3),intArrayOf(5,4,7,6),intArrayOf(4,0,3,7),
            intArrayOf(1,5,6,2),intArrayOf(4,5,1,0),intArrayOf(3,2,6,7)
        )
        faces.forEach { f ->
            outward(p,v[f[0]],v[f[1]],v[f[2]],x,y,z)
            outward(p,v[f[0]],v[f[2]],v[f[3]],x,y,z)
        }
    }

    private fun ellipsoid(p: Part, cx: Float, cy: Float, cz: Float,
                          rx: Float, ry: Float, rz: Float, segments: Int = 10) {
        val rings=6
        for (j in 0 until rings) {
            val a0=-PI.toFloat()*0.5f+PI.toFloat()*j/rings
            val a1=-PI.toFloat()*0.5f+PI.toFloat()*(j+1)/rings
            for (i in 0 until segments) {
                val b0=2f*PI.toFloat()*i/segments
                val b1=2f*PI.toFloat()*(i+1)/segments
                fun v(a:Float,b:Float)=floatArrayOf(
                    cx+rx*cos(a)*cos(b),cy+ry*sin(a),cz+rz*cos(a)*sin(b)
                )
                val q0=v(a0,b0);val q1=v(a0,b1);val q2=v(a1,b0);val q3=v(a1,b1)
                outward(p,q0,q1,q2,cx,cy,cz)
                outward(p,q1,q3,q2,cx,cy,cz)
            }
        }
    }

    private fun floatBytes(values: List<Float>) =
        ByteBuffer.allocate(values.size*4).order(ByteOrder.LITTLE_ENDIAN)
            .apply { values.forEach { putFloat(it) } }.array()
    private fun intBytes(values: List<Int>) =
        ByteBuffer.allocate(values.size*4).order(ByteOrder.LITTLE_ENDIAN)
            .apply { values.forEach { putInt(it) } }.array()
    private fun align(out: ByteArrayOutputStream) { while(out.size()%4!=0) out.write(0) }

    fun build(hero: Int, team: Int): ByteArray {
        val style=hero.coerceIn(0,2);val red=team!=0
        val parts=ArrayList<Part>()
        val torso=Part("gear_torso",0).also { parts.add(it) }
        val trim=Part("gear_trim",1).also { parts.add(it) }
        val head=Part("gear_head",0).also { parts.add(it) }
        val headTrim=Part("gear_head_trim",1).also { parts.add(it) }
        val back=Part("gear_back",0).also { parts.add(it) }
        val shoulderL=Part("gear_shoulder_l",0).also { parts.add(it) }
        val shoulderR=Part("gear_shoulder_r",0).also { parts.add(it) }
        val forearmL=Part("gear_forearm_l",1).also { parts.add(it) }
        val forearmR=Part("gear_forearm_r",1).also { parts.add(it) }
        val thighL=Part("gear_thigh_l",0).also { parts.add(it) }
        val thighR=Part("gear_thigh_r",0).also { parts.add(it) }
        val bootL=Part("gear_boot_l",1).also { parts.add(it) }
        val bootR=Part("gear_boot_r",1).also { parts.add(it) }

        when(style) {
            0 -> { // Lyra: layered mantle and light ceremonial plates.
                plate(torso,0f,0.02f,0.065f,0.155f,0.205f,0.25f,0.085f)
                plate(torso,0f,-0.095f,0.07f,0.17f,0.145f,0.10f,0.075f)
                ellipsoid(torso,-0.205f,0.105f,0f,0.105f,0.07f,0.12f)
                ellipsoid(torso,0.205f,0.105f,0f,0.105f,0.07f,0.12f)
                box(torso,0f,-0.17f,0f,0.34f,0.055f,0.16f)
                plate(trim,0f,0.01f,0.112f,0.025f,0.042f,0.12f,0.018f)
                ellipsoid(trim,0f,0.06f,0.13f,0.042f,0.052f,0.025f,8)
                box(head,0f,0.105f,0.005f,0.24f,0.045f,0.20f)
                ellipsoid(head,0f,0.13f,-0.01f,0.135f,0.07f,0.14f)
                box(headTrim,0f,0.12f,0.118f,0.075f,0.035f,0.022f)
                plate(back,0f,-0.04f,-0.105f,0.19f,0.24f,0.36f,0.035f)
                // Two layered mantle tails create a recognisable support silhouette in motion.
                plate(back,-0.13f,-0.28f,-0.13f,0.10f,0.16f,0.54f,0.025f)
                plate(back,0.13f,-0.25f,-0.13f,0.10f,0.15f,0.48f,0.025f)
                plate(back,0f,-0.24f,-0.17f,0.16f,0.19f,0.42f,0.025f)
                ellipsoid(shoulderL,0f,0.015f,-0.005f,0.105f,0.085f,0.11f,9)
                ellipsoid(shoulderR,0f,0.015f,-0.005f,0.105f,0.085f,0.11f,9)
            }
            1 -> { // Bastion: heavier layered torso, broad shoulders and a ridged helm.
                plate(torso,0f,0.035f,0.075f,0.205f,0.235f,0.29f,0.13f)
                plate(torso,0f,-0.075f,0.115f,0.13f,0.16f,0.13f,0.055f)
                ellipsoid(torso,-0.23f,0.105f,0.005f,0.145f,0.105f,0.15f)
                ellipsoid(torso,0.23f,0.105f,0.005f,0.145f,0.105f,0.15f)
                box(torso,0f,-0.17f,0.005f,0.36f,0.08f,0.18f)
                plate(trim,0f,0.025f,0.148f,0.045f,0.06f,0.17f,0.018f)
                box(head,0f,0.11f,-0.005f,0.27f,0.08f,0.22f)
                ellipsoid(head,0f,0.145f,-0.015f,0.15f,0.075f,0.15f)
                plate(headTrim,0f,0.22f,0.0f,0.045f,0.015f,0.16f,0.045f)
                plate(back,0f,-0.065f,-0.12f,0.22f,0.25f,0.32f,0.04f)
                box(headTrim,-0.145f,0.18f,-0.01f,0.085f,0.20f,0.09f)
                box(headTrim,0.145f,0.18f,-0.01f,0.085f,0.20f,0.09f)
                plate(back,0f,-0.22f,-0.17f,0.25f,0.30f,0.48f,0.055f)
                box(shoulderL,0f,0.07f,-0.01f,0.22f,0.13f,0.19f)
                box(shoulderR,0f,0.07f,-0.01f,0.22f,0.13f,0.19f)
            }
            else -> { // Kairo: asymmetrical light armour, hood and split travel mantle.
                plate(torso,0f,0.035f,0.075f,0.145f,0.19f,0.25f,0.075f)
                plate(torso,-0.075f,-0.05f,0.105f,0.11f,0.13f,0.15f,0.04f)
                ellipsoid(torso,-0.205f,0.095f,0f,0.09f,0.07f,0.105f)
                ellipsoid(torso,0.205f,0.12f,0f,0.12f,0.075f,0.12f)
                box(torso,0f,-0.17f,0f,0.31f,0.06f,0.15f)
                plate(trim,-0.065f,0.01f,0.12f,0.025f,0.035f,0.19f,0.018f)
                ellipsoid(head,0f,0.105f,-0.025f,0.15f,0.09f,0.16f)
                plate(headTrim,0f,0.12f,0.12f,0.12f,0.11f,0.045f,0.025f)
                plate(back,0.015f,-0.05f,-0.12f,0.16f,0.22f,0.32f,0.035f)
                plate(back,-0.12f,-0.19f,-0.13f,0.07f,0.10f,0.22f,0.025f)
                // Hood volume and split scarf tails give Kairo an asymmetrical, agile outline.
                ellipsoid(head,0f,0.12f,-0.075f,0.185f,0.145f,0.19f,12)
                plate(headTrim,0f,0.22f,-0.055f,0.13f,0.10f,0.10f,0.035f)
                plate(back,-0.12f,-0.24f,-0.16f,0.08f,0.12f,0.50f,0.028f)
                plate(back,0.15f,-0.18f,-0.16f,0.07f,0.10f,0.40f,0.028f)
                box(shoulderR,0f,0.045f,0.015f,0.19f,0.075f,0.11f)
                plate(forearmR,0f,0.06f,0.065f,0.075f,0.09f,0.18f,0.025f)
            }
        }

        // Bone-local plates finish the silhouette without duplicating full character meshes.
        val shoulderScale = if(style==1) 1.62f else if(style==2) 0.82f else 1.02f
        ellipsoid(shoulderL,0f,0.02f,0f,0.084f*shoulderScale,0.095f*shoulderScale,0.092f*shoulderScale,8)
        ellipsoid(shoulderR,0f,0.02f,0f,0.084f*shoulderScale,0.095f*shoulderScale,0.092f*shoulderScale,8)
        box(forearmL,0f,0.07f,0.015f,0.10f*shoulderScale,0.16f,0.09f)
        box(forearmR,0f,0.07f,0.015f,0.10f*shoulderScale,0.16f,0.09f)
        plate(thighL,0f,-0.16f,0.03f,0.075f*shoulderScale,0.095f*shoulderScale,0.16f,0.055f)
        plate(thighR,0f,-0.16f,0.03f,0.075f*shoulderScale,0.095f*shoulderScale,0.16f,0.055f)
        box(bootL,0f,0.005f,0.045f,0.12f,0.075f,0.17f)
        box(bootR,0f,0.005f,0.045f,0.12f,0.075f,0.17f)

        val teamColor=if(red) listOf(0.55f,0.16f,0.14f,1f) else listOf(0.14f,0.36f,0.56f,1f)
        val trimColor=when(style) {
            0 -> listOf(0.76f,0.68f,0.42f,1f)
            1 -> listOf(0.56f,0.49f,0.36f,1f)
            else -> listOf(0.57f,0.47f,0.30f,1f)
        }
        val materials=listOf(teamColor,trimColor).mapIndexed { index,color ->
            val rough=if(index==0) 0.74f else 0.38f
            "{\"name\":\"gear_material_$index\",\"pbrMetallicRoughness\":{\"baseColorFactor\":[${color.joinToString()}],\"metallicFactor\":${if(index==0) 0.05 else 0.42},\"roughnessFactor\":$rough}}"
        }.joinToString(",")

        val bin=ByteArrayOutputStream();val views=StringBuilder();val accessors=StringBuilder()
        val meshes=StringBuilder();val nodes=StringBuilder()
        var viewIndex=0;var accessorIndex=0
        parts.forEachIndexed { index,p ->
            if(p.indices.isEmpty()) return@forEachIndexed
            align(bin);val posOffset=bin.size();val pos=floatBytes(p.positions);bin.write(pos)
            align(bin);val normalOffset=bin.size();val normal=floatBytes(p.normals);bin.write(normal)
            align(bin);val indexOffset=bin.size();val indices=intBytes(p.indices);bin.write(indices)
            if(views.isNotEmpty())views.append(',')
            views.append("{\"buffer\":0,\"byteOffset\":$posOffset,\"byteLength\":${pos.size},\"target\":34962}")
            views.append(",{\"buffer\":0,\"byteOffset\":$normalOffset,\"byteLength\":${normal.size},\"target\":34962}")
            views.append(",{\"buffer\":0,\"byteOffset\":$indexOffset,\"byteLength\":${indices.size},\"target\":34963}")
            val xs=p.positions.filterIndexed { i,_->i%3==0 }
            val ys=p.positions.filterIndexed { i,_->i%3==1 }
            val zs=p.positions.filterIndexed { i,_->i%3==2 }
            val min=listOf(xs.minOrNull()?:0f,ys.minOrNull()?:0f,zs.minOrNull()?:0f)
            val max=listOf(xs.maxOrNull()?:0f,ys.maxOrNull()?:0f,zs.maxOrNull()?:0f)
            if(accessors.isNotEmpty())accessors.append(',')
            accessors.append("{\"bufferView\":$viewIndex,\"componentType\":5126,\"count\":${p.positions.size/3},\"type\":\"VEC3\",\"min\":[${min.joinToString()}],\"max\":[${max.joinToString()}]}")
            accessors.append(",{\"bufferView\":${viewIndex+1},\"componentType\":5126,\"count\":${p.normals.size/3},\"type\":\"VEC3\"}")
            accessors.append(",{\"bufferView\":${viewIndex+2},\"componentType\":5125,\"count\":${p.indices.size},\"type\":\"SCALAR\"}")
            if(meshes.isNotEmpty())meshes.append(',')
            meshes.append("{\"name\":\"${p.name}\",\"primitives\":[{\"attributes\":{\"POSITION\":$accessorIndex,\"NORMAL\":${accessorIndex+1}},\"indices\":${accessorIndex+2},\"material\":${p.material}}]}")
            if(nodes.isNotEmpty())nodes.append(',')
            nodes.append("{\"name\":\"${p.name}\",\"mesh\":$index,\"translation\":[0,0,0]}")
            viewIndex+=3;accessorIndex+=3
        }
        val nodeIds=parts.indices.filter { parts[it].indices.isNotEmpty() }.joinToString(",")
        align(bin);val payload=bin.toByteArray()
        val json="""{"asset":{"version":"2.0","generator":"DuckDreamStudios-HeroGear-0.15"},"scene":0,"scenes":[{"nodes":[$nodeIds]}],"nodes":[$nodes],"meshes":[$meshes],"materials":[$materials],"buffers":[{"byteLength":${payload.size}}],"bufferViews":[$views],"accessors":[$accessors]}"""
        val raw=json.toByteArray(Charsets.UTF_8);val padding=(4-raw.size%4)%4
        val jsonBytes=raw+ByteArray(padding){0x20}
        val binPadding=(4-payload.size%4)%4
        val total=12+8+jsonBytes.size+8+payload.size+binPadding
        return ByteBuffer.allocate(total).order(ByteOrder.LITTLE_ENDIAN).apply {
            put(byteArrayOf(0x67,0x6c,0x54,0x46));putInt(2);putInt(total)
            putInt(jsonBytes.size);putInt(0x4E4F534A);put(jsonBytes)
            putInt(payload.size+binPadding);putInt(0x004E4942);put(payload);repeat(binPadding){put(0)}
        }.array()
    }
}
