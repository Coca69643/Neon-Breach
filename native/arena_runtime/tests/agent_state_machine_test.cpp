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
        std::cerr << "FAIL: " << message << '\\n';
        return false;
    }
    return true;
}

bool send(
    AgentStateMachine& machine,
    const AgentEvent event,
    const char* message
) {
    return check(machine.dispatch(event).changed, message);
}

bool test_minion_patrol_and_target_loop() {
    AgentStateMachine minion(AgentKind::Minion);

    if (!send(minion, AgentEvent::BeginPatrol, "minion enters patrol")) {
        return false;
    }
    if (!send(minion, AgentEvent::TargetDetected, "minion detects target")) {
        return false;
    }
    if (!send(minion, AgentEvent::TargetConfirmed, "minion confirms target")) {
        return false;
    }
    if (!send(minion, AgentEvent::TargetInRange, "minion enters attack range")) {
        return false;
    }
    if (!check(minion.state() == AgentState::Attack, "minion enters attack")) {
        return false;
    }
    if (!send(minion, AgentEvent::TargetLost, "minion loses target")) {
        return false;
    }

    return check(
        minion.state() == AgentState::Patrol,
        "minion returns to patrol when target is lost"
    );
}

bool test_bot_retreat_and_recovery() {
    AgentStateMachine bot(AgentKind::Bot);

    if (!send(bot, AgentEvent::BeginPatrol, "bot enters patrol")) return false;
    if (!send(bot, AgentEvent::TargetDetected, "bot detects target")) return false;
    if (!send(bot, AgentEvent::TargetConfirmed, "bot confirms target")) return false;
    if (!send(bot, AgentEvent::TargetInRange, "bot enters attack range")) return false;
    if (!send(bot, AgentEvent::HealthCritical, "bot enters retreat")) return false;

    if (!check(bot.state() == AgentState::Retreat, "bot retreats at critical health")) {
        return false;
    }
    if (!send(bot, AgentEvent::Recovered, "bot recovery completes")) return false;

    return check(
        bot.state() == AgentState::Idle,
        "bot returns to idle after recovery"
    );
}

bool test_minion_does_not_use_bot_retreat_policy() {
    AgentStateMachine minion(AgentKind::Minion);
    if (!send(minion, AgentEvent::BeginPatrol, "minion enters patrol")) {
        return false;
    }

    const auto result = minion.dispatch(AgentEvent::HealthCritical);
    return check(
        !result.changed && minion.state() == AgentState::Patrol,
        "minion rejects the bot-only retreat transition"
    );
}

bool test_dead_is_terminal() {
    AgentStateMachine bot(AgentKind::Bot);
    if (!send(bot, AgentEvent::LethalDamage, "bot enters terminal dead state")) {
        return false;
    }

    const auto afterDeath = bot.dispatch(AgentEvent::BeginPatrol);
    return check(
        bot.is_terminal() &&
            bot.state() == AgentState::Dead &&
            !afterDeath.changed,
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

    std::cout << "All agent state machine tests passed.\\n";
    return EXIT_SUCCESS;
}
