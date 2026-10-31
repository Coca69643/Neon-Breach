#include "PhysicsWorld.h"

#include <Jolt/Jolt.h>
#include <Jolt/RegisterTypes.h>
#include <Jolt/Core/Factory.h>
#include <Jolt/Core/TempAllocator.h>
#include <Jolt/Physics/PhysicsSystem.h>
#include <Jolt/Physics/Body/BodyCreationSettings.h>
#include <Jolt/Physics/Collision/Shape/BoxShape.h>
#include <Jolt/Physics/Collision/Shape/CapsuleShape.h>
#include <Jolt/Physics/Character/CharacterVirtual.h>

#include <android/log.h>
#include <algorithm>
#include <array>
#include <cstdarg>
#include <cstdio>
#include <mutex>
#include <vector>

namespace neonbreach {
namespace {

using namespace JPH;

namespace Layers {
static constexpr ObjectLayer NON_MOVING = 0;
static constexpr ObjectLayer MOVING = 1;
static constexpr ObjectLayer NUM_LAYERS = 2;
}

namespace BroadPhaseLayers {
static constexpr BroadPhaseLayer NON_MOVING(0);
static constexpr BroadPhaseLayer MOVING(1);
static constexpr uint NUM_LAYERS = 2;
}

class BroadPhaseLayerInterfaceImpl final : public BroadPhaseLayerInterface {
public:
    uint GetNumBroadPhaseLayers() const override {
        return BroadPhaseLayers::NUM_LAYERS;
    }

    BroadPhaseLayer GetBroadPhaseLayer(ObjectLayer layer) const override {
        JPH_ASSERT(layer < Layers::NUM_LAYERS);
        return layer == Layers::MOVING ? BroadPhaseLayers::MOVING
                                       : BroadPhaseLayers::NON_MOVING;
    }

#if defined(JPH_EXTERNAL_PROFILE) || defined(JPH_PROFILE_ENABLED)
    const char *GetBroadPhaseLayerName(BroadPhaseLayer layer) const override {
        return layer == BroadPhaseLayers::MOVING ? "MOVING" : "NON_MOVING";
    }
#endif
};

class ObjectVsBroadPhaseLayerFilterImpl final : public ObjectVsBroadPhaseLayerFilter {
public:
    bool ShouldCollide(ObjectLayer layer, BroadPhaseLayer broadPhase) const override {
        if (layer == Layers::NON_MOVING) return broadPhase == BroadPhaseLayers::MOVING;
        return true;
    }
};

class ObjectLayerPairFilterImpl final : public ObjectLayerPairFilter {
public:
    bool ShouldCollide(ObjectLayer first, ObjectLayer second) const override {
        return first == Layers::MOVING || second == Layers::MOVING;
    }
};

std::once_flag gJoltInit;
void traceJolt(const char *format, ...) {
    char buffer[1024];
    va_list args;
    va_start(args, format);
    std::vsnprintf(buffer, sizeof(buffer), format, args);
    va_end(args);
    __android_log_print(ANDROID_LOG_INFO, "NeonBreachPhysics", "%s", buffer);
}

void initializeJoltOnce() {
    RegisterDefaultAllocator();
    Trace = traceJolt;
    Factory::sInstance = new Factory();
    RegisterTypes();
}

} // namespace

struct PhysicsWorld::Impl {
    BroadPhaseLayerInterfaceImpl broadPhase;
    ObjectVsBroadPhaseLayerFilterImpl objectVsBroadPhase;
    ObjectLayerPairFilterImpl objectPairs;
    PhysicsSystem system;
    TempAllocatorImpl allocator{2 * 1024 * 1024};
    Ref<CharacterVirtual> character;
    std::vector<BodyID> staticBodies;
    struct GateState {
        BodyID body;
        PhysicsBox box;
        bool open = false;
    };
    std::vector<GateState> gates;
    bool initialized = false;

    BodyID addBox(const PhysicsBox &box) {
        if (!initialized || box.halfX <= 0.0f || box.halfY <= 0.0f || box.halfZ <= 0.0f)
            return BodyID();

        RefConst<Shape> shape = new BoxShape(Vec3(box.halfX, box.halfY, box.halfZ), 0.02f);
        BodyCreationSettings settings(shape,
            RVec3(box.x, box.y, box.z),
            Quat::sIdentity(),
            EMotionType::Static,
            Layers::NON_MOVING);
        return system.GetBodyInterface().CreateAndAddBody(settings, EActivation::DontActivate);
    }

    void removeBody(BodyID id) {
        if (id.IsInvalid()) return;
        BodyInterface &bodyInterface = system.GetBodyInterface();
        if (bodyInterface.IsAdded(id)) bodyInterface.RemoveBody(id);
        bodyInterface.DestroyBody(id);
    }

    void clearGeometry() {
        character = nullptr;
        for (BodyID id : staticBodies) removeBody(id);
        staticBodies.clear();
        for (auto &gate : gates) {
            removeBody(gate.body);
            gate.body = BodyID();
        }
        gates.clear();
    }

    void refreshCharacterContacts() {
        if (!character) return;
        character->RefreshContacts(
            system.GetDefaultBroadPhaseLayerFilter(Layers::MOVING),
            system.GetDefaultLayerFilter(Layers::MOVING),
            {}, {}, allocator);
    }

