#pragma once

namespace arena_camp {

inline bool canAggro(float health, float targetDistance, float aggroRadius, float leashRadius) {
    return health > 0.0f && targetDistance <= aggroRadius && targetDistance <= leashRadius;
}

inline bool canStrike(float health, float cooldown, float targetDistance,
                      float attackRange, float leashRadius) {
    return health > 0.0f && cooldown <= 0.0f &&
        targetDistance <= attackRange && targetDistance <= leashRadius;
}

} // namespace arena_camp
