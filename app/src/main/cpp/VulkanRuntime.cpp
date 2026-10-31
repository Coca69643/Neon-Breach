#include "VulkanRuntime.h"

#include <vulkan/vulkan.h>

#include <android/log.h>
#include <dlfcn.h>

#include <algorithm>
#include <cstdint>
#include <cstring>
#include <string>
#include <vector>

namespace neonbreach {
namespace {

constexpr const char *kLogTag = "ORION-9Vulkan";

bool apiAtLeast11(uint32_t version) {
    return VK_VERSION_MAJOR(version) > 1 ||
        (VK_VERSION_MAJOR(version) == 1 && VK_VERSION_MINOR(version) >= 1);
}

bool containsExtension(const std::vector<VkExtensionProperties> &extensions,
                       const char *name) {
    return std::any_of(extensions.begin(), extensions.end(),
        [name](const VkExtensionProperties &extension) {
            return std::strcmp(extension.extensionName, name) == 0;
        });
}

bool readInstanceExtensions(
    PFN_vkEnumerateInstanceExtensionProperties enumerate,
    std::vector<VkExtensionProperties> &extensions) {
    uint32_t count = 0;
    if (!enumerate || enumerate(nullptr, &count, nullptr) != VK_SUCCESS || count == 0)
        return false;
    extensions.resize(count);
    const VkResult result = enumerate(nullptr, &count, extensions.data());
    if (result != VK_SUCCESS) return false;
    extensions.resize(count);
    return true;
}

bool readDeviceExtensions(
    PFN_vkEnumerateDeviceExtensionProperties enumerate,
    VkPhysicalDevice device,
    std::vector<VkExtensionProperties> &extensions) {
    uint32_t count = 0;
    if (!enumerate || enumerate(device, nullptr, &count, nullptr) != VK_SUCCESS || count == 0)
        return false;
    extensions.resize(count);
    const VkResult result = enumerate(device, nullptr, &count, extensions.data());
    if (result != VK_SUCCESS) return false;
    extensions.resize(count);
    return true;
}

} // namespace

bool probeVulkanRuntime() {
    // dlopen keeps API-23 devices launchable even when libvulkan.so is absent.
    void *loader = dlopen("libvulkan.so", RTLD_NOW | RTLD_LOCAL);
    if (!loader) {
        __android_log_print(ANDROID_LOG_INFO, kLogTag,
            "Vulkan loader unavailable; legacy GLES route remains usable");
        return false;
    }

    const auto getProc = reinterpret_cast<PFN_vkGetInstanceProcAddr>(
        dlsym(loader, "vkGetInstanceProcAddr"));
    if (!getProc) {
        __android_log_print(ANDROID_LOG_WARN, kLogTag,
            "Vulkan loader has no vkGetInstanceProcAddr entry point");
        dlclose(loader);
        return false;
    }

    const auto enumerateInstanceExtensions =
        reinterpret_cast<PFN_vkEnumerateInstanceExtensionProperties>(
            getProc(VK_NULL_HANDLE, "vkEnumerateInstanceExtensionProperties"));
    const auto createInstance =
        reinterpret_cast<PFN_vkCreateInstance>(
            getProc(VK_NULL_HANDLE, "vkCreateInstance"));
    const auto enumerateVersion =
        reinterpret_cast<PFN_vkEnumerateInstanceVersion>(
            getProc(VK_NULL_HANDLE, "vkEnumerateInstanceVersion"));

    uint32_t loaderVersion = VK_API_VERSION_1_0;
    if (enumerateVersion) {
        const VkResult versionResult = enumerateVersion(&loaderVersion);
        if (versionResult != VK_SUCCESS) loaderVersion = VK_API_VERSION_1_0;
    }

    std::vector<VkExtensionProperties> instanceExtensions;
    const bool instanceExtensionsRead =
        readInstanceExtensions(enumerateInstanceExtensions, instanceExtensions);
    const bool hasSurface = instanceExtensionsRead &&
        containsExtension(instanceExtensions, "VK_KHR_surface");
    const bool hasAndroidSurface = instanceExtensionsRead &&
        containsExtension(instanceExtensions, "VK_KHR_android_surface");

    if (!createInstance || !instanceExtensionsRead || !apiAtLeast11(loaderVersion)) {
        __android_log_print(ANDROID_LOG_INFO, kLogTag,
            "Vulkan preflight rejected: loader API=%u.%u.%u, Android surface=%d, surface=%d",
            VK_VERSION_MAJOR(loaderVersion), VK_VERSION_MINOR(loaderVersion),
            VK_VERSION_PATCH(loaderVersion), hasAndroidSurface ? 1 : 0, hasSurface ? 1 : 0);
        dlclose(loader);
        return false;
    }

    VkApplicationInfo applicationInfo{};
    applicationInfo.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
    applicationInfo.pApplicationName = "ORION-9";
    applicationInfo.applicationVersion = VK_MAKE_API_VERSION(0, 0, 9, 3);
    applicationInfo.pEngineName = "Duck Dream Native Runtime";
    applicationInfo.engineVersion = VK_MAKE_API_VERSION(0, 1, 0, 0);
    applicationInfo.apiVersion = VK_API_VERSION_1_1;

    VkInstanceCreateInfo createInfo{};
    createInfo.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    createInfo.pApplicationInfo = &applicationInfo;

    VkInstance instance = VK_NULL_HANDLE;
    const VkResult createResult = createInstance(&createInfo, nullptr, &instance);
    if (createResult != VK_SUCCESS || instance == VK_NULL_HANDLE) {
        __android_log_print(ANDROID_LOG_WARN, kLogTag,
            "vkCreateInstance failed with VkResult=%d", static_cast<int>(createResult));
        dlclose(loader);
        return false;
    }

    const auto destroyInstance =
        reinterpret_cast<PFN_vkDestroyInstance>(getProc(instance, "vkDestroyInstance"));
    const auto enumerateDevices =
        reinterpret_cast<PFN_vkEnumeratePhysicalDevices>(
            getProc(instance, "vkEnumeratePhysicalDevices"));
    const auto getProperties =
        reinterpret_cast<PFN_vkGetPhysicalDeviceProperties>(
            getProc(instance, "vkGetPhysicalDeviceProperties"));
    const auto enumerateDeviceExtensions =
        reinterpret_cast<PFN_vkEnumerateDeviceExtensionProperties>(
            getProc(instance, "vkEnumerateDeviceExtensionProperties"));

    bool qualifiedDevice = false;
    if (enumerateDevices && getProperties && enumerateDeviceExtensions) {
        uint32_t deviceCount = 0;
        VkResult result = enumerateDevices(instance, &deviceCount, nullptr);
        if (result == VK_SUCCESS && deviceCount > 0) {
            std::vector<VkPhysicalDevice> devices(deviceCount);
            result = enumerateDevices(instance, &deviceCount, devices.data());
            if (result == VK_SUCCESS) {
                devices.resize(deviceCount);
                for (VkPhysicalDevice device : devices) {
                    VkPhysicalDeviceProperties properties{};
                    getProperties(device, &properties);

                    std::vector<VkExtensionProperties> deviceExtensions;
                    const bool deviceExtensionsRead =
                        readDeviceExtensions(enumerateDeviceExtensions, device, deviceExtensions);
                    const bool hasSwapchain = deviceExtensionsRead &&
                        containsExtension(deviceExtensions, "VK_KHR_swapchain");
                    const bool api11 = apiAtLeast11(properties.apiVersion);

                    __android_log_print(ANDROID_LOG_INFO, kLogTag,
                        "GPU=%s vendor=0x%04x device=0x%04x API=%u.%u.%u swapchain=%d",
                        properties.deviceName, properties.vendorID, properties.deviceID,
                        VK_VERSION_MAJOR(properties.apiVersion), VK_VERSION_MINOR(properties.apiVersion),
                        VK_VERSION_PATCH(properties.apiVersion), hasSwapchain ? 1 : 0);

                    if (api11 && hasSwapchain && hasSurface && hasAndroidSurface) {
                        qualifiedDevice = true;
                        break;
                    }
                }
            } else {
                __android_log_print(ANDROID_LOG_WARN, kLogTag,
                    "vkEnumeratePhysicalDevices(list) failed with VkResult=%d",
                    static_cast<int>(result));
            }
        } else {
            __android_log_print(ANDROID_LOG_WARN, kLogTag,
                "No Vulkan physical devices; VkResult=%d count=%u",
                static_cast<int>(result), deviceCount);
        }
    }

    if (destroyInstance) destroyInstance(instance, nullptr);
    dlclose(loader);

    __android_log_print(qualifiedDevice ? ANDROID_LOG_INFO : ANDROID_LOG_WARN, kLogTag,
        "Vulkan preflight %s (loader API=%u.%u.%u, Android surface=%d, surface=%d)",
        qualifiedDevice ? "passed" : "not qualified",
        VK_VERSION_MAJOR(loaderVersion), VK_VERSION_MINOR(loaderVersion),
        VK_VERSION_PATCH(loaderVersion), hasAndroidSurface ? 1 : 0, hasSurface ? 1 : 0);

    return qualifiedDevice;
}

} // namespace neonbreach
