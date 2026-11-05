cmake_minimum_required(VERSION 3.22)

project(arena_agent_fsm LANGUAGES CXX)

add_library(arena_agent_fsm
    src/ai/agent_state_machine.cpp
)

target_include_directories(arena_agent_fsm
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_compile_features(arena_agent_fsm PUBLIC cxx_std_20)

if(MSVC)
    target_compile_options(arena_agent_fsm PRIVATE /W4 /WX)
else()
    target_compile_options(arena_agent_fsm PRIVATE -Wall -Wextra -Wpedantic -Werror)
endif()

include(CTest)

if(BUILD_TESTING)
    add_executable(arena_agent_fsm_tests
        tests/agent_state_machine_test.cpp
    )

    target_link_libraries(arena_agent_fsm_tests PRIVATE arena_agent_fsm)

    if(MSVC)
        target_compile_options(arena_agent_fsm_tests PRIVATE /W4 /WX)
    else()
        target_compile_options(arena_agent_fsm_tests PRIVATE -Wall -Wextra -Wpedantic -Werror)
    endif()

    add_test(NAME arena_agent_fsm_tests COMMAND arena_agent_fsm_tests)
endif()
