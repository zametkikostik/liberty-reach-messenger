cmake_minimum_required(VERSION 3.20)
project(liberty_reach_crypto VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Options
option(BUILD_TESTS "Build tests" ON)
option(BUILD_SHARED_LIBS "Build shared libraries" OFF)

# Dependencies
find_package(OpenSSL REQUIRED)
find_package(PkgConfig REQUIRED)

# Fetch pqc-kyber
include(FetchContent)
FetchContent_Declare(
  pqc_kyber
  GIT_REPOSITORY https://github.com/randombit/pqc-kyber.git
  GIT_TAG master
)
FetchContent_MakeAvailable(pqc_kyber)

# Fetch libsodium
pkg_check_modules(SODIUM REQUIRED libsodium)

# Fetch blake3
FetchContent_Declare(
  blake3
  GIT_REPOSITORY https://github.com/BLAKE3-team/BLAKE3.git
  GIT_TAG v1.5.0
)
FetchContent_MakeAvailable(blake3)

# Source files
set(SOURCES
  src/liberty_reach_crypto.cpp
  src/keys.cpp
  src/session.cpp
  src/ratchet.cpp
  src/steganography.cpp
  src/profile.cpp
  src/utils.cpp
)

# Header files
set(HEADERS
  ../include/liberty_reach_crypto.h
)

# Create library
add_library(liberty_reach_crypto STATIC ${SOURCES})

target_include_directories(liberty_reach_crypto PUBLIC
  ${CMAKE_CURRENT_SOURCE_DIR}/../include
  ${SODIUM_INCLUDE_DIRS}
)

target_link_libraries(liberty_reach_crypto PUBLIC
  OpenSSL::Crypto
  OpenSSL::SSL
  ${SODIUM_LIBRARIES}
  blake3
  pqc_kyber
)

target_compile_options(liberty_reach_crypto PRIVATE
  -Wall
  -Wextra
  -Wpedantic
  -O3
)

# Install
install(TARGETS liberty_reach_crypto
  ARCHIVE DESTINATION lib
  LIBRARY DESTINATION lib
)

install(FILES ${HEADERS}
  DESTINATION include/liberty_reach
)

# Tests
if(BUILD_TESTS)
  enable_testing()
  
  add_executable(crypto_tests tests/crypto_tests.cpp)
  target_link_libraries(crypto_tests PRIVATE liberty_reach_crypto)
  
  add_test(NAME crypto_tests COMMAND crypto_tests)
endif()

# TDLib integration example
option(BUILD_TDLIB_EXAMPLE "Build TDLib integration example" OFF)

if(BUILD_TDLIB_EXAMPLE)
  find_package(TDLib REQUIRED)
  
  add_executable(tdlib_example tests/tdlib_integration.cpp)
  target_link_libraries(tdlib_example PRIVATE
    liberty_reach_crypto
    TDLib::Td
  )
endif()
