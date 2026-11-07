package com.duckdream.projectarena.poc;

import android.opengl.GLES20;
import android.opengl.GLSurfaceView;
import android.opengl.Matrix;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.FloatBuffer;
import java.util.ArrayList;
import java.util.List;

/**
 * Minimal city-scene renderer built directly on Android OpenGL ES 2.0.
 *
 * No scene graph, model loader, physics package or game engine is used.
 * Geometry is baked into one static VBO and rendered in one draw call.
 */
final class CitySceneRenderer implements GLSurfaceView.Renderer {
    private static final int FLOATS_PER_VERTEX = 9;
    private static final int STRIDE_BYTES = FLOATS_PER_VERTEX * 4;

    private static final String VERTEX_SHADER =
            "uniform mat4 uMvp;\n" +
            "attribute vec3 aPosition;\n" +
            "attribute vec3 aNormal;\n" +
            "attribute vec3 aColor;\n" +
            "varying vec3 vColor;\n" +
            "varying float vLight;\n" +
            "void main() {\n" +
            "  vec3 lightDir = normalize(vec3(-0.35, 0.82, 0.44));\n" +
            "  float diffuse = max(dot(normalize(aNormal), lightDir), 0.0);\n" +
            "  vLight = 0.58 + diffuse * 0.42;\n" +
            "  vColor = aColor;\n" +
            "  gl_Position = uMvp * vec4(aPosition, 1.0);\n" +
            "}\n";

    private static final String FRAGMENT_SHADER =
            "precision mediump float;\n" +
            "varying vec3 vColor;\n" +
            "varying float vLight;\n" +
            "void main() {\n" +
            "  gl_FragColor = vec4(vColor * vLight, 1.0);\n" +
            "}\n";

    private final float[] projection = new float[16];
    private final float[] view = new float[16];
    private final float[] mvp = new float[16];
    private int vertexBufferId;
    private int vertexCount;
    private int program;
    private int mvpLocation;
    private int positionLocation;
    private int normalLocation;
    private int colorLocation;
    private volatile float yawDegrees = 24f;
    private volatile float pitchDegrees = 27f;

    void orbit(float deltaX, float deltaY) {
        yawDegrees = (yawDegrees + deltaX * 0.28f) % 360f;
        pitchDegrees = clamp(pitchDegrees - deltaY * 0.18f, 12f, 54f);
    }

    @Override
    public void onSurfaceCreated(javax.microedition.khronos.opengles.GL10 unused,
                                 javax.microedition.khronos.egl.EGLConfig config) {
        GLES20.glClearColor(0.055f, 0.085f, 0.105f, 1f);
        GLES20.glEnable(GLES20.GL_DEPTH_TEST);
        GLES20.glDisable(GLES20.GL_CULL_FACE);

        program = createProgram(VERTEX_SHADER, FRAGMENT_SHADER);
        mvpLocation = GLES20.glGetUniformLocation(program, "uMvp");
        positionLocation = GLES20.glGetAttribLocation(program, "aPosition");
        normalLocation = GLES20.glGetAttribLocation(program, "aNormal");
        colorLocation = GLES20.glGetAttribLocation(program, "aColor");

        float[] vertices = buildCity();
        vertexCount = vertices.length / FLOATS_PER_VERTEX;
        FloatBuffer staging = ByteBuffer.allocateDirect(vertices.length * 4)
                .order(ByteOrder.nativeOrder())
                .asFloatBuffer();
        staging.put(vertices);
        staging.position(0);

        int[] buffers = new int[1];
        GLES20.glGenBuffers(1, buffers, 0);
        vertexBufferId = buffers[0];
        GLES20.glBindBuffer(GLES20.GL_ARRAY_BUFFER, vertexBufferId);
        GLES20.glBufferData(
                GLES20.GL_ARRAY_BUFFER,
                vertices.length * 4,
                staging,
                GLES20.GL_STATIC_DRAW
        );
        GLES20.glBindBuffer(GLES20.GL_ARRAY_BUFFER, 0);
    }

