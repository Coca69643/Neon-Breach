import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Procedural, offline-safe player model for Linn.
/// Reuses cached Scene geometry/materials and keeps only one rig active at a time.
class ArenaLinnHeroModel extends StatefulWidget {
  const ArenaLinnHeroModel({
    super.key,
    required this.position,
    required this.rotation,
    required this.scale,
    required this.elapsedSeconds,
    required this.speedRatio,
    required this.moving,
    required this.attacking,
    required this.formBlend,
    this.onReady,
  });

  final vm.Vector3 position;
  final vm.Quaternion rotation;
  final double scale;
  final double elapsedSeconds;
  final double speedRatio;
  final bool moving;
  final bool attacking;
  final double formBlend;
  final VoidCallback? onReady;

  @override
  State<ArenaLinnHeroModel> createState() => _ArenaLinnHeroModelState();
}

class _ArenaLinnHeroModelState extends State<ArenaLinnHeroModel> {
  static final SphereGeometry _sphere =
      SphereGeometry(segments: 16, rings: 10);
  static final CuboidGeometry _plate =
      CuboidGeometry(vm.Vector3(1, 1, 1));
  static final PhysicallyBasedMaterial _shell = PhysicallyBasedMaterial()
    ..baseColorFactor = vm.Vector4(0.70, 0.81, 0.82, 1)
    ..metallicFactor = 0.78
    ..roughnessFactor = 0.34;
  static final PhysicallyBasedMaterial _shellBright = PhysicallyBasedMaterial()
    ..baseColorFactor = vm.Vector4(0.88, 0.92, 0.88, 1)
    ..metallicFactor = 0.54
    ..roughnessFactor = 0.31;
  static final PhysicallyBasedMaterial _darkMetal = PhysicallyBasedMaterial()
    ..baseColorFactor = vm.Vector4(0.055, 0.105, 0.13, 1)
    ..metallicFactor = 0.68
    ..roughnessFactor = 0.40;
  static final PhysicallyBasedMaterial _feralOrange = PhysicallyBasedMaterial()
    ..baseColorFactor = vm.Vector4(0.88, 0.28, 0.075, 1)
    ..metallicFactor = 0.18
    ..roughnessFactor = 0.68;
  static final PhysicallyBasedMaterial _feralLight = PhysicallyBasedMaterial()
    ..baseColorFactor = vm.Vector4(0.96, 0.72, 0.43, 1)
    ..metallicFactor = 0.12
    ..roughnessFactor = 0.72;
  static final PhysicallyBasedMaterial _feralDark = PhysicallyBasedMaterial()
    ..baseColorFactor = vm.Vector4(0.18, 0.075, 0.045, 1)
    ..metallicFactor = 0.12
    ..roughnessFactor = 0.74;
  static final UnlitMaterial _cyan = UnlitMaterial()
    ..baseColorFactor = vm.Vector4(0.12, 0.89, 0.84, 1);
  static final UnlitMaterial _amber = UnlitMaterial()
    ..baseColorFactor = vm.Vector4(1.0, 0.58, 0.18, 1);
  static final UnlitMaterial _visor = UnlitMaterial()
    ..baseColorFactor = vm.Vector4(0.018, 0.075, 0.095, 1);

  bool _readySent = false;

  @override
  void initState() {
    super.initState();
    _scheduleReady();
  }

