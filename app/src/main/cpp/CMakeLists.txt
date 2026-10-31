cmake_minimum_required(VERSION 3.22.1)
project(neonbreach LANGUAGES CXX)

include(FetchContent)
set(ENABLE_ALL_WARNINGS OFF CACHE BOOL "" FORCE)
set(GENERATE_DEBUG_SYMBOLS OFF CACHE BOOL "" FORCE)
set(ENABLE_INSTALL OFF CACHE BOOL "" FORCE)
set(INTERPROCEDURAL_OPTIMIZATION OFF CACHE BOOL "" FORCE)
set(JPH_USE_DX12 OFF CACHE BOOL "" FORCE)
set(JPH_USE_VK OFF CACHE BOOL "" FORCE)
set(JPH_USE_MTL OFF CACHE BOOL "" FORCE)
set(JPH_USE_CPU_COMPUTE ON CACHE BOOL "" FORCE)
set(DEBUG_RENDERER_IN_DEBUG_AND_RELEASE OFF CACHE BOOL "" FORCE)
set(PROFILER_IN_DEBUG_AND_RELEASE OFF CACHE BOOL "" FORCE)
set(ENABLE_OBJECT_STREAM OFF CACHE BOOL "" FORCE)
set(CPP_EXCEPTIONS_ENABLED OFF CACHE BOOL "" FORCE)
set(CPP_RTTI_ENABLED OFF CACHE BOOL "" FORCE)

FetchContent_Declare(
    JoltPhysics
    GIT_REPOSITORY https://github.com/jrouwe/JoltPhysics.git
    GIT_TAG v5.6.0
    GIT_SHALLOW TRUE
)
FetchContent_GetProperties(JoltPhysics)
if(NOT joltphysics_POPULATED)
    FetchContent_Populate(JoltPhysics)
    add_subdirectory(${joltphysics_SOURCE_DIR}/Build ${joltphysics_BINARY_DIR})
endif()

add_library(neonbreach SHARED game.cpp PhysicsWorld.cpp ProgressionManager.cpp VulkanRuntime.cpp)
find_library(log-lib log)
find_library(dl-lib dl)
find_library(android-lib android)
target_compile_features(neonbreach PRIVATE cxx_std_17)
target_compile_options(neonbreach PRIVATE -O3 -Wall -Wextra)
target_link_libraries(neonbreach PRIVATE Jolt GLESv3 ${android-lib} ${log-lib} ${dl-lib})
