package com.duckdream.neonbreach

import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/** Original low-poly Lyra body with a glTF skin, inverse-bind matrices and weighted vertices. */
internal object LyraCharacterGlbBuilder {
    private data class Bone(val name:String,val parent:Int,val x:Float,val y:Float,val z:Float)
    private data class Part(val material:Int) {
        val p=ArrayList<Float>(); val n=ArrayList<Float>()
        val joints=ArrayList<Int>(); val weights=ArrayList<Float>(); val ix=ArrayList<Int>()
    }
    private val bones=listOf(
        Bone("root",-1,0f,0f,0f), Bone("pelvis",0,0f,0.82f,0f),
        Bone("spine_01",1,0f,0.15f,0f), Bone("spine_02",2,0f,0.19f,0f),
        Bone("spine_03",3,0f,0.20f,0f), Bone("neck_01",4,0f,0.18f,0f),
        Bone("Head",5,0f,0.17f,0f), Bone("upperarm_l",4,-0.29f,0.01f,0f),
        Bone("upperarm_r",4,0.29f,0.01f,0f), Bone("lowerarm_l",7,-0.27f,0f,0f),
        Bone("lowerarm_r",8,0.27f,0f,0f), Bone("hand_l",9,-0.22f,0f,0f),
        Bone("hand_r",10,0.22f,0f,0f), Bone("thigh_l",1,-0.14f,-0.08f,0f),
        Bone("thigh_r",1,0.14f,-0.08f,0f), Bone("calf_l",13,0f,-0.33f,0f),
        Bone("calf_r",14,0f,-0.33f,0f), Bone("foot_l",15,0f,-0.29f,0.045f),
        Bone("foot_r",16,0f,-0.29f,0.045f)
    )
    private val parts=List(7){Part(it)}

    private fun addVertex(part:Part,p:FloatArray,n:FloatArray,joint:Int,secondaryJoint:Int=-1,primaryWeight:Float=1f):Int {
        val id=part.p.size/3
        part.p.add(p[0]);part.p.add(p[1]);part.p.add(p[2])
        part.n.add(n[0]);part.n.add(n[1]);part.n.add(n[2])
        val blend=if(secondaryJoint>=0)(1f-primaryWeight.coerceIn(0.65f,1f)) else 0f
        part.joints.add(joint);part.joints.add(if(secondaryJoint>=0)secondaryJoint else 0);part.joints.add(0);part.joints.add(0)
        part.weights.add(1f-blend);part.weights.add(blend);part.weights.add(0f);part.weights.add(0f)
        return id
    }
    private fun triangle(part:Part,a:Int,b:Int,c:Int) {
        val ax=part.p[a*3];val ay=part.p[a*3+1];val az=part.p[a*3+2]
        val bx=part.p[b*3];val by=part.p[b*3+1];val bz=part.p[b*3+2]
        val cx=part.p[c*3];val cy=part.p[c*3+1];val cz=part.p[c*3+2]
        val ux=bx-ax;val uy=by-ay;val uz=bz-az
        val vx=cx-ax;val vy=cy-ay;val vz=cz-az
        val nx=uy*vz-uz*vy;val ny=uz*vx-ux*vz;val nz=ux*vy-uy*vx
        val sx=part.n[a*3]+part.n[b*3]+part.n[c*3]
        val sy=part.n[a*3+1]+part.n[b*3+1]+part.n[c*3+1]
        val sz=part.n[a*3+2]+part.n[b*3+2]+part.n[c*3+2]
        if(nx*sx+ny*sy+nz*sz>=0f){part.ix.add(a);part.ix.add(b);part.ix.add(c)}
        else{part.ix.add(a);part.ix.add(c);part.ix.add(b)}
    }
    private fun ellipsoid(
        material:Int,cx:Float,cy:Float,cz:Float,rx:Float,ry:Float,rz:Float,joint:Int,
        rotationZ:Float=0f,segments:Int=14,rings:Int=9,secondaryJoint:Int=-1,primaryWeight:Float=1f
    ) {
        val part=parts[material];val c=cos(rotationZ);val s=sin(rotationZ)
        val grid=Array(rings+1){IntArray(segments+1)}
        for(j in 0..rings){
            val latitude=-PI.toFloat()*0.5f+PI.toFloat()*j/rings
            val cl=cos(latitude);val sl=sin(latitude)
            for(i in 0..segments){
                val longitude=2f*PI.toFloat()*i/segments
                val lx=rx*cl*cos(longitude);val ly=ry*sl;val lz=rz*cl*sin(longitude)
                val x=cx+lx*c-ly*s;val y=cy+lx*s+ly*c;val z=cz+lz
                var nx=cl*cos(longitude)/rx.coerceAtLeast(0.0001f)
                var ny=sl/ry.coerceAtLeast(0.0001f)
                val nz=cl*sin(longitude)/rz.coerceAtLeast(0.0001f)
                val ox=nx*c-ny*s;val oy=nx*s+ny*c
                nx=ox;ny=oy
                val len=sqrt(nx*nx+ny*ny+nz*nz).coerceAtLeast(0.0001f)
                grid[j][i]=addVertex(part,floatArrayOf(x,y,z),floatArrayOf(nx/len,ny/len,nz/len),joint,secondaryJoint,primaryWeight)
            }
        }
        for(j in 0 until rings)for(i in 0 until segments){
            triangle(part,grid[j][i],grid[j][i+1],grid[j+1][i])
            triangle(part,grid[j][i+1],grid[j+1][i+1],grid[j+1][i])
        }
    }

