#pragma once

namespace arena::ai {

enum class AgentKind {
    Bot,
    Minion,
};

enum class AgentState {
    Idle,
    Patrol,
    AcquireTarget,
    Approach,
    Attack,
    Retreat,
    Dead,
};

enum class AgentEvent {
    BeginPatrol,
    TargetDetected,
    TargetConfirmed,
    TargetLost,
    TargetInRange,
    TargetOutOfRange,
    HealthCritical,
    Recovered,
    LethalDamage,
};

struct TransitionResult final {
    AgentState previous;
    AgentState current;
    bool changed;
};

class AgentStateMachine final {
public:
    explicit AgentStateMachine(
        AgentKind kind,
        AgentState initial = AgentState::Idle
    ) noexcept;

    [[nodiscard]] TransitionResult dispatch(AgentEvent event) noexcept;
    [[nodiscard]] AgentKind kind() const noexcept;
    [[nodiscard]] AgentState state() const noexcept;
    [[nodiscard]] bool is_terminal() const noexcept;

private:
    [[nodiscard]] AgentState state_after_target_lost() const noexcept;
    [[nodiscard]] TransitionResult transition_to(AgentState next) noexcept;
    [[nodiscard]] TransitionResult reject() const noexcept;

    AgentKind kind_;
    AgentState state_;
};

}  // namespace arena::ai
