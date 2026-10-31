#pragma once

namespace neonbreach {

// Checks whether the system loader, GPU API level, Android surface extensions and
// swapchain extension are present. This deliberately does not create a device or
// replace the active renderer; presentation support is validated in the next stage.
bool probeVulkanRuntime();

} // namespace neonbreach
