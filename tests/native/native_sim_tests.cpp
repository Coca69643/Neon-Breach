#include <cmath>
#include <cstdlib>
#include <iostream>
#include <string>
#include <vector>

#include "../../app/src/main/cpp/ArenaSimulation.cpp"

namespace {
void require(bool condition, const std::string& message) {
    if (!condition) {
        std::cerr << "FAIL: " << message << '\n';
        std::exit(1);
    }
}

void reset(JNIEnv& env) {
    Java_com_duckdream_neonbreach_MainActivity_nativeReset(&env, nullptr);
}

std::vector<float> snapshot(JNIEnv& env) {
    jfloatArray result = Java_com_duckdream_neonbreach_MainActivity_nativeStep(
        &env, nullptr, 0.0f, 0.0f, 1.0f / 60.0f);
    require(result != nullptr, "nativeStep returned a null array");
    const std::vector<float> values = result->values;
    delete result;
    return values;
}

void advance(float seconds) {
    const int frames = static_cast<int>(std::ceil(seconds / 0.05f));
    for (int frame = 0; frame < frames; ++frame) {
        simulate(0.0f, 0.0f, 0.05f);
    }
}

void isolateEnemyTeam() {
    for (int index = 4; index < kBotCount; ++index) {
        gBots[static_cast<std::size_t>(index)].disabled = 30.0f;
    }
    for (int index = 6; index < kLaneUnitCount; ++index) {
        gLaneUnits[static_cast<std::size_t>(index)].health = 0.0f;
    }
}

void testSnapshotContract(JNIEnv& env) {
    reset(env);
    const auto values = snapshot(env);
    require(values.size() == 94, "JNI snapshot length must remain 94");
    for (float value : values) {
        require(std::isfinite(value), "snapshot contains a non-finite value");
    }
    require(values[72] == 100.0f, "player health must start at 100");
    for (int lane = 0; lane < 3; ++lane) {
        require(values[73 + lane] == kTowerMaxHealth, "blue tower health mismatch");
        require(values[76 + lane] == kTowerMaxHealth, "red tower health mismatch");
    }
    require(values[79] == kCoreMaxHealth && values[80] == kCoreMaxHealth,
            "both cores must start at full health");
}

void testHeroAbilityProfiles(JNIEnv& env) {
    reset(env);
    Java_com_duckdream_neonbreach_MainActivity_nativeSelectHero(&env, nullptr, 0);
    require(Java_com_duckdream_neonbreach_MainActivity_nativeActivateShield(&env, nullptr) == JNI_TRUE,
            "Lyra shield should activate");
    require(std::abs(gShieldTime - 3.6f) < 0.001f, "Lyra shield duration mismatch");

    reset(env);
    Java_com_duckdream_neonbreach_MainActivity_nativeSelectHero(&env, nullptr, 1);
    require(Java_com_duckdream_neonbreach_MainActivity_nativeActivateShield(&env, nullptr) == JNI_TRUE,
            "Bastion shield should activate");
    require(std::abs(gShieldTime - 4.2f) < 0.001f, "Bastion shield duration mismatch");

    reset(env);
    Java_com_duckdream_neonbreach_MainActivity_nativeSelectHero(&env, nullptr, 2);
    require(Java_com_duckdream_neonbreach_MainActivity_nativeActivateDash(&env, nullptr, 0.0f, 1.0f) == JNI_TRUE,
            "Kairo dash should activate");
    require(std::abs(gBoostTime - 0.62f) < 0.001f, "Kairo dash duration mismatch");
    require(std::abs(gBoostCooldown - 4.2f) < 0.001f, "Kairo dash cooldown mismatch");
}

void testManualCombatAndCooldown(JNIEnv& env) {
    reset(env);
    isolateEnemyTeam();
    gPlayerAttackCooldown = 0.0f;
    gPlayerX = -12.0f;
    gPlayerZ = -19.0f;
    require(Java_com_duckdream_neonbreach_MainActivity_nativeBasicAttack(&env, nullptr) == JNI_FALSE,
            "attack must not hit targets outside range");

    gBots[4].disabled = 0.0f;
    gBots[4].position = {gPlayerX + 1.0f, gPlayerZ};
    gBots[4].health = 100.0f;
    gPlayerAttackCooldown = 0.0f;
    require(Java_com_duckdream_neonbreach_MainActivity_nativeBasicAttack(&env, nullptr) == JNI_TRUE,
            "manual attack should hit a nearby rival");
    require(std::abs(gBots[4].health - 58.0f) < 0.001f, "manual hero damage mismatch");
    require(Java_com_duckdream_neonbreach_MainActivity_nativeBasicAttack(&env, nullptr) == JNI_FALSE,
            "manual attack must respect its cooldown");

    reset(env);
    isolateEnemyTeam();
    gPlayerAttackCooldown = 0.0f;
    gPlayerX = -12.0f;
    gPlayerZ = -19.0f;
    gLaneUnits[6].health = 120.0f;
    gLaneUnits[6].position = {gPlayerX + 1.0f, gPlayerZ};
    require(Java_com_duckdream_neonbreach_MainActivity_nativeBasicAttack(&env, nullptr) == JNI_TRUE,
            "manual attack should hit a nearby rival lane unit");
    require(std::abs(gLaneUnits[6].health - 60.0f) < 0.001f, "manual lane-unit damage mismatch");
}

void testTowerAndCoreGating(JNIEnv& env) {
    reset(env);
    isolateEnemyTeam();
    gPlayerX = -12.0f;
    gPlayerZ = 8.0f;
    gPlayerAttackCooldown = 0.0f;
    gRedTowers[0] = 500.0f;
    require(Java_com_duckdream_neonbreach_MainActivity_nativeBasicAttack(&env, nullptr) == JNI_TRUE,
            "player should damage an in-range enemy tower");
    require(std::abs(gRedTowers[0] - 448.0f) < 0.001f, "tower damage mismatch");

    reset(env);
    isolateEnemyTeam();
    gPlayerX = -12.0f;
    gPlayerZ = 22.0f;
    gPlayerAttackCooldown = 0.0f;
    gRedTowers = {{0.0f, 0.0f, kTowerMaxHealth}};
    const float lockedCoreHealth = gRedCoreHealth;
    require(Java_com_duckdream_neonbreach_MainActivity_nativeBasicAttack(&env, nullptr) == JNI_FALSE,
            "core must stay locked while any enemy tower remains");
    require(gRedCoreHealth == lockedCoreHealth, "locked core health changed");

    gRedTowers.fill(0.0f);
    gPlayerAttackCooldown = 0.0f;
    require(Java_com_duckdream_neonbreach_MainActivity_nativeBasicAttack(&env, nullptr) == JNI_TRUE,
            "core should become attackable after all enemy towers fall");
    require(std::abs(gRedCoreHealth - (kCoreMaxHealth - 48.0f)) < 0.001f,
            "core damage mismatch");
}

void testWaveRespawn(JNIEnv& env) {
    reset(env);
    gLaneUnits[0].health = 0.0f;
    gLaneUnits[3].health = 0.0f;
    advance(7.0f);
    require(gLaneUnits[0].health > 0.0f && gLaneUnits[3].health > 0.0f,
            "dead lane units did not return in the next wave");
}

void testLongSimulation(JNIEnv& env) {
    reset(env);
    Java_com_duckdream_neonbreach_MainActivity_nativeSelectHero(&env, nullptr, 2);
    for (int frame = 0; frame < 12000; ++frame) {
        const float phase = static_cast<float>(frame) * 0.008f;
        simulate(std::sin(phase) * 0.55f, std::cos(phase) * 0.55f, 0.05f);
        if (frame % 120 == 0) {
            const auto values = snapshot(env);
            require(values.size() == 94, "long-run snapshot length changed");
            for (float value : values) {
                require(std::isfinite(value), "long-run simulation produced a non-finite value");
            }
        }
        if (gWinner != 0) resetSimulation();
    }
    require(std::isfinite(gPlayerX) && std::isfinite(gPlayerZ) && std::isfinite(gPlayerHealth),
            "player state became non-finite during long simulation");
    for (const Bot& bot : gBots) {
        require(std::isfinite(bot.position.x) && std::isfinite(bot.position.z) &&
                std::isfinite(bot.health), "bot state became non-finite during long simulation");
    }
    for (const LaneUnit& unit : gLaneUnits) {
        require(std::isfinite(unit.position.x) && std::isfinite(unit.position.z) &&
                std::isfinite(unit.health), "lane-unit state became non-finite during long simulation");
    }
}
} // namespace

int main() {
    JNIEnv env;
    testSnapshotContract(env);
    testHeroAbilityProfiles(env);
    testManualCombatAndCooldown(env);
    testTowerAndCoreGating(env);
    testWaveRespawn(env);
    testLongSimulation(env);
    std::cout << "Native gameplay regression tests passed: snapshot, hero profiles, manual combat, cooldowns, siege gating, wave respawn, and 10-minute simulation.\n";
    return 0;
}
