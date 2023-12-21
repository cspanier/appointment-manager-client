set(WindowsSDKVersion $ENV{WindowsSDKVersion} CACHE PATH
  "Path to the Windows SDK to use.")
if ("$ENV{WindowsSDKVersion}" STREQUAL "" AND
  "${WindowsSDKVersion}" STREQUAL "")
  message(FATAL_ERROR "Cannot find environment variable WindowsSDKVersion.\n"
    "Please call this script from a command prompt where all build environment "
    "variables for the given compiler toolchain are properly set.")
endif()
# Remove any backslashes from the value of WindowsSDKVersion.
string(REGEX REPLACE "\\\\" "" WINSDK_VERSION ${WindowsSDKVersion})
message(STATUS "Using Windows SDK version ${WINSDK_VERSION}")

set(CMAKE_HOST_SYSTEM_VERSION ${WINSDK_VERSION})

set(CMAKE_SYSTEM_PROCESSOR AMD64)

# Only set CMAKE_SYSTEM_NAME when it is not equal to CMAKE_HOST_SYSTEM_NAME,
# because otherwise CMake will always enable crosscompilation.
if (NOT "${CMAKE_HOST_SYSTEM_NAME}" STREQUAL "Windows")
  set(CMAKE_SYSTEM_NAME Windows)
endif()

# Setting CMAKE_SYSTEM_VERSION without CMAKE_SYSTEM_NAME is explicitely allowed
# and won't enable crosscompilation as long as the executable will run on the
# host system as well.
set(CMAKE_SYSTEM_VERSION ${WINSDK_VERSION})

set(ENV{X_VCPKG_ASSET_SOURCES} "${X_VCPKG_ASSET_SOURCES}")
set(ENV{VCPKG_BINARY_SOURCES} "${VCPKG_BINARY_SOURCES}")
set(VCPKG_PATH_SOURCE "${CMAKE_BINARY_DIR}/vcpkg-path.txt")
if(EXISTS "${VCPKG_PATH_SOURCE}")
  file(READ "${VCPKG_PATH_SOURCE}" VCPKG_PATH)
  include("${VCPKG_PATH}/scripts/buildsystems/vcpkg.cmake")
endif()
