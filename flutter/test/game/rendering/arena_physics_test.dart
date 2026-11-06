// ignore_for_file: invalid_use_of_internal_member

import 'package:flutter_scene/physics.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_scene_rapier/flutter_scene_rapier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

(Node, PhysicsWorld) _createPhysicsWorld() {
  final root = Node();
  final world = PhysicsWorld(
    RapierWorld(gravity: Vector3(0, -18.0, 0)),
  );
  root.addComponent(world);
  world.mount();
  return (root, world);
}

void _addBox(
  Node root,
  Vector3 position,
  Vector3 halfExtents, {
  String name = 'static_box',
}) {
  final node = Node(
    name: name,
    localTransform: Matrix4.translation(position),
  );
  node.addComponent(RigidBody(type: BodyType.fixed));
  node.addComponent(Collider(shape: BoxShape(halfExtents: halfExtents)));
  root.add(node);
  node.getComponents<RigidBody>().first.mount();
  node.getComponents<Collider>().first.mount();
}

(Node, RigidBody) _addDynamicBox(Node root, Vector3 position) {
  final node = Node(localTransform: Matrix4.translation(position));
  final body = RigidBody(type: BodyType.dynamic_, mass: 1.0);
  node.addComponent(body);
  node.addComponent(
    Collider(shape: BoxShape(halfExtents: Vector3.all(0.5))),
  );
  root.add(node);
  body.mount();
  node.getComponents<Collider>().first.mount();
  return (node, body);
}

(Node, KinematicCharacterController) _addCharacter(
  Node root,
  Vector3 position,
) {
  final node = Node(localTransform: Matrix4.translation(position));
  node.addComponent(RigidBody(type: BodyType.kinematic));
  node.addComponent(
    Collider(shape: CapsuleShape(radius: 0.3, halfHeight: 0.5)),
  );
  final controller = KinematicCharacterController(
    snapToGround: 0.1,
    autostep: true,
    autostepMaxHeight: 0.3,
  );
  node.addComponent(controller);
  root.add(node);
  node.getComponents<RigidBody>().first.mount();
  node.getComponents<Collider>().first.mount();
  controller.mount();
  return (node, controller);
}

void main() {
  setUpAll(RapierWorld.ensureInitialized);

  test('Rapier applies gravity and blocks a kinematic character at a wall', () {
    final (root, world) = _createPhysicsWorld();
    _addBox(
      root,
      Vector3(0, -0.5, 0),
      Vector3(10, 0.5, 10),
      name: 'ground',
    );
    _addBox(
      root,
      Vector3(1.0, 1.0, 0),
      Vector3(0.1, 2.0, 5.0),
      name: 'wall',
    );
    final (_, fallingBody) = _addDynamicBox(root, Vector3(4, 5, 0));

    // Build the broad phase, then simulate two seconds under gravity.
    world.step(1.0 / 60.0);
    for (var i = 0; i < 120; i++) {
      world.step(1.0 / 60.0);
    }
    final settledY = fallingBody.readSimulationPose().$1.y;
    expect(settledY, lessThan(5.0));
    expect(settledY, closeTo(0.5, 0.12));

    final (characterNode, controller) = _addCharacter(
      root,
      Vector3(0, 0.8, 0),
    );
    world.step(1.0 / 60.0);

    final movement = controller.move(
      Vector3(1.0, 0, 0),
      deltaSeconds: 1.0 / 30.0,
    );
    expect(movement.translation.x, greaterThan(0));
    expect(movement.translation.x, lessThan(0.8));
    expect(
      characterNode.globalTransform.getTranslation().x,
      lessThan(0.8),
    );
  });
}
