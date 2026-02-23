cmake_minimum_required(VERSION 3.20)
project(liberty_reach_mesh VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

option(BUILD_TESTS "Build tests" ON)

# Source files
set(SOURCES
    src/mesh_network.cpp
)

set(HEADERS
    include/mesh_network.h
)

# Create library
add_library(liberty_reach_mesh STATIC ${SOURCES})

target_include_directories(liberty_reach_mesh PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(liberty_reach_mesh PUBLIC
    liberty_reach_crypto
)

target_compile_options(liberty_reach_mesh PRIVATE
    -Wall
    -Wextra
    -O3
)

# Install
install(TARGETS liberty_reach_mesh
    ARCHIVE DESTINATION lib
    LIBRARY DESTINATION lib
)

install(FILES ${HEADERS}
    DESTINATION include/liberty_reach/mesh
)
