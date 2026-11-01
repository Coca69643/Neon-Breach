#include <jni.h>
#include <algorithm>
#include <array>
#include <cmath>
#include <mutex>

namespace {
struct Vec2 { float x; float z; };
struct Bot {
    Vec2 position{};
    Vec2 velocity{};
    int team = 0;
    int lane = 1;
    int slot = 0;
    int routeStep = 0;
    float disabled = 0.0f;
    float startDelay = 0.0f;
    float speedScale = 1.0f;
};

constexpr int kBotCount = 9;
constexpr std::array<float, 3> kLaneX{{-12.0f, 0.0f, 12.0f}};
constexpr float kPlayerWalkSpeed = 5.6f;
constexpr float kPlayerBoostSpeed = 9.2f;
constexpr float kBotSpeed = 2.45f;
constexpr float kBotAcceleration = 8.5f;
constexpr float kBotArrivalSpeedScale = 1.85f;
constexpr float kBotArrivalSnap = 0.12f;
constexpr std::array<float, 5> kBlueRouteZ{{-19.0f, -9.0f, -3.0f, 0.0f, 0.0f}};
constexpr std::array<float, 5> kRedRouteZ{{19.0f, 9.0f, 3.0f, 0.0f, 0.0f}};
constexpr float kBotFormationSpacing = 1.3f;

std::mutex gMutex;
std::array<Bot, kBotCount> gBots{};
std::array<float, 3> gLaneProgress{{0.0f, 0.0f, 0.0f}};
std::array<int, 3> gBlueCreeps{{4, 4, 4}};
std::array<int, 3> gRedCreeps{{4, 4, 4}};
float gPlayerX = -12.0f;
float gPlayerZ = -19.0f;
float gPlayerVx = 0.0f;
float gPlayerVz = 0.0f;
float gElapsed = 0.0f;
float gWaveTimer = 0.0f;
float gCreepClashTimer = 0.0f;
float gBoostTime = 0.0f;
float gBoostCooldown = 0.0f;
float gPulseCooldown = 0.0f;
float gShieldCooldown = 0.0f;
float gShieldTime = 0.0f;
float gPlayerDisrupted = 0.0f;
float gBotScoreBlue = 0.0f;
float gBotScoreRed = 0.0f;
int gSelectedHero = 0;
int gWinner = 0;
bool gInitialized = false;

float length(Vec2 value) {
    return std::sqrt(value.x * value.x + value.z * value.z);
}

float distance(Vec2 a, Vec2 b) {
    return length({a.x - b.x, a.z - b.z});
}

float terrainHeight(float x, float z) {
    const float hill = 0.48f * std::exp(-((x - 10.0f) * (x - 10.0f)
                                  + (z - 8.0f) * (z - 8.0f)) / 95.0f);
    return 0.40f * std::sin(x * 0.18f) * std::cos(z * 0.14f)
         + 0.20f * std::sin((x + z) * 0.29f) + hill;
}

int laneForX(float x) {
    if (x < -6.0f) return 0;
    if (x > 6.0f) return 2;
    return 1;
}

void resetBot(Bot &bot, int index) {
    const bool blue = bot.team == 0;
    const float homeZ = blue ? -19.0f : 19.0f;
    const float lateral = static_cast<float>(bot.slot) * kBotFormationSpacing;
    const float depth = static_cast<float>((index / 3) % 2) * 1.4f;
    bot.position = {
        kLaneX[static_cast<std::size_t>(bot.lane)] + lateral,
        homeZ + (blue ? depth : -depth)
    };
    bot.velocity = {0.0f, 0.0f};
    bot.routeStep = 0;
    bot.disabled = 0.0f;
    bot.startDelay = 0.12f * static_cast<float>(index % 5);
    bot.speedScale = 0.84f + 0.055f * static_cast<float>(index % 5);
}

void resetSimulation() {
    gLaneProgress = {{0.0f, 0.0f, 0.0f}};
    gBlueCreeps = {{4, 4, 4}};
    gRedCreeps = {{4, 4, 4}};
    gPlayerX = -12.0f;
    gPlayerZ = -19.0f;
    gPlayerVx = 0.0f;
    gPlayerVz = 0.0f;
    gElapsed = 0.0f;
    gWaveTimer = 0.0f;
    gCreepClashTimer = 0.0f;
    gBoostTime = 0.0f;
    gBoostCooldown = 0.0f;
    gPulseCooldown = 0.0f;
    gShieldCooldown = 0.0f;
    gShieldTime = 0.0f;
    gPlayerDisrupted = 0.0f;
    gBotScoreBlue = 0.0f;
    gBotScoreRed = 0.0f;
    gWinner = 0;

    // Four autonomous allies and five autonomous opponents.
    constexpr std::array<int, kBotCount> teams{{0, 0, 0, 0, 1, 1, 1, 1, 1}};
    constexpr std::array<int, kBotCount> lanes{{0, 1, 2, 1, 0, 1, 2, 0, 2}};
    constexpr std::array<int, kBotCount> slots{{-1, -1, -1, 1, -1, -1, -1, 1, 1}};
    for (int i = 0; i < kBotCount; ++i) {
        Bot &bot = gBots[static_cast<std::size_t>(i)];
        bot.team = teams[static_cast<std::size_t>(i)];
        bot.lane = lanes[static_cast<std::size_t>(i)];
        bot.slot = slots[static_cast<std::size_t>(i)];
        resetBot(bot, i);
    }
    gInitialized = true;
}

void disableBot(Bot &bot, int index, int sourceTeam) {
    (void)index;
    if (bot.disabled > 0.0f) return;
    bot.disabled = 2.4f;
    bot.velocity = {0.0f, 0.0f};
    if (sourceTeam == 0) gBotScoreBlue += 1.0f;
    else gBotScoreRed += 1.0f;
}

void movePlayer(float inputX, float inputZ, float dt) {
    const float inputLength = std::sqrt(inputX * inputX + inputZ * inputZ);
    if (inputLength > 1.0f) {
        inputX /= inputLength;
        inputZ /= inputLength;
    }
    const float speed = gBoostTime > 0.0f ? kPlayerBoostSpeed : kPlayerWalkSpeed;
    const float targetX = inputX * speed;
    const float targetZ = inputZ * speed;
    if (inputLength > 0.08f) {
        const float blend = std::min(1.0f, 19.0f * dt / std::max(speed, 1.0f));
        gPlayerVx += (targetX - gPlayerVx) * blend;
        gPlayerVz += (targetZ - gPlayerVz) * blend;
    } else {
        const float decay = std::exp(-8.5f * dt);
        gPlayerVx *= decay;
        gPlayerVz *= decay;
    }

    gPlayerX += gPlayerVx * dt;
    gPlayerZ += gPlayerVz * dt;
    const float radius = std::sqrt(gPlayerX * gPlayerX + gPlayerZ * gPlayerZ);
    if (radius > 24.7f) {
        const float scale = 24.7f / std::max(radius, 0.001f);
        gPlayerX *= scale;
        gPlayerZ *= scale;
    }

    // The three lane walls are soft obstacles around the central structures.
    for (const Vec2 obstacle : std::array<Vec2, 8>{{
        {-16.0f, -8.0f}, {-8.0f, -14.0f}, {8.0f, -14.0f}, {16.0f, -8.0f},
        {-16.0f, 8.0f}, {-8.0f, 14.0f}, {8.0f, 14.0f}, {16.0f, 8.0f}
    }}) {
        const Vec2 delta{gPlayerX - obstacle.x, gPlayerZ - obstacle.z};
        const float d = length(delta);
        if (d < 1.7f) {
            const float nx = delta.x / std::max(d, 0.001f);
            const float nz = delta.z / std::max(d, 0.001f);
            gPlayerX = obstacle.x + nx * 1.7f;
            gPlayerZ = obstacle.z + nz * 1.7f;
            const float into = gPlayerVx * nx + gPlayerVz * nz;
            if (into < 0.0f) {
                gPlayerVx -= into * nx;
                gPlayerVz -= into * nz;
            }
        }
    }
}

void moveBotTo(Bot &bot, Vec2 goal, float dt) {
    const Vec2 delta{goal.x - bot.position.x, goal.z - bot.position.z};
    const float distanceToGoal = length(delta);
    if (distanceToGoal <= kBotArrivalSnap) {
        bot.position = goal;
        bot.velocity = {0.0f, 0.0f};
        return;
    }

    const float brakingSpeed = std::sqrt(2.0f * kBotAcceleration * distanceToGoal);
    const float desiredSpeed = std::min(
        kBotSpeed * bot.speedScale,
        std::min(brakingSpeed, distanceToGoal * kBotArrivalSpeedScale));
    const float inverseDistance = 1.0f / std::max(distanceToGoal, 0.001f);
    const Vec2 desiredVelocity{
        delta.x * inverseDistance * desiredSpeed,
        delta.z * inverseDistance * desiredSpeed
    };
    const float blend = 1.0f - std::exp(-kBotAcceleration * dt);
    bot.velocity.x += (desiredVelocity.x - bot.velocity.x) * blend;
    bot.velocity.z += (desiredVelocity.z - bot.velocity.z) * blend;
    bot.position.x += bot.velocity.x * dt;
    bot.position.z += bot.velocity.z * dt;

    const Vec2 remaining{goal.x - bot.position.x, goal.z - bot.position.z};
    if (remaining.x * delta.x + remaining.z * delta.z <= 0.0f) {
        bot.position = goal;
        bot.velocity = {0.0f, 0.0f};
    }
}

float routeTargetZ(const Bot &bot) {
    const auto &route = bot.team == 0 ? kBlueRouteZ : kRedRouteZ;
    return route[static_cast<std::size_t>(std::clamp(bot.routeStep, 0, 4))];
}

void updateBots(float dt) {
    // Each unit advances along a fixed lane route with its own delay and speed.
    // Its path never reads the player transform or the lane-score value.
    for (int i = 0; i < kBotCount; ++i) {
        Bot &bot = gBots[static_cast<std::size_t>(i)];
        if (bot.disabled > 0.0f) {
            bot.disabled = std::max(0.0f, bot.disabled - dt);
            if (bot.disabled == 0.0f) resetBot(bot, i);
            continue;
        }
        if (bot.startDelay > 0.0f) {
            bot.startDelay = std::max(0.0f, bot.startDelay - dt);
            continue;
        }
        const float teamOffset = bot.team == 0 ? -0.72f : 0.72f;
        const float targetX = kLaneX[static_cast<std::size_t>(bot.lane)]
                            + static_cast<float>(bot.slot) * kBotFormationSpacing + teamOffset;
        const Vec2 goal{targetX, routeTargetZ(bot)};
        moveBotTo(bot, goal, dt);
        if (distance(bot.position, goal) <= kBotArrivalSnap && bot.routeStep < 4) {
            ++bot.routeStep;
        }
        bot.position.x = std::clamp(bot.position.x, -23.5f, 23.5f);
        bot.position.z = std::clamp(bot.position.z, -23.5f, 23.5f);
    }
}

void updateLanes(float dt) {
    gWaveTimer += dt;
    if (gWaveTimer >= 18.0f) {
        gWaveTimer -= 18.0f;
        for (int lane = 0; lane < 3; ++lane) {
            gBlueCreeps[static_cast<std::size_t>(lane)] =
                std::min(6, gBlueCreeps[static_cast<std::size_t>(lane)] + 4);
            gRedCreeps[static_cast<std::size_t>(lane)] =
                std::min(6, gRedCreeps[static_cast<std::size_t>(lane)] + 4);
        }
    }

    gCreepClashTimer += dt;
    if (gCreepClashTimer >= 4.0f) {
        gCreepClashTimer -= 4.0f;
        for (int lane = 0; lane < 3; ++lane) {
            int &blue = gBlueCreeps[static_cast<std::size_t>(lane)];
            int &red = gRedCreeps[static_cast<std::size_t>(lane)];
            if (blue > 0 && red > 0) {
                --blue;
                --red;
            }
        }
    }

    for (int lane = 0; lane < 3; ++lane) {
        int blueHeroes = 0;
        int redHeroes = 0;
        for (const Bot &bot : gBots) {
            if (bot.lane != lane || bot.disabled > 0.0f) continue;
            // Route control is scored in a fixed central zone, not a score-driven
            // moving front; NPC navigation and objective progress are decoupled.
            if (std::abs(bot.position.z) > 2.8f) continue;
            if (bot.team == 0) ++blueHeroes;
            else ++redHeroes;
        }
        const bool playerOnObjective = laneForX(gPlayerX) == lane &&
            std::abs(gPlayerZ) < 3.6f && gPlayerDisrupted <= 0.0f;
        const float playerSupport = playerOnObjective
            ? (gShieldTime > 0.0f ? 1.85f : 1.15f) : 0.0f;
        const float creepAdvantage =
            static_cast<float>(gBlueCreeps[static_cast<std::size_t>(lane)]
                             - gRedCreeps[static_cast<std::size_t>(lane)]) * 0.12f;
        const float pressure = static_cast<float>(blueHeroes - redHeroes)
                             + playerSupport + creepAdvantage;
        gLaneProgress[static_cast<std::size_t>(lane)] =
            std::clamp(gLaneProgress[static_cast<std::size_t>(lane)] + pressure * 0.0085f * dt,
                       -1.0f, 1.0f);
    }

    int blueCaptured = 0;
    int redCaptured = 0;
    for (float progress : gLaneProgress) {
        if (progress >= 0.98f) ++blueCaptured;
        if (progress <= -0.98f) ++redCaptured;
    }
    if (blueCaptured >= 2) gWinner = 1;
    if (redCaptured >= 2) gWinner = -1;
}

void simulate(float inputX, float inputZ, float dt) {
    dt = std::clamp(dt, 0.0f, 0.05f);
    if (!gInitialized) resetSimulation();
    if (gWinner != 0) return;

    gElapsed += dt;
    gBoostTime = std::max(0.0f, gBoostTime - dt);
    gBoostCooldown = std::max(0.0f, gBoostCooldown - dt);
    gPulseCooldown = std::max(0.0f, gPulseCooldown - dt);
    gShieldCooldown = std::max(0.0f, gShieldCooldown - dt);
    gShieldTime = std::max(0.0f, gShieldTime - dt);
    gPlayerDisrupted = std::max(0.0f, gPlayerDisrupted - dt);

    if (gPlayerDisrupted <= 0.0f) movePlayer(inputX, inputZ, dt);
    else {
        gPlayerVx = 0.0f;
        gPlayerVz = 0.0f;
    }

    updateBots(dt);
    updateLanes(dt);
}
} // namespace

