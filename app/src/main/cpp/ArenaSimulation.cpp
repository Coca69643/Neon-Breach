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
    float health = 100.0f;
    float attackCooldown = 0.0f;
};

struct LaneUnit {
    Vec2 position{};
    Vec2 velocity{};
    int team = 0;
    int lane = 0;
    int slot = 0;
    float startDelay = 0.0f;
    float health = 120.0f;
    float attackCooldown = 0.45f;
};

constexpr int kBotCount = 9;
constexpr int kLaneUnitCount = 12;
constexpr float kTowerMaxHealth = 780.0f;
constexpr float kCoreMaxHealth = 1600.0f;
constexpr std::array<float, 3> kLaneX{{-12.0f, 0.0f, 12.0f}};
constexpr float kPlayerWalkSpeed = 5.6f;
constexpr float kPlayerBoostSpeed = 9.2f;
constexpr float kBotSpeed = 2.45f;
constexpr float kBotAcceleration = 8.5f;
constexpr float kBotArrivalSpeedScale = 1.85f;
constexpr float kBotArrivalSnap = 0.12f;
constexpr std::array<float, 5> kBlueRouteZ{{-19.0f, -9.0f, -3.0f, 7.0f, 12.0f}};
constexpr std::array<float, 5> kRedRouteZ{{19.0f, 9.0f, 3.0f, -7.0f, -12.0f}};
constexpr float kBotFormationSpacing = 1.3f;

std::mutex gMutex;
std::array<Bot, kBotCount> gBots{};
std::array<LaneUnit, kLaneUnitCount> gLaneUnits{};
std::array<float, 3> gLaneProgress{{0.0f, 0.0f, 0.0f}};
std::array<int, 3> gBlueCreeps{{0, 0, 0}};
std::array<int, 3> gRedCreeps{{0, 0, 0}};
std::array<float, 3> gBlueTowers{{kTowerMaxHealth, kTowerMaxHealth, kTowerMaxHealth}};
std::array<float, 3> gRedTowers{{kTowerMaxHealth, kTowerMaxHealth, kTowerMaxHealth}};
std::array<float, 3> gBlueTowerCooldown{};
std::array<float, 3> gRedTowerCooldown{};
std::array<std::array<float, 3>, 2> gLaneWaveCooldown{};
float gBlueCoreHealth = kCoreMaxHealth;
float gRedCoreHealth = kCoreMaxHealth;
float gPlayerX = -12.0f;
float gPlayerZ = -19.0f;
float gPlayerVx = 0.0f;
float gPlayerVz = 0.0f;
float gElapsed = 0.0f;
float gBoostTime = 0.0f;
float gBoostCooldown = 0.0f;
float gPulseCooldown = 0.0f;
float gShieldCooldown = 0.0f;
float gShieldTime = 0.0f;
float gPulseVisualTime = 0.0f;
float gPulseCaptureTime = 0.0f;
float gLastMoveX = 0.0f;
float gLastMoveZ = 1.0f;
float gDashX = 0.0f;
float gDashZ = 1.0f;
float gPlayerDisrupted = 0.0f;
float gPlayerHealth = 100.0f;
float gPlayerRespawnTime = 0.0f;
int gPlayerDeaths = 0;
float gPlayerAttackCooldown = 0.25f;
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
    const float westRidge = 1.05f * std::exp(-((x + 23.0f) * (x + 23.0f)) / 52.0f)
        * (0.45f + 0.55f * std::cos(z * 0.075f));
    const float eastRidge = 0.92f * std::exp(-((x - 23.0f) * (x - 23.0f)) / 58.0f)
        * (0.45f + 0.55f * std::cos(z * 0.07f));
    const float centralRise = 0.48f * std::exp(-((x - 1.0f) * (x - 1.0f)
        + (z - 1.0f) * (z - 1.0f)) / 90.0f);
    return 0.36f * std::sin(x * 0.18f) * std::cos(z * 0.14f)
        + 0.18f * std::sin((x + z) * 0.29f) + westRidge + eastRidge + centralRise;
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
    bot.health = 100.0f;
    bot.attackCooldown = 0.35f + 0.11f * static_cast<float>(index % 4);
    bot.startDelay = 0.12f * static_cast<float>(index % 5);
    bot.speedScale = 0.84f + 0.055f * static_cast<float>(index % 5);
}

