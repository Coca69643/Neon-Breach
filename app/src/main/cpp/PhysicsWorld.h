#pragma once

#include <vector>

namespace neonbreach {

struct PhysicsBox {
    float x = 0.0f;
    float y = 0.0f;
    float z = 0.0f;
    float halfX = 0.5f;
    float halfY = 0.5f;
    float halfZ = 0.5f;
};

struct PhysicsGate {
    PhysicsBox box;
    bool open = false;
};

class PhysicsWorld final {
public:
    PhysicsWorld();
    ~PhysicsWorld();
    PhysicsWorld(const PhysicsWorld &) = delete;
    PhysicsWorld &operator=(const PhysicsWorld &) = delete;

    bool initialize();
    void rebuild(const std::vector<PhysicsBox> &staticBoxes,
                 const std::vector<PhysicsGate> &gates);
    void setGateOpen(std::size_t gateIndex, bool open);
    void setCharacterPosition(float x, float z, float y = 0.0f);
    void moveCharacter(float velocityX, float velocityZ, float deltaTime);
    bool getCharacterPosition(float &x, float &y, float &z) const;
    bool ready() const;

private:
    struct Impl;
    Impl *impl_;
};

} // namespace neonbreach
