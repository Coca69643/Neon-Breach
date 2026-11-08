import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_scene/scene.dart' hide Material;
import 'package:vector_math/vector_math.dart' as vm;

/// Procedural, low-draw-call-count synthetic prototype.
///
/// The body is assembled from cached primitive geometry. It is deliberately
/// separate from MobaHeroId and the production roster until the final rig and
/// animation package are ready.
class ArenaSyntheticHeroModel extends StatelessWidget {
  const ArenaSyntheticHeroModel({
    super.key,
    required this.position,
    required this.facingRadians,
    required this.gaitPhase,
    required this.speedRatio,
    required this.airborne,
  });

  final vm.Vector3 position;
  final double facingRadians;
  final double gaitPhase;
  final double speedRatio;
  final bool airborne;

  static final CuboidGeometry _torso = CuboidGeometry(vm.Vector3(0.56, 0.70, 0.34));
  static final CuboidGeometry _chestPlate = CuboidGeometry(vm.Vector3(0.48, 0.47, 0.12));
  static final CuboidGeometry _head = CuboidGeometry(vm.Vector3(0.42, 0.40, 0.36));
  static final CuboidGeometry _visor = CuboidGeometry(vm.Vector3(0.32, 0.105, 0.055));
  static final CuboidGeometry _core = CuboidGeometry(vm.Vector3(0.15, 0.19, 0.055));
  static final CuboidGeometry _shoulder = CuboidGeometry(vm.Vector3(0.29, 0.22, 0.31));
  static final CuboidGeometry _arm = CuboidGeometry(vm.Vector3(0.21, 0.58, 0.23));
  static final CuboidGeometry _hand = CuboidGeometry(vm.Vector3(0.18, 0.16, 0.19));
  static final CuboidGeometry _hip = CuboidGeometry(vm.Vector3(0.48, 0.22, 0.30));
  static final CuboidGeometry _leg = CuboidGeometry(vm.Vector3(0.24, 0.68, 0.25));
  static final CuboidGeometry _boot = CuboidGeometry(vm.Vector3(0.28, 0.15, 0.42));
  static final CuboidGeometry _backpack = CuboidGeometry(vm.Vector3(0.34, 0.46, 0.18));
  static final CuboidGeometry _antenna = CuboidGeometry(vm.Vector3(0.055, 0.17, 0.055));

  static final UnlitMaterial _shell = UnlitMaterial()
    ..baseColorFactor = vm.Vector4(0.66, 0.76, 0.78, 1);
  static final UnlitMaterial _shellLight = UnlitMaterial()
    ..baseColorFactor = vm.Vector4(0.83, 0.88, 0.88, 1);
  static final UnlitMaterial _dark = UnlitMaterial()
    ..baseColorFactor = vm.Vector4(0.075, 0.12, 0.15, 1);
  static final UnlitMaterial _cyan = UnlitMaterial()
    ..baseColorFactor = vm.Vector4(0.13, 0.86, 0.79, 1);
  static final UnlitMaterial _amber = UnlitMaterial()
    ..baseColorFactor = vm.Vector4(0.96, 0.58, 0.22, 1);

