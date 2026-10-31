#include "ProgressionManager.h"

#include <cassert>

int main() {
    neonbreach::ProgressionManager progression;

    progression.reset();
    assert(progression.totalEliminations() == 0);
    assert(progression.sectorIndex() == 0);

    for (int kill = 1; kill < neonbreach::ProgressionManager::KILLS_PER_SECTOR; ++kill) {
        assert(!progression.registerElimination());
    }
    assert(progression.totalEliminations() == 19);
    assert(progression.sectorIndex() == 0);

    assert(progression.registerElimination());
    assert(progression.totalEliminations() == 20);
    assert(progression.sectorIndex() == 1);

    for (int kill = 21; kill < 40; ++kill) {
        assert(!progression.registerElimination());
    }
    assert(progression.registerElimination());
    assert(progression.totalEliminations() == 40);
    assert(progression.sectorIndex() == 2);

    progression.reset();
    assert(progression.totalEliminations() == 0);
    assert(progression.sectorIndex() == 0);
    return 0;
}
