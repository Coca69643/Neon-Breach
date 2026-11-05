#include "arena/ai/agent_state_machine.hpp"

namespace arena::ai {

AgentStateMachine::AgentStateMachine(
    const AgentKind kind,
    const AgentState initial
) noexcept
    : kind_(kind), state_(initial) {}

TransitionResult AgentStateMachine::dispatch(const AgentEvent event) noexcept {
    if (is_terminal()) {
        return reject();
    }

    if (event == AgentEvent::LethalDamage) {
        return transition_to(AgentState::Dead);
    }

    switch (state_) {
        case AgentState::Idle:
            switch (event) {
                case AgentEvent::BeginPatrol:
                    return transition_to(AgentState::Patrol);
                case AgentEvent::TargetDetected:
                    return transition_to(AgentState::AcquireTarget);
                default:
                    return reject();
            }

        case AgentState::Patrol:
            switch (event) {
                case AgentEvent::TargetDetected:
                    return transition_to(AgentState::AcquireTarget);
                case AgentEvent::HealthCritical:
                    return kind_ == AgentKind::Bot
                        ? transition_to(AgentState::Retreat)
                        : reject();
                default:
                    return reject();
            }

        case AgentState::AcquireTarget:
            switch (event) {
                case AgentEvent::TargetConfirmed:
                    return transition_to(AgentState::Approach);
                case AgentEvent::TargetLost:
                    return transition_to(state_after_target_lost());
                case AgentEvent::HealthCritical:
                    return kind_ == AgentKind::Bot
                        ? transition_to(AgentState::Retreat)
                        : reject();
                default:
                    return reject();
            }

        case AgentState::Approach:
            switch (event) {
                case AgentEvent::TargetInRange:
                    return transition_to(AgentState::Attack);
                case AgentEvent::TargetLost:
                    return transition_to(state_after_target_lost());
                case AgentEvent::HealthCritical:
                    return kind_ == AgentKind::Bot
                        ? transition_to(AgentState::Retreat)
                        : reject();
                default:
                    return reject();
            }

        case AgentState::Attack:
            switch (event) {
                case AgentEvent::TargetOutOfRange:
                    return transition_to(AgentState::Approach);
                case AgentEvent::TargetLost:
                    return transition_to(state_after_target_lost());
                case AgentEvent::HealthCritical:
                    return kind_ == AgentKind::Bot
                        ? transition_to(AgentState::Retreat)
                        : reject();
                default:
                    return reject();
            }

        case AgentState::Retreat:
            if (event == AgentEvent::Recovered) {
                return transition_to(AgentState::Idle);
            }
            return reject();

        case AgentState::Dead:
            return reject();
    }

    return reject();
}

AgentKind AgentStateMachine::kind() const noexcept {
    return kind_;
}

AgentState AgentStateMachine::state() const noexcept {
    return state_;
}

bool AgentStateMachine::is_terminal() const noexcept {
    return state_ == AgentState::Dead;
}

AgentState AgentStateMachine::state_after_target_lost() const noexcept {
    return kind_ == AgentKind::Minion
        ? AgentState::Patrol
        : AgentState::Idle;
}

TransitionResult AgentStateMachine::transition_to(
    const AgentState next
) noexcept {
    const AgentState previous = state_;
    state_ = next;
    return TransitionResult{previous, state_, true};
}

TransitionResult AgentStateMachine::reject() const noexcept {
    return TransitionResult{state_, state_, false};
}

}  // namespace arena::ai
