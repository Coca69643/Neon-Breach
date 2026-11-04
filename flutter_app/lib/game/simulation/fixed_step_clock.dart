import 'dart:math' as math;

/// Accumulates frame time and advances simulation using a fixed time step.
///
/// Rendering may run at the display refresh rate. Gameplay state is updated
/// only in fixed increments, avoiding frame-rate-dependent physics and AI.
final class FixedStepClock {
  FixedStepClock({
    this.stepSeconds = 1.0 / 60.0,
    this.maxFrameSeconds = 0.1,
    this.maxStepsPerFrame = 5,
  }) {
    if (!stepSeconds.isFinite || stepSeconds <= 0) {
      throw ArgumentError.value(stepSeconds, 'stepSeconds');
    }
    if (!maxFrameSeconds.isFinite || maxFrameSeconds <= 0) {
      throw ArgumentError.value(maxFrameSeconds, 'maxFrameSeconds');
    }
    if (maxStepsPerFrame <= 0) {
      throw ArgumentError.value(maxStepsPerFrame, 'maxStepsPerFrame');
    }
  }

  static const double _epsilon = 1e-12;

  final double stepSeconds;
  final double maxFrameSeconds;
  final int maxStepsPerFrame;

  double _accumulator = 0;
  double _droppedTimeSeconds = 0;

  double get interpolationAlpha =>
      (_accumulator / stepSeconds).clamp(0.0, 1.0);

  double get droppedTimeSeconds => _droppedTimeSeconds;

  /// Advances at most [maxStepsPerFrame] fixed updates.
  ///
  /// Very long frame stalls are clamped. If the simulation still cannot catch
  /// up within the step budget, excess whole steps are discarded to prevent a
  /// spiral of death. The retained fractional remainder is used for render
  /// interpolation.
  int advance(
    double frameDeltaSeconds,
    void Function(double fixedDeltaSeconds) update,
  ) {
    if (!frameDeltaSeconds.isFinite || frameDeltaSeconds < 0) {
      throw ArgumentError.value(frameDeltaSeconds, 'frameDeltaSeconds');
    }

    final admitted = math.min(frameDeltaSeconds, maxFrameSeconds);
    _droppedTimeSeconds += frameDeltaSeconds - admitted;
    _accumulator += admitted;

    var steps = 0;
    while (_accumulator + _epsilon >= stepSeconds &&
        steps < maxStepsPerFrame) {
      update(stepSeconds);
      _accumulator -= stepSeconds;
      if (_accumulator < 0 && _accumulator > -_epsilon) {
        _accumulator = 0;
      }
      steps += 1;
    }

    if (_accumulator + _epsilon >= stepSeconds) {
      final retained = _accumulator % stepSeconds;
      _droppedTimeSeconds += _accumulator - retained;
      _accumulator = retained;
    }

    return steps;
  }

  void reset() {
    _accumulator = 0;
    _droppedTimeSeconds = 0;
  }
}