    @Override
    public void onSurfaceChanged(javax.microedition.khronos.opengles.GL10 unused,
                                 int width, int height) {
        int safeWidth = Math.max(1, width);
        int safeHeight = Math.max(1, height);
        GLES20.glViewport(0, 0, safeWidth, safeHeight);
        Matrix.perspectiveM(
                projection, 0, 48f,
                (float) safeWidth / (float) safeHeight,
                0.1f, 170f
        );
    }

    @Override
    public void onDrawFrame(javax.microedition.khronos.opengles.GL10 unused) {
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT | GLES20.GL_DEPTH_BUFFER_BIT);

        double yaw = Math.toRadians(yawDegrees);
        double pitch = Math.toRadians(pitchDegrees);
        float distance = 48f;
        float horizontal = (float) (Math.cos(pitch) * distance);
        float cameraX = (float) Math.sin(yaw) * horizontal;
        float cameraY = 8f + (float) Math.sin(pitch) * distance;
        float cameraZ = (float) Math.cos(yaw) * horizontal;

        Matrix.setLookAtM(
                view, 0,
                cameraX, cameraY, cameraZ,
                0f, 1.4f, 0f,
                0f, 1f, 0f
        );
        Matrix.multiplyMM(mvp, 0, projection, 0, view, 0);

        GLES20.glUseProgram(program);
        GLES20.glUniformMatrix4fv(mvpLocation, 1, false, mvp, 0);
        GLES20.glBindBuffer(GLES20.GL_ARRAY_BUFFER, vertexBufferId);

        GLES20.glEnableVertexAttribArray(positionLocation);
        GLES20.glVertexAttribPointer(
                positionLocation, 3, GLES20.GL_FLOAT, false,
                STRIDE_BYTES, 0
        );

        GLES20.glEnableVertexAttribArray(normalLocation);
        GLES20.glVertexAttribPointer(
                normalLocation, 3, GLES20.GL_FLOAT, false,
                STRIDE_BYTES, 12
        );

        GLES20.glEnableVertexAttribArray(colorLocation);
        GLES20.glVertexAttribPointer(
                colorLocation, 3, GLES20.GL_FLOAT, false,
                STRIDE_BYTES, 24
        );

        GLES20.glDrawArrays(GLES20.GL_TRIANGLES, 0, vertexCount);

