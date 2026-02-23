cmake_minimum_required(VERSION 3.20)
project(LibertyReachMessenger VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Build options
option(BUILD_TESTS "Build tests" ON)
option(BUILD_DESKTOP "Build Desktop client" ON)
option(BUILD_CLI "Build CLI client" ON)
option(BUILD_FULL "Build full integrated version" ON)

# Build type
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

# Compiler flags
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra -Wno-unused-parameter")
set(CMAKE_CXX_FLAGS_DEBUG "-g -O0")
set(CMAKE_CXX_FLAGS_RELEASE "-O3 -DNDEBUG")

# Find required packages
find_package(PkgConfig REQUIRED)
pkg_check_modules(OPENSSL REQUIRED openssl)
pkg_check_modules(SODIUM REQUIRED libsodium)
pkg_check_modules(CURL REQUIRED libcurl)

# ============================================
# Crypto Core (Rust + C++)
# ============================================

# Build Rust library
execute_process(
    COMMAND cargo build --release
    WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/core/crypto
    RESULT_VARIABLE RUST_BUILD_RESULT
)

if(NOT RUST_BUILD_RESULT EQUAL 0)
    message(FATAL_ERROR "Rust build failed!")
endif()

# Find Rust library
find_library(RUST_CRYPTO_LIB
    NAMES liberty_reach_crypto
    PATHS ${CMAKE_SOURCE_DIR}/core/crypto/target/release
)

# C++ crypto wrapper
add_library(liberty_reach_crypto_cpp STATIC
    core/src/liberty_reach_crypto.cpp
    core/src/keys.cpp
    core/src/session.cpp
    core/src/ratchet.cpp
    core/src/steganography.cpp
    core/src/profile.cpp
    core/src/utils.cpp
    core/src/network_client.cpp
)

target_include_directories(liberty_reach_crypto_cpp PUBLIC
    ${CMAKE_SOURCE_DIR}/core/include
    ${OPENSSL_INCLUDE_DIRS}
    ${SODIUM_INCLUDE_DIRS}
)

target_link_libraries(liberty_reach_crypto_cpp PUBLIC
    ${RUST_CRYPTO_LIB}
    ${OPENSSL_LIBRARIES}
    ${SODIUM_LIBRARIES}
    ${CURL_LIBRARIES}
    blake3
)

# ============================================
# VoIP Module
# ============================================

pkg_check_modules(GSTREAMER gstreamer-1.0 gstreamer-app-1.0)
pkg_check_modules(OPUS opus)

if(GSTREAMER_FOUND AND OPUS_FOUND)
    add_library(liberty_reach_voip STATIC
        webrtc/src/voip_manager.cpp
    )
    
    target_include_directories(liberty_reach_voip PUBLIC
        ${CMAKE_SOURCE_DIR}/webrtc/include
        ${GSTREAMER_INCLUDE_DIRS}
        ${OPUS_INCLUDE_DIRS}
    )
    
    target_link_libraries(liberty_reach_voip PUBLIC
        liberty_reach_crypto_cpp
        ${GSTREAMER_LIBRARIES}
        ${OPUS_LIBRARIES}
    )
else()
    message(WARNING "GStreamer or Opus not found, VoIP disabled")
    add_library(liberty_reach_voip STATIC webrtc/src/voip_manager.cpp)
    target_include_directories(liberty_reach_voip PUBLIC ${CMAKE_SOURCE_DIR}/webrtc/include)
    target_link_libraries(liberty_reach_voip PUBLIC liberty_reach_crypto_cpp)
endif()

# ============================================
# Mesh Network Module
# ============================================

add_library(liberty_reach_mesh STATIC
    mesh/src/mesh_network.cpp
)

target_include_directories(liberty_reach_mesh PUBLIC
    ${CMAKE_SOURCE_DIR}/mesh/include
)

target_link_libraries(liberty_reach_mesh PUBLIC
    liberty_reach_crypto_cpp
)

# ============================================
# Desktop Client
# ============================================

if(BUILD_DESKTOP)
    pkg_check_modules(GTK3 REQUIRED gtk+-3.0)
    
    if(BUILD_FULL)
        # Full integrated version
        add_executable(liberty_reach_desktop
            desktop/src/main_full.cpp
        )
    else()
        # Simple version
        add_executable(liberty_reach_desktop
            desktop/src/main.cpp
            desktop/src/main_window.cpp
            desktop/src/chat_widget.cpp
            desktop/src/call_widget.cpp
        )
    endif()
    
    target_include_directories(liberty_reach_desktop PUBLIC
        ${CMAKE_SOURCE_DIR}/core/include
        ${GTK3_INCLUDE_DIRS}
    )
    
    target_link_libraries(liberty_reach_desktop
        liberty_reach_crypto_cpp
        liberty_reach_voip
        liberty_reach_mesh
        ${GTK3_LIBRARIES}
        ${CURL_LIBRARIES}
    )
endif()

# ============================================
# CLI Client
# ============================================

if(BUILD_CLI)
    add_executable(liberty_reach_cli
        cli/src/main.cpp
        cli/src/cli_app.cpp
    )
    
    target_include_directories(liberty_reach_cli PUBLIC
        ${CMAKE_SOURCE_DIR}/core/include
    )
    
    target_link_libraries(liberty_reach_cli
        liberty_reach_crypto_cpp
        liberty_reach_mesh
        ${CURL_LIBRARIES}
    )
endif()

# ============================================
# Tests
# ============================================

if(BUILD_TESTS)
    enable_testing()
    
    # Crypto tests
    add_executable(crypto_tests tests/crypto_tests.cpp)
    target_link_libraries(crypto_tests liberty_reach_crypto_cpp)
    add_test(NAME crypto_tests COMMAND crypto_tests)
    
    # VoIP tests
    add_executable(voip_tests tests/voip_tests.cpp)
    target_link_libraries(voip_tests liberty_reach_voip)
    add_test(NAME voip_tests COMMAND voip_tests)
    
    # Mesh tests
    add_executable(mesh_tests tests/mesh_tests.cpp)
    target_link_libraries(mesh_tests liberty_reach_mesh)
    add_test(NAME mesh_tests COMMAND mesh_tests)
endif()

# ============================================
# Installation
# ============================================

install(TARGETS liberty_reach_desktop liberty_reach_cli
    RUNTIME DESTINATION bin
)

install(FILES core/include/liberty_reach_crypto.h core/include/network_client.h
    DESTINATION include/liberty_reach
)

# ============================================
# Summary
# ============================================

# ============================================
# Crypto Wallet Module
# ============================================

add_library(liberty_reach_wallet STATIC
    wallet/src/crypto_wallet.cpp
)

target_include_directories(liberty_reach_wallet PUBLIC
    ${CMAKE_SOURCE_DIR}/wallet/include
)

target_link_libraries(liberty_reach_wallet PUBLIC
    liberty_reach_crypto_cpp
)

# ============================================
# Production Features Module
# ============================================

add_library(liberty_reach_production STATIC
    core/src/production_features.cpp
)

target_include_directories(liberty_reach_production PUBLIC
    ${CMAKE_SOURCE_DIR}/core/include
)

target_link_libraries(liberty_reach_production PUBLIC
    liberty_reach_crypto_cpp
)

# ============================================
# Family Statuses Module
# ============================================

add_library(liberty_reach_family STATIC
    core/src/family_statuses.cpp
)

target_include_directories(liberty_reach_family PUBLIC
    ${CMAKE_SOURCE_DIR}/core/include
)

target_link_libraries(liberty_reach_family PUBLIC
    liberty_reach_crypto_cpp
)

# Link to desktop
if(BUILD_DESKTOP)
    target_link_libraries(liberty_reach_desktop
        liberty_reach_wallet
        liberty_reach_production
        liberty_reach_family
    )
endif()

# ============================================
# Summary
# ============================================

message(STATUS "")
message(STATUS "═══════════════════════════════════════════════")
message(STATUS "  Liberty Reach Messenger v${PROJECT_VERSION}")
message(STATUS "═══════════════════════════════════════════════")
message(STATUS "")
message(STATUS "  Build type:        ${CMAKE_BUILD_TYPE}")
message(STATUS "  Build tests:       ${BUILD_TESTS}")
message(STATUS "  Build desktop:     ${BUILD_DESKTOP}")
message(STATUS "  Build CLI:         ${BUILD_CLI}")
message(STATUS "  Full version:      ${BUILD_FULL}")
message(STATUS "")
message(STATUS "  Install prefix:    ${CMAKE_INSTALL_PREFIX}")
message(STATUS "")
message(STATUS "  ✓ Crypto:            Post-Quantum + E2EE")
message(STATUS "  ✓ Network:           Cloudflare + P2P")
message(STATUS "  ✓ VoIP:              WebRTC + ZRTP")
message(STATUS "  ✓ Mesh:              BLE + WiFi + LoRa")
message(STATUS "  ✓ Wallet:            Multi-blockchain")
message(STATUS "  ✓ Telegram Features: Channels, Bots, Stickers")
message(STATUS "  ✓ Desktop UI:        GTK3 Full")
message(STATUS "")
message(STATUS "═══════════════════════════════════════════════")
