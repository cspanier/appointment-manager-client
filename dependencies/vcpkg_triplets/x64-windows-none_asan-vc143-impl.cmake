if("${PORT}" MATCHES "breakpad|crashpad|catch2|fmt|libtom|cryptopp|boost|libpq")
  set(VCPKG_LIBRARY_LINKAGE static)
endif()
# The following libraries are incompatible with ASAN.
if(NOT "${PORT}" MATCHES "openssl|python3|icu")
  set(VCPKG_C_FLAGS "/fsanitize=address")
  set(VCPKG_CXX_FLAGS "/fsanitize=address")
endif()
