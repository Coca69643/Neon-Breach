#include <jni.h>
#include <algorithm>
#include <array>
#include <cmath>
#include <mutex>

namespace {
struct V2 { float x; float z; };
struct Obstacle { float x; float z; float radius; };

constexpr float kPlayerRadius = 0.42f;
constexpr float kWalkSpeed = 5.6f;
constexpr float kBoostSpeed = 9.2f;
constexpr float kAcceleration = 19.0f;
constexpr float kDrag = 8.5f;
constexpr float kCaptureRadius = 3.4f;
constexpr float kCaptureDuration = 9.0f;
constexpr float kBoostDuration = 0.48f;
constexpr float kBoostCooldown = 5.0f;

constexpr std::array<Obstacle, 18> kObstacles{{
    {-16.0f, -9.0f, 1.55f}, {-13.2f, -13.6f, 1.15f},
    {-9.0f, -16.5f, 1.25f}, {-4.8f, -18.0f, 1.05f},
    {7.0f, -17.0f, 1.30f}, {12.5f, -14.2f, 1.55f},
    {17.5f, -9.8f, 1.20f}, {19.0f, -3.2f, 1.45f},
    {16.0f, 8.5f, 1.35f}, {12.2f, 14.0f, 1.20f},
    {7.0f, 18.0f, 1.50f}, {-7.5f, 17.0f, 1.20f},
    {-13.7f, 13.2f, 1.45f}, {-18.0f, 7.0f, 1.25f},
    {-20.0f, 0.0f, 1.40f}, {-6.0f, -8.0f, 0.95f},
    {8.5f, 7.0f, 1.00f}, {5.5f, -6.8f, 0.95f}
}};

std::mutex gMutex;
float gX = -12.0f;
float gZ = -8.5f;
float gVx = 0.0f;
float gVz = 0.0f;
float gBoostTime = 0.0f;
float gBoostCooldown = 0.0f;
float gCaptureProgress = 0.0f;
bool gCaptured = false;

float terrainHeight(float x, float z) {
    const float hill = 0.48f * std::exp(-((x - 10.0f) * (x - 10.0f)
                                  + (z - 8.0f) * (z - 8.0f)) / 95.0f);
    return 0.40f * std::sin(x * 0.18f) * std::cos(z * 0.14f)
         + 0.20f * std::sin((x + z) * 0.29f) + hill;
}

void resolveCollisions(float &x, float &z) {
    // Soft circular island boundary rather than a square arena wall.
    const float boundary = 25.5f;
    const float radius = std::sqrt(x * x + z * z);
    if (radius > boundary) {
        const float scale = boundary / std::max(radius, 0.001f);
        x *= scale;
        z *= scale;
    }

    for (const auto &obstacle : kObstacles) {
        float dx = x - obstacle.x;
        float dz = z - obstacle.z;
        const float minimum = obstacle.radius + kPlayerRadius;
        const float distanceSq = dx * dx + dz * dz;
        if (distanceSq >= minimum * minimum) continue;

        const float distance = std::sqrt(std::max(distanceSq, 0.0001f));
        const float nx = dx / distance;
        const float nz = dz / distance;
        const float push = minimum - distance;
        x += nx * push;
        z += nz * push;

        // Remove only the velocity component pointing into the obstacle.
        const float into = gVx * nx + gVz * nz;
        if (into < 0.0f) {
            gVx -= into * nx;
            gVz -= into * nz;
        }
    }
}

void stepSimulation(float ix, float iz, float dt) {
    dt = std::clamp(dt, 0.0f, 0.05f);
    const float inputLength = std::sqrt(ix * ix + iz * iz);
    if (inputLength > 1.0f) {
        ix /= inputLength;
        iz /= inputLength;
    }

    const float targetSpeed = gBoostTime > 0.0f ? kBoostSpeed : kWalkSpeed;
    const float targetVx = ix * targetSpeed;
    const float targetVz = iz * targetSpeed;
    const bool hasInput = inputLength > 0.08f;

    if (hasInput) {
        const float blend = std::min(1.0f, kAcceleration * dt / std::max(targetSpeed, 1.0f));
        gVx += (targetVx - gVx) * blend;
        gVz += (targetVz - gVz) * blend;
    } else {
        const float decay = std::exp(-kDrag * dt);
        gVx *= decay;
        gVz *= decay;
    }

    const int substeps = std::max(1, static_cast<int>(std::ceil(dt / (1.0f / 120.0f))));
    const float subDt = dt / static_cast<float>(substeps);
    for (int i = 0; i < substeps; ++i) {
        gX += gVx * subDt;
        gZ += gVz * subDt;
        resolveCollisions(gX, gZ);
    }

    gBoostTime = std::max(0.0f, gBoostTime - dt);
    gBoostCooldown = std::max(0.0f, gBoostCooldown - dt);

    const float objectiveDistance = std::sqrt(gX * gX + gZ * gZ);
    if (objectiveDistance <= kCaptureRadius) {
        gCaptureProgress = std::min(1.0f, gCaptureProgress + dt / kCaptureDuration);
        if (gCaptureProgress >= 1.0f) gCaptured = true;
    } else if (!gCaptured) {
        gCaptureProgress = std::max(0.0f, gCaptureProgress - dt * 0.12f);
    }
}
} // namespace

extern "C" JNIEXPORT void JNICALL
Java_com_duckdream_neonbreach_MainActivity_nativeReset(JNIEnv *, jobject) {
    std::scoped_lock lock(gMutex);
    gX = -12.0f;
    gZ = -8.5f;
    gVx = 0.0f;
    gVz = 0.0f;
    gBoostTime = 0.0f;
    gBoostCooldown = 0.0f;
    gCaptureProgress = 0.0f;
    gCaptured = false;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_duckdream_neonbreach_MainActivity_nativeActivateDash(JNIEnv *, jobject) {
    std::scoped_lock lock(gMutex);
    if (gBoostCooldown > 0.0f) return JNI_FALSE;

    float length = std::sqrt(gVx * gVx + gVz * gVz);
    if (length < 0.25f) {
        gVx = 0.0f;
        gVz = -kWalkSpeed;
        length = kWalkSpeed;
    }
    const float scale = kBoostSpeed / std::max(length, 0.001f);
    gVx *= scale;
    gVz *= scale;
    gBoostTime = kBoostDuration;
    gBoostCooldown = kBoostCooldown;
    return JNI_TRUE;
}

extern "C" JNIEXPORT jfloatArray JNICALL
Java_com_duckdream_neonbreach_MainActivity_nativeStep(
        JNIEnv *env, jobject, jfloat inputX, jfloat inputZ, jfloat deltaTime) {
    std::scoped_lock lock(gMutex);
    stepSimulation(inputX, inputZ, deltaTime);

    const float speed = std::sqrt(gVx * gVx + gVz * gVz);
    const jfloat values[] = {
        gX,
        terrainHeight(gX, gZ),
        gZ,
        speed,
        gCaptureProgress,
        gBoostCooldown,
        gCaptured ? 1.0f : 0.0f
    };
    jfloatArray result = env->NewFloatArray(7);
    if (result != nullptr) env->SetFloatArrayRegion(result, 0, 7, values);
    return result;
}
