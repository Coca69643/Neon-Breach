#include <jni.h>
#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>
#include <mutex>
#include "ArenaPhysics.h"
#include "ArenaMapDefinition.h"
#include "ArenaNavigation.h"
#include "ArenaCampCombat.h"

namespace {
struct Vec2 { float x; float z; };
struct Bot {
    Vec2 position{};
    Vec2 velocity{};
    int team = 0;
    int lane = 1;
    int role = 2; // 0 solo, 1 jungle, 2 mid, 3 carry, 4 support
    float disabled = 0.0f;
    float startDelay = 0.0f;
    float health = 100.0f;
    float attackCooldown = 0.0f;
    float thinkCooldown = 0.0f;
};
struct LaneUnit {
    Vec2 position{};
    Vec2 velocity{};
    int team = 0;
    int lane = 0;
    int slot = 0; // 0-2 melee, 3 ranged
    int waveGroup = 0;
    float health = 0.0f;
    float attackCooldown = 0.0f;
    float respawnTime = 0.0f;
    float startDelay = 0.0f;
};
struct NeutralCamp {
    Vec2 position{};
    float health = 180.0f;
    float respawnTime = 0.0f;
    float attackCooldown = 0.0f;
    float attackPulse = 0.0f;
    float aggroTime = 0.0f;
    int kind = 0;
};
constexpr int kBotCount = 9;
constexpr int kLaneUnitCount = 48;
constexpr int kCampCount = static_cast<int>(arena_world_17::kCamps.size());
constexpr int kTowerCount = 18;
constexpr int kSnapshotCount = 332;
constexpr float kTowerMaxHealth = 820.0f;
constexpr float kCoreMaxHealth = 2200.0f;
constexpr float kWalkSpeed = 5.6f;
constexpr float kBoostSpeed = 9.2f;
constexpr float kBotSpeed = 3.15f;
constexpr float kLaneWaveInterval = 26.0f;
constexpr float kMeleeMinionHealth = 145.0f;
constexpr float kRangedMinionHealth = 92.0f;
constexpr float kPlayerRespawnDuration = 4.0f;

std::mutex gMutex;
std::array<Bot, kBotCount> gBots{};
std::array<LaneUnit, kLaneUnitCount> gLaneUnits{};
std::array<NeutralCamp, kCampCount> gCamps{};
std::array<float, kTowerCount> gTowerHealth{};
std::array<float, kTowerCount> gTowerCooldown{};
std::array<std::array<float, 3>, 2> gWaveCooldown{};
std::array<std::array<int, 3>, 2> gNextWaveGroup{};
std::array<float, 2> gCoreHealth{{kCoreMaxHealth, kCoreMaxHealth}};
std::array<float, 2> gTeamKills{{0.0f, 0.0f}};
std::array<float, 2> gTeamGold{{500.0f, 500.0f}};
std::array<float, 2> gTeamXp{{0.0f, 0.0f}};
std::array<float, 2> gTeamSiegeBuff{};
Vec2 gPlayerPosition{0.0f, -68.0f};
Vec2 gPlayerVelocity{};
Vec2 gLastMove{0.0f, 1.0f};
Vec2 gDashDirection{0.0f, 1.0f};
float gElapsed = 0.0f;
float gBoostTime = 0.0f;
float gBoostCooldown = 0.0f;
float gPulseCooldown = 0.0f;
float gShieldCooldown = 0.0f;
float gShieldTime = 0.0f;
float gPulseVisualTime = 0.0f;
float gPlayerDisrupted = 0.0f;
float gPlayerHealth = 100.0f;
float gPlayerMaxHealth = 100.0f;
float gPlayerRespawnTime = 0.0f;
float gPlayerAttackCooldown = 0.0f;
float gPlayerXp = 0.0f;
float gPlayerGold = 500.0f;
float gPlayerPower = 1.0f;
float gPlayerArmor = 0.0f;
float gPlayerHaste = 0.0f;
float gPlayerDeathCount = 0.0f;
float gObjectiveOneHealth = 0.0f;
float gObjectiveTwoHealth = 0.0f;
float gObjectiveOneSpawnAt = 78.0f;
float gObjectiveTwoSpawnAt = 210.0f;
float gObjectiveOneRespawnAt = 0.0f;
float gObjectiveTwoRespawnAt = 0.0f;
float gObjectiveOneVisualTime = 0.0f;
float gObjectiveTwoVisualTime = 0.0f;
int gPlayerLevel = 1;
int gPlayerSkillLevel = 1;
int gPlayerSelectedHero = 0;
std::array<int, 3> gItemCounts{{0, 0, 0}};
int gWinner = 0;
bool gInitialized = false;
float gSimulationAccumulator = 0.0f;

float length(Vec2 v) { return std::sqrt(v.x * v.x + v.z * v.z); }
float distance(Vec2 a, Vec2 b) { return length({a.x - b.x, a.z - b.z}); }
Vec2 add(Vec2 a, Vec2 b) { return {a.x + b.x, a.z + b.z}; }
Vec2 sub(Vec2 a, Vec2 b) { return {a.x - b.x, a.z - b.z}; }
Vec2 mul(Vec2 a, float s) { return {a.x * s, a.z * s}; }
Vec2 normalized(Vec2 v) {
    const float d = std::max(length(v), 0.001f);
    return {v.x / d, v.z / d};
}
float terrainHeight(float x, float z) { return arena_physics::terrainHeight(x, z); }
float laneCenterX(int lane, float worldZ) {
    return arena_map::laneCenterX(lane, worldZ / arena_map::kWorldScale) * arena_map::kWorldScale;
}
Vec2 lanePoint(int lane, float worldZ, float offset = 0.0f) {
    return {laneCenterX(lane, worldZ) + offset * arena_map::kWorldScale, worldZ};
}
int laneForPosition(Vec2 p) {
    int best = 0;
    float bestDistance = 1.0e9f;
    for (int lane = 0; lane < 3; ++lane) {
        const float d = std::abs(p.x - laneCenterX(lane, p.z));
        if (d < bestDistance) { bestDistance = d; best = lane; }
    }
    return best;
}
int towerIndex(int team, int lane, int tier) {
    return team * 9 + lane * 3 + tier;
}
int activeTowerTier(int defendingTeam, int lane) {
    for (int tier = 0; tier < 3; ++tier) {
        if (gTowerHealth[static_cast<std::size_t>(towerIndex(defendingTeam, lane, tier))] > 0.0f) return tier;
    }
    return -1;
}
bool laneOpen(int defendingTeam, int lane) {
    return activeTowerTier(defendingTeam, lane) < 0;
}
bool anyLaneOpen(int defendingTeam) {
    for (int lane = 0; lane < 3; ++lane) if (laneOpen(defendingTeam, lane)) return true;
    return false;
}
Vec2 towerPosition(int team, int lane, int tier) {
    const arena_map::Point point = arena_map::towerPosition(team, lane, tier);
    return {point.x * arena_map::kWorldScale, point.z * arena_map::kWorldScale};
}
Vec2 corePosition(int team) { const auto &base = arena_world_17::kBases[static_cast<std::size_t>(team)]; return {base.position.x, base.position.z}; }
Vec2 campPosition(int index) {
    const arena_map::Point point = arena_map::kCampPositions[static_cast<std::size_t>(index)];
    return {point.x * arena_map::kWorldScale, point.z * arena_map::kWorldScale};
}
Vec2 campEntryPosition(int index, float side) {
    Vec2 position = campPosition(index);
    // Spawn outside the guardian's body collider and the camp's inner ring.
    position.x += side * 3.6f * arena_map::kWorldScale;
    return position;
}
Vec2 objectivePosition(int objective) {
    const arena_map::Point point = arena_map::kObjectivePositions[static_cast<std::size_t>(objective)];
    return {point.x * arena_map::kWorldScale, point.z * arena_map::kWorldScale};
}
int playerRole() {
    if (gPlayerSelectedHero == 1) return 0; // Bastion: solo lane
    if (gPlayerSelectedHero == 2) return 1; // Kairo: jungle
    return 4; // Lyra: support
}
void addPlayerXp(float amount) {
    if (amount <= 0.0f || gPlayerLevel >= 15) return;
    gPlayerXp += amount;
    while (gPlayerLevel < 15) {
        const float threshold = 220.0f + static_cast<float>(gPlayerLevel - 1) * 85.0f;
        if (gPlayerXp < threshold) break;
        gPlayerXp -= threshold;
        ++gPlayerLevel;
        gPlayerMaxHealth += 14.0f;
        gPlayerHealth = std::min(gPlayerMaxHealth, gPlayerHealth + 14.0f);
        gPlayerPower += 0.035f;
    }
}
void awardTeam(int team, float gold, float xp) {
    gTeamGold[static_cast<std::size_t>(team)] += gold;
    gTeamXp[static_cast<std::size_t>(team)] += xp;
    if (team == 0) {
        gPlayerGold += gold;
        addPlayerXp(xp);
    }
}
void resetBot(Bot &bot, int index) {
    const float homeZ = (bot.team == 0 ? -66.0f : 66.0f) * arena_map::kWorldScale;
    if (bot.role == 1) {
        bot.position = campEntryPosition(bot.team == 0 ? 0 : 4, bot.team == 0 ? -1.0f : 1.0f);
    } else {
        const int lane = bot.lane;
        const float z = homeZ + (bot.team == 0 ? 2.0f : -2.0f) * arena_map::kWorldScale;
        const float lateral = bot.role == 4 ? 1.5f : -0.8f;
        bot.position = lanePoint(lane, z, lateral);
    }
    bot.velocity = {0.0f, 0.0f};
    bot.disabled = 0.0f;
    bot.health = 100.0f;
    bot.attackCooldown = 0.45f + static_cast<float>(index % 4) * 0.08f;
    bot.startDelay = 0.10f * static_cast<float>(index % 5);
    bot.thinkCooldown = 0.0f;
}
void spawnLaneUnit(LaneUnit &unit, int team, int lane, int slot, int waveGroup) {
    unit.team = team;
    unit.lane = lane;
    unit.slot = slot;
    unit.waveGroup = waveGroup;
    const float z = (team == 0 ? -68.0f - waveGroup * 1.35f : 68.0f + waveGroup * 1.35f) * arena_map::kWorldScale;
    const float side = slot == 0 ? -0.86f : (slot == 1 ? 0.0f : (slot == 2 ? 0.86f : 1.45f));
    unit.position = lanePoint(lane, z, side);
    unit.velocity = {0.0f, 0.0f};
    unit.health = slot == 3 ? kRangedMinionHealth : kMeleeMinionHealth;
    unit.attackCooldown = 0.5f + static_cast<float>(slot) * 0.08f;
    unit.respawnTime = 0.0f;
    unit.startDelay = 0.12f * static_cast<float>(slot);
}
void initializeCamps() {
    for (int i = 0; i < kCampCount; ++i) {
        NeutralCamp &camp = gCamps[static_cast<std::size_t>(i)];
        camp.position = campPosition(i);
        camp.health = 180.0f + (i % 2) * 45.0f;
        camp.respawnTime = 0.0f;
        camp.attackCooldown = 0.0f;
        camp.attackPulse = 0.0f;
        camp.aggroTime = 0.0f;
        camp.kind = arena_world_17::kCamps[static_cast<std::size_t>(i)].tier <= 1 ? 0 : 1;
    }
}
void initializeLaneUnits() {
    for (int team = 0; team < 2; ++team) {
        for (int lane = 0; lane < 3; ++lane) {
            for (int group = 0; group < 2; ++group) {
                for (int slot = 0; slot < 4; ++slot) {
                    const int index = team * 24 + lane * 8 + group * 4 + slot;
                    LaneUnit &unit = gLaneUnits[static_cast<std::size_t>(index)];
                    if (group == 0) {
                        spawnLaneUnit(unit, team, lane, slot, group);
                    } else {
                        unit.team = team;
                        unit.lane = lane;
                        unit.slot = slot;
                        unit.waveGroup = group;
                        unit.health = 0.0f;
                        unit.respawnTime = 0.0f;
                    }
                }
            }
            gWaveCooldown[static_cast<std::size_t>(team)][static_cast<std::size_t>(lane)] = kLaneWaveInterval;
            gNextWaveGroup[static_cast<std::size_t>(team)][static_cast<std::size_t>(lane)] = 1;
        }
    }
}
void initializeBots() {
    // The player occupies one role; four allies fill the remaining roles.
    constexpr std::array<int, 5> lanes{{0, 1, 1, 2, 2}};
    const int occupiedRole = playerRole();
    int blueIndex = 0;
    for (int role = 0; role < 5; ++role) {
        if (role == occupiedRole) continue;
        Bot &bot = gBots[static_cast<std::size_t>(blueIndex)];
        bot.team = 0;
        bot.role = role;
        bot.lane = lanes[static_cast<std::size_t>(role)];
        resetBot(bot, blueIndex);
        ++blueIndex;
    }
    for (int role = 0; role < 5; ++role) {
        const int index = 4 + role;
        Bot &bot = gBots[static_cast<std::size_t>(index)];
        bot.team = 1;
        bot.role = role;
        bot.lane = lanes[static_cast<std::size_t>(role)];
        resetBot(bot, index);
    }
}
void resetSimulation() {
    gElapsed = 0.0f;
    gSimulationAccumulator = 0.0f;
    gPlayerSelectedHero = std::clamp(gPlayerSelectedHero, 0, 2);
    gPlayerPosition = playerRole() == 0 ? lanePoint(0, -67.0f) :
                      (playerRole() == 1 ? campEntryPosition(0, -1.0f) : lanePoint(2, -67.0f, 1.8f));
    gPlayerVelocity = {0.0f, 0.0f};
    gLastMove = {0.0f, 1.0f};
    gDashDirection = {0.0f, 1.0f};
    gBoostTime = gBoostCooldown = gPulseCooldown = 0.0f;
    gShieldCooldown = gShieldTime = gPulseVisualTime = 0.0f;
    gPlayerDisrupted = 0.0f;
    gPlayerMaxHealth = 100.0f;
    gPlayerHealth = 100.0f;
    gPlayerRespawnTime = 0.0f;
    gPlayerAttackCooldown = 0.0f;
    gPlayerXp = 0.0f;
    gPlayerGold = 500.0f;
    gPlayerPower = 1.0f;
    gPlayerArmor = 0.0f;
    gPlayerHaste = 0.0f;
    gPlayerDeathCount = 0.0f;
    gPlayerLevel = 1;
    gPlayerSkillLevel = 1;
    gItemCounts = {{0, 0, 0}};
    gTeamKills = {{0.0f, 0.0f}};
    gTeamGold = {{500.0f, 500.0f}};
    gTeamXp = {{0.0f, 0.0f}};
    gTeamSiegeBuff = {{0.0f, 0.0f}};
    gTowerHealth.fill(kTowerMaxHealth);
    gTowerCooldown.fill(0.0f);
    gCoreHealth = {{kCoreMaxHealth, kCoreMaxHealth}};
    gObjectiveOneHealth = 0.0f;
    gObjectiveTwoHealth = 0.0f;
    gObjectiveOneSpawnAt = 78.0f;
    gObjectiveTwoSpawnAt = 210.0f;
    gObjectiveOneRespawnAt = 0.0f;
    gObjectiveTwoRespawnAt = 0.0f;
    gObjectiveOneVisualTime = gObjectiveTwoVisualTime = 0.0f;
    initializeCamps();
    initializeLaneUnits();
    initializeBots();
    gWinner = 0;
    gInitialized = true;
}
void movePlayer(float inputX, float inputZ, float dt) {
    Vec2 input{inputX, inputZ};
    const bool dashing = gBoostTime > 0.0f;
    if (dashing) input = gDashDirection;
    const float inputLength = length(input);
    if (inputLength > 1.0f) input = mul(input, 1.0f / inputLength);
    if (!dashing && inputLength > 0.08f) gLastMove = normalized(input);
    const float heroMoveBonus = gPlayerSelectedHero == 2 ? 0.55f : 0.0f;
    const float speed = dashing ? kBoostSpeed * (gPlayerSelectedHero == 2 ? 1.18f : 1.0f)
                                : kWalkSpeed + heroMoveBonus;
    const Vec2 desired = mul(input, speed);
    arena_physics::Body body{gPlayerPosition.x, gPlayerPosition.z,
        gPlayerVelocity.x, gPlayerVelocity.z, 0.43f};
    arena_physics::move(body, desired.x, desired.z, dt,
        dashing ? 72.0f : 24.0f, dashing ? 38.0f : 31.0f, 43.0f);
    gPlayerPosition = {body.x, body.z};
    gPlayerVelocity = {body.vx, body.vz};
}
void moveActor(Vec2 &position, Vec2 &velocity, Vec2 target, float speed,
               float dt, float radius = 0.38f) {
    const Vec2 delta = sub(target, position);
    const float d = length(delta);
    const float desiredSpeed = d < 0.16f ? 0.0f :
        std::min(speed, std::sqrt(2.0f * 7.5f * d));
    Vec2 desired = d < 0.16f ? Vec2{0.0f, 0.0f} :
        mul(normalized(delta), desiredSpeed);
    arena_physics::Body body{position.x, position.z, velocity.x, velocity.z, radius};
    arena_physics::avoidObstacles(body, desired.x, desired.z);
    arena_physics::move(body, desired.x, desired.z, dt, 18.0f, 25.0f, 41.0f);
    position = {body.x, body.z};
    velocity = {body.vx, body.vz};
}

void moveActorOnMap(Vec2 &position, Vec2 &velocity, Vec2 target, float speed, float dt,
                    float radius = 0.38f) {
    const arena_navigation::Vec2 waypoint = arena_navigation::nextWaypoint(
        {position.x, position.z}, {target.x, target.z});
    moveActor(position, velocity, {waypoint.x, waypoint.z}, speed, dt, radius);
}
int nearestEnemyBot(Vec2 position, int team, float range) {
    int target = -1;
    float nearest = range;
    for (int i = 0; i < kBotCount; ++i) {
        const Bot &bot = gBots[static_cast<std::size_t>(i)];
        if (bot.team == team || bot.disabled > 0.0f) continue;
        const float d = distance(position, bot.position);
        if (d < nearest) { nearest = d; target = i; }
    }
    return target;
}
int nearestEnemyMinion(Vec2 position, int team, int lane, float range) {
    int target = -1;
    float nearest = range;
    for (int i = 0; i < kLaneUnitCount; ++i) {
        const LaneUnit &unit = gLaneUnits[static_cast<std::size_t>(i)];
        if (unit.team == team || unit.lane != lane || unit.health <= 0.0f) continue;
        const float d = distance(position, unit.position);
        if (d < nearest) { nearest = d; target = i; }
    }
    return target;
}
int nearestCamp(Vec2 position, int team, float range) {
    int target = -1;
    float nearest = range;
    for (int i = 0; i < kCampCount; ++i) {
        const NeutralCamp &camp = gCamps[static_cast<std::size_t>(i)];
        const bool onHomeHalf = (camp.position.z < 0.0f) == (team == 0);
        if (camp.health <= 0.0f || !onHomeHalf) continue;
        const float d = distance(position, camp.position);
        if (d < nearest) { nearest = d; target = i; }
    }
    return target;
}
float playerDamageTaken(float damage);

bool friendlyMinionSupports(int team, int lane, Vec2 position, float range) {
    for (const LaneUnit &unit : gLaneUnits) {
        if (unit.team == team && unit.health > 0.0f && unit.lane == lane &&
            distance(unit.position, position) <= range) return true;
    }
    return false;
}
void awardBotElimination(int team, int index) {
    Bot &bot = gBots[static_cast<std::size_t>(index)];
    if (bot.disabled > 0.0f) return;
    bot.health = 0.0f;
    bot.disabled = 5.0f;
    bot.velocity = {0.0f, 0.0f};
    gTeamKills[static_cast<std::size_t>(team)] += 1.0f;
    awardTeam(team, 170.0f, 115.0f);
}
void damageBot(Bot &bot, int index, int sourceTeam, float damage) {
    if (bot.disabled > 0.0f) return;
    bot.health = std::max(0.0f, bot.health - damage);
    if (bot.health <= 0.0f) awardBotElimination(sourceTeam, index);
}
void damageLaneUnit(LaneUnit &unit, int sourceTeam, float damage) {
    if (unit.health <= 0.0f) return;
    unit.health = std::max(0.0f, unit.health - damage);
    if (unit.health <= 0.0f) {
        unit.respawnTime = 0.0f;
        // Team rewards also credit the single offline player; avoid double rewards.
        awardTeam(sourceTeam, unit.slot == 3 ? 58.0f : 42.0f,
                  unit.slot == 3 ? 34.0f : 26.0f);
    }
}
void damageCamp(int campIndex, int sourceTeam, float damage) {
    NeutralCamp &camp = gCamps[static_cast<std::size_t>(campIndex)];
    if (camp.health <= 0.0f) return;
    camp.health = std::max(0.0f, camp.health - damage);
    if (camp.health <= 0.0f) {
        camp.respawnTime = camp.kind == 0 ? 54.0f : 72.0f;
        camp.attackPulse = 0.0f;
        camp.aggroTime = 0.0f;
        awardTeam(sourceTeam, camp.kind == 0 ? 90.0f : 130.0f,
                  camp.kind == 0 ? 70.0f : 95.0f);
    }
}
void damageObjective(int objective, int sourceTeam, float damage) {
    if (objective == 0) {
        if (gObjectiveOneHealth <= 0.0f) return;
        gObjectiveOneHealth = std::max(0.0f, gObjectiveOneHealth - damage);
        if (gObjectiveOneHealth <= 0.0f) {
            awardTeam(sourceTeam, 360.0f, 145.0f);
            gObjectiveOneRespawnAt = gElapsed + 150.0f;
            gTeamSiegeBuff[static_cast<std::size_t>(sourceTeam)] = 85.0f;
            gObjectiveOneVisualTime = 1.1f;
        }
    } else {
        if (gObjectiveTwoHealth <= 0.0f) return;
        gObjectiveTwoHealth = std::max(0.0f, gObjectiveTwoHealth - damage);
        if (gObjectiveTwoHealth <= 0.0f) {
            awardTeam(sourceTeam, 620.0f, 210.0f);
            gObjectiveTwoRespawnAt = gElapsed + 210.0f;
            gTeamSiegeBuff[static_cast<std::size_t>(sourceTeam)] = 115.0f;
            gObjectiveTwoVisualTime = 1.1f;
        }
    }
}
void updateObjectives(float dt) {
    if (gObjectiveOneHealth <= 0.0f && gElapsed >= gObjectiveOneSpawnAt) {
        if (gObjectiveOneRespawnAt <= 0.0f || gElapsed >= gObjectiveOneRespawnAt) {
            gObjectiveOneHealth = 520.0f;
            gObjectiveOneRespawnAt = 0.0f;
            gObjectiveOneSpawnAt = gElapsed + 150.0f;
        }
    }
    if (gObjectiveTwoHealth <= 0.0f && gElapsed >= gObjectiveTwoSpawnAt) {
        if (gObjectiveTwoRespawnAt <= 0.0f || gElapsed >= gObjectiveTwoRespawnAt) {
            gObjectiveTwoHealth = 880.0f;
            gObjectiveTwoRespawnAt = 0.0f;
            gObjectiveTwoSpawnAt = gElapsed + 210.0f;
        }
    }
    gObjectiveOneVisualTime = std::max(0.0f, gObjectiveOneVisualTime - dt);
    gObjectiveTwoVisualTime = std::max(0.0f, gObjectiveTwoVisualTime - dt);
    for (float &buff : gTeamSiegeBuff) buff = std::max(0.0f, buff - dt);
}
void updateCamps(float dt) {
    const float scale = arena_map::kWorldScale;
    for (NeutralCamp &camp : gCamps) {
        camp.attackPulse = std::max(0.0f, camp.attackPulse - dt);
        camp.aggroTime = std::max(0.0f, camp.aggroTime - dt);
        if (camp.health <= 0.0f) {
            camp.respawnTime = std::max(0.0f, camp.respawnTime - dt);
            if (camp.respawnTime <= 0.0f) {
                camp.health = camp.kind == 0 ? 180.0f : 225.0f;
                camp.attackCooldown = 0.0f;
                camp.attackPulse = 0.0f;
                camp.aggroTime = 0.0f;
            }
            continue;
        }

        camp.attackCooldown = std::max(0.0f, camp.attackCooldown - dt);
        const float aggroRadius = 12.0f * scale;
        const float leashRadius = 10.0f * scale;
        const float attackRange = (camp.kind == 0 ? 2.45f : 2.85f) * scale;
        float nearestDistance = aggroRadius;
        bool targetPlayer = false;
        int targetBot = -1;

        if (gPlayerHealth > 0.0f && gPlayerRespawnTime <= 0.0f) {
            const float d = distance(camp.position, gPlayerPosition);
            if (d < nearestDistance && arena_camp::canAggro(
                    camp.health, d, aggroRadius, leashRadius)) {
                nearestDistance = d;
                targetPlayer = true;
                targetBot = -1;
            }
        }

        for (int index = 0; index < kBotCount; ++index) {
            const Bot &bot = gBots[static_cast<std::size_t>(index)];
            if (bot.health <= 0.0f || bot.disabled > 0.0f) continue;
            const float d = distance(camp.position, bot.position);
            if (d < nearestDistance && arena_camp::canAggro(
                    camp.health, d, aggroRadius, leashRadius)) {
                nearestDistance = d;
                targetPlayer = false;
                targetBot = index;
            }
        }

        if (nearestDistance < aggroRadius) {
            camp.aggroTime = 0.8f;
            if (arena_camp::canStrike(camp.health, camp.attackCooldown,
                    nearestDistance, attackRange, leashRadius)) {
                const float damage = camp.kind == 0 ? 8.0f : 11.5f;
                if (targetPlayer) {
                    gPlayerHealth = std::max(0.0f, gPlayerHealth - playerDamageTaken(damage));
                } else if (targetBot >= 0) {
                    Bot &target = gBots[static_cast<std::size_t>(targetBot)];
                    target.health = std::max(0.0f, target.health - damage);
                    if (target.health <= 0.0f) {
                        target.disabled = 5.0f;
                        target.velocity = {0.0f, 0.0f};
                    }
                }
                camp.attackCooldown = camp.kind == 0 ? 1.35f : 1.55f;
                camp.attackPulse = 0.52f;
            }
        }
    }
}
void updatePlayerTimers(float dt) {
    gBoostTime = std::max(0.0f, gBoostTime - dt);
    gBoostCooldown = std::max(0.0f, gBoostCooldown - dt);
    gPulseCooldown = std::max(0.0f, gPulseCooldown - dt);
    gShieldCooldown = std::max(0.0f, gShieldCooldown - dt);
    gShieldTime = std::max(0.0f, gShieldTime - dt);
    gPulseVisualTime = std::max(0.0f, gPulseVisualTime - dt);
    gPlayerDisrupted = std::max(0.0f, gPlayerDisrupted - dt);
    gPlayerAttackCooldown = std::max(0.0f, gPlayerAttackCooldown - dt);
    if (gPlayerHealth <= 0.0f && gPlayerRespawnTime <= 0.0f) {
        gPlayerRespawnTime = kPlayerRespawnDuration;
        gPlayerDeathCount += 1.0f;
        gPlayerVelocity = {0.0f, 0.0f};
    }
    const bool wasRespawning = gPlayerRespawnTime > 0.0f;
    if (wasRespawning) {
        gPlayerRespawnTime = std::max(0.0f, gPlayerRespawnTime - dt);
        gPlayerVelocity = {0.0f, 0.0f};
        if (gPlayerRespawnTime <= 0.0f) {
            gPlayerHealth = gPlayerMaxHealth;
            gPlayerPosition = playerRole() == 0 ? lanePoint(0, -67.0f) :
                              (playerRole() == 1 ? campEntryPosition(0, -1.0f) : lanePoint(2, -67.0f, 1.8f));
            gPlayerDisrupted = 0.9f;
        }
    }
    if (!wasRespawning && gPlayerDisrupted <= 0.0f) {
        // Home fountain restores health while the hero is inside the protected base.
        if (gPlayerPosition.z < -25.0f * arena_map::kWorldScale &&
            gPlayerPosition.x > -6.0f * arena_map::kWorldScale && gPlayerPosition.x < 6.0f * arena_map::kWorldScale) {
            gPlayerHealth = std::min(gPlayerMaxHealth, gPlayerHealth + 18.0f * dt);
        }
    }
}
void updateLaneUnits(float dt) {
    for (LaneUnit &unit : gLaneUnits) {
        if (unit.health <= 0.0f) continue;
        unit.attackCooldown = std::max(0.0f, unit.attackCooldown - dt);
        if (unit.startDelay > 0.0f) {
            unit.startDelay = std::max(0.0f, unit.startDelay - dt);
            continue;
        }
        const float attackRange = unit.slot == 3 ? 5.2f : 1.75f;
        const int enemyMinion = nearestEnemyMinion(unit.position, unit.team, unit.lane, unit.slot == 3 ? 5.5f : 3.0f);
        if (enemyMinion >= 0) {
            LaneUnit &target = gLaneUnits[static_cast<std::size_t>(enemyMinion)];
            const float d = distance(unit.position, target.position);
            if (d > attackRange) {
                moveActor(unit.position, unit.velocity, target.position, unit.slot == 3 ? 2.3f : 2.55f, dt, 0.25f);
            } else if (unit.attackCooldown <= 0.0f) {
                damageLaneUnit(target, unit.team, unit.slot == 3 ? 14.0f : 25.0f);
                unit.attackCooldown = unit.slot == 3 ? 1.05f : 0.88f;
            }
            continue;
        }
        const int enemyBot = nearestEnemyBot(unit.position, unit.team, 3.8f);
        if (enemyBot >= 0) {
            Bot &target = gBots[static_cast<std::size_t>(enemyBot)];
            const float d = distance(unit.position, target.position);
            if (d > 2.0f) moveActor(unit.position, unit.velocity, target.position, 2.35f, dt, 0.25f);
            else if (unit.attackCooldown <= 0.0f) {
                damageBot(target, enemyBot, unit.team, unit.slot == 3 ? 8.0f : 14.0f);
                unit.attackCooldown = 1.0f;
            }
            continue;
        }
        const int defendingTeam = 1 - unit.team;
        const int tier = activeTowerTier(defendingTeam, unit.lane);
        if (tier >= 0) {
            const Vec2 target = towerPosition(defendingTeam, unit.lane, tier);
            if (distance(unit.position, target) > 2.65f) {
                moveActor(unit.position, unit.velocity, target, unit.slot == 3 ? 2.25f : 2.5f, dt, 0.25f);
            } else if (unit.attackCooldown <= 0.0f) {
                const float buff = gTeamSiegeBuff[static_cast<std::size_t>(unit.team)] > 0.0f ? 1.35f : 1.0f;
                const int idx = towerIndex(defendingTeam, unit.lane, tier);
                gTowerHealth[static_cast<std::size_t>(idx)] =
                    std::max(0.0f, gTowerHealth[static_cast<std::size_t>(idx)] - (unit.slot == 3 ? 34.0f : 42.0f) * buff);
                unit.attackCooldown = 1.12f;
            }
        } else {
            const Vec2 target = corePosition(defendingTeam);
            if (distance(unit.position, target) > 3.5f) {
                moveActor(unit.position, unit.velocity, target, 2.4f, dt, 0.25f);
            } else if (unit.attackCooldown <= 0.0f) {
                gCoreHealth[static_cast<std::size_t>(defendingTeam)] =
                    std::max(0.0f, gCoreHealth[static_cast<std::size_t>(defendingTeam)] - 26.0f);
                unit.attackCooldown = 1.0f;
            }
        }
    }
    for (int team = 0; team < 2; ++team) {
        for (int lane = 0; lane < 3; ++lane) {
            float &wave = gWaveCooldown[static_cast<std::size_t>(team)][static_cast<std::size_t>(lane)];
            wave -= dt;
            if (wave > 0.0f) continue;
            int group = gNextWaveGroup[static_cast<std::size_t>(team)][static_cast<std::size_t>(lane)];
            auto groupIsFree = [&](int candidate) {
                for (int slot = 0; slot < 4; ++slot) {
                    const int index = team * 24 + lane * 8 + candidate * 4 + slot;
                    if (gLaneUnits[static_cast<std::size_t>(index)].health > 0.0f) return false;
                }
                return true;
            };
            if (!groupIsFree(group)) group = 1 - group;
            if (!groupIsFree(group)) {
                // Keep the unit budget fixed at 48 while both active formations survive.
                wave = 6.0f;
                continue;
            }
            for (int slot = 0; slot < 4; ++slot) {
                const int index = team * 24 + lane * 8 + group * 4 + slot;
                spawnLaneUnit(gLaneUnits[static_cast<std::size_t>(index)], team, lane, slot, group);
            }
            gNextWaveGroup[static_cast<std::size_t>(team)][static_cast<std::size_t>(lane)] = 1 - group;
            wave = kLaneWaveInterval;
        }
    }
}
void updateTowers(float dt) {
    for (int defendingTeam = 0; defendingTeam < 2; ++defendingTeam) {
        for (int lane = 0; lane < 3; ++lane) {
            const int tier = activeTowerTier(defendingTeam, lane);
            if (tier < 0) continue;
            const int index = towerIndex(defendingTeam, lane, tier);
            float &cooldown = gTowerCooldown[static_cast<std::size_t>(index)];
            cooldown = std::max(0.0f, cooldown - dt);
            if (cooldown > 0.0f) continue;
            const Vec2 pos = towerPosition(defendingTeam, lane, tier);
            const int attackingTeam = 1 - defendingTeam;
            int minionTarget = -1;
            float nearest = 7.8f;
            for (int i = 0; i < kLaneUnitCount; ++i) {
                const LaneUnit &unit = gLaneUnits[static_cast<std::size_t>(i)];
                if (unit.team != attackingTeam || unit.health <= 0.0f || unit.lane != lane) continue;
                const float d = distance(pos, unit.position);
                if (d < nearest) { nearest = d; minionTarget = i; }
            }
            if (minionTarget >= 0) {
                damageLaneUnit(gLaneUnits[static_cast<std::size_t>(minionTarget)], defendingTeam, 24.0f);
                cooldown = 0.92f;
                continue;
            }
            int botTarget = -1;
            nearest = 7.8f;
            for (int i = 0; i < kBotCount; ++i) {
                const Bot &bot = gBots[static_cast<std::size_t>(i)];
                if (bot.team != attackingTeam || bot.disabled > 0.0f || bot.lane != lane) continue;
                const float d = distance(pos, bot.position);
                if (d < nearest) { nearest = d; botTarget = i; }
            }
            if (botTarget >= 0) {
                damageBot(gBots[static_cast<std::size_t>(botTarget)], botTarget, defendingTeam, 16.0f);
                cooldown = 1.0f;
                continue;
            }
            if (defendingTeam == 1 && gPlayerHealth > 0.0f && gPlayerRespawnTime <= 0.0f &&
                distance(pos, gPlayerPosition) <= 7.8f) {
                gPlayerHealth = std::max(0.0f, gPlayerHealth - playerDamageTaken(12.0f));
                cooldown = 1.0f;
            }
        }
    }
}
void updateBots(float dt) {
    for (int i = 0; i < kBotCount; ++i) {
        Bot &bot = gBots[static_cast<std::size_t>(i)];
        if (bot.disabled > 0.0f) {
            bot.disabled = std::max(0.0f, bot.disabled - dt);
            if (bot.disabled <= 0.0f) resetBot(bot, i);
            continue;
        }
        bot.attackCooldown = std::max(0.0f, bot.attackCooldown - dt);
        bot.thinkCooldown = std::max(0.0f, bot.thinkCooldown - dt);
        if (bot.startDelay > 0.0f) {
            bot.startDelay = std::max(0.0f, bot.startDelay - dt);
            continue;
        }
        const int enemyBot = nearestEnemyBot(bot.position, bot.team, 6.4f);
        const float playerDistance = bot.team == 1 && gPlayerHealth > 0.0f && gPlayerRespawnTime <= 0.0f
            ? distance(bot.position, gPlayerPosition) : 1000.0f;
        if (bot.team == 1 && playerDistance < 6.2f && playerDistance <= (enemyBot >= 0 ? distance(bot.position, gBots[static_cast<std::size_t>(enemyBot)].position) : 1000.0f)) {
            const Vec2 delta = sub(gPlayerPosition, bot.position);
            if (playerDistance > 2.2f) moveActor(bot.position, bot.velocity, add(gPlayerPosition, mul(normalized(mul(delta, -1.0f)), 1.9f)), kBotSpeed, dt);
            else if (bot.attackCooldown <= 0.0f) {
                gPlayerHealth = std::max(0.0f, gPlayerHealth - playerDamageTaken(10.0f));
                bot.attackCooldown = 1.05f;
            }
            continue;
        }
        if (enemyBot >= 0) {
            Bot &enemy = gBots[static_cast<std::size_t>(enemyBot)];
            const float d = distance(bot.position, enemy.position);
            const float preferredRange = bot.role == 3 ? 4.8f : 2.15f;
            if (d > preferredRange) {
                const float stopDistance = bot.role == 3 ? 3.9f : 1.65f;
                moveActor(bot.position, bot.velocity,
                          add(enemy.position, mul(normalized(sub(bot.position, enemy.position)), stopDistance)),
                          kBotSpeed, dt);
            } else if (bot.attackCooldown <= 0.0f) {
                const float damage = bot.role == 0 ? 18.0f : (bot.role == 1 ? 13.0f : (bot.role == 3 ? 12.0f : 15.0f));
                damageBot(enemy, enemyBot, bot.team, damage);
                bot.attackCooldown = bot.role == 0 ? 0.92f : (bot.role == 3 ? 0.82f : 1.0f);
            }
            continue;
        }
        if (bot.role == 4 && bot.thinkCooldown <= 0.0f) {
            int ally = -1;
            float lowestHealth = 72.0f;
            for (int allyIndex = 0; allyIndex < kBotCount; ++allyIndex) {
                Bot &candidate = gBots[static_cast<std::size_t>(allyIndex)];
                if (candidate.team != bot.team || candidate.disabled > 0.0f || allyIndex == i) continue;
                const float d = distance(bot.position, candidate.position);
                if (d <= 4.8f && candidate.health < lowestHealth) {
                    lowestHealth = candidate.health;
                    ally = allyIndex;
                }
            }
            if (ally >= 0) {
                Bot &target = gBots[static_cast<std::size_t>(ally)];
                target.health = std::min(100.0f, target.health + 18.0f);
                bot.thinkCooldown = 4.2f;
            }
        }
        if (bot.role == 1) {
            int camp = nearestCamp(bot.position, bot.team, 18.0f);
            if (camp >= 0) {
                NeutralCamp &target = gCamps[static_cast<std::size_t>(camp)];
                if (distance(bot.position, target.position) > 2.5f) moveActorOnMap(bot.position, bot.velocity, target.position, kBotSpeed * 1.05f, dt);
                else if (bot.attackCooldown <= 0.0f) {
                    damageCamp(camp, bot.team, 32.0f);
                    bot.attackCooldown = 0.95f;
                }
                continue;
            }
            // The jungler rotates toward a contested neutral objective before returning to camps.
            if ((gObjectiveOneHealth > 0.0f || gObjectiveTwoHealth > 0.0f) && bot.thinkCooldown <= 0.0f) {
                const int preferredObjective = bot.team == 0 ? 0 : 1;
                const int fallbackObjective = 1 - preferredObjective;
                const bool preferredAlive = preferredObjective == 0
                    ? gObjectiveOneHealth > 0.0f : gObjectiveTwoHealth > 0.0f;
                const int objectiveIndex = preferredAlive ? preferredObjective : fallbackObjective;
                const Vec2 objective = objectivePosition(objectiveIndex);
                if (distance(bot.position, objective) > 2.7f) moveActorOnMap(bot.position, bot.velocity, objective, kBotSpeed, dt);
                else if (bot.attackCooldown <= 0.0f) {
                    damageObjective(objectiveIndex, bot.team, objectiveIndex == 0 ? 22.0f : 27.0f);
                    bot.attackCooldown = 1.0f;
                }
            } else {
                bot.thinkCooldown = 1.2f;
                const int desiredLane = (laneForPosition(bot.position) + 1) % 3;
                const int tier = activeTowerTier(1 - bot.team, desiredLane);
                const Vec2 target = tier >= 0 ? lanePoint(desiredLane, (bot.team == 0 ? 2.0f : -2.0f) * arena_map::kWorldScale)
                                                : corePosition(1 - bot.team);
                moveActorOnMap(bot.position, bot.velocity, target, kBotSpeed, dt);
            }
            continue;
        }
        const int lane = bot.lane;
        // Lane roles follow their own wave front and rotate only to nearby contests.
        float frontZ = (bot.team == 0 ? -66.0f : 66.0f) * arena_map::kWorldScale;
        for (const LaneUnit &unit : gLaneUnits) {
            if (unit.team == bot.team && unit.lane == lane && unit.health > 0.0f) {
                if (bot.team == 0) frontZ = std::max(frontZ, unit.position.z);
                else frontZ = std::min(frontZ, unit.position.z);
            }
        }
        frontZ += (bot.team == 0 ? 2.5f : -2.5f) * arena_map::kWorldScale;
        const int defendingTeam = 1 - bot.team;
        const int tier = activeTowerTier(defendingTeam, lane);
        const Vec2 laneGoal = tier >= 0 ? lanePoint(lane, frontZ, bot.role == 4 ? 1.7f : -0.6f)
                                        : corePosition(defendingTeam);
        moveActorOnMap(bot.position, bot.velocity, laneGoal, kBotSpeed * (bot.role == 3 ? 1.02f : 0.92f), dt);
        if (tier >= 0 && distance(bot.position, towerPosition(defendingTeam, lane, tier)) <= 4.4f &&
            friendlyMinionSupports(bot.team, lane, towerPosition(defendingTeam, lane, tier), 7.2f) &&
            bot.attackCooldown <= 0.0f) {
            const int idx = towerIndex(defendingTeam, lane, tier);
            const float buff = gTeamSiegeBuff[static_cast<std::size_t>(bot.team)] > 0.0f ? 1.25f : 1.0f;
            gTowerHealth[static_cast<std::size_t>(idx)] = std::max(0.0f, gTowerHealth[static_cast<std::size_t>(idx)] - 24.0f * buff);
            bot.attackCooldown = 1.15f;
        } else if (tier < 0 && distance(bot.position, corePosition(defendingTeam)) <= 4.0f && bot.attackCooldown <= 0.0f) {
            gCoreHealth[static_cast<std::size_t>(defendingTeam)] = std::max(0.0f, gCoreHealth[static_cast<std::size_t>(defendingTeam)] - 22.0f);
            bot.attackCooldown = 1.2f;
        }
    }
}
void resolveActorContacts() {
    arena_physics::Body player{gPlayerPosition.x,gPlayerPosition.z,gPlayerVelocity.x,gPlayerVelocity.z,0.43f};
    std::array<arena_physics::Body,kBotCount> bots{};
    std::array<arena_physics::Body,kLaneUnitCount> units{};
    for(int i=0;i<kBotCount;++i) {
        const Bot &bot=gBots[static_cast<std::size_t>(i)];
        bots[static_cast<std::size_t>(i)]={bot.position.x,bot.position.z,bot.velocity.x,bot.velocity.z,0.38f};
    }
    for(int i=0;i<kLaneUnitCount;++i) {
        const LaneUnit &unit=gLaneUnits[static_cast<std::size_t>(i)];
        units[static_cast<std::size_t>(i)]={unit.position.x,unit.position.z,unit.velocity.x,unit.velocity.z,0.25f};
    }
    for(int pass=0;pass<2;++pass) {
        for(int i=0;i<kBotCount;++i) {
            if(gBots[static_cast<std::size_t>(i)].disabled<=0.0f)
                arena_physics::separate(player,bots[static_cast<std::size_t>(i)]);
            for(int j=i+1;j<kBotCount;++j) {
                if(gBots[static_cast<std::size_t>(i)].disabled<=0.0f &&
                   gBots[static_cast<std::size_t>(j)].disabled<=0.0f)
                    arena_physics::separate(bots[static_cast<std::size_t>(i)],bots[static_cast<std::size_t>(j)]);
            }
        }
        for(int i=0;i<kLaneUnitCount;++i) {
            if(gLaneUnits[static_cast<std::size_t>(i)].health<=0.0f)continue;
            arena_physics::separate(player,units[static_cast<std::size_t>(i)]);
            for(int j=0;j<kBotCount;++j) {
                if(gBots[static_cast<std::size_t>(j)].disabled<=0.0f)
                    arena_physics::separate(bots[static_cast<std::size_t>(j)],units[static_cast<std::size_t>(i)]);
            }
            for(int j=i+1;j<kLaneUnitCount;++j) {
                if(gLaneUnits[static_cast<std::size_t>(j)].health>0.0f)
                    arena_physics::separate(units[static_cast<std::size_t>(i)],units[static_cast<std::size_t>(j)]);
            }
        }
    }
    gPlayerPosition={player.x,player.z};
    gPlayerVelocity={player.vx,player.vz};
    for(int i=0;i<kBotCount;++i) {
        Bot &bot=gBots[static_cast<std::size_t>(i)];
        const auto &body=bots[static_cast<std::size_t>(i)];
        bot.position={body.x,body.z};bot.velocity={body.vx,body.vz};
    }
    for(int i=0;i<kLaneUnitCount;++i) {
        LaneUnit &unit=gLaneUnits[static_cast<std::size_t>(i)];
        const auto &body=units[static_cast<std::size_t>(i)];
        if(unit.health>0.0f){unit.position={body.x,body.z};unit.velocity={body.vx,body.vz};}
    }
}

float playerDamageTaken(float damage) {
    const float shieldScale = gShieldTime > 0.0f ? 0.58f : 1.0f;
    return damage * (1.0f - gPlayerArmor) * shieldScale;
}

void updatePlayerTimersAndMovement(float inputX, float inputZ, float dt) {
    updatePlayerTimers(dt);
    if (gPlayerRespawnTime <= 0.0f && gPlayerDisrupted <= 0.0f) movePlayer(inputX, inputZ, dt);
    else gPlayerVelocity = {0.0f, 0.0f};
}
void simulateTick(float inputX, float inputZ, float dt) {
    if (gWinner != 0) return;
    gElapsed += dt;
    updatePlayerTimersAndMovement(inputX, inputZ, dt);
    updateObjectives(dt);
    updateCamps(dt);
    updateLaneUnits(dt);
    updateBots(dt);
    resolveActorContacts();
    updateTowers(dt);
    if (gCoreHealth[1] <= 0.0f) gWinner = 1;
    if (gCoreHealth[0] <= 0.0f) gWinner = -1;
}
void simulate(float inputX, float inputZ, float dt) {
    if (!gInitialized) resetSimulation();
    if (gWinner != 0) return;
    constexpr float kFixedStep = 1.0f / 60.0f;
    constexpr int kMaxSubsteps = 4;
    gSimulationAccumulator = std::min(gSimulationAccumulator +
        std::clamp(dt, 0.0f, 0.05f), kFixedStep * static_cast<float>(kMaxSubsteps));
    int steps = 0;
    while (gSimulationAccumulator + 0.000001f >= kFixedStep && steps < kMaxSubsteps) {
        simulateTick(inputX, inputZ, kFixedStep);
        gSimulationAccumulator -= kFixedStep;
        ++steps;
        if (gWinner != 0) break;
    }
}

float playerBasicDamage() {
    const float base = gPlayerSelectedHero == 1 ? 48.0f : (gPlayerSelectedHero == 2 ? 34.0f : 39.0f);
    return base * gPlayerPower;
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
    gPlayerSelectedHero = std::clamp(static_cast<int>(hero), 0, 2);
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_duckdream_neonbreach_MainActivity_nativeActivateDash(JNIEnv *, jobject, jfloat inputX, jfloat inputZ) {
    std::scoped_lock lock(gMutex);
    if (!gInitialized) resetSimulation();
    if (gPlayerHealth <= 0.0f || gPlayerRespawnTime > 0.0f || gBoostCooldown > 0.0f || gPlayerDisrupted > 0.0f) return JNI_FALSE;
    Vec2 dir{inputX, inputZ};
    if (length(dir) < 0.08f) dir = gLastMove;
    gDashDirection = normalized(dir);
    gPlayerVelocity = mul(gDashDirection, kBoostSpeed);
    gBoostTime = 0.46f;
    gBoostCooldown = std::max(2.8f, (gPlayerSelectedHero == 2 ? 3.5f : 5.0f) * (1.0f - gPlayerHaste));
    return JNI_TRUE;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_duckdream_neonbreach_MainActivity_nativeBasicAttack(JNIEnv *, jobject) {
    std::scoped_lock lock(gMutex);
    if (!gInitialized) resetSimulation();
    if (gWinner != 0 || gPlayerHealth <= 0.0f || gPlayerRespawnTime > 0.0f ||
        gPlayerDisrupted > 0.0f || gPlayerAttackCooldown > 0.0f) return JNI_FALSE;
    const float damage = playerBasicDamage();
    const int enemyBot = nearestEnemyBot(gPlayerPosition, 0, 4.8f);
    if (enemyBot >= 0) {
        damageBot(gBots[static_cast<std::size_t>(enemyBot)], enemyBot, 0, damage);
        gPlayerAttackCooldown = gPlayerSelectedHero == 1 ? 0.66f : (gPlayerSelectedHero == 2 ? 0.34f : 0.48f);
        return JNI_TRUE;
    }
    int minionTarget = -1;
    float nearest = 4.4f;
    for (int i = 0; i < kLaneUnitCount; ++i) {
        LaneUnit &unit = gLaneUnits[static_cast<std::size_t>(i)];
        if (unit.team != 1 || unit.health <= 0.0f) continue;
        const float d = distance(gPlayerPosition, unit.position);
        if (d < nearest) { nearest = d; minionTarget = i; }
    }
    if (minionTarget >= 0) {
        damageLaneUnit(gLaneUnits[static_cast<std::size_t>(minionTarget)], 0, damage * 1.35f);
        gPlayerAttackCooldown = 0.42f;
        return JNI_TRUE;
    }
    for (int i = 0; i < kCampCount; ++i) {
        NeutralCamp &camp = gCamps[static_cast<std::size_t>(i)];
        if (camp.health > 0.0f && distance(gPlayerPosition, camp.position) <= 4.6f) {
            damageCamp(i, 0, damage);
            gPlayerAttackCooldown = 0.55f;
            return JNI_TRUE;
        }
    }
    if (gObjectiveTwoHealth > 0.0f && distance(gPlayerPosition, objectivePosition(1)) <= 5.0f) {
        damageObjective(1, 0, damage);
        gPlayerAttackCooldown = 0.58f;
        return JNI_TRUE;
    }
    if (gObjectiveOneHealth > 0.0f && distance(gPlayerPosition, objectivePosition(0)) <= 5.0f) {
        damageObjective(0, 0, damage);
        gPlayerAttackCooldown = 0.58f;
        return JNI_TRUE;
    }
    const int lane = laneForPosition(gPlayerPosition);
    const int tier = activeTowerTier(1, lane);
    if (tier >= 0) {
        const Vec2 pos = towerPosition(1, lane, tier);
        if (distance(gPlayerPosition, pos) <= 5.1f && friendlyMinionSupports(0, lane, pos, 7.4f)) {
            const int idx = towerIndex(1, lane, tier);
            const float buff = gTeamSiegeBuff[0] > 0.0f ? 1.35f : 1.0f;
            gTowerHealth[static_cast<std::size_t>(idx)] =
                std::max(0.0f, gTowerHealth[static_cast<std::size_t>(idx)] - 58.0f * gPlayerPower * buff);
            gPlayerAttackCooldown = 0.58f;
            return JNI_TRUE;
        }
    } else if (anyLaneOpen(1) && distance(gPlayerPosition, corePosition(1)) <= 5.8f &&
               friendlyMinionSupports(0, lane, corePosition(1), 8.0f)) {
        gCoreHealth[1] = std::max(0.0f, gCoreHealth[1] - 62.0f * gPlayerPower);
        gPlayerAttackCooldown = 0.62f;
        return JNI_TRUE;
    }
    return JNI_FALSE;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_duckdream_neonbreach_MainActivity_nativeCastPulse(JNIEnv *, jobject) {
    std::scoped_lock lock(gMutex);
    if (!gInitialized) resetSimulation();
    if (gPlayerHealth <= 0.0f || gPlayerRespawnTime > 0.0f || gPulseCooldown > 0.0f || gPlayerDisrupted > 0.0f) return JNI_FALSE;
    const float skillScale = 1.0f + static_cast<float>(gPlayerSkillLevel - 1) * 0.08f;
    const float radius = (gPlayerSelectedHero == 1 ? 7.0f : (gPlayerSelectedHero == 2 ? 5.6f : 6.2f)) * (1.0f + static_cast<float>(gPlayerSkillLevel - 1) * 0.025f);
    int affected = 0;
    if (gPlayerSelectedHero == 0) {
        const float before = gPlayerHealth;
        gPlayerHealth = std::min(gPlayerMaxHealth, gPlayerHealth + 28.0f);
        if (gPlayerHealth > before) ++affected;
        for (Bot &bot : gBots) {
            if (bot.team != 0 || bot.disabled > 0.0f || distance(bot.position, gPlayerPosition) > radius) continue;
            const float old = bot.health;
            bot.health = std::min(100.0f, bot.health + 26.0f);
            if (bot.health > old) ++affected;
        }
        for (LaneUnit &unit : gLaneUnits) {
            if (unit.team == 0 && unit.health > 0.0f && distance(unit.position, gPlayerPosition) <= radius) {
                const float old = unit.health;
                unit.health = std::min(unit.slot == 3 ? kRangedMinionHealth : kMeleeMinionHealth, unit.health + 22.0f);
                if (unit.health > old) ++affected;
            }
        }
        for (int i = 4; i < kBotCount; ++i) {
            Bot &bot = gBots[static_cast<std::size_t>(i)];
            if (bot.disabled > 0.0f || distance(bot.position, gPlayerPosition) > radius) continue;
            damageBot(bot, i, 0, 18.0f);
            ++affected;
        }
    } else {
        for (int i = 4; i < kBotCount; ++i) {
            Bot &bot = gBots[static_cast<std::size_t>(i)];
            if (bot.disabled > 0.0f || distance(bot.position, gPlayerPosition) > radius) continue;
            damageBot(bot, i, 0, (gPlayerSelectedHero == 1 ? 52.0f : 36.0f) * skillScale);
            ++affected;
        }
        for (LaneUnit &unit : gLaneUnits) {
            if (unit.team == 1 && unit.health > 0.0f && distance(unit.position, gPlayerPosition) <= radius) {
                damageLaneUnit(unit, 0, (gPlayerSelectedHero == 1 ? 48.0f : 36.0f) * skillScale);
                ++affected;
            }
        }
        for (int i = 0; i < kCampCount; ++i) {
            if (gCamps[static_cast<std::size_t>(i)].health > 0.0f &&
                distance(gPlayerPosition, gCamps[static_cast<std::size_t>(i)].position) <= radius) {
                damageCamp(i, 0, 26.0f);
                ++affected;
            }
        }
    }
    if (affected == 0) return JNI_FALSE;
    gPulseVisualTime = 0.82f;
    gPulseCooldown = std::max(4.5f, (gPlayerSelectedHero == 0 ? 10.0f : (gPlayerSelectedHero == 1 ? 9.0f : 6.2f)) * (1.0f - gPlayerHaste));
    return JNI_TRUE;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_duckdream_neonbreach_MainActivity_nativeActivateShield(JNIEnv *, jobject) {
    std::scoped_lock lock(gMutex);
    if (!gInitialized) resetSimulation();
    if (gPlayerHealth <= 0.0f || gPlayerRespawnTime > 0.0f || gShieldCooldown > 0.0f || gPlayerDisrupted > 0.0f) return JNI_FALSE;
    gShieldTime = gPlayerSelectedHero == 1 ? 4.5f : 3.0f;
    gShieldCooldown = std::max(5.0f, (gPlayerSelectedHero == 1 ? 8.5f : 11.0f) * (1.0f - gPlayerHaste));
    return JNI_TRUE;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_duckdream_neonbreach_MainActivity_nativeBuyItem(JNIEnv *, jobject, jint item) {
    std::scoped_lock lock(gMutex);
    if (!gInitialized || gWinner != 0 || item < 0 || item > 2) return JNI_FALSE;
    const std::array<int, 3> costs{{250, 300, 280}};
    if (gPlayerGold < static_cast<float>(costs[static_cast<std::size_t>(item)]) ||
        gItemCounts[static_cast<std::size_t>(item)] >= 3) return JNI_FALSE;
    gPlayerGold -= static_cast<float>(costs[static_cast<std::size_t>(item)]);
    ++gItemCounts[static_cast<std::size_t>(item)];
    if (item == 0) {
        gPlayerMaxHealth += 42.0f;
        gPlayerHealth = std::min(gPlayerMaxHealth, gPlayerHealth + 42.0f);
        gPlayerArmor = std::min(0.40f, gPlayerArmor + 0.07f);
    } else if (item == 1) {
        gPlayerPower += 0.14f;
    } else {
        gPlayerHaste = std::min(0.28f, gPlayerHaste + 0.08f);
    }
    return JNI_TRUE;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_duckdream_neonbreach_MainActivity_nativeUpgradeSkill(JNIEnv *, jobject) {
    std::scoped_lock lock(gMutex);
    if (!gInitialized || gWinner != 0 || gPlayerLevel <= gPlayerSkillLevel || gPlayerSkillLevel >= 5) return JNI_FALSE;
    ++gPlayerSkillLevel;
    gPlayerPower += 0.035f;
    return JNI_TRUE;
}

extern "C" JNIEXPORT jfloatArray JNICALL
Java_com_duckdream_neonbreach_MainActivity_nativeStep(JNIEnv *env, jobject, jfloat inputX, jfloat inputZ, jfloat deltaTime) {
    std::scoped_lock lock(gMutex);
    simulate(inputX, inputZ, deltaTime);
    std::array<jfloat, kSnapshotCount> values{};
    values[0] = gPlayerPosition.x;
    values[1] = terrainHeight(gPlayerPosition.x, gPlayerPosition.z);
    values[2] = gPlayerPosition.z;
    values[3] = length(gPlayerVelocity);
    values[4] = gElapsed;
    values[5] = gTeamKills[0];
    values[6] = gTeamKills[1];
    values[7] = gShieldTime;
    values[8] = gPulseCooldown;
    values[9] = gBoostCooldown;
    values[10] = 0.0f;
    values[11] = 0.0f;
    values[15] = static_cast<float>(gWinner);
    for (int i = 0; i < kBotCount; ++i) {
        const Bot &bot = gBots[static_cast<std::size_t>(i)];
        values[static_cast<std::size_t>(16 + i * 2)] = bot.position.x;
        values[static_cast<std::size_t>(17 + i * 2)] = bot.position.z;
        values[static_cast<std::size_t>(63 + i)] = bot.disabled;
    }
    values[34] = gPlayerVelocity.x;
    values[35] = gPlayerVelocity.z;
    for (int i = 0; i < 12; ++i) {
        const LaneUnit &unit = gLaneUnits[static_cast<std::size_t>(i)];
        values[static_cast<std::size_t>(36 + i * 2)] = unit.position.x;
        values[static_cast<std::size_t>(37 + i * 2)] = unit.position.z;
        values[static_cast<std::size_t>(82 + i)] = unit.health;
    }
    values[60] = gShieldCooldown;
    values[61] = gPulseVisualTime;
    values[62] = gBoostTime;
    values[72] = gPlayerHealth;
    values[94] = gPlayerDeathCount;
    values[95] = gPlayerRespawnTime;
    for (int lane = 0; lane < 3; ++lane) {
        values[static_cast<std::size_t>(73 + lane)] = gTowerHealth[static_cast<std::size_t>(towerIndex(0, lane, 0))];
        values[static_cast<std::size_t>(76 + lane)] = gTowerHealth[static_cast<std::size_t>(towerIndex(1, lane, 0))];
        int blueAlive = 0;
        int redAlive = 0;
        for (const LaneUnit &unit : gLaneUnits) {
            if (unit.lane == lane && unit.health > 0.0f) {
                if (unit.team == 0) ++blueAlive; else ++redAlive;
            }
        }
        values[static_cast<std::size_t>(10)] += static_cast<float>(blueAlive);
        values[static_cast<std::size_t>(11)] += static_cast<float>(redAlive);
        values[static_cast<std::size_t>(12 + lane)] = 0.0f;
    }
    values[79] = gCoreHealth[0];
    values[80] = gCoreHealth[1];
    values[81] = gPlayerAttackCooldown;
    values[96] = static_cast<float>(gPlayerLevel);
    values[97] = gPlayerXp;
    values[98] = gPlayerGold;
    values[99] = 220.0f + static_cast<float>(gPlayerLevel - 1) * 85.0f;
    values[100] = gPlayerMaxHealth;
    values[101] = gPlayerPower;
    values[102] = gPlayerArmor;
    values[103] = gObjectiveOneHealth > 0.0f ? 0.0f :
        std::max(0.0f, std::max(gObjectiveOneSpawnAt, gObjectiveOneRespawnAt) - gElapsed);
    values[104] = gObjectiveOneHealth;
    values[105] = gObjectiveTwoHealth > 0.0f ? 0.0f :
        std::max(0.0f, std::max(gObjectiveTwoSpawnAt, gObjectiveTwoRespawnAt) - gElapsed);
    values[106] = gObjectiveTwoHealth;
    for (int i = 0; i < kTowerCount; ++i) values[static_cast<std::size_t>(107 + i)] = gTowerHealth[static_cast<std::size_t>(i)];
    // Extended snapshot preserves the first eight camp slots and appends four slots per signal.
    for (int i = 0; i < kLaneUnitCount; ++i) {
        const LaneUnit &unit = gLaneUnits[static_cast<std::size_t>(i)];
        values[static_cast<std::size_t>(126 + i * 2)] = unit.position.x;
        values[static_cast<std::size_t>(127 + i * 2)] = unit.position.z;
        values[static_cast<std::size_t>(222 + i)] = unit.health;
    }
    for (int i = 0; i < kCampCount; ++i) {
        const NeutralCamp &camp = gCamps[static_cast<std::size_t>(i)];
        const std::size_t extra = static_cast<std::size_t>(std::max(0, i - 8));
        const std::size_t healthIndex = i < 8 ? static_cast<std::size_t>(270 + i) : 320u + extra;
        const std::size_t respawnIndex = i < 8 ? static_cast<std::size_t>(278 + i) : 324u + extra;
        const std::size_t pulseIndex = i < 8 ? static_cast<std::size_t>(312 + i) : 328u + extra;
        values[healthIndex] = camp.health;
        values[respawnIndex] = camp.respawnTime;
        values[pulseIndex] = camp.attackPulse;
    }
    values[286] = static_cast<float>(gItemCounts[0]);
    values[287] = static_cast<float>(gItemCounts[1]);
    values[288] = static_cast<float>(gItemCounts[2]);
    values[289] = static_cast<float>(gPlayerSkillLevel);
    values[290] = gTeamSiegeBuff[0];
    values[291] = gTeamSiegeBuff[1];
    values[292] = gObjectiveOneVisualTime;
    values[293] = gObjectiveTwoVisualTime;
    values[294] = gTeamGold[0];
    values[295] = gTeamGold[1];
    values[296] = gTeamXp[0];
    values[297] = gTeamXp[1];
    values[298] = static_cast<float>(playerRole());
    for (int i = 0; i < kBotCount; ++i) values[static_cast<std::size_t>(299 + i)] = static_cast<float>(gBots[static_cast<std::size_t>(i)].role);
    values[308] = gElapsed;
    values[309] = static_cast<float>(gWinner);
    values[310] = gPlayerHaste;
    values[311] = gPlayerPower;
    jfloatArray result = env->NewFloatArray(static_cast<jsize>(values.size()));
    if (result != nullptr) env->SetFloatArrayRegion(result, 0, static_cast<jsize>(values.size()), values.data());
    return result;
}
