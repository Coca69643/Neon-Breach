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
    float disabled = 0.0f;
    float actionCooldown = 0.0f;
};

constexpr int kBotCount = 9;
constexpr std::array<float, 3> kLaneX{{-12.0f, 0.0f, 12.0f}};
constexpr float kPlayerWalkSpeed = 5.6f;
constexpr float kPlayerBoostSpeed = 9.2f;
constexpr float kPlayerRadius = 0.42f;
constexpr float kBotSpeed = 2.7f;

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
    const float homeZ = blue ? -17.5f : 17.5f;
    const float side = (index % 2 == 0) ? -0.9f : 0.9f;
    const float formationOffset = index == 3 ? 3.0f : (index == 8 ? -3.0f : 0.0f);
    bot.position = {kLaneX[static_cast<std::size_t>(bot.lane)] + side,
                    homeZ + (blue ? side : -side) + (blue ? formationOffset : -formationOffset)};
    bot.velocity = {0.0f, 0.0f};
    bot.disabled = 0.0f;
    bot.actionCooldown = 1.0f + static_cast<float>(index % 3);
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
    for (int i = 0; i < kBotCount; ++i) {
        Bot &bot = gBots[static_cast<std::size_t>(i)];
        bot.team = teams[static_cast<std::size_t>(i)];
        bot.lane = lanes[static_cast<std::size_t>(i)];
        resetBot(bot, i);
    }
    gInitialized = true;
}

void disableBot(Bot &bot, int index, int sourceTeam) {
    if (bot.disabled > 0.0f) return;
    bot.disabled = 2.4f;
    bot.velocity = {0.0f, 0.0f};
    if (sourceTeam == 0) gBotScoreBlue += 1.0f;
    else gBotScoreRed += 1.0f;
    bot.actionCooldown = 3.5f + static_cast<float>(index % 2);
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

void updateBots(float dt) {
    for (int i = 0; i < kBotCount; ++i) {
        Bot &bot = gBots[static_cast<std::size_t>(i)];
        bot.disabled = std::max(0.0f, bot.disabled - dt);
        bot.actionCooldown = std::max(0.0f, bot.actionCooldown - dt);
        if (bot.disabled > 0.0f) continue;

        const bool blue = bot.team == 0;
        Vec2 target{kLaneX[static_cast<std::size_t>(bot.lane)], blue ? 22.0f : -22.0f};
        float bestDistance = 7.0f;
        int targetBot = -1;
        bool targetPlayer = false;

        for (int j = 0; j < kBotCount; ++j) {
            const Bot &other = gBots[static_cast<std::size_t>(j)];
            if (other.team == bot.team || other.disabled > 0.0f) continue;
            const float d = distance(bot.position, other.position);
            if (d < bestDistance) {
                bestDistance = d;
                target = other.position;
                targetBot = j;
                targetPlayer = false;
            }
        }

        if (!blue) {
            const float playerDistance = distance(bot.position, {gPlayerX, gPlayerZ});
            if (playerDistance < bestDistance && gPlayerDisrupted <= 0.0f) {
                bestDistance = playerDistance;
                target = {gPlayerX, gPlayerZ};
                targetBot = -1;
                targetPlayer = true;
            }
        }

        Vec2 desired{0.0f, 0.0f};
        if (bestDistance < 7.0f) {
            const Vec2 delta{target.x - bot.position.x, target.z - bot.position.z};
            const float d = std::max(length(delta), 0.001f);
            desired = {delta.x / d, delta.z / d};
        } else {
            const float dx = kLaneX[static_cast<std::size_t>(bot.lane)] - bot.position.x;
            const float dz = (blue ? 22.0f : -22.0f) - bot.position.z;
            const float d = std::max(std::sqrt(dx * dx + dz * dz), 0.001f);
            desired = {dx / d, dz / d};
        }

        const float blend = std::min(1.0f, dt * 3.0f);
        bot.velocity.x += (desired.x * kBotSpeed - bot.velocity.x) * blend;
        bot.velocity.z += (desired.z * kBotSpeed - bot.velocity.z) * blend;
        bot.position.x += bot.velocity.x * dt;
        bot.position.z += bot.velocity.z * dt;
        bot.position.x = std::clamp(bot.position.x, -23.0f, 23.0f);
        bot.position.z = std::clamp(bot.position.z, -23.0f, 23.0f);

        if (bestDistance < 3.1f && bot.actionCooldown <= 0.0f) {
            if (targetBot >= 0) {
                disableBot(gBots[static_cast<std::size_t>(targetBot)], targetBot, bot.team);
            } else if (targetPlayer && gShieldTime <= 0.0f) {
                gPlayerDisrupted = 1.15f;
                gBotScoreRed += 1.0f;
                gPlayerX = -12.0f;
                gPlayerZ = -19.0f;
                gPlayerVx = 0.0f;
                gPlayerVz = 0.0f;
            }
            bot.actionCooldown = 4.2f;
        }
    }

    for (int i = 0; i < kBotCount; ++i) {
        Bot &bot = gBots[static_cast<std::size_t>(i)];
        if (bot.disabled <= 0.0f && bot.actionCooldown < 0.0f) {
            bot.actionCooldown = 0.0f;
        }
        if (bot.disabled == 0.0f && length(bot.velocity) < 0.01f) {
            const float homeZ = bot.team == 0 ? -17.5f : 17.5f;
            if (std::abs(bot.position.z - homeZ) > 8.0f) {
                resetBot(bot, i);
            }
        }
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
            if (bot.team == 0) ++blueHeroes;
            else ++redHeroes;
        }
        const float playerSupport =
            (laneForX(gPlayerX) == lane && gPlayerDisrupted <= 0.0f) ? 0.65f : 0.0f;
        const float creepAdvantage =
            static_cast<float>(gBlueCreeps[static_cast<std::size_t>(lane)]
                             - gRedCreeps[static_cast<std::size_t>(lane)]) * 0.12f;
        const float pressure = static_cast<float>(blueHeroes - redHeroes)
                             + playerSupport + creepAdvantage;
        gLaneProgress[static_cast<std::size_t>(lane)] =
            std::clamp(gLaneProgress[static_cast<std::size_t>(lane)] + pressure * 0.0018f * dt,
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

    std::array<jfloat, 34> values{};
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

    jfloatArray result = env->NewFloatArray(static_cast<jsize>(values.size()));
    if (result != nullptr) {
        env->SetFloatArrayRegion(result, 0, static_cast<jsize>(values.size()), values.data());
    }
    return result;
}