void spawnLaneUnit(LaneUnit &unit, int team, int lane, int slot, int index) {
    unit.team = team;
    unit.lane = lane;
    unit.slot = slot;
    const float side = slot == 0 ? -0.75f : 0.75f;
    const float teamOffset = team == 0 ? -0.48f : 0.48f;
    const float spawnZ = team == 0 ? -23.5f - slot * 1.2f
                                   : 23.5f + slot * 1.2f;
    unit.position = {kLaneX[static_cast<std::size_t>(lane)] + side + teamOffset, spawnZ};
    unit.velocity = {0.0f, 0.0f};
    unit.health = 120.0f;
    unit.attackCooldown = 0.45f + 0.12f * static_cast<float>(slot);
    unit.startDelay = 0.12f * static_cast<float>((index * 7) % 5);
}

void resetLaneUnits() {
    gLaneWaveCooldown = {};
    for (int i = 0; i < kLaneUnitCount; ++i) {
        const int team = i < 6 ? 0 : 1;
        const int local = i % 6;
        spawnLaneUnit(gLaneUnits[static_cast<std::size_t>(i)], team, local % 3, local / 3, i);
    }
}

void resetSimulation() {
    gLaneProgress = {{0.0f, 0.0f, 0.0f}};
    gBlueCreeps = {{0, 0, 0}};
    gRedCreeps = {{0, 0, 0}};
    gBlueTowers.fill(kTowerMaxHealth);
    gRedTowers.fill(kTowerMaxHealth);
    gBlueTowerCooldown.fill(0.0f);
    gRedTowerCooldown.fill(0.0f);
    gBlueCoreHealth = kCoreMaxHealth;
    gRedCoreHealth = kCoreMaxHealth;
    resetLaneUnits();
    gPlayerX = -12.0f;
    gPlayerZ = -19.0f;
    gPlayerVx = 0.0f;
    gPlayerVz = 0.0f;
    gElapsed = 0.0f;
    gBoostTime = 0.0f;
    gBoostCooldown = 0.0f;
    gPulseCooldown = 0.0f;
    gShieldCooldown = 0.0f;
    gShieldTime = 0.0f;
    gPulseVisualTime = 0.0f;
    gPulseCaptureTime = 0.0f;
    gLastMoveX = 0.0f;
    gLastMoveZ = 1.0f;
    gDashX = 0.0f;
    gDashZ = 1.0f;
    gPlayerDisrupted = 0.0f;
    gPlayerHealth = 100.0f;
    gPlayerRespawnTime = 0.0f;
    gPlayerDeaths = 0;
    gPlayerAttackCooldown = 0.0f;
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
    bot.health = 0.0f;
    bot.disabled = 3.2f;
    bot.velocity = {0.0f, 0.0f};
    if (sourceTeam == 0) gBotScoreBlue += 1.0f;
    else gBotScoreRed += 1.0f;
}