    private fun cape() {
        val part=parts[2]
        val v=listOf(
            floatArrayOf(-0.30f,1.48f,-0.12f),floatArrayOf(0.30f,1.48f,-0.12f),
            floatArrayOf(-0.25f,0.73f,-0.17f),floatArrayOf(0f,0.84f,-0.20f),floatArrayOf(0.25f,0.73f,-0.17f),
            floatArrayOf(-0.30f,1.48f,-0.22f),floatArrayOf(0.30f,1.48f,-0.22f),
            floatArrayOf(-0.25f,0.73f,-0.25f),floatArrayOf(0f,0.84f,-0.27f),floatArrayOf(0.25f,0.73f,-0.25f)
        )
        fun tri(a:Int,b:Int,c:Int){
            val va=v[a];val vb=v[b];val vc=v[c]
            val ux=vb[0]-va[0];val uy=vb[1]-va[1];val uz=vb[2]-va[2]
            val vx=vc[0]-va[0];val vy=vc[1]-va[1];val vz=vc[2]-va[2]
            var nx=uy*vz-uz*vy;var ny=uz*vx-ux*vz;var nz=ux*vy-uy*vx
            val len=sqrt(nx*nx+ny*ny+nz*nz).coerceAtLeast(0.0001f)
            nx/=len;ny/=len;nz/=len
            val ia=addVertex(part,va,floatArrayOf(nx,ny,nz),2)
            val ib=addVertex(part,vb,floatArrayOf(nx,ny,nz),2)
            val ic=addVertex(part,vc,floatArrayOf(nx,ny,nz),2)
            part.ix.add(ia);part.ix.add(ib);part.ix.add(ic)
        }
        tri(0,2,3);tri(0,3,1);tri(1,3,4)
        tri(6,8,5);tri(5,8,7);tri(6,9,8)
        tri(0,5,7);tri(0,7,2);tri(1,4,9);tri(1,9,6)
        tri(2,7,8);tri(2,8,3);tri(3,8,9);tri(3,9,4)
    }

