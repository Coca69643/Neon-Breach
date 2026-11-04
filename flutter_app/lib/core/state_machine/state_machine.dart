/// A typed transition in a finite state machine.
final class StateTransition<S extends Enum, E extends Enum> {
  const StateTransition({
    required this.from,
    required this.event,
    required this.to,
  });

  final S from;
  final E event;
  final S to;
}

/// Immutable record emitted after an accepted transition.
final class StateTransitionRecord<S extends Enum, E extends Enum> {
  const StateTransitionRecord({
    required this.previous,
    required this.current,
    required this.event,
    required this.revision,
  });

  final S previous;
  final S current;
  final E event;

  /// Monotonically increasing transition number for this machine instance.
  final int revision;
}

typedef StateMachineListener<S extends Enum, E extends Enum> = void Function(
  StateTransitionRecord<S, E> record,
);

/// A small, deterministic FSM.
///
/// State transitions are explicit and event-driven. Unknown transitions are
/// rejected without mutating state. Listeners are notified only after state
/// has changed. Re-entrant dispatch from a listener is rejected so a
/// transition remains atomic and predictable.
final class StateMachine<S extends Enum, E extends Enum> {
  StateMachine({
    required S initialState,
    required Iterable<StateTransition<S, E>> transitions,
  }) : _state = initialState {
    for (final transition in transitions) {
      if (transition.from == transition.to) {
        throw ArgumentError(
          'Self transitions are not supported: '
          '${transition.from.name} on ${transition.event.name}.',
        );
      }

      final key = (transition.from, transition.event);
      if (_routes.containsKey(key)) {
        throw ArgumentError(
          'Duplicate transition: ${transition.from.name} '
          'on ${transition.event.name}.',
        );
      }
      _routes[key] = transition.to;
    }
  }

  final Map<(S, E), S> _routes = <(S, E), S>{};
  final Set<StateMachineListener<S, E>> _listeners =
      <StateMachineListener<S, E>>{};

  S _state;
  int _revision = 0;
  bool _notifyingListeners = false;

  S get state => _state;
  int get revision => _revision;

  bool canDispatch(E event) => _routes.containsKey((_state, event));

  void addListener(StateMachineListener<S, E> listener) {
    _listeners.add(listener);
  }

  void removeListener(StateMachineListener<S, E> listener) {
    _listeners.remove(listener);
  }

  /// Applies [event] if a transition exists for the current state.
  ///
  /// Returns false for an invalid event. Invalid events never mutate state or
  /// increment [revision].
  bool dispatch(E event) {
    if (_notifyingListeners) {
      throw StateError(
        'StateMachine listeners cannot dispatch events re-entrantly. '
        'Schedule follow-up work outside the listener callback.',
      );
    }

    final next = _routes[(_state, event)];
    if (next == null) {
      return false;
    }

    final previous = _state;
    _state = next;
    _revision += 1;

    final record = StateTransitionRecord<S, E>(
      previous: previous,
      current: next,
      event: event,
      revision: _revision,
    );

    _notifyingListeners = true;
    try {
      for (final listener in List<StateMachineListener<S, E>>.of(_listeners)) {
        listener(record);
      }
    } finally {
      _notifyingListeners = false;
    }

    return true;
  }
}
