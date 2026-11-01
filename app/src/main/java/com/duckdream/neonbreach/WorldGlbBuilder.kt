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
        val westRidge = 1.05f * exp(-((x + 23f).pow(2)) / 52f) * (0.45f + 0.55f * cos(z * 0.075f))
        val eastRidge = 0.92f * exp(-((x - 23f).pow(2)) / 58f) * (0.45f + 0.55f * cos(z * 0.07f))
        val centralRise = 0.48f * exp(-((x - 1f).pow(2) + (z - 1f).pow(2)) / 90f)
        return 0.36f*sin(x*0.18f)*cos(z*0.14f)+0.18f*sin((x+z)*0.29f)+westRidge+eastRidge+centralRise
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
        tri(p,a,c,b);tri(p,b,c,d)
    }
    private fun floatBytes(v:List<Float>)=ByteBuffer.allocate(v.size*4).order(ByteOrder.LITTLE_ENDIAN).apply{v.forEach{putFloat(it)}}.array()
    private fun intBytes(v:List<Int>)=ByteBuffer.allocate(v.size*4).order(ByteOrder.LITTLE_ENDIAN).apply{v.forEach{putInt(it)}}.array()
    private fun align(out:ByteArrayOutputStream){while(out.size()%4!=0)out.write(0)}

    fun build():ByteArray {
        parts.clear()
        terrain=part("meadow_terrain",0)
        trail=part("limestone_lane_surface",1)
        val routeEdge=part("lane_edge_stone",2)
        val water=part("crossing_river",3)
        terrainMesh()
        val west=listOf(floatArrayOf(-12f,-29f),floatArrayOf(-13f,-19f),floatArrayOf(-12f,-9f),floatArrayOf(-11f,0f),floatArrayOf(-12f,9f),floatArrayOf(-13f,19f),floatArrayOf(-12f,29f))
        val center=listOf(floatArrayOf(0f,-29f),floatArrayOf(0.8f,-19f),floatArrayOf(0f,-9f),floatArrayOf(0f,0f),floatArrayOf(-0.6f,9f),floatArrayOf(0.5f,19f),floatArrayOf(0f,29f))
        val east=listOf(floatArrayOf(12f,-29f),floatArrayOf(13f,-19f),floatArrayOf(12f,-9f),floatArrayOf(11f,0f),floatArrayOf(12f,9f),floatArrayOf(13f,19f),floatArrayOf(12f,29f))
        // Three wide continuous lanes. All natural props, bases, towers and flags are real CC0 glTF models.
        ribbon(routeEdge,west,3.05f,0.025f);ribbon(trail,west,2.38f,0.075f)
        ribbon(routeEdge,center,3.15f,0.025f);ribbon(trail,center,2.48f,0.075f)
        ribbon(routeEdge,east,3.05f,0.025f);ribbon(trail,east,2.38f,0.075f)
        val river=listOf(floatArrayOf(-31f,0.4f),floatArrayOf(-20f,-0.2f),floatArrayOf(-10f,0.25f),floatArrayOf(0f,0f),floatArrayOf(10f,-0.25f),floatArrayOf(20f,0.2f),floatArrayOf(31f,-0.35f))
        ribbon(water,river,1.55f,-0.12f)

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
        val names=listOf("Temperate meadow","Pale limestone roads","Roadside stone edging","Shallow river")
        val colors=listOf(
            listOf(0.25f,0.31f,0.19f,1f),
            listOf(0.56f,0.51f,0.40f,1f),
            listOf(0.19f,0.20f,0.16f,1f),
            listOf(0.12f,0.30f,0.34f,1f))
        val materials=names.mapIndexed{i,name->
            val emission=""
            "{\"name\":\"$name\",\"pbrMetallicRoughness\":{\"baseColorFactor\":[${colors[i].joinToString()}],\"metallicFactor\":0.02,\"roughnessFactor\":${if(i==6)0.24f else 0.88f}}$emission}"
        }.joinToString(",")
        align(bin);val payload=bin.toByteArray()
        val nodeIds=parts.indices.filter{parts[it].ix.isNotEmpty()}.joinToString(",")
        val json="""{"asset":{"version":"2.0","generator":"DuckDreamStudios-World-0.7"},"scene":0,"scenes":[{"nodes":[$nodeIds]}],"nodes":[$nodes],"meshes":[$meshes],"materials":[$materials],"buffers":[{"byteLength":${payload.size}}],"bufferViews":[$views],"accessors":[$accessors]}"""
        val raw=json.toByteArray(Charsets.UTF_8);val pad=(4-raw.size%4)%4;val jsonBytes=raw+ByteArray(pad){0x20}
        val binPad=(4-payload.size%4)%4;val total=12+8+jsonBytes.size+8+payload.size+binPad
        return ByteBuffer.allocate(total).order(ByteOrder.LITTLE_ENDIAN).apply{
            put(byteArrayOf(0x67,0x6c,0x54,0x46));putInt(2);putInt(total)
            putInt(jsonBytes.size);putInt(0x4E4F534A);put(jsonBytes)
            putInt(payload.size+binPad);putInt(0x004E4942);put(payload);repeat(binPad){put(0)}
        }.array()
    }
}
