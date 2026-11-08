import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart' hide Material;
import 'package:vector_math/vector_math.dart' as vm;

import '../game/match/moba_match_simulation.dart';
import '../game/physics/arena_physics_runtime.dart';
import '../game/rendering/arena_synthetic_hero_model.dart';
import '../game/world/arena_world_catalog.dart';

class ArenaSyntheticTraversalLab extends StatefulWidget {
  const ArenaSyntheticTraversalLab({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<ArenaSyntheticTraversalLab> createState() =>
      _ArenaSyntheticTraversalLabState();
}

class _SyntheticLabFrame {
  const _SyntheticLabFrame({
    required this.position,
    required this.elapsed,
    required this.facing,
    required this.speedRatio,
    required this.grounded,
    required this.sliding,
    required this.jumping,
    required this.staminaRatio,
    required this.canDash,
    required this.canSlide,
    required this.canJump,
  });

  final MobaPoint position;
  final double elapsed;
  final double facing;
  final double speedRatio;
  final bool grounded;
  final bool sliding;
  final bool jumping;
  final double staminaRatio;
  final bool canDash;
  final bool canSlide;
  final bool canJump;
}

class _ArenaSyntheticTraversalLabState
    extends State<ArenaSyntheticTraversalLab>
    with WidgetsBindingObserver {
  static const MobaPoint _spawn = MobaPoint(-4.0, -60.0);
  static const MobaPoint _springPad = MobaPoint(6.0, -60.0);
  static const double _stickRadius = 48;
  static final RingGeometry _padRing = RingGeometry(
    innerRadius: 1.22,
    outerRadius: 1.62,
    segments: 32,
  );
  static final CuboidGeometry _padBase =
      CuboidGeometry(vm.Vector3(2.65, 0.18, 2.65));
  static final UnlitMaterial _padBaseMaterial = UnlitMaterial()
    ..baseColorFactor = vm.Vector4(0.075, 0.14, 0.17, 1);
  static final UnlitMaterial _padReadyMaterial = UnlitMaterial()
    ..baseColorFactor = vm.Vector4(0.12, 0.84, 0.72, 0.98);
  static final UnlitMaterial _padCoreMaterial = UnlitMaterial()
    ..baseColorFactor = vm.Vector4(0.94, 0.62, 0.24, 1);

  late final ValueNotifier<_SyntheticLabFrame> _frame;
  ArenaPhysicsRuntime? _physics;
  double _moveX = 0;
  double _moveZ = 0;
  double _facingRadians = 0;
  double _elapsed = 0;
  bool _padTriggered = false;
  late final ValueNotifier<String> _status =
      ValueNotifier<String>('Explore a arena e teste a mobilidade do sintético.');
  bool _loading = true;
  String? _failure;
  Offset _stickOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _frame = ValueNotifier<_SyntheticLabFrame>(_initialFrame());
    unawaited(_initializePhysics());
  }

  _SyntheticLabFrame _initialFrame() {
    return const _SyntheticLabFrame(
      position: _spawn,
      elapsed: 0,
      facing: 0,
      speedRatio: 0,
      grounded: true,
      sliding: false,
      jumping: false,
      staminaRatio: 1,
      canDash: false,
      canSlide: false,
      canJump: false,
    );
  }

  Future<void> _initializePhysics() async {
    try {
      final runtime = await ArenaPhysicsRuntime.create(
        spawn: _spawn,
        traversalProfile: ArenaTraversalProfile.syntheticPrototype(),
      );
      if (!mounted) {
        runtime.dispose();
        return;
      }
      _physics = runtime;
      _frame.value = _snapshotFrame(runtime);
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _failure = 'Falha ao iniciar a física: $error';
        _loading = false;
      });
    }
  }

  _SyntheticLabFrame _snapshotFrame(ArenaPhysicsRuntime physics) {
    final point = physics.playerPosition;
    if (_moveX.abs() + _moveZ.abs() > 0.08) {
      _facingRadians = math.atan2(_moveX, _moveZ);
    }
    return _SyntheticLabFrame(
      position: point,
      elapsed: _elapsed,
      facing: _facingRadians,
      speedRatio: physics.movementSpeedRatio,
      grounded: physics.grounded,
      sliding: physics.sliding,
      jumping: physics.jumping,
      staminaRatio: physics.traversalStaminaRatio,
      canDash: physics.canTriggerTraversalDash,
      canSlide: physics.canTriggerSlide,
      canJump: physics.canTriggerJump,
    );
  }

  void _onSceneTick(Duration elapsed, double deltaSeconds) {
    final physics = _physics;
    if (physics == null || _loading || _failure != null) return;

    final dt = deltaSeconds.clamp(0.0, 0.05).toDouble();
    _elapsed += dt;
    physics.setInput(_moveX, _moveZ);
    physics.update(dt);

    final point = physics.playerPosition;
    final dx = point.x - _springPad.x;
    final dz = point.z - _springPad.z;
    final onSpringPad = dx * dx + dz * dz <= 2.0 * 2.0;

    // The floor pad is an actual traversal interaction, not a decorative
    // trigger: contact while grounded applies one boosted vertical impulse.
    if (onSpringPad && !_padTriggered && physics.grounded) {
      if (physics.triggerTraversalJump(impulseMultiplier: 1.55)) {
        _padTriggered = true;
        _status.value = 'Plataforma de impulso ativada.';
      }
    } else if (!onSpringPad) {
      _padTriggered = false;
    }

    _frame.value = _snapshotFrame(physics);
  }

  void _applyStick(Offset localPosition) {
    final center = const Offset(62, 62);
    final delta = localPosition - center;
    final length = delta.distance;
    final limited = length > _stickRadius
        ? delta / length * _stickRadius
        : delta;
    setState(() {
      _stickOffset = limited;
      _moveX = (limited.dx / _stickRadius).clamp(-1.0, 1.0).toDouble();
      _moveZ = (-limited.dy / _stickRadius).clamp(-1.0, 1.0).toDouble();
    });
  }

  void _releaseStick() {
    setState(() {
      _stickOffset = Offset.zero;
      _moveX = 0;
      _moveZ = 0;
    });
  }

  void _jump() {
    final physics = _physics;
    if (physics == null) return;
    if (physics.triggerTraversalJump()) {
      _status.value = 'Salto vetorial executado.';
    }
  }

  void _dash() {
    final physics = _physics;
    if (physics == null) return;
    var x = _moveX;
    var z = _moveZ;
    if (x * x + z * z < 0.02) {
      x = 0;
      z = 1;
    }
    if (physics.triggerTraversalDash(x, z)) {
      _status.value = 'Impulso vetorial executado.';
    }
  }

  void _slide() {
    final physics = _physics;
    if (physics == null) return;
    if (physics.triggerTraversalSlide()) {
      _status.value = 'Deslizamento por conservação de momento.';
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _physics?.setActive(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _frame.dispose();
    _status.dispose();
    _physics?.dispose();
    _physics = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101A20),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_failure == null)
            ValueListenableBuilder<_SyntheticLabFrame>(
              valueListenable: _frame,
              builder: (context, frame, _) {
                final point = frame.position;
                final ground = ArenaWorldCatalog.navigationHeightAt(
                  point.x,
                  point.z,
                  elevation: point.elevation,
                );
                final padGround = ArenaWorldCatalog.navigationHeightAt(
                  _springPad.x,
                  _springPad.z,
                );
                return SceneView.declarative(
                  key: const ValueKey('synthetic-traversal-lab-scene'),
                  pixelRatio: 0.76,
                  maxFrameRate: 30,
                  cameraBuilder: (_) => PerspectiveCamera(
                    fovRadiansY: 47 * math.pi / 180,
                    position: vm.Vector3(
                      point.x,
                      ground + 5.5,
                      point.z - 8.3,
                    ),
                    target: vm.Vector3(
                      point.x,
                      ground + 0.95,
                      point.z + 0.45,
                    ),
                    fovNear: 0.08,
                    fovFar: 180,
                  ),
                  onTick: _onSceneTick,
                  loadingBuilder: (context, progress) => const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF79D6BD),
                    ),
                  ),
                  children: [
                    SceneModel(
                      'assets/world/arena_terrain.glb',
                      key: const ValueKey('synthetic-lab-terrain'),
                      name: 'synthetic_lab_terrain',
                    ),
                    SceneModel(
                      'assets/world/city/street_light_square.glb',
                      key: const ValueKey('synthetic-lab-light'),
                      name: 'synthetic_lab_cc0_street_light',
                      position: vm.Vector3(
                        10,
                        ArenaWorldCatalog.navigationHeightAt(10, -60),
                        -60,
                      ),
                      scale: vm.Vector3.all(1.7),
                    ),
                    SceneModel(
                      'assets/world/city/park_tree_oak.glb',
                      key: const ValueKey('synthetic-lab-tree'),
                      name: 'synthetic_lab_cc0_tree',
                      position: vm.Vector3(
                        -9,
                        ArenaWorldCatalog.navigationHeightAt(-9, -64),
                        -64,
                      ),
                      scale: vm.Vector3.all(1.9),
                    ),
                    SceneMesh(
                      name: 'synthetic_lab_spring_pad_base',
                      geometry: _padBase,
                      material: _padBaseMaterial,
                      position: vm.Vector3(
                        _springPad.x,
                        padGround + 0.10,
                        _springPad.z,
                      ),
                    ),
                    SceneMesh(
                      name: 'synthetic_lab_spring_pad_ring',
                      geometry: _padRing,
                      material: _padReadyMaterial,
                      position: vm.Vector3(
                        _springPad.x,
                        padGround + 0.205,
                        _springPad.z,
                      ),
                    ),
                    SceneMesh(
                      name: 'synthetic_lab_spring_pad_core',
                      geometry: _padBase,
                      material: _padCoreMaterial,
                      position: vm.Vector3(
                        _springPad.x,
                        padGround + 0.24,
                        _springPad.z,
                      ),
                      scale: vm.Vector3(0.72, 0.38, 0.72),
                    ),
                    ArenaSyntheticHeroModel(
                      position: vm.Vector3(point.x, ground + 0.03, point.z),
                      facingRadians: frame.facing,
                      gaitPhase: frame.elapsed * (4.0 + frame.speedRatio * 5.0),
                      speedRatio: frame.speedRatio,
                      airborne: frame.jumping || !frame.grounded,
                    ),
                  ],
                );
              },
            ),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  left: 14,
                  top: 10,
                  child: TextButton.icon(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back_rounded, size: 17),
                    label: const Text('VOLTAR À SELEÇÃO'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFE6F2EF),
                      backgroundColor: const Color(0xA514252C),
                      textStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  left: 18,
                  top: 60,
                  child: _LabTitle(),
                ),
                Positioned(
                  left: 18,
                  bottom: 16,
                  child: _buildJoystick(),
                ),
                Positioned(
                  right: 16,
                  bottom: 18,
                  child: ValueListenableBuilder<_SyntheticLabFrame>(
                    valueListenable: _frame,
                    builder: (context, frame, _) => _buildActionButtons(frame),
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  top: 106,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ValueListenableBuilder<String>(
                      valueListenable: _status,
                      builder: (context, status, _) => Text(
                      status,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFE6F2EF),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_loading || _failure != null)
            ColoredBox(
              color: const Color(0xCC101A20),
              child: Center(
                child: _failure == null
                    ? const CircularProgressIndicator(
                        color: Color(0xFF79D6BD),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Color(0xFFFFB36B),
                              size: 34,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _failure!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: widget.onBack,
                              child: const Text('VOLTAR'),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildJoystick() {
    return GestureDetector(
      onPanDown: (details) => _applyStick(details.localPosition),
      onPanUpdate: (details) => _applyStick(details.localPosition),
      onPanEnd: (_) => _releaseStick(),
      onPanCancel: _releaseStick,
      child: SizedBox(
        width: 124,
        height: 124,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0x88304149),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x9979D6BD), width: 1.2),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Color(0x668CE2D0),
                  shape: BoxShape.circle,
                ),
              ),
              Transform.translate(
                offset: _stickOffset,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8BDCC8),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE2FFF7),
                      width: 1.2,
                    ),
                    boxShadow: const [
                      BoxShadow(color: Color(0x66000000), blurRadius: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(_SyntheticLabFrame frame) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _LabActionButton(
          label: 'SALTO',
          icon: Icons.north_rounded,
          enabled: frame.canJump,
          onTap: _jump,
        ),
        const SizedBox(height: 8),
        _LabActionButton(
          label: 'SLIDE',
          icon: Icons.swipe_down_alt_rounded,
          enabled: frame.canSlide,
          onTap: _slide,
        ),
        const SizedBox(height: 8),
        _LabActionButton(
          label: 'IMPULSO',
          icon: Icons.bolt_rounded,
          enabled: frame.canDash,
          onTap: _dash,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 116,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 5,
              value: frame.staminaRatio,
              backgroundColor: const Color(0x66485B62),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF83D6C1)),
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'RESERVA DE MOVIMENTO',
          style: TextStyle(
            color: Color(0xFFD5E2E2),
            fontSize: 7,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.7,
            shadows: [Shadow(color: Colors.black87, blurRadius: 7)],
          ),
        ),
      ],
    );
  }
}

class _LabTitle extends StatelessWidget {
  const _LabTitle();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SYNTH-01',
          style: TextStyle(
            color: Color(0xFFF3F7F5),
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
            shadows: [Shadow(color: Colors.black87, blurRadius: 10)],
          ),
        ),
        SizedBox(height: 4),
        Text(
          'LABORATÓRIO DE MOBILIDADE  /  PROTÓTIPO',
          style: TextStyle(
            color: Color(0xFF9EDFCF),
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
            shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
          ),
        ),
      ],
    );
  }
}

class _LabActionButton extends StatelessWidget {
  const _LabActionButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 116,
      height: 44,
      child: FilledButton.icon(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, size: 15),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF294F4D),
          foregroundColor: const Color(0xFFE7FAF4),
          disabledBackgroundColor: const Color(0x77303C42),
          disabledForegroundColor: const Color(0xFF849194),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: const BorderSide(color: Color(0x8879D6BD)),
          ),
        ),
      ),
    );
  }
}
