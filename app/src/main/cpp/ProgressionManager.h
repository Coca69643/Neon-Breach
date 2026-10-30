#pragma once
namespace neonbreach {
struct SectorPalette { float r; float g; float b; };
class ProgressionManager {
public:
    static constexpr int KILLS_PER_SECTOR = 20;
    void reset() noexcept;
    bool registerElimination() noexcept;
    int totalEliminations() const noexcept;
    int sectorIndex() const noexcept;
    float minX() const noexcept;
    float maxX() const noexcept;
    float minZ() const noexcept;
    float maxZ() const noexcept;
    SectorPalette palette() const noexcept;
private:
    int totalEliminations_ = 0;
    int sectorIndex_ = 0;
};
}
