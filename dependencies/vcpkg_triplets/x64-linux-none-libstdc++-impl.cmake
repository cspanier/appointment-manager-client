if("${PORT}" MATCHES "breakpad|crashpad|catch2|fmt|boost")
  set(VCPKG_LIBRARY_LINKAGE static)
endif()