void movePlayer(float inputX, float inputZ, float dt) {
    float inputLength = std::sqrt(inputX * inputX + inputZ * inputZ);
    const bool dashing = gBoostTime > 0.0f;
    if (dashing) {
        inputX = gDashX;
        inputZ = gDashZ;
        inputLength = 1.0f;
    }
    if (inputLength > 1.0f) {
        inputX /= inputLength;
        inputZ /= inputLength;
        inputLength = 1.0f;
    }
    if (!dashing && inputLength > 0.08f) {
        gLastMoveX = inputX;
        gLastMoveZ = inputZ;
    }
    const float walkSpeed = gSelectedHero == 2 ? 6.25f : kPlayerWalkSpeed;
    const float dashSpeed = gSelectedHero == 2 ? 10.9f : kPlayerBoostSpeed;
    const float speed = dashing ? dashSpeed * 1.18f : walkSpeed;
    const float targetX = inputX * speed;
    const float targetZ = inputZ * speed;
    if (inputLength > 0.08f) {
        const float blend = dashing ? 1.0f : 1.0f - std::exp(-16.0f * dt);
        gPlayerVx += (targetX - gPlayerVx) * blend;
        gPlayerVz += (targetZ - gPlayerVz) * blend;
    } else {
        const float decay = std::exp(-8.5f * dt);
        gPlayerVx *= decay;
        gPlayerVz *= decay;
    }

    gPlayerX += gPlayerVx * dt;
    gPlayerZ += gPlayerVz * dt;
    // Match the rectangular battlefield bounds; do not constrain the player to a circular island.
    gPlayerX = std::clamp(gPlayerX, -29.0f, 29.0f);
    gPlayerZ = std::clamp(gPlayerZ, -29.0f, 29.0f);

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

float enemyTowerZ(int team) { return team == 0 ? 12.2f : -12.2f; }
float enemyCoreZ(int team) { return team == 0 ? 25.4f : -25.4f; }

float &enemyTowerHealth(int team, int lane) {
    return team == 0 ? gRedTowers[static_cast<std::size_t>(lane)]
                     : gBlueTowers[static_cast<std::size_t>(lane)];
}

float &enemyCoreHealth(int team) {
    return team == 0 ? gRedCoreHealth : gBlueCoreHealth;
}

bool allEnemyTowersDown(int team) {
    const auto &towers = team == 0 ? gRedTowers : gBlueTowers;
    return std::all_of(towers.begin(), towers.end(),
                       [](float health) { return health <= 0.0f; });
}

void updateBots(float dt) {
    for (int i = 0; i < kBotCount; ++i) {
        Bot &bot = gBots[static_cast<std::size_t>(i)];
        if (bot.disabled > 0.0f) {
            bot.disabled = std::max(0.0f, bot.disabled - dt);
            if (bot.disabled == 0.0f) resetBot(bot, i);
            continue;
        }
        bot.attackCooldown = std::max(0.0f, bot.attackCooldown - dt);
        if (bot.startDelay > 0.0f) {
            bot.startDelay = std::max(0.0f, bot.startDelay - dt);
            continue;
        }

        int target = -1;
        float nearest = 5.8f;
        for (int j = 0; j < kBotCount; ++j) {
            Bot &candidate = gBots[static_cast<std::size_t>(j)];
            if (candidate.team == bot.team || candidate.disabled > 0.0f) continue;
            const float d = distance(bot.position, candidate.position);
            if (d < nearest) { nearest = d; target = j; }
        }

        const float playerDistance = bot.team == 1 && gPlayerHealth > 0.0f && gPlayerRespawnTime <= 0.0f
            ? distance(bot.position, {gPlayerX, gPlayerZ}) : 1000.0f;
        if (playerDistance < 5.2f && playerDistance <= nearest) {
            const Vec2 delta{gPlayerX - bot.position.x, gPlayerZ - bot.position.z};
            const float d = std::max(length(delta), 0.001f);
            if (playerDistance > 2.35f) {
                moveBotTo(bot, {gPlayerX - delta.x / d * 1.9f, gPlayerZ - delta.z / d * 1.9f}, dt);
            } else if (bot.attackCooldown <= 0.0f) {
                gPlayerHealth = std::max(0.0f, gPlayerHealth - (gShieldTime > 0.0f ? 4.0f : 11.0f));
                bot.attackCooldown = 1.0f;
            }
        } else if (target >= 0 && nearest < 5.8f) {
            Bot &enemy = gBots[static_cast<std::size_t>(target)];
            if (nearest > 2.35f) {
                const Vec2 delta{enemy.position.x - bot.position.x, enemy.position.z - bot.position.z};
                const float d = std::max(length(delta), 0.001f);
                moveBotTo(bot, {enemy.position.x - delta.x / d * 1.65f,
                                enemy.position.z - delta.z / d * 1.65f}, dt);
            } else if (bot.attackCooldown <= 0.0f) {
                enemy.health = std::max(0.0f, enemy.health - 12.0f);
                if (enemy.health <= 0.0f) disableBot(enemy, target, bot.team);
                bot.attackCooldown = 0.92f;
            }
        } else if (bot.routeStep < 4) {
            const float teamOffset = bot.team == 0 ? -0.72f : 0.72f;
            const float targetX = kLaneX[static_cast<std::size_t>(bot.lane)]
                                + static_cast<float>(bot.slot) * kBotFormationSpacing + teamOffset;
            const Vec2 goal{targetX, routeTargetZ(bot)};
            moveBotTo(bot, goal, dt);
            if (distance(bot.position, goal) <= kBotArrivalSnap) ++bot.routeStep;
        } else {
            const float targetZ = enemyTowerHealth(bot.team, bot.lane) > 0.0f
                ? enemyTowerZ(bot.team) : enemyCoreZ(bot.team);
            const Vec2 goal{kLaneX[static_cast<std::size_t>(bot.lane)], targetZ};
            if (distance(bot.position, goal) > 2.8f) {
                moveBotTo(bot, goal, dt);
            } else if (bot.attackCooldown <= 0.0f) {
                if (enemyTowerHealth(bot.team, bot.lane) > 0.0f) {
                    enemyTowerHealth(bot.team, bot.lane) =
                        std::max(0.0f, enemyTowerHealth(bot.team, bot.lane) - 30.0f);
                } else if (allEnemyTowersDown(bot.team)) {
                    enemyCoreHealth(bot.team) =
                        std::max(0.0f, enemyCoreHealth(bot.team) - 24.0f);
                    if (enemyCoreHealth(bot.team) <= 0.0f) gWinner = bot.team == 0 ? 1 : -1;
                }
                bot.attackCooldown = 1.15f;
            }
        }

        bot.position.x = std::clamp(bot.position.x, -28.5f, 28.5f);
        bot.position.z = std::clamp(bot.position.z, -28.5f, 28.5f);
    }

    if (gPlayerHealth <= 0.0f && gPlayerRespawnTime <= 0.0f) {
        gPlayerRespawnTime = 1.45f;
        ++gPlayerDeaths;
        gPlayerVx = gPlayerVz = 0.0f;
    }
}

void moveLaneUnitTo(LaneUnit &unit, Vec2 goal, float dt) {
    const Vec2 delta{goal.x - unit.position.x, goal.z - unit.position.z};
    const float distanceToGoal = length(delta);
    if (distanceToGoal <= 0.16f) {
        unit.position = goal;
        unit.velocity = {0.0f, 0.0f};
        return;
    }
    const float speed = std::min(2.6f, distanceToGoal * 1.35f);
    const float inverseDistance = 1.0f / std::max(distanceToGoal, 0.001f);
    const Vec2 desired{delta.x * inverseDistance * speed, delta.z * inverseDistance * speed};
    const float blend = 1.0f - std::exp(-5.8f * dt);
    unit.velocity.x += (desired.x - unit.velocity.x) * blend;
    unit.velocity.z += (desired.z - unit.velocity.z) * blend;
    unit.position.x += unit.velocity.x * dt;
    unit.position.z += unit.velocity.z * dt;
}

void updateLaneUnits(float dt) {
    gBlueCreeps = {{0, 0, 0}};
    gRedCreeps = {{0, 0, 0}};

    for (int team = 0; team < 2; ++team) {
        for (int lane = 0; lane < 3; ++lane) {
            int alive = 0;
            for (const LaneUnit &unit : gLaneUnits) {
                if (unit.team == team && unit.lane == lane && unit.health > 0.0f) ++alive;
            }
            float &waveCooldown = gLaneWaveCooldown[static_cast<std::size_t>(team)]
                                                   [static_cast<std::size_t>(lane)];
            if (alive == 0) {
                if (waveCooldown <= 0.0f) waveCooldown = 6.0f;
                waveCooldown = std::max(0.0f, waveCooldown - dt);
                if (waveCooldown <= 0.0f) {
                    for (int i = 0; i < kLaneUnitCount; ++i) {
                        LaneUnit &unit = gLaneUnits[static_cast<std::size_t>(i)];
                        if (unit.team == team && unit.lane == lane) {
                            spawnLaneUnit(unit, team, lane, unit.slot, i);
                        }
                    }
                }
            }
        }
    }

    for (LaneUnit &unit : gLaneUnits) {
        if (unit.health <= 0.0f) continue;
        unit.attackCooldown = std::max(0.0f, unit.attackCooldown - dt);
        if (unit.startDelay > 0.0f) {
            unit.startDelay = std::max(0.0f, unit.startDelay - dt);
            continue;
        }

        int target = -1;
        float nearest = 4.5f;
        for (int i = 0; i < kLaneUnitCount; ++i) {
            LaneUnit &candidate = gLaneUnits[static_cast<std::size_t>(i)];
            if (candidate.team == unit.team || candidate.lane != unit.lane || candidate.health <= 0.0f) continue;
            const float d = distance(unit.position, candidate.position);
            if (d < nearest) { nearest = d; target = i; }
        }

        if (target >= 0) {
            LaneUnit &enemy = gLaneUnits[static_cast<std::size_t>(target)];
            if (nearest > 1.75f) {
                const Vec2 delta{enemy.position.x - unit.position.x, enemy.position.z - unit.position.z};
                const float d = std::max(length(delta), 0.001f);
                moveLaneUnitTo(unit, {enemy.position.x - delta.x / d * 1.55f,
                                      enemy.position.z - delta.z / d * 1.55f}, dt);
            } else if (unit.attackCooldown <= 0.0f) {
                enemy.health = std::max(0.0f, enemy.health - 36.0f);
                unit.attackCooldown = 1.05f;
            }
        } else {
            const float targetZ = enemyTowerHealth(unit.team, unit.lane) > 0.0f
                ? enemyTowerZ(unit.team) : enemyCoreZ(unit.team);
            const Vec2 goal{kLaneX[static_cast<std::size_t>(unit.lane)], targetZ};
            if (distance(unit.position, goal) > 2.5f) {
                moveLaneUnitTo(unit, goal, dt);
            } else if (unit.attackCooldown <= 0.0f) {
                if (enemyTowerHealth(unit.team, unit.lane) > 0.0f) {
                    enemyTowerHealth(unit.team, unit.lane) =
                        std::max(0.0f, enemyTowerHealth(unit.team, unit.lane) - 42.0f);
                } else if (allEnemyTowersDown(unit.team)) {
                    enemyCoreHealth(unit.team) =
                        std::max(0.0f, enemyCoreHealth(unit.team) - 28.0f);
                    if (enemyCoreHealth(unit.team) <= 0.0f) gWinner = unit.team == 0 ? 1 : -1;
                }
                unit.attackCooldown = 1.05f;
            }
        }

        const std::size_t laneIndex = static_cast<std::size_t>(unit.lane);
        if (std::abs(unit.position.z) <= 6.0f) {
            if (unit.team == 0) ++gBlueCreeps[laneIndex];
            else ++gRedCreeps[laneIndex];
        }
    }
}

void updateTowers(float dt) {
    for (int lane = 0; lane < 3; ++lane) {
        for (int ownerTeam = 0; ownerTeam < 2; ++ownerTeam) {
            float &health = ownerTeam == 0 ? gBlueTowers[static_cast<std::size_t>(lane)]
                                            : gRedTowers[static_cast<std::size_t>(lane)];
            float &cooldown = ownerTeam == 0 ? gBlueTowerCooldown[static_cast<std::size_t>(lane)]
                                              : gRedTowerCooldown[static_cast<std::size_t>(lane)];
            if (health <= 0.0f) continue;
            cooldown = std::max(0.0f, cooldown - dt);
            if (cooldown > 0.0f) continue;

            const int enemyTeam = 1 - ownerTeam;
            const Vec2 towerPosition{kLaneX[static_cast<std::size_t>(lane)],
                                     ownerTeam == 0 ? -12.2f : 12.2f};
            int unitTarget = -1;
            float nearest = 7.2f;
            for (int i = 0; i < kLaneUnitCount; ++i) {
                const LaneUnit &unit = gLaneUnits[static_cast<std::size_t>(i)];
                if (unit.team != enemyTeam || unit.lane != lane || unit.health <= 0.0f) continue;
                const float d = distance(towerPosition, unit.position);
                if (d < nearest) { nearest = d; unitTarget = i; }
            }
            if (unitTarget >= 0) {
                LaneUnit &target = gLaneUnits[static_cast<std::size_t>(unitTarget)];
                target.health = std::max(0.0f, target.health - 18.0f);
                cooldown = 1.0f;
                continue;
            }

            int botTarget = -1;
            nearest = 7.2f;
            for (int i = 0; i < kBotCount; ++i) {
                const Bot &bot = gBots[static_cast<std::size_t>(i)];
                if (bot.team != enemyTeam || bot.lane != lane || bot.disabled > 0.0f) continue;
                const float d = distance(towerPosition, bot.position);
                if (d < nearest) { nearest = d; botTarget = i; }
            }
            if (botTarget >= 0) {
                Bot &target = gBots[static_cast<std::size_t>(botTarget)];
                target.health = std::max(0.0f, target.health - 16.0f);
                if (target.health <= 0.0f) disableBot(target, botTarget, ownerTeam);
                cooldown = 1.0f;
                continue;
            }

            if (ownerTeam == 1 && gPlayerHealth > 0.0f && gPlayerRespawnTime <= 0.0f &&
                distance(towerPosition, {gPlayerX, gPlayerZ}) <= 7.2f) {
                gPlayerHealth = std::max(0.0f, gPlayerHealth - (gShieldTime > 0.0f ? 5.0f : 12.0f));
                cooldown = 1.0f;
            }
        }
    }
}

void updateLanes(float dt) {
    updateLaneUnits(dt);
    updateTowers(dt);
    for (int lane = 0; lane < 3; ++lane) {
        const float enemyTower = gRedTowers[static_cast<std::size_t>(lane)];
        gLaneProgress[static_cast<std::size_t>(lane)] =
            1.0f - std::clamp(enemyTower / kTowerMaxHealth, 0.0f, 1.0f);
    }
    if (gRedCoreHealth <= 0.0f) gWinner = 1;
    if (gBlueCoreHealth <= 0.0f) gWinner = -1;
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
    gPulseVisualTime = std::max(0.0f, gPulseVisualTime - dt);
    gPulseCaptureTime = std::max(0.0f, gPulseCaptureTime - dt);
    gPlayerDisrupted = std::max(0.0f, gPlayerDisrupted - dt);
    gPlayerAttackCooldown = std::max(0.0f, gPlayerAttackCooldown - dt);

    const bool wasRespawning = gPlayerRespawnTime > 0.0f;
    if (wasRespawning) {
        gPlayerRespawnTime = std::max(0.0f, gPlayerRespawnTime - dt);
        gPlayerVx = gPlayerVz = 0.0f;
        if (gPlayerRespawnTime <= 0.0f) {
            gPlayerHealth = 100.0f;
            gPlayerX = -12.0f;
            gPlayerZ = -19.0f;
            gPlayerDisrupted = 0.85f;
        }
    }

    if (!wasRespawning && gPlayerDisrupted <= 0.0f) movePlayer(inputX, inputZ, dt);
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
Java_com_duckdream_neonbreach_MainActivity_nativeActivateDash(JNIEnv *, jobject, jfloat inputX, jfloat inputZ) {
    std::scoped_lock lock(gMutex);
    if (!gInitialized) resetSimulation();
    if (gPlayerHealth <= 0.0f || gPlayerRespawnTime > 0.0f ||
        gBoostCooldown > 0.0f || gPlayerDisrupted > 0.0f) return JNI_FALSE;
    float directionLength = std::sqrt(inputX * inputX + inputZ * inputZ);
    if (directionLength < 0.08f) {
        inputX = gLastMoveX;
        inputZ = gLastMoveZ;
        directionLength = std::sqrt(inputX * inputX + inputZ * inputZ);
    }
    if (directionLength < 0.08f) {
        inputX = 0.0f;
        inputZ = 1.0f;
        directionLength = 1.0f;
    }
    gDashX = inputX / directionLength;
    gDashZ = inputZ / directionLength;
    gPlayerVx = gDashX * kPlayerBoostSpeed;
    gPlayerVz = gDashZ * kPlayerBoostSpeed;
    gBoostTime = 0.46f;
    gBoostCooldown = gSelectedHero == 2 ? 3.6f : (gSelectedHero == 1 ? 6.0f : 5.0f);
    return JNI_TRUE;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_duckdream_neonbreach_MainActivity_nativeBasicAttack(JNIEnv *, jobject) {
    std::scoped_lock lock(gMutex);
    if (!gInitialized) resetSimulation();
    if (gWinner != 0 || gPlayerHealth <= 0.0f || gPlayerRespawnTime > 0.0f ||
        gPlayerDisrupted > 0.0f || gPlayerAttackCooldown > 0.0f) return JNI_FALSE;

    int botTarget = -1;
    float nearest = 4.8f;
    for (int i = 0; i < kBotCount; ++i) {
        Bot &bot = gBots[static_cast<std::size_t>(i)];
        if (bot.team != 1 || bot.disabled > 0.0f) continue;
        const float d = distance({gPlayerX, gPlayerZ}, bot.position);
        if (d < nearest) { nearest = d; botTarget = i; }
    }
    bool hit = false;
    if (botTarget >= 0) {
        Bot &enemy = gBots[static_cast<std::size_t>(botTarget)];
        const float damage = gSelectedHero == 1 ? 52.0f : (gSelectedHero == 2 ? 34.0f : 42.0f);
        enemy.health = std::max(0.0f, enemy.health - damage);
        if (enemy.health <= 0.0f) disableBot(enemy, botTarget, 0);
        hit = true;
    } else {
        int unitTarget = -1;
        nearest = 4.2f;
        for (int i = 0; i < kLaneUnitCount; ++i) {
            LaneUnit &unit = gLaneUnits[static_cast<std::size_t>(i)];
            if (unit.team != 1 || unit.health <= 0.0f) continue;
            const float d = distance({gPlayerX, gPlayerZ}, unit.position);
            if (d < nearest) { nearest = d; unitTarget = i; }
        }
        if (unitTarget >= 0) {
            LaneUnit &enemy = gLaneUnits[static_cast<std::size_t>(unitTarget)];
            const float damage = gSelectedHero == 1 ? 72.0f : (gSelectedHero == 2 ? 48.0f : 60.0f);
            enemy.health = std::max(0.0f, enemy.health - damage);
            hit = true;
        } else {
            const int lane = laneForX(gPlayerX);
            const Vec2 towerPosition{kLaneX[static_cast<std::size_t>(lane)], 12.2f};
            if (gRedTowers[static_cast<std::size_t>(lane)] > 0.0f &&
                distance({gPlayerX, gPlayerZ}, towerPosition) <= 5.2f) {
                gRedTowers[static_cast<std::size_t>(lane)] =
                    std::max(0.0f, gRedTowers[static_cast<std::size_t>(lane)] - 52.0f);
                hit = true;
            } else if (allEnemyTowersDown(0) &&
                       distance({gPlayerX, gPlayerZ}, {kLaneX[static_cast<std::size_t>(lane)], 25.4f}) <= 5.2f) {
                gRedCoreHealth = std::max(0.0f, gRedCoreHealth - 48.0f);
                if (gRedCoreHealth <= 0.0f) gWinner = 1;
                hit = true;
            }
        }
    }
    if (hit) gPlayerAttackCooldown = gSelectedHero == 1 ? 0.66f : (gSelectedHero == 2 ? 0.32f : 0.46f);
    return hit ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_duckdream_neonbreach_MainActivity_nativeCastPulse(JNIEnv *, jobject) {
    std::scoped_lock lock(gMutex);
    if (!gInitialized) resetSimulation();
    if (gPlayerHealth <= 0.0f || gPlayerRespawnTime > 0.0f ||
        gPulseCooldown > 0.0f || gPlayerDisrupted > 0.0f) return JNI_FALSE;

    const float radius = gSelectedHero == 1 ? 7.0f : (gSelectedHero == 2 ? 5.2f : 6.2f);
    int affected = 0;

    // Lyra's pulse is a field medic skill: it restores nearby allies and still
    // gives a small defensive response against enemies caught inside the field.
    if (gSelectedHero == 0) {
        if (gPlayerHealth < 100.0f) {
            const float before = gPlayerHealth;
            gPlayerHealth = std::min(100.0f, gPlayerHealth + 24.0f);
            if (gPlayerHealth > before) ++affected;
        }
        for (int i = 0; i < kBotCount; ++i) {
            Bot &bot = gBots[static_cast<std::size_t>(i)];
            if (bot.team != 0 || bot.disabled > 0.0f ||
                distance(bot.position, {gPlayerX, gPlayerZ}) > radius) continue;
            const float before = bot.health;
            bot.health = std::min(100.0f, bot.health + 28.0f);
            if (bot.health > before) ++affected;
        }
        for (LaneUnit &unit : gLaneUnits) {
            if (unit.team != 0 || unit.health <= 0.0f ||
                distance(unit.position, {gPlayerX, gPlayerZ}) > radius) continue;
            const float before = unit.health;
            unit.health = std::min(120.0f, unit.health + 36.0f);
            if (unit.health > before) ++affected;
        }
        for (int i = 0; i < kBotCount; ++i) {
            Bot &bot = gBots[static_cast<std::size_t>(i)];
            if (bot.team != 1 || bot.disabled > 0.0f ||
                distance(bot.position, {gPlayerX, gPlayerZ}) > radius) continue;
            bot.health = std::max(0.0f, bot.health - 20.0f);
            bot.attackCooldown = std::max(bot.attackCooldown, 1.15f);
            if (bot.health <= 0.0f) disableBot(bot, i, 0);
            ++affected;
        }
        for (LaneUnit &unit : gLaneUnits) {
            if (unit.team != 1 || unit.health <= 0.0f ||
                distance(unit.position, {gPlayerX, gPlayerZ}) > radius) continue;
            unit.health = std::max(0.0f, unit.health - 24.0f);
            ++affected;
        }
    } else {
        const float botDamage = gSelectedHero == 1 ? 52.0f : 34.0f;
        const float unitDamage = gSelectedHero == 1 ? 62.0f : 42.0f;
        for (int i = 0; i < kBotCount; ++i) {
            Bot &bot = gBots[static_cast<std::size_t>(i)];
            if (bot.team != 1 || bot.disabled > 0.0f ||
                distance(bot.position, {gPlayerX, gPlayerZ}) > radius) continue;
            bot.health = std::max(0.0f, bot.health - botDamage);
            bot.attackCooldown = std::max(bot.attackCooldown, 1.25f);
            if (bot.health <= 0.0f) disableBot(bot, i, 0);
            ++affected;
        }
        for (LaneUnit &unit : gLaneUnits) {
            if (unit.team != 1 || unit.health <= 0.0f ||
                distance(unit.position, {gPlayerX, gPlayerZ}) > radius) continue;
            unit.health = std::max(0.0f, unit.health - unitDamage);
            unit.attackCooldown = std::max(unit.attackCooldown, 1.1f);
            ++affected;
        }
    }

    if (affected == 0) return JNI_FALSE;
    gPulseVisualTime = 0.82f;
    gPulseCooldown = gSelectedHero == 0 ? 11.0f : (gSelectedHero == 1 ? 10.0f : 6.8f);
    return JNI_TRUE;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_duckdream_neonbreach_MainActivity_nativeActivateShield(JNIEnv *, jobject) {
    std::scoped_lock lock(gMutex);
    if (!gInitialized) resetSimulation();
    if (gPlayerHealth <= 0.0f || gPlayerRespawnTime > 0.0f ||
        gShieldCooldown > 0.0f || gPlayerDisrupted > 0.0f) return JNI_FALSE;
    gShieldTime = gSelectedHero == 1 ? 4.2f : 3.0f;
    gShieldCooldown = gSelectedHero == 1 ? 9.0f : 12.0f;
    return JNI_TRUE;
}

extern "C" JNIEXPORT jfloatArray JNICALL
Java_com_duckdream_neonbreach_MainActivity_nativeStep(
        JNIEnv *env, jobject, jfloat inputX, jfloat inputZ, jfloat deltaTime) {
    std::scoped_lock lock(gMutex);
    simulate(inputX, inputZ, deltaTime);

    std::array<jfloat, 96> values{};
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
    for (int i = 0; i < kLaneUnitCount; ++i) {
        const LaneUnit &unit = gLaneUnits[static_cast<std::size_t>(i)];
        values[static_cast<std::size_t>(36 + i * 2)] = unit.position.x;
        values[static_cast<std::size_t>(37 + i * 2)] = unit.position.z;
    }
    values[60] = gShieldCooldown;
    values[61] = gPulseVisualTime;
    values[62] = gBoostTime;
    values[72] = gPlayerHealth;
    values[94] = static_cast<float>(gPlayerDeaths);
    values[95] = gPlayerRespawnTime;
    for (int lane = 0; lane < 3; ++lane) {
        values[static_cast<std::size_t>(73 + lane)] = gBlueTowers[static_cast<std::size_t>(lane)];
        values[static_cast<std::size_t>(76 + lane)] = gRedTowers[static_cast<std::size_t>(lane)];
    }
    values[79] = gBlueCoreHealth;
    values[80] = gRedCoreHealth;
    values[81] = gPlayerAttackCooldown;
    for (int i = 0; i < kBotCount; ++i) {
        values[static_cast<std::size_t>(63 + i)] = gBots[static_cast<std::size_t>(i)].disabled;
    }
    for (int i = 0; i < kLaneUnitCount; ++i) {
        values[static_cast<std::size_t>(82 + i)] = gLaneUnits[static_cast<std::size_t>(i)].health;
    }

    jfloatArray result = env->NewFloatArray(static_cast<jsize>(values.size()));
    if (result != nullptr) {
        env->SetFloatArrayRegion(result, 0, static_cast<jsize>(values.size()), values.data());
    }
    return result;
}
