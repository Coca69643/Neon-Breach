cmake_minimum_required(VERSION 3.22.1)
project(arena_sim LANGUAGES CXX)

add_library(arena_sim SHARED ArenaSimulation.cpp)

find_library(log-lib log)
target_compile_features(arena_sim PRIVATE cxx_std_20)
target_compile_options(arena_sim PRIVATE
    -O2
    -Wall
    -Wextra
    -Werror
    -fno-exceptions
    -fno-rtti
)
target_link_libraries(arena_sim PRIVATE ${log-lib})