  void _scheduleReady() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _readySent) return;
      _readySent = true;
      widget.onReady?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final blend = widget.formBlend.clamp(0.0, 1.0).toDouble();
    final isFeral = blend >= 0.5;
    final transitionScale = 0.88 + 0.12 * (2 * blend - 1).abs();
    final speed = widget.speedRatio.clamp(0.0, 1.25).toDouble();
    final phase = widget.elapsedSeconds * (4.1 + speed * 2.5);
    final gait = widget.moving ? speed : 0.035;
    final stride = math.sin(phase) * 0.34 * gait;

    return SceneNode(
      name: 'linn_player_root',
      position: widget.position,
      rotation: widget.rotation,
      scale: vm.Vector3.all(widget.scale * transitionScale),
      children: [
        if (isFeral)
          _buildFeralRig(phase, stride)
        else
          _buildSyntheticRig(phase, stride),
      ],
    );
  }

  Widget _buildSyntheticRig(double phase, double stride) {
    final armSwing = stride * 0.82 + (widget.attacking ? -0.32 : 0);
    return SceneNode(
      name: 'linn_synthetic_form',
      children: [
        SceneMesh(
          name: 'linn_backpack',
          geometry: _plate,
          material: _darkMetal,
          position: vm.Vector3(0, 1.13, -0.25),
          scale: vm.Vector3(0.38, 0.49, 0.20),
        ),
        SceneMesh(
          name: 'linn_torso_shell',
          geometry: _sphere,
          material: _shell,
          position: vm.Vector3(0, 1.12, 0),
          scale: vm.Vector3(0.57, 0.69, 0.39),
        ),
        SceneMesh(
          name: 'linn_chest_plate',
          geometry: _plate,
          material: _shellBright,
          position: vm.Vector3(0, 1.16, 0.22),
          scale: vm.Vector3(0.48, 0.48, 0.12),
        ),
        SceneMesh(
          name: 'linn_reactor_core',
          geometry: _sphere,
          material: _cyan,
          position: vm.Vector3(0, 1.18, 0.30),
          scale: vm.Vector3(0.13, 0.16, 0.055),
        ),
        SceneMesh(
          name: 'linn_hip_frame',
          geometry: _plate,
          material: _darkMetal,
          position: vm.Vector3(0, 0.69, 0),
          scale: vm.Vector3(0.50, 0.24, 0.34),
        ),
        SceneMesh(
          name: 'linn_head_shell',
          geometry: _sphere,
          material: _shellBright,
          position: vm.Vector3(0, 1.78, 0.02),
          scale: vm.Vector3(0.36, 0.35, 0.32),
        ),
        SceneMesh(
          name: 'linn_head_crown',
          geometry: _plate,
          material: _darkMetal,
          position: vm.Vector3(0, 2.03, -0.015),
          scale: vm.Vector3(0.30, 0.10, 0.25),
        ),
        SceneMesh(
          name: 'linn_face_visor',
          geometry: _plate,
          material: _visor,
          position: vm.Vector3(0, 1.80, 0.30),
          scale: vm.Vector3(0.40, 0.12, 0.055),
        ),
        SceneMesh(
          name: 'linn_left_optic',
          geometry: _sphere,
          material: _cyan,
          position: vm.Vector3(-0.12, 1.80, 0.34),
          scale: vm.Vector3(0.045, 0.035, 0.022),
        ),
        SceneMesh(
          name: 'linn_right_optic',
          geometry: _sphere,
          material: _cyan,
          position: vm.Vector3(0.12, 1.80, 0.34),
          scale: vm.Vector3(0.045, 0.035, 0.022),
        ),
        SceneMesh(
          name: 'linn_left_sensor_fin',
          geometry: _sphere,
          material: _shellBright,
          position: vm.Vector3(-0.28, 2.02, -0.015),
          scale: vm.Vector3(0.085, 0.20, 0.12),
          rotation: vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), -0.27),
        ),
        SceneMesh(
          name: 'linn_right_sensor_fin',
          geometry: _sphere,
          material: _shellBright,
          position: vm.Vector3(0.28, 2.02, -0.015),
          scale: vm.Vector3(0.085, 0.20, 0.12),
          rotation: vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), 0.27),
        ),
        _syntheticArm('linn_left_arm', -0.47, armSwing, false),
        _syntheticArm('linn_right_arm', 0.47, -armSwing, true),
        _syntheticLeg('linn_left_leg', -0.16, stride),
        _syntheticLeg('linn_right_leg', 0.16, -stride),
        SceneMesh(
          name: 'linn_left_shoulder_armor',
          geometry: _sphere,
          material: _shellBright,
          position: vm.Vector3(-0.46, 1.47, 0),
          scale: vm.Vector3(0.22, 0.20, 0.25),
        ),
        SceneMesh(
          name: 'linn_right_shoulder_armor',
          geometry: _sphere,
          material: _shellBright,
          position: vm.Vector3(0.46, 1.47, 0),
          scale: vm.Vector3(0.22, 0.20, 0.25),
        ),
        SceneMesh(
          name: 'linn_forearm_emitter',
          geometry: _sphere,
          material: widget.attacking ? _amber : _cyan,
          position: vm.Vector3(0.56, 0.93, 0.21),
          scale: vm.Vector3(0.12, 0.10, 0.12),
        ),
      ],
    );
  }

  Widget _syntheticArm(String name, double side, double swing, bool emitter) {
    return SceneNode(
      name: name,
      position: vm.Vector3(side, 1.40, 0),
      rotation: vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), swing),
      children: [
        SceneMesh(
          name: '${name}_upper',
          geometry: _sphere,
          material: _shell,
          position: vm.Vector3(0, -0.23, 0),
          scale: vm.Vector3(0.16, 0.30, 0.17),
        ),
        SceneMesh(
          name: '${name}_forearm',
          geometry: _sphere,
          material: _shellBright,
          position: vm.Vector3(0, -0.52, 0.035),
          scale: vm.Vector3(0.17, 0.25, 0.18),
        ),
        SceneMesh(
          name: '${name}_wrist',
          geometry: _sphere,
          material: emitter ? _darkMetal : _shell,
          position: vm.Vector3(0, -0.72, 0.07),
          scale: vm.Vector3(0.17, 0.13, 0.16),
        ),
        if (emitter)
          SceneMesh(
            name: '${name}_pulse_aperture',
            geometry: _sphere,
            material: widget.attacking ? _amber : _cyan,
            position: vm.Vector3(0, -0.72, 0.20),
            scale: vm.Vector3(0.10, 0.10, 0.045),
          ),
      ],
    );
  }

  Widget _syntheticLeg(String name, double side, double swing) {
    return SceneNode(
      name: name,
      position: vm.Vector3(side, 0.73, 0),
      rotation: vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), swing),
      children: [
        SceneMesh(
          name: '${name}_thigh',
          geometry: _sphere,
          material: _shell,
          position: vm.Vector3(0, -0.21, 0),
          scale: vm.Vector3(0.15, 0.28, 0.16),
        ),
        SceneMesh(
          name: '${name}_shin',
          geometry: _sphere,
          material: _shellBright,
          position: vm.Vector3(0, -0.48, 0.025),
          scale: vm.Vector3(0.13, 0.23, 0.14),
        ),
        SceneMesh(
          name: '${name}_boot',
          geometry: _plate,
          material: _darkMetal,
          position: vm.Vector3(0, -0.69, 0.105),
          scale: vm.Vector3(0.29, 0.14, 0.40),
        ),
      ],
    );
  }

  Widget _buildFeralRig(double phase, double stride) {
    final foxStride = stride * 1.34;
    final headPitch = widget.attacking ? -0.22 : 0.02;
    final tailSway = math.sin(phase * 0.52) * 0.14;
    return SceneNode(
      name: 'linn_feral_form',
      children: [
        SceneMesh(
          name: 'linn_feral_body',
          geometry: _sphere,
          material: _feralOrange,
          position: vm.Vector3(0, 0.79, -0.05),
          scale: vm.Vector3(0.40, 0.39, 0.78),
        ),
        SceneMesh(
          name: 'linn_feral_belly',
          geometry: _sphere,
          material: _feralLight,
          position: vm.Vector3(0, 0.64, 0.13),
          scale: vm.Vector3(0.28, 0.20, 0.55),
        ),
        SceneMesh(
          name: 'linn_feral_left_haunch',
          geometry: _sphere,
          material: _feralOrange,
          position: vm.Vector3(-0.28, 0.72, -0.43),
          scale: vm.Vector3(0.22, 0.29, 0.31),
        ),
        SceneMesh(
          name: 'linn_feral_right_haunch',
          geometry: _sphere,
          material: _feralOrange,
          position: vm.Vector3(0.28, 0.72, -0.43),
          scale: vm.Vector3(0.22, 0.29, 0.31),
        ),
        _foxLeg('linn_feral_front_left_leg', -0.24, 0.47, foxStride),
        _foxLeg('linn_feral_front_right_leg', 0.24, 0.47, -foxStride),
        _foxLeg('linn_feral_rear_left_leg', -0.24, -0.48, -foxStride),
        _foxLeg('linn_feral_rear_right_leg', 0.24, -0.48, foxStride),
        SceneNode(
          name: 'linn_feral_head_pivot',
          position: vm.Vector3(0, 1.00, 0.59),
          rotation: vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), headPitch),
          children: [
            SceneMesh(
              name: 'linn_feral_head',
              geometry: _sphere,
              material: _feralOrange,
              scale: vm.Vector3(0.34, 0.30, 0.37),
            ),
            SceneMesh(
              name: 'linn_feral_muzzle',
              geometry: _sphere,
              material: _feralLight,
              position: vm.Vector3(0, -0.08, 0.34),
              scale: vm.Vector3(0.22, 0.14, 0.30),
            ),
            SceneMesh(
              name: 'linn_feral_nose',
              geometry: _sphere,
              material: _feralDark,
              position: vm.Vector3(0, -0.02, 0.59),
              scale: vm.Vector3(0.065, 0.05, 0.055),
            ),
            SceneMesh(
              name: 'linn_feral_left_ear',
              geometry: _sphere,
              material: _feralOrange,
              position: vm.Vector3(-0.22, 0.28, -0.02),
              scale: vm.Vector3(0.11, 0.25, 0.12),
              rotation: vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), -0.24),
            ),
            SceneMesh(
              name: 'linn_feral_right_ear',
              geometry: _sphere,
              material: _feralOrange,
              position: vm.Vector3(0.22, 0.28, -0.02),
              scale: vm.Vector3(0.11, 0.25, 0.12),
              rotation: vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), 0.24),
            ),
            SceneMesh(
              name: 'linn_feral_left_eye',
              geometry: _sphere,
              material: _amber,
              position: vm.Vector3(-0.22, 0.075, 0.23),
              scale: vm.Vector3(0.045, 0.035, 0.025),
            ),
            SceneMesh(
              name: 'linn_feral_right_eye',
              geometry: _sphere,
              material: _amber,
              position: vm.Vector3(0.22, 0.075, 0.23),
              scale: vm.Vector3(0.045, 0.035, 0.025),
            ),
          ],
        ),
        SceneNode(
          name: 'linn_feral_tail',
          position: vm.Vector3(0, 0.88, -0.67),
          rotation: vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), tailSway),
          children: [
            SceneMesh(
              name: 'linn_feral_tail_base',
              geometry: _sphere,
              material: _feralOrange,
              position: vm.Vector3(0, 0.02, -0.22),
              scale: vm.Vector3(0.22, 0.22, 0.38),
            ),
            SceneMesh(
              name: 'linn_feral_tail_mid',
              geometry: _sphere,
              material: _feralOrange,
              position: vm.Vector3(0, 0.07, -0.50),
              scale: vm.Vector3(0.18, 0.19, 0.33),
            ),
            SceneMesh(
              name: 'linn_feral_tail_tip',
              geometry: _sphere,
              material: _feralLight,
              position: vm.Vector3(0, 0.12, -0.72),
              scale: vm.Vector3(0.14, 0.15, 0.24),
            ),
          ],
        ),
        if (widget.attacking)
          SceneMesh(
            name: 'linn_feral_attack_glow',
            geometry: _sphere,
            material: _amber,
            position: vm.Vector3(0, 0.91, 0.92),
            scale: vm.Vector3(0.16, 0.11, 0.13),
          ),
      ],
    );
  }

  Widget _foxLeg(String name, double side, double forward, double swing) {
    return SceneNode(
      name: name,
      position: vm.Vector3(side, 0.63, forward),
      rotation: vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), swing),
      children: [
        SceneMesh(
          name: '${name}_upper',
          geometry: _sphere,
          material: _feralOrange,
          position: vm.Vector3(0, -0.14, 0),
          scale: vm.Vector3(0.14, 0.25, 0.15),
        ),
        SceneMesh(
          name: '${name}_lower',
          geometry: _sphere,
          material: _feralOrange,
          position: vm.Vector3(0, -0.36, 0.025),
          scale: vm.Vector3(0.10, 0.22, 0.11),
        ),
        SceneMesh(
          name: '${name}_paw',
          geometry: _sphere,
          material: _feralLight,
          position: vm.Vector3(0, -0.53, 0.10),
          scale: vm.Vector3(0.14, 0.085, 0.20),
        ),
        SceneMesh(
          name: '${name}_claws',
          geometry: _plate,
          material: _feralDark,
          position: vm.Vector3(0, -0.55, 0.23),
          scale: vm.Vector3(0.15, 0.035, 0.08),
        ),
      ],
    );
  }
}