  static vm.Quaternion _swing(double angle) =>
      vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), angle);

  @override
  Widget build(BuildContext context) {
    final gait = speedRatio.clamp(0.0, 1.25).toDouble();
    final stride = math.sin(gaitPhase) * 0.48 * gait;
    final armLift = airborne ? -0.28 : 0.0;
    final bob = airborne ? 0.0 : math.sin(gaitPhase * 2) * 0.022 * gait;

    return SceneNode(
      name: 'synthetic_01_root',
      position: position,
      rotation: vm.Quaternion.axisAngle(
        vm.Vector3(0, 1, 0),
        facingRadians,
      ),
      children: [
        SceneNode(
          name: 'synthetic_01_body',
          position: vm.Vector3(0, bob, 0),
          children: [
            SceneMesh(
              name: 'synthetic_01_backpack',
              geometry: _backpack,
              material: _dark,
              position: vm.Vector3(0, 1.14, -0.25),
            ),
            SceneMesh(
              name: 'synthetic_01_torso',
              geometry: _torso,
              material: _shell,
              position: vm.Vector3(0, 1.12, 0),
            ),
            SceneMesh(
              name: 'synthetic_01_chest_plate',
              geometry: _chestPlate,
              material: _shellLight,
              position: vm.Vector3(0, 1.14, 0.205),
            ),
            SceneMesh(
              name: 'synthetic_01_energy_core',
              geometry: _core,
              material: _cyan,
              position: vm.Vector3(0, 1.20, 0.282),
            ),
            SceneMesh(
              name: 'synthetic_01_hip',
              geometry: _hip,
              material: _dark,
              position: vm.Vector3(0, 0.70, 0),
            ),
            SceneMesh(
              name: 'synthetic_01_head',
              geometry: _head,
              material: _shellLight,
              position: vm.Vector3(0, 1.77, 0.015),
            ),
            SceneMesh(
              name: 'synthetic_01_visor',
              geometry: _visor,
              material: _dark,
              position: vm.Vector3(0, 1.78, 0.225),
            ),
            SceneMesh(
              name: 'synthetic_01_visor_light',
              geometry: _visor,
              material: _cyan,
              position: vm.Vector3(0, 1.78, 0.261),
            ),
            SceneMesh(
              name: 'synthetic_01_antenna',
              geometry: _antenna,
              material: _amber,
              position: vm.Vector3(0.14, 2.065, -0.02),
            ),
antenna base
            SceneMesh(
              name: 'synthetic_01_shoulder_left',
              geometry: _shoulder,
              material: _shellLight,
              position: vm.Vector3(-0.43, 1.48, 0),
            ),
            SceneMesh(
              name: 'synthetic_01_shoulder_right',
              geometry: _shoulder,
              material: _shellLight,
              position: vm.Vector3(0.43, 1.48, 0),
            ),
            SceneNode(
              name: 'synthetic_01_arm_left',
              position: vm.Vector3(-0.46, 1.40, 0),
              rotation: _swing(stride + armLift),
              children: [
                SceneMesh(
                  name: 'synthetic_01_arm_left_mesh',
                  geometry: _arm,
                  material: _shell,
                  position: vm.Vector3(0, -0.29, 0),
                ),
                SceneMesh(
                  name: 'synthetic_01_hand_left',
                  geometry: _hand,
                  material: _dark,
                  position: vm.Vector3(0, -0.63, 0.045),
                ),
              ],
            ),
            SceneNode(
              name: 'synthetic_01_arm_right',
              position: vm.Vector3(0.46, 1.40, 0),
              rotation: _swing(-stride + armLift),
              children: [
                SceneMesh(
                  name: 'synthetic_01_arm_right_mesh',
                  geometry: _arm,
                  material: _shell,
                  position: vm.Vector3(0, -0.29, 0),
                ),
                SceneMesh(
                  name: 'synthetic_01_hand_right',
                  geometry: _hand,
                  material: _dark,
                  position: vm.Vector3(0, -0.63, 0.045),
                ),
              ],
            ),
            SceneNode(
              name: 'synthetic_01_leg_left',
              position: vm.Vector3(-0.145, 0.75, 0),
              rotation: _swing(-stride),
              children: [
                SceneMesh(
                  name: 'synthetic_01_leg_left_mesh',
                  geometry: _leg,
                  material: _shell,
                  position: vm.Vector3(0, -0.34, 0),
                ),
                SceneMesh(
                  name: 'synthetic_01_boot_left',
                  geometry: _boot,
                  material: _dark,
                  position: vm.Vector3(0, -0.70, 0.085),
                ),
              ],
            ),
            SceneNode(
              name: 'synthetic_01_leg_right',
              position: vm.Vector3(0.145, 0.75, 0),
              rotation: _swing(stride),
              children: [
                SceneMesh(
                  name: 'synthetic_01_leg_right_mesh',
                  geometry: _leg,
                  material: _shell,
                  position: vm.Vector3(0, -0.36, 0),
                ),
                SceneMesh(
                  name: 'synthetic_01_boot_right',
                  geometry: _boot,
                  material: _dark,
                  position: vm.Vector3(0, -0.72, 0.085),
                ),
              ],
            ),
            SceneMesh(
              name: 'synthetic_01_arm_band_left',
              geometry: _hand,
              material: _amber,
              position: vm.Vector3(-0.46, 0.99, 0.02),
              scale: vm.Vector3(0.9, 0.35, 1.05),
            ),
            SceneMesh(
              name: 'synthetic_01_arm_band_right',
              geometry: _hand,
              material: _amber,
              position: vm.Vector3(0.46, 0.99, 0.02),
              scale: vm.Vector3(0.9, 0.35, 1.05),
            ),
          ],
        ),
      ],
    );
  }
}

/// Full-bleed 3D stage for the selector's experimental synthetic preview.
class ArenaSyntheticHeroStage extends StatelessWidget {
  const ArenaSyntheticHeroStage({super.key});

  @override
  Widget build(BuildContext context) {
    return SceneView.declarative(
      pixelRatio: 0.82,
      maxFrameRate: 30,
      cameraBuilder: (_) => PerspectiveCamera(
        fovRadiansY: 42 * math.pi / 180,
        position: vm.Vector3(0, 2.6, -5.8),
        target: vm.Vector3(0, 1.0, 0),
      ),
      children: [
        ArenaSyntheticHeroModel(
          position: vm.Vector3(0, 0, 0),
          facingRadians: 0,
          gaitPhase: 0,
          speedRatio: 0,
          airborne: false,
        ),
      ],
    );
  }
}