    private fun buildGeometry() {
        // 0 skin, 1 indigo cloth, 2 plum cape, 3 gold, 4 chestnut hair, 5 leather, 6 turquoise.
        ellipsoid(1,0f,1.26f,0f,0.285f,0.31f,0.19f,3)
        ellipsoid(1,0f,0.90f,0f,0.345f,0.22f,0.225f,1)
        ellipsoid(1,0f,1.05f,0.015f,0.29f,0.095f,0.205f,1)
        ellipsoid(2,0f,1.10f,-0.16f,0.345f,0.43f,0.075f,2)
        cape()

        for(side in listOf(-1f,1f)){
            val upper=if(side<0f)7 else 8
            val lower=if(side<0f)9 else 10
            val hand=if(side<0f)11 else 12
            ellipsoid(1,side*0.31f,1.43f,0f,0.17f,0.135f,0.17f,upper)
            ellipsoid(1,side*0.425f,1.34f,0f,0.205f,0.13f,0.13f,upper)
            ellipsoid(0,side*0.435f,1.345f,0.01f,0.135f,0.105f,0.11f,upper)
            ellipsoid(3,side*0.555f,1.255f,0.015f,0.075f,0.105f,0.135f,lower)
            ellipsoid(0,side*0.615f,1.17f,0.005f,0.105f,0.145f,0.105f,lower)
            ellipsoid(0,side*0.735f,1.065f,0.015f,0.105f,0.085f,0.105f,hand)
            ellipsoid(6,side*0.305f,1.50f,0.025f,0.105f,0.065f,0.15f,upper)
            ellipsoid(3,side*0.30f,1.55f,0.01f,0.11f,0.035f,0.14f,upper)
        }
        for(side in listOf(-1f,1f)){
            val thigh=if(side<0f)13 else 14
            val calf=if(side<0f)15 else 16
            val foot=if(side<0f)17 else 18
            ellipsoid(5,side*0.145f,0.625f,0f,0.145f,0.245f,0.145f,thigh)
            ellipsoid(5,side*0.145f,0.34f,0f,0.12f,0.185f,0.125f,calf)
            ellipsoid(3,side*0.145f,0.19f,0.025f,0.145f,0.09f,0.15f,foot)
            ellipsoid(5,side*0.145f,0.12f,0.075f,0.155f,0.12f,0.235f,foot)
            ellipsoid(3,side*0.145f,0.205f,0.17f,0.13f,0.035f,0.055f,foot)
        }

        ellipsoid(0,0f,1.57f,0f,0.115f,0.135f,0.12f,5)
        ellipsoid(0,0f,1.82f,0.015f,0.235f,0.265f,0.215f,6)
        ellipsoid(4,0f,2.025f,-0.035f,0.245f,0.135f,0.225f,6)
        ellipsoid(4,0f,1.965f,0.165f,0.205f,0.075f,0.075f,6)
        ellipsoid(4,-0.195f,1.84f,0.015f,0.075f,0.20f,0.105f,6)
        ellipsoid(4,0.195f,1.84f,0.015f,0.075f,0.20f,0.105f,6)
        ellipsoid(5,-0.083f,1.855f,0.207f,0.032f,0.041f,0.018f,6,segments=10,rings=6)
        ellipsoid(5,0.083f,1.855f,0.207f,0.032f,0.041f,0.018f,6,segments=10,rings=6)
        ellipsoid(6,-0.083f,1.86f,0.222f,0.012f,0.019f,0.009f,6,segments=8,rings=5)
        ellipsoid(6,0.083f,1.86f,0.222f,0.012f,0.019f,0.009f,6,segments=8,rings=5)
        ellipsoid(0,0f,1.795f,0.226f,0.035f,0.045f,0.03f,6,segments=8,rings=5)
        ellipsoid(5,0f,1.735f,0.213f,0.065f,0.012f,0.012f,6,segments=10,rings=5)

        ellipsoid(6,0f,1.515f,0.055f,0.19f,0.075f,0.17f,4)
        ellipsoid(3,0f,1.43f,0.185f,0.052f,0.075f,0.026f,3)
        ellipsoid(6,0f,1.415f,0.211f,0.025f,0.035f,0.018f,3)
        ellipsoid(3,0f,1.045f,0.208f,0.085f,0.065f,0.026f,1)
        ellipsoid(6,-0.23f,0.99f,0.16f,0.07f,0.085f,0.055f,1)
        ellipsoid(6,0.23f,0.99f,0.16f,0.07f,0.085f,0.055f,1)
    }

    private fun floats(a:List<Float>)=ByteBuffer.allocate(a.size*4).order(ByteOrder.LITTLE_ENDIAN).apply{a.forEach{putFloat(it)}}.array()
    private fun ints(a:List<Int>)=ByteBuffer.allocate(a.size*4).order(ByteOrder.LITTLE_ENDIAN).apply{a.forEach{putInt(it)}}.array()
    private fun shorts(a:List<Int>)=ByteBuffer.allocate(a.size*2).order(ByteOrder.LITTLE_ENDIAN).apply{a.forEach{putShort(it.toShort())}}.array()
    private fun align(out:ByteArrayOutputStream){while(out.size()%4!=0)out.write(0)}