extern "C" JNIEXPORT void JNICALL
Java_com_duckdream_neonbreach_MainActivity_nativeReset(JNIEnv *, jobject) {
    std::scoped_lock lock(gMutex);
    resetSimulation();
}

extern "C" JNIEXPORT void JNICALL
Java_com_duckdream_neonbreach_MainActivity_nativeSelectHero(JNIEnv *, jobject, jint hero) {
    std::scoped_lock lock(gMutex);
    gSelectedHero = std::clamp(static_cast<int>(hero), 0, 2);
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_duckdream_neonbreach_MainActivity_nativeActivateDash(JNIEnv *, jobject) {
    std::scoped_lock lock(gMutex);
    if (!gInitialized) resetSimulation();
    if (gBoostCooldown > 0.0f || gPlayerDisrupted > 0.0f) return JNI_FALSE;
    const float speed = std::sqrt(gPlayerVx * gPlayerVx + gPlayerVz * gPlayerVz);
    if (speed < 0.25f) {
        gPlayerVx = 0.0f;
        gPlayerVz = -kPlayerWalkSpeed;
    }
    const float scale = kPlayerBoostSpeed / std::max(
        std::sqrt(gPlayerVx * gPlayerVx + gPlayerVz * gPlayerVz), 0.001f);
    gPlayerVx *= scale;
    gPlayerVz *= scale;
    gBoostTime = 0.48f;
    gBoostCooldown = 5.0f;
    return JNI_TRUE;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_duckdream_neonbreach_MainActivity_nativeCastPulse(JNIEnv *, jobject) {
    std::scoped_lock lock(gMutex);
    if (!gInitialized) resetSimulation();
    if (gPulseCooldown > 0.0f || gPlayerDisrupted > 0.0f) return JNI_FALSE;
    const float radius = gSelectedHero == 1 ? 8.0f : 6.5f;
    int affected = 0;
    for (int i = 0; i < kBotCount; ++i) {
        Bot &bot = gBots[static_cast<std::size_t>(i)];
        if (bot.team != 1 || bot.disabled > 0.0f) continue;
        if (distance(bot.position, {gPlayerX, gPlayerZ}) <= radius) {
            disableBot(bot, i, 0);
            ++affected;
        }
    }
    if (affected == 0) {
        const int lane = laneForX(gPlayerX);
        gLaneProgress[static_cast<std::size_t>(lane)] =
            std::min(1.0f, gLaneProgress[static_cast<std::size_t>(lane)] + 0.035f);
    }
    gPulseCooldown = gSelectedHero == 2 ? 7.0f : 9.0f;
    return JNI_TRUE;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_duckdream_neonbreach_MainActivity_nativeActivateShield(JNIEnv *, jobject) {
    std::scoped_lock lock(gMutex);
    if (!gInitialized) resetSimulation();
    if (gShieldCooldown > 0.0f || gPlayerDisrupted > 0.0f) return JNI_FALSE;
    gShieldTime = gSelectedHero == 1 ? 4.2f : 3.0f;
    gShieldCooldown = gSelectedHero == 1 ? 9.0f : 12.0f;
    return JNI_TRUE;
}

extern "C" JNIEXPORT jfloatArray JNICALL
Java_com_duckdream_neonbreach_MainActivity_nativeStep(
        JNIEnv *env, jobject, jfloat inputX, jfloat inputZ, jfloat deltaTime) {
    std::scoped_lock lock(gMutex);
    simulate(inputX, inputZ, deltaTime);

    std::array<jfloat, 36> values{};
    values[0] = gPlayerX;
    values[1] = terrainHeight(gPlayerX, gPlayerZ);
    values[2] = gPlayerZ;
    values[3] = std::sqrt(gPlayerVx * gPlayerVx + gPlayerVz * gPlayerVz);
    values[4] = gElapsed;
    values[5] = gBotScoreBlue;
    values[6] = gBotScoreRed;
    values[7] = gShieldTime;
    values[8] = gPulseCooldown;
    values[9] = gBoostCooldown;
    values[10] = static_cast<float>(gBlueCreeps[0] + gBlueCreeps[1] + gBlueCreeps[2]);
    values[11] = static_cast<float>(gRedCreeps[0] + gRedCreeps[1] + gRedCreeps[2]);
    values[12] = gLaneProgress[0];
    values[13] = gLaneProgress[1];
    values[14] = gLaneProgress[2];
    values[15] = static_cast<float>(gWinner);

    for (int i = 0; i < kBotCount; ++i) {
        const Bot &bot = gBots[static_cast<std::size_t>(i)];
        values[static_cast<std::size_t>(16 + i * 2)] = bot.position.x;
        values[static_cast<std::size_t>(17 + i * 2)] = bot.position.z;
    }

    values[34] = gPlayerVx;
    values[35] = gPlayerVz;

    jfloatArray result = env->NewFloatArray(static_cast<jsize>(values.size()));
    if (result != nullptr) {
        env->SetFloatArrayRegion(result, 0, static_cast<jsize>(values.size()), values.data());
    }
    return result;
}
