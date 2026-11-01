package com.duckdream.neonbreach

import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.*
import kotlin.random.Random

/** Runtime glTF builder for a continuous, organic outdoor arena. */
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
    private lateinit var bark:Part
    private lateinit var leaves:Part
    private lateinit var leavesLit:Part
    private lateinit var stones:Part
    private lateinit var stream:Part
    private lateinit var shrine:Part
    private lateinit var beacon:Part
    private lateinit var grass:Part

    private fun part(name:String,mat:Int)=Part(name,mat).also{parts.add(it)}
    private fun h(x:Float,z:Float):Float {
        val mound=0.48f*exp(-((x-10f).pow(2)+(z-8f).pow(2))/95f)
        return 0.40f*sin(x*0.18f)*cos(z*0.14f)+0.20f*sin((x+z)*0.29f)+mound
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
    private fun sphere(p:Part,cx:Float,cy:Float,cz:Float,rx:Float,ry:Float,rz:Float,
                       rings:Int=9,segs:Int=14,rough:Float=0f) {
        val ids=Array(rings+1){IntArray(segs+1)}
        for(r in 0..rings) for(s in 0..segs) {
            val t=PI.toFloat()*r/rings;val a=2f*PI.toFloat()*s/segs
            val jitter=1f+rough*(0.45f*sin(a*3f+t*2f)*sin(t*4f)+0.3f*cos(a*5f-t*3f)*sin(t))
            val sx=cos(a)*sin(t);val sy=cos(t);val sz=sin(a)*sin(t)
            val nx=sx/rx;val ny=sy/ry;val nz=sz/rz
            val nl=sqrt(nx*nx+ny*ny+nz*nz).coerceAtLeast(0.0001f)
            ids[r][s]=p.vertex(cx+sx*rx*jitter,cy+sy*ry*jitter,cz+sz*rz*jitter,nx/nl,ny/nl,nz/nl)
        }
        for(r in 0 until rings) for(s in 0 until segs) {
            val a=ids[r][s];val b=ids[r][s+1];val c=ids[r+1][s];val d=ids[r+1][s+1]
            // Reverse the old winding: the previous indices faced inward and were culled,
            // which made foliage, rocks and rounded props render as black silhouettes.
            p.tri(a,b,c);p.tri(b,d,c)
        }
    }
    private fun cylinder(p:Part,x:Float,z:Float,y0:Float,y1:Float,r0:Float,r1:Float,sides:Int=12) {
        val lo=IntArray(sides+1);val hi=IntArray(sides+1)
        for(i in 0..sides) {
            val a=2f*PI.toFloat()*i/sides;val cs=cos(a);val sn=sin(a)
            lo[i]=p.vertex(x+cs*r0,y0,z+sn*r0,cs,0.05f,sn)
            hi[i]=p.vertex(x+cs*r1,y1,z+sn*r1,cs,0.05f,sn)
        }
        for(i in 0 until sides){p.tri(lo[i],hi[i],lo[i+1]);p.tri(lo[i+1],hi[i],hi[i+1])}
    }

    private fun terrainMesh() {
        val steps=80;val size=64f;val start=-32f;val radiusSq=30.7f*30.7f
        val ids=Array(steps+1){IntArray(steps+1)}
        val worldX=FloatArray(steps+1){start+size*it/steps}
        val worldZ=FloatArray(steps+1){start+size*it/steps}
        for(z in 0..steps) for(x in 0..steps) {
            val wx=worldX[x];val wz=worldZ[z]
            val n=norm(wx,wz);ids[z][x]=terrain.vertex(wx,h(wx,wz),wz,n[0],n[1],n[2])
        }
        for(z in 0 until steps)for(x in 0 until steps){
            val x0=worldX[x];val x1=worldX[x+1]
            val z0=worldZ[z];val z1=worldZ[z+1]
            // Clip the terrain to a broad rounded island instead of exposing a square edge.
            if(x0*x0+z0*z0>radiusSq || x1*x1+z0*z0>radiusSq ||
                x0*x0+z1*z1>radiusSq || x1*x1+z1*z1>radiusSq) continue
            val a=ids[z][x];val b=ids[z][x+1];val c=ids[z+1][x];val d=ids[z+1][x+1]
            terrain.tri(a,c,b);terrain.tri(b,c,d)
        }
    }
    private fun ribbon(p:Part,points:List<FloatArray>,width:Float,lift:Float) {
        fun at(t:Float):FloatArray {
            val f=t.coerceIn(0f,0.99999f)*(points.size-1);val i=floor(f).toInt();val u=f-i
            val p0=points[(i-1).coerceAtLeast(0)];val p1=points[i]
            val p2=points[(i+1).coerceAtMost(points.lastIndex)];val p3=points[(i+2).coerceAtMost(points.lastIndex)]
            fun cat(a:Float,b:Float,c:Float,d:Float)=0.5f*((2f*b)+(-a+c)*u+(2f*a-5f*b+4f*c-d)*u*u+(-a+3f*b-3f*c+d)*u*u*u)
            return floatArrayOf(cat(p0[0],p1[0],p2[0],p3[0]),cat(p0[1],p1[1],p2[1],p3[1]))
        }
        var pl:FloatArray?=null;var pr:FloatArray?=null
        for(i in 0..180){
            val t=i/180f;val c=at(t);val a=at((t-0.003f).coerceAtLeast(0f));val b=at((t+0.003f).coerceAtMost(1f))
            val dx=b[0]-a[0];val dz=b[1]-a[1];val l=sqrt(dx*dx+dz*dz).coerceAtLeast(0.0001f)
            val sx=-dz/l;val sz=dx/l;val y=h(c[0],c[1])+lift
            val left=floatArrayOf(c[0]+sx*width,y,c[1]+sz*width)
            val right=floatArrayOf(c[0]-sx*width,y,c[1]-sz*width)
            if(pl!=null&&pr!=null)quad(p,pl!!,left,pr!!,right)
            pl=left;pr=right
        }
    }
    private fun treesAndShrubs() {
        val r=Random(20261031)
        repeat(34){
            val x=r.nextFloat()*48f-24f;val z=r.nextFloat()*48f-24f
            val laneClearance=minOf(abs(x+12f),abs(x),abs(x-12f))
            if(x*x+z*z>65f && laneClearance>4.6f){
                val s=0.78f+r.nextFloat()*0.55f;val y=h(x,z)
                cylinder(bark,x,z,y,y+2.5f*s,0.34f*s,0.15f*s)
                val crown=y+2.9f*s
                sphere(leaves,x,crown,z,1.55f*s,1.65f*s,1.45f*s,12,18,0.07f)
                sphere(leavesLit,x-0.62f*s,crown+0.28f*s,z+0.42f*s,0.90f*s,1.05f*s,0.88f*s,10,16,0.06f)
                sphere(leaves,x+0.68f*s,crown+0.18f*s,z-0.36f*s,0.92f*s,1.0f*s,0.90f*s,10,16,0.06f)
            }
        }
        repeat(60){
            val x=r.nextFloat()*50f-25f;val z=r.nextFloat()*50f-25f
            val laneClearance=minOf(abs(x+12f),abs(x),abs(x-12f))
            if(x*x+z*z>25f && laneClearance>3.8f){val s=0.35f+r.nextFloat()*0.48f;sphere(leaves,x,h(x,z)+0.45f*s,z,0.75f*s,0.58f*s,0.78f*s,8,12,0.08f)}
        }
        repeat(140){
            val x=r.nextFloat()*50f-25f;val z=r.nextFloat()*50f-25f
            if(x*x+z*z>30f){
                val y=h(x,z)+0.035f
                repeat(3){k->
                    val a=k*2.1f+r.nextFloat()*0.4f;val dx=cos(a)*0.2f;val dz=sin(a)*0.2f
                    val tip=floatArrayOf(x+cos(a+0.8f)*0.12f,y+0.45f+r.nextFloat()*0.22f,z+sin(a+0.8f)*0.12f)
                    tri(grass,floatArrayOf(x-dx,y,z-dz),floatArrayOf(x+dx,y,z+dz),tip)
                }
            }
        }
    }
    private fun rocks() {
        val r=Random(74)
        repeat(50){
            val x=r.nextFloat()*48f-24f;val z=r.nextFloat()*48f-24f
            val laneClearance=minOf(abs(x+12f),abs(x),abs(x-12f))
            if(x*x+z*z>60f && laneClearance>3.2f){val s=0.35f+r.nextFloat()*0.72f;sphere(stones,x,h(x,z)+s*0.32f,z,s*0.95f,s*0.54f,s*0.72f,8,12,0.16f)}
        }
    }
    private fun laneStructures() {
        for(x in listOf(-12f,0f,12f)) {
            for(z in listOf(-10.5f,10.5f)) {
                val y=h(x,z)
                cylinder(shrine,x,z,y+0.05f,y+1.15f,0.72f,0.46f,12)
                cylinder(beacon,x,z,y+1.10f,y+1.52f,0.34f,0.25f,12)
                sphere(beacon,x,y+1.72f,z,0.34f,0.34f,0.34f,8,12)
            }
            val blueY=h(x,-22f)
            val redY=h(x,22f)
            cylinder(shrine,x,-22f,blueY,blueY+1.7f,1.0f,0.72f,16)
            cylinder(shrine,x,22f,redY,redY+1.7f,1.0f,0.72f,16)
        }
    }
    private fun shrineAndWater() {
        ribbon(stream,listOf(floatArrayOf(-28f,-20f),floatArrayOf(-21f,-14f),floatArrayOf(-17f,-4f),floatArrayOf(-12f,6f),floatArrayOf(-7f,13f),floatArrayOf(2f,17f),floatArrayOf(13f,18f),floatArrayOf(24f,15f),floatArrayOf(29f,8f)),0.82f,-0.06f)
        val y=h(0f,0f)
        cylinder(shrine,0f,0f,y+0.04f,y+0.34f,3.8f,3.8f,48)
        cylinder(shrine,0f,0f,y+0.34f,y+0.49f,2.7f,2.7f,48)
        cylinder(beacon,0f,0f,y+0.50f,y+3.5f,0.26f,0.18f,24)
        for(i in 0 until 8){
            val a=2f*PI.toFloat()*i/8f;val x=cos(a)*3.25f;val z=sin(a)*3.25f
            cylinder(shrine,x,z,h(x,z)+0.28f,h(x,z)+1.4f,0.34f,0.28f,10)
            sphere(beacon,x,h(x,z)+1.52f,z,0.24f,0.26f,0.24f,8,12)
        }
        sphere(beacon,0f,y+3.7f,0f,0.68f,0.68f,0.68f,16,24)
    }
    private fun floatBytes(v:List<Float>)=ByteBuffer.allocate(v.size*4).order(ByteOrder.LITTLE_ENDIAN).apply{v.forEach{putFloat(it)}}.array()
    private fun intBytes(v:List<Int>)=ByteBuffer.allocate(v.size*4).order(ByteOrder.LITTLE_ENDIAN).apply{v.forEach{putInt(it)}}.array()
    private fun align(out:ByteArrayOutputStream){while(out.size()%4!=0)out.write(0)}

    fun build():ByteArray {
        parts.clear()
        terrain=part("continuous_terrain",0);trail=part("curved_paths",1);bark=part("tree_trunks",2)
        leaves=part("tree_canopies",3);leavesLit=part("sunlit_canopies",4);stones=part("natural_rocks",5)
        stream=part("water_stream",6);shrine=part("central_stone_shrine",7);beacon=part("capture_beacon",8)
        grass=part("grass_details",4)
        terrainMesh()
        val west=listOf(floatArrayOf(-12f,-29f),floatArrayOf(-13f,-19f),floatArrayOf(-12f,-9f),floatArrayOf(-11f,0f),floatArrayOf(-12f,9f),floatArrayOf(-13f,19f),floatArrayOf(-12f,29f))
        val center=listOf(floatArrayOf(0f,-29f),floatArrayOf(0.8f,-19f),floatArrayOf(0f,-9f),floatArrayOf(0f,0f),floatArrayOf(-0.6f,9f),floatArrayOf(0.5f,19f),floatArrayOf(0f,29f))
        val east=listOf(floatArrayOf(12f,-29f),floatArrayOf(13f,-19f),floatArrayOf(12f,-9f),floatArrayOf(11f,0f),floatArrayOf(12f,9f),floatArrayOf(13f,19f),floatArrayOf(12f,29f))
        // Dark shoulders and a lighter stone running surface make all three lanes readable.
        val routeEdge=part("route_shoulders",9)
        ribbon(routeEdge,west,2.45f,0.025f);ribbon(trail,west,1.78f,0.065f)
        ribbon(routeEdge,center,2.55f,0.025f);ribbon(trail,center,1.86f,0.07f)
        ribbon(routeEdge,east,2.45f,0.025f);ribbon(trail,east,1.78f,0.065f)
        treesAndShrubs();rocks();shrineAndWater()
        laneStructures()

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
        val names=listOf("Meadow","Limestone paths","Tree bark","Deep foliage","Sunlit foliage","Mossy rock","Clear water","Carved stone","Beacon","Route shoulders")
        val colors=listOf(
            listOf(0.19f,0.31f,0.13f,1f),listOf(0.43f,0.38f,0.26f,1f),
            listOf(0.20f,0.13f,0.075f,1f),listOf(0.065f,0.19f,0.10f,1f),
            listOf(0.22f,0.34f,0.12f,1f),listOf(0.25f,0.29f,0.25f,1f),
            listOf(0.035f,0.30f,0.34f,1f),listOf(0.48f,0.48f,0.39f,1f),
            listOf(0.20f,0.77f,0.72f,1f),listOf(0.10f,0.14f,0.13f,1f))
        val materials=names.mapIndexed{i,name->
            val emission=if(i==8)",\"emissiveFactor\":[0.10,0.65,0.58]" else ""
            "{\"name\":\"$name\",\"pbrMetallicRoughness\":{\"baseColorFactor\":[${colors[i].joinToString()}],\"metallicFactor\":0.02,\"roughnessFactor\":${if(i==6)0.24f else 0.88f}}$emission}"
        }.joinToString(",")
        align(bin);val payload=bin.toByteArray()
        val nodeIds=parts.indices.filter{parts[it].ix.isNotEmpty()}.joinToString(",")
        val json="""{"asset":{"version":"2.0","generator":"DuckDreamStudios-World-0.1"},"scene":0,"scenes":[{"nodes":[$nodeIds]}],"nodes":[$nodes],"meshes":[$meshes],"materials":[$materials],"buffers":[{"byteLength":${payload.size}}],"bufferViews":[$views],"accessors":[$accessors]}"""
        val raw=json.toByteArray(Charsets.UTF_8);val pad=(4-raw.size%4)%4;val jsonBytes=raw+ByteArray(pad){0x20}
        val binPad=(4-payload.size%4)%4;val total=12+8+jsonBytes.size+8+payload.size+binPad
        return ByteBuffer.allocate(total).order(ByteOrder.LITTLE_ENDIAN).apply{
            put(byteArrayOf(0x67,0x6c,0x54,0x46));putInt(2);putInt(total)
            putInt(jsonBytes.size);putInt(0x4E4F534A);put(jsonBytes)
            putInt(payload.size+binPad);putInt(0x004E4942);put(payload);repeat(binPad){put(0)}
        }.array()
    }
}
