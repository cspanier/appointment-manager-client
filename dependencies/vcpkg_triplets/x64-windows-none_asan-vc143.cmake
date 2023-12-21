set(VCPKG_LIBRARY_LINKAGE dynamic)
set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE dynamic)

# vcpkg hashes triplet files, thus invalidating the binary cache with each change.
# To circumvent this, move any customizations to a separate file
# from which port-specific changes to the above variables can be assigned.
include("${CMAKE_CURRENT_LIST_DIR}/x64-windows-none_asan-vc143-impl.cmake")