    private fun inverseBinds():ByteArray {
        val world=Array(bones.size){FloatArray(3)}
        for(i in bones.indices){
            val b=bones[i]
            if(b.parent>=0){val p=world[b.parent];world[i][0]=p[0]+b.x;world[i][1]=p[1]+b.y;world[i][2]=p[2]+b.z}
            else{world[i][0]=b.x;world[i][1]=b.y;world[i][2]=b.z}
        }
        val a=ArrayList<Float>(bones.size*16)
        for(i in bones.indices)a.addAll(listOf(1f,0f,0f,0f,0f,1f,0f,0f,0f,0f,1f,0f,-world[i][0],-world[i][1],-world[i][2],1f))
        return floats(a)
    }

    fun build():ByteArray {
        parts.forEach{it.p.clear();it.n.clear();it.joints.clear();it.weights.clear();it.ix.clear()}
        buildGeometry()
        val bin=ByteArrayOutputStream();val views=StringBuilder();val accessors=StringBuilder();val primitives=StringBuilder()
        var vi=0;var ai=0
        parts.forEach{part->
            if(part.ix.isEmpty())return@forEach
            val pos=floats(part.p);val norm=floats(part.n);val joints=shorts(part.joints);val weights=floats(part.weights);val indices=ints(part.ix)
            align(bin);val po=bin.size();bin.write(pos)
            align(bin);val no=bin.size();bin.write(norm)
            align(bin);val jo=bin.size();bin.write(joints)
            align(bin);val wo=bin.size();bin.write(weights)
            align(bin);val io=bin.size();bin.write(indices)
            if(views.isNotEmpty())views.append(',')
            views.append("{\"buffer\":0,\"byteOffset\":"+po+",\"byteLength\":"+pos.size+",\"target\":34962}")
            views.append(",{\"buffer\":0,\"byteOffset\":"+no+",\"byteLength\":"+norm.size+",\"target\":34962}")
            views.append(",{\"buffer\":0,\"byteOffset\":"+jo+",\"byteLength\":"+joints.size+",\"target\":34962}")
            views.append(",{\"buffer\":0,\"byteOffset\":"+wo+",\"byteLength\":"+weights.size+",\"target\":34962}")
            views.append(",{\"buffer\":0,\"byteOffset\":"+io+",\"byteLength\":"+indices.size+",\"target\":34963}")
            val xs=part.p.filterIndexed{i,_->i%3==0};val ys=part.p.filterIndexed{i,_->i%3==1};val zs=part.p.filterIndexed{i,_->i%3==2}
            val mn=listOf(xs.minOrNull()?:0f,ys.minOrNull()?:0f,zs.minOrNull()?:0f)
            val mx=listOf(xs.maxOrNull()?:0f,ys.maxOrNull()?:0f,zs.maxOrNull()?:0f)
            if(accessors.isNotEmpty())accessors.append(',')
            accessors.append("{\"bufferView\":"+vi+",\"componentType\":5126,\"count\":"+(part.p.size/3)+",\"type\":\"VEC3\",\"min\":["+mn.joinToString()+"],\"max\":["+mx.joinToString()+"]}")
            accessors.append(",{\"bufferView\":"+(vi+1)+",\"componentType\":5126,\"count\":"+(part.n.size/3)+",\"type\":\"VEC3\"}")
            accessors.append(",{\"bufferView\":"+(vi+2)+",\"componentType\":5123,\"count\":"+(part.joints.size/4)+",\"type\":\"VEC4\"}")
            accessors.append(",{\"bufferView\":"+(vi+3)+",\"componentType\":5126,\"count\":"+(part.weights.size/4)+",\"type\":\"VEC4\"}")
            accessors.append(",{\"bufferView\":"+(vi+4)+",\"componentType\":5125,\"count\":"+part.ix.size+",\"type\":\"SCALAR\"}")
            if(primitives.isNotEmpty())primitives.append(',')
            primitives.append("{\"attributes\":{\"POSITION\":"+ai+",\"NORMAL\":"+(ai+1)+",\"JOINTS_0\":"+(ai+2)+",\"WEIGHTS_0\":"+(ai+3)+"},\"indices\":"+(ai+4)+",\"material\":"+part.material+"}")
            vi+=5;ai+=5
        }
        align(bin);val ibmOffset=bin.size();val ibm=inverseBinds();bin.write(ibm)
        if(views.isNotEmpty())views.append(',')
        views.append("{\"buffer\":0,\"byteOffset\":"+ibmOffset+",\"byteLength\":"+ibm.size+"}")
        if(accessors.isNotEmpty())accessors.append(',')
        val ibmAccessor=ai
        accessors.append("{\"bufferView\":"+vi+",\"componentType\":5126,\"count\":"+bones.size+",\"type\":\"MAT4\"}")

        val children=bones.indices.groupBy{bones[it].parent}
        val nodes=StringBuilder()
        bones.forEachIndexed{index,bone->
            if(nodes.isNotEmpty())nodes.append(',')
            val childList=children[index].orEmpty().joinToString(",")
            nodes.append("{\"name\":\""+bone.name+"\",\"translation\":["+bone.x+","+bone.y+","+bone.z+"]")
            if(childList.isNotEmpty())nodes.append(",\"children\":["+childList+"]")
            nodes.append('}')
        }
        nodes.append(',').append("{\"name\":\"Lyra_Skinned_Body\",\"mesh\":0,\"skin\":0}")
        val colors=listOf(
            listOf(0.86f,0.57f,0.42f,1f),listOf(0.22f,0.25f,0.62f,1f),listOf(0.34f,0.20f,0.49f,1f),
            listOf(0.91f,0.64f,0.22f,1f),listOf(0.20f,0.105f,0.075f,1f),listOf(0.15f,0.12f,0.16f,1f),
            listOf(0.12f,0.70f,0.68f,1f))
        val names=listOf("Lyra_Skin","Lyra_Indigo_Cloth","Lyra_Plum_Cape","Lyra_Aged_Gold","Lyra_Chestnut_Hair","Lyra_Dark_Leather","Lyra_Turquoise")
        val materials=names.mapIndexed{i,name->
            val metal=if(i==3)0.34f else 0.02f
            val rough=if(i==3)0.42f else 0.82f
            "{\"name\":\""+name+"\",\"pbrMetallicRoughness\":{\"baseColorFactor\":["+colors[i].joinToString()+"],\"metallicFactor\":"+metal+",\"roughnessFactor\":"+rough+"}}"
        }.joinToString(",")
        val payload=bin.toByteArray();val jointList=bones.indices.joinToString(",");val meshNode=bones.size
        val json="{\"asset\":{\"version\":\"2.0\",\"generator\":\"DuckDreamStudios-Lyra-0.1\"},\"scene\":0,\"scenes\":[{\"nodes\":[0,"+meshNode+"]}],\"nodes\":["+nodes+"],\"meshes\":[{\"name\":\"Lyra_Original_Character\",\"primitives\":["+primitives+"]}],\"materials\":["+materials+"],\"skins\":[{\"name\":\"Lyra_Humanoid_Rig\",\"skeleton\":0,\"joints\":["+jointList+"],\"inverseBindMatrices\":"+ibmAccessor+"}],\"buffers\":[{\"byteLength\":"+payload.size+"}],\"bufferViews\":["+views+"],\"accessors\":["+accessors+"]}"
        val raw=json.toByteArray(Charsets.UTF_8);val jp=(4-raw.size%4)%4;val jsonBytes=raw+ByteArray(jp){0x20}
        val bp=(4-payload.size%4)%4;val total=12+8+jsonBytes.size+8+payload.size+bp
        return ByteBuffer.allocate(total).order(ByteOrder.LITTLE_ENDIAN).apply{
            put(byteArrayOf(0x67,0x6c,0x54,0x46));putInt(2);putInt(total)
            putInt(jsonBytes.size);putInt(0x4E4F534A);put(jsonBytes)
            putInt(payload.size+bp);putInt(0x004E4942);put(payload);repeat(bp){put(0)}
        }.array()
    }
}
