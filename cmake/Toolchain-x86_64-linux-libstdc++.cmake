# set(CMAKE_HOST_SYSTEM_VERSION 6.6)
set(CMAKE_SYSTEM_PROCESSOR AMD64)

# Only set CMAKE_SYSTEM_NAME when it is not equal to CMAKE_HOST_SYSTEM_NAME,
# because otherwise CMake will always enable crosscompilation.
if (NOT "${CMAKE_HOST_SYSTEM_NAME}" STREQUAL "Linux")
  set(CMAKE_SYSTEM_NAME Linux)
endif()

# Setting CMAKE_SYSTEM_VERSION without CMAKE_SYSTEM_NAME is explicitely allowed
# and won't enable crosscompilation as long as the executable will run on the
# host system as well.
# set(CMAKE_SYSTEM_VERSION "5.15")
# set(CMAKE_SYSTEM_PROCESSOR AMD64)

set(ENV{X_VCPKG_ASSET_SOURCES} "${X_VCPKG_ASSET_SOURCES}")
set(ENV{VCPKG_BINARY_SOURCES} "${VCPKG_BINARY_SOURCES}")
set(VCPKG_PATH_SOURCE "${CMAKE_BINARY_DIR}/vcpkg-path.txt")
if(EXISTS "${VCPKG_PATH_SOURCE}")
  file(READ "${VCPKG_PATH_SOURCE}" VCPKG_PATH)
  include("${VCPKG_PATH}/scripts/buildsystems/vcpkg.cmake")
endif()

# set(CMAKE_C_COMPILER   "clang")
# set(CMAKE_CXX_COMPILER "clang++")
