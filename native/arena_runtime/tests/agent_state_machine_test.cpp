#include "arena/ai/agent_state_machine.hpp"

#include <cstdlib>
#include <iostream>

using arena::ai::AgentEvent;
using arena::ai::AgentKind;
using arena::ai::AgentState;
using arena::ai::AgentStateMachine;

namespace {

bool check(const bool condition, const char* message) {
    if (!condition) {
        std::cerr << "FAIL: " << message << '\n';
        return false;
    }
    return true;
}

bool test_minion_patrol_and_target_loop() {
    AgentStateMachine minion(AgentKind::Minion);

    if (!check(
            minion.dispatch(AgentEvent::BeginPatrol).changed &&
                minion.state() == AgentState::Patrol,
            "minion should enter patrol")) {
        return false;
    }

    minion.dispatch(AgentEvent::TargetDetected);
    if (!check(
            minion.state() == AgentState::AcquireTarget,
            "minion should acquire a detected target")) {
        return false;
    }

    minion.dispatch(AgentEvent::TargetConfirmed);
    minion.dispatch(AgentEvent::TargetInRange);
    if (!check(
            minion.state() == AgentState::Attack,
            "minion should attack after entering range")) {
        return false;
    }

    minion.dispatch(AgentEvent::TargetLost);
    return check(
        minion.state() == AgentState::Patrol,
        "minion should return to patrol when target is lost"
    );
}

bool test_bot_retreat_and_recovery() {
    AgentStateMachine bot(AgentKind::Bot);
    bot.dispatch(AgentEvent::BeginPatrol);
    bot.dispatch(AgentEvent::TargetDetected);
    bot.dispatch(AgentEvent::TargetConfirmed);
    bot.dispatch(AgentEvent::TargetInRange);

    bot.dispatch(AgentEvent::HealthCritical);
    if (!check(
            bot.state() == AgentState::Retreat,
            "bot should retreat at critical health")) {
        return false;
    }

    bot.dispatch(AgentEvent::Recovered);
    return check(
        bot.state() == AgentState::Idle,
        "bot should return to idle after recovery"
    );
}

bool test_minion_does_not_use_bot_retreat_policy() {
    AgentStateMachine minion(AgentKind::Minion);
    minion.dispatch(AgentEvent::BeginPatrol);

    const auto result = minion.dispatch(AgentEvent::HealthCritical);
    return check(
        !result.changed && minion.state() == AgentState::Patrol,
        "minion should reject the bot-only retreat transition"
    );
}

bool test_dead_is_terminal() {
    AgentStateMachine bot(AgentKind::Bot);
    bot.dispatch(AgentEvent::LethalDamage);

    const auto after_death = bot.dispatch(AgentEvent::BeginPatrol);
    return check(
        bot.is_terminal() &&
            bot.state() == AgentState::Dead &&
            !after_death.changed,
        "dead agent must reject all later transitions"
    );
}

bool test_invalid_transition_is_non_mutating() {
    AgentStateMachine minion(AgentKind::Minion);
    const auto result = minion.dispatch(AgentEvent::TargetInRange);

    return check(
        !result.changed &&
            result.previous == AgentState::Idle &&
            result.current == AgentState::Idle,
        "invalid event must not mutate the state"
    );
}

}  // namespace

int main() {
    const bool passed =
        test_minion_patrol_and_target_loop() &&
        test_bot_retreat_and_recovery() &&
        test_minion_does_not_use_bot_retreat_policy() &&
        test_dead_is_terminal() &&
        test_invalid_transition_is_non_mutating();

    if (!passed) {
        return EXIT_FAILURE;
    }

    std::cout << "All agent state machine tests passed.\n";
    return EXIT_SUCCESS;
}