    void createCharacter(float x, float z, float y) {
        Ref<CapsuleShape> capsule = new CapsuleShape(0.48f, 0.29f);
        Ref<CharacterVirtualSettings> settings = new CharacterVirtualSettings();
        settings->mShape = capsule;
        settings->mShapeOffset = Vec3(0.0f, 0.77f, 0.0f);
        settings->mSupportingVolume = Plane(Vec3::sAxisY(), -0.29f);
        settings->mMaxSlopeAngle = DegreesToRadians(48.0f);
        settings->mCharacterPadding = 0.035f;
        settings->mPredictiveContactDistance = 0.10f;
        settings->mEnhancedInternalEdgeRemoval = true;
        character = new CharacterVirtual(settings, RVec3(x, y, z), Quat::sIdentity(), &system);
        character->SetLinearVelocity(Vec3::sZero());
    }
};

PhysicsWorld::PhysicsWorld() : impl_(new Impl()) {}

PhysicsWorld::~PhysicsWorld() {
    if (impl_) {
        impl_->clearGeometry();
        delete impl_;
        impl_ = nullptr;
    }
}

bool PhysicsWorld::initialize() {
    if (!impl_) return false;
    std::call_once(gJoltInit, initializeJoltOnce);
    if (!impl_->initialized) {
        constexpr uint maxBodies = 512;
        constexpr uint maxBodyPairs = 1024;
        constexpr uint maxContactConstraints = 1024;
        impl_->system.Init(maxBodies, 0, maxBodyPairs, maxContactConstraints,
            impl_->broadPhase, impl_->objectVsBroadPhase, impl_->objectPairs);
        impl_->initialized = true;
        __android_log_print(ANDROID_LOG_INFO, "NeonBreachPhysics",
            "Jolt Physics 5.6.0 initialized (Android native, 2-layer broadphase)");
    }
    return impl_->initialized;
}

void PhysicsWorld::rebuild(const std::vector<PhysicsBox> &staticBoxes,
                           const std::vector<PhysicsGate> &gateBoxes) {
    if (!initialize()) return;
    impl_->clearGeometry();
    impl_->staticBodies.reserve(staticBoxes.size());
    for (const PhysicsBox &box : staticBoxes) {
        BodyID id = impl_->addBox(box);
        if (!id.IsInvalid()) impl_->staticBodies.push_back(id);
    }
    impl_->gates.reserve(gateBoxes.size());
    for (const PhysicsGate &gate : gateBoxes) {
        Impl::GateState state;
        state.box = gate.box;
        state.open = gate.open;
        state.body = gate.open ? BodyID() : impl_->addBox(gate.box);
        impl_->gates.push_back(state);
    }
    impl_->system.OptimizeBroadPhase();
    impl_->createCharacter(0.0f, 0.0f, 0.0f);
    __android_log_print(ANDROID_LOG_INFO, "NeonBreachPhysics",
        "Facility collision world rebuilt: %zu static colliders, %zu energy gates",
        impl_->staticBodies.size(), impl_->gates.size());
}

void PhysicsWorld::setGateOpen(std::size_t gateIndex, bool open) {
    if (!impl_ || gateIndex >= impl_->gates.size()) return;
    auto &gate = impl_->gates[gateIndex];
    if (gate.open == open) return;
    if (open) {
        impl_->removeBody(gate.body);
        gate.body = BodyID();
    } else {
        gate.body = impl_->addBox(gate.box);
    }
    gate.open = open;
    impl_->refreshCharacterContacts();
}

void PhysicsWorld::setCharacterPosition(float x, float z, float y) {
    if (!impl_ || !impl_->initialized) return;
    if (!impl_->character) impl_->createCharacter(x, z, y);
    impl_->character->SetPosition(RVec3(x, y, z));
    impl_->character->SetLinearVelocity(Vec3::sZero());
    impl_->refreshCharacterContacts();
}

void PhysicsWorld::moveCharacter(float velocityX, float velocityZ, float deltaTime) {
    if (!impl_ || !impl_->character || deltaTime <= 0.0f) return;
    const Vec3 current = impl_->character->GetLinearVelocity();
    // ExtendedUpdate applies gravity exactly once using its gravity argument.
    const Vec3 velocity(velocityX, current.GetY(), velocityZ);
    impl_->character->SetLinearVelocity(velocity);
    CharacterVirtual::ExtendedUpdateSettings update;
    update.mStickToFloorStepDown = Vec3(0.0f, -0.56f, 0.0f);
    update.mWalkStairsStepUp = Vec3(0.0f, 0.38f, 0.0f);
    update.mWalkStairsMinStepForward = 0.03f;
    update.mWalkStairsStepForwardTest = 0.15f;
    impl_->character->ExtendedUpdate(
        deltaTime,
        Vec3(0.0f, -9.81f, 0.0f),
        update,
        impl_->system.GetDefaultBroadPhaseLayerFilter(Layers::MOVING),
        impl_->system.GetDefaultLayerFilter(Layers::MOVING),
        {}, {},
        impl_->allocator);
}

bool PhysicsWorld::getCharacterPosition(float &x, float &y, float &z) const {
    if (!impl_ || !impl_->character) return false;
    const RVec3 p = impl_->character->GetPosition();
    x = (float)p.GetX();
    y = (float)p.GetY();
    z = (float)p.GetZ();
    return true;
}

bool PhysicsWorld::ready() const {
    return impl_ && impl_->initialized && impl_->character != nullptr;
}

} // namespace neonbreach
