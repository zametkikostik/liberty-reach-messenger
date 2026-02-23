cmake_minimum_required(VERSION 3.20)
project(liberty_reach_voip VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Options
option(BUILD_TESTS "Build tests" ON)

# Find dependencies
find_package(PkgConfig REQUIRED)
pkg_check_modules(GSTREAMER REQUIRED gstreamer-1.0 gstreamer-app-1.0)
pkg_check_modules(OPUS REQUIRED opus)

# For WebRTC (in production, use actual WebRTC SDK)
# For now, we'll use a simplified approach with GStreamer

# Source files
set(SOURCES
    src/voip_manager.cpp
)

set(HEADERS
    include/voip_manager.h
)

# Create library
add_library(liberty_reach_voip STATIC ${SOURCES})

target_include_directories(liberty_reach_voip PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${GSTREAMER_INCLUDE_DIRS}
    ${OPUS_INCLUDE_DIRS}
)

target_link_libraries(liberty_reach_voip PUBLIC
    ${GSTREAMER_LIBRARIES}
    ${OPUS_LIBRARIES}
    liberty_reach_crypto
)

target_compile_options(liberty_reach_voip PRIVATE
    -Wall
    -Wextra
    -O3
)

# Install
install(TARGETS liberty_reach_voip
    ARCHIVE DESTINATION lib
    LIBRARY DESTINATION lib
)

install(FILES ${HEADERS}
    DESTINATION include/liberty_reach/voip
)