        GLES20.glDisableVertexAttribArray(positionLocation);
        GLES20.glDisableVertexAttribArray(normalLocation);
        GLES20.glDisableVertexAttribArray(colorLocation);
        GLES20.glBindBuffer(GLES20.GL_ARRAY_BUFFER, 0);
    }

    private static float[] buildCity() {
        List<Float> data = new ArrayList<>(180000);

        float[] ground = color(0.19f, 0.25f, 0.27f);
        float[] road = color(0.075f, 0.10f, 0.12f);
        float[] sidewalk = color(0.34f, 0.40f, 0.40f);
        float[] marking = color(0.76f, 0.70f, 0.52f);

        addBox(data, 0f, -0.42f, 0f, 38f, 0.32f, 38f, ground);
        addBox(data, 0f, -0.045f, 0f, 5.1f, 0.045f, 38f, road);
        addBox(data, 0f, -0.045f, 0f, 38f, 0.045f, 4.2f, road);

        addBox(data, -5.8f, 0.015f, 0f, 0.58f, 0.09f, 38f, sidewalk);
        addBox(data, 5.8f, 0.015f, 0f, 0.58f, 0.09f, 38f, sidewalk);
        addBox(data, 0f, 0.015f, -4.9f, 5.1f, 0.09f, 0.58f, sidewalk);
        addBox(data, 0f, 0.015f, 4.9f, 5.1f, 0.09f, 0.58f, sidewalk);

        for (int z = -32; z <= 32; z += 8) {
            addBox(data, 0f, 0.012f, z, 0.11f, 0.012f, 2.2f, marking);
        }
        for (int x = -32; x <= 32; x += 8) {
            addBox(data, x, 0.012f, 0f, 2.2f, 0.012f, 0.11f, marking);
        }

        addBuilding(data, -13f, -19f, 3.4f, 4.2f, 10f, color(0.25f, 0.36f, 0.39f));
        addBuilding(data, -20f, -8f, 2.9f, 4.0f, 15f, color(0.34f, 0.36f, 0.34f));
        addBuilding(data, -13f, 11f, 4.1f, 3.6f, 12f, color(0.36f, 0.31f, 0.27f));
        addBuilding(data, -20f, 21f, 3.1f, 3.8f, 17f, color(0.23f, 0.34f, 0.37f));

        addBuilding(data, 13f, -19f, 3.8f, 4.1f, 13f, color(0.31f, 0.34f, 0.35f));
        addBuilding(data, 20f, -8f, 2.9f, 3.8f, 9f, color(0.39f, 0.32f, 0.27f));
        addBuilding(data, 13f, 11f, 4.2f, 3.6f, 16f, color(0.24f, 0.35f, 0.37f));
        addBuilding(data, 20f, 21f, 3.0f, 3.9f, 11f, color(0.34f, 0.37f, 0.34f));

        addBuilding(data, -28f, -25f, 2.5f, 3.2f, 8f, color(0.36f, 0.34f, 0.29f));
        addBuilding(data, 28f, -25f, 2.4f, 3.2f, 12f, color(0.24f, 0.34f, 0.38f));
        addBuilding(data, -28f, 28f, 2.6f, 3.0f, 12f, color(0.29f, 0.36f, 0.35f));
        addBuilding(data, 28f, 28f, 2.7f, 3.2f, 9f, color(0.37f, 0.32f, 0.28f));

        addStreetFurniture(data, -6.8f, -28f);
        addStreetFurniture(data, 6.8f, -28f);
        addStreetFurniture(data, -6.8f, -12f);
        addStreetFurniture(data, 6.8f, -12f);
        addStreetFurniture(data, -6.8f, 12f);
        addStreetFurniture(data, 6.8f, 12f);
        addStreetFurniture(data, -6.8f, 28f);
        addStreetFurniture(data, 6.8f, 28f);

        return toArray(data);
    }

    private static void addBuilding(List<Float> out, float x, float z,
                                    float halfWidth, float halfDepth, float height,
                                    float[] baseColor) {
        addBox(out, x, height * 0.5f, z,
                halfWidth, height * 0.5f, halfDepth, baseColor);
        addBox(out, x, height + 0.13f, z,
                halfWidth + 0.14f, 0.13f, halfDepth + 0.14f,
                color(0.47f, 0.52f, 0.49f));
        addBox(out, x, height * 0.57f, z + halfDepth + 0.035f,
                0.07f, height * 0.36f, 0.045f,
                color(0.32f, 0.58f, 0.54f));

        int columns = Math.max(2, (int) ((halfWidth * 2f) / 1.45f));
        int rows = Math.max(2, (int) (height / 1.65f));
        float spacing = (halfWidth * 2f) / columns;
        for (int row = 0; row < rows; row++) {
            float y = 1.1f + row * 1.5f;
            if (y > height - 0.6f) break;
            for (int column = 0; column < columns; column++) {
                float wx = x - halfWidth + spacing * (column + 0.5f);
                float[] glass = ((row + column) % 4 == 0)
                        ? color(0.76f, 0.66f, 0.46f)
                        : color(0.24f, 0.48f, 0.49f);
                addBox(out, wx, y, z + halfDepth + 0.055f,
                        Math.min(0.28f, spacing * 0.22f), 0.34f, 0.035f, glass);
            }
        }
    }

    private static void addStreetFurniture(List<Float> out, float x, float z) {
        addBox(out, x, 2.45f, z, 0.065f, 2.45f, 0.065f,
                color(0.29f, 0.35f, 0.35f));
        addBox(out, x, 4.95f, z, 0.30f, 0.13f, 0.30f,
                color(0.83f, 0.73f, 0.53f));
        addBox(out, x + 0.22f, 4.78f, z, 0.22f, 0.055f, 0.055f,
                color(0.48f, 0.61f, 0.56f));
    }

    private static void addBox(List<Float> out, float cx, float cy, float cz,
                               float hx, float hy, float hz, float[] base) {
        float x0 = cx - hx, x1 = cx + hx;
        float y0 = cy - hy, y1 = cy + hy;
        float z0 = cz - hz, z1 = cz + hz;

        face(out, 0f, 0f, -1f, base, 0.82f,
                x0,y0,z0, x1,y0,z0, x1,y1,z0, x0,y1,z0);
        face(out, 0f, 0f, 1f, base, 1.00f,
                x1,y0,z1, x0,y0,z1, x0,y1,z1, x1,y1,z1);
        face(out, -1f, 0f, 0f, base, 0.72f,
                x0,y0,z1, x0,y0,z0, x0,y1,z0, x0,y1,z1);
        face(out, 1f, 0f, 0f, base, 0.90f,
                x1,y0,z0, x1,y0,z1, x1,y1,z1, x1,y1,z0);
        face(out, 0f, 1f, 0f, base, 1.14f,
                x0,y1,z0, x1,y1,z0, x1,y1,z1, x0,y1,z1);
        face(out, 0f, -1f, 0f, base, 0.55f,
                x0,y0,z1, x1,y0,z1, x1,y0,z0, x0,y0,z0);
    }

    private static void face(List<Float> out, float nx, float ny, float nz,
                             float[] base, float shade,
                             float ax, float ay, float az,
                             float bx, float by, float bz,
                             float cx, float cy, float cz,
                             float dx, float dy, float dz) {
        vertex(out, ax,ay,az,nx,ny,nz,base,shade);
        vertex(out, bx,by,bz,nx,ny,nz,base,shade);
        vertex(out, cx,cy,cz,nx,ny,nz,base,shade);
        vertex(out, ax,ay,az,nx,ny,nz,base,shade);
        vertex(out, cx,cy,cz,nx,ny,nz,base,shade);
        vertex(out, dx,dy,dz,nx,ny,nz,base,shade);
    }

    private static void vertex(List<Float> out, float x, float y, float z,
                               float nx, float ny, float nz,
                               float[] base, float shade) {
        out.add(x); out.add(y); out.add(z);
        out.add(nx); out.add(ny); out.add(nz);
        out.add(clamp(base[0] * shade, 0f, 1f));
        out.add(clamp(base[1] * shade, 0f, 1f));
        out.add(clamp(base[2] * shade, 0f, 1f));
    }

    private static float[] color(float r, float g, float b) {
        return new float[] {r, g, b};
    }

    private static float[] toArray(List<Float> values) {
        float[] result = new float[values.size()];
        for (int i = 0; i < values.size(); i++) result[i] = values.get(i);
        return result;
    }

    private static float clamp(float value, float min, float max) {
        return Math.max(min, Math.min(max, value));
    }

    private static int compileShader(int type, String source) {
        int shader = GLES20.glCreateShader(type);
        GLES20.glShaderSource(shader, source);
        GLES20.glCompileShader(shader);
        int[] status = new int[1];
        GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, status, 0);
        if (status[0] == 0) {
            String error = GLES20.glGetShaderInfoLog(shader);
            GLES20.glDeleteShader(shader);
            throw new IllegalStateException("OpenGL ES shader compile failed: " + error);
        }
        return shader;
    }

    private static int createProgram(String vertexSource, String fragmentSource) {
        int vertex = compileShader(GLES20.GL_VERTEX_SHADER, vertexSource);
        int fragment = compileShader(GLES20.GL_FRAGMENT_SHADER, fragmentSource);
        int linked = GLES20.glCreateProgram();
        GLES20.glAttachShader(linked, vertex);
        GLES20.glAttachShader(linked, fragment);
        GLES20.glLinkProgram(linked);

        int[] status = new int[1];
        GLES20.glGetProgramiv(linked, GLES20.GL_LINK_STATUS, status, 0);
        GLES20.glDeleteShader(vertex);
        GLES20.glDeleteShader(fragment);
        if (status[0] == 0) {
            String error = GLES20.glGetProgramInfoLog(linked);
            GLES20.glDeleteProgram(linked);
            throw new IllegalStateException("OpenGL ES program link failed: " + error);
        }
        return linked;
    }
}
