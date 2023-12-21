set(VCPKG_LIBRARY_LINKAGE dynamic)
set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_PLATFORM_TOOLSET v143)
# ToDo: Pass toolset version from cmake.py (via environment? generate this toolset file?)
set(VCPKG_PLATFORM_TOOLSET_VERSION 14.38.33130)
# ToDo: Pass windows SDK version from cmake.py (via environment? generate this toolset file?)
set(VCPKG_CMAKE_SYSTEM_VERSION 10.0.20348.0)

# vcpkg hashes triplet files, thus invalidating the binary cache with each change.
# To circumvent this, move any customizations to a separate file
# from which port-specific changes to the above variables can be assigned.
include("${CMAKE_CURRENT_LIST_DIR}/x64-windows-none-vc143-impl.cmake")
