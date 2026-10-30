#include "ProgressionManager.h"
namespace neonbreach {
void ProgressionManager::reset() noexcept {
    totalEliminations_ = 0;
    sectorIndex_ = 0;
}
bool ProgressionManager::registerElimination() noexcept {
    ++totalEliminations_;
    const int nextUnlock = (sectorIndex_ + 1) * KILLS_PER_SECTOR;
    if (totalEliminations_ >= nextUnlock) {
        ++sectorIndex_;
        return true;
    }
    return false;
}
int ProgressionManager::totalEliminations() const noexcept { return totalEliminations_; }
int ProgressionManager::sectorIndex() const noexcept { return sectorIndex_; }
float ProgressionManager::minX() const noexcept { return -6.10f; }
float ProgressionManager::maxX() const noexcept { return 6.10f + 9.20f * static_cast<float>(sectorIndex_); }
float ProgressionManager::minZ() const noexcept { return -4.30f; }
float ProgressionManager::maxZ() const noexcept { return 4.30f; }
SectorPalette ProgressionManager::palette() const noexcept {
    switch (sectorIndex_ % 3) {
        case 1: return {0.34f, 0.16f, 0.045f};
        case 2: return {0.12f, 0.08f, 0.36f};
        default: return {0.025f, 0.16f, 0.22f};
    }
}
}
