if(USE_DEVELOPMENT_VERSION)
  message(STATUS "Tagging the build as non-official development version.")
  set(BUILD_VERSION_HASH "non-official")
else()
  # Retrieve current git commit hash.
  execute_process(
    COMMAND git log -1 --format=%h
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    OUTPUT_VARIABLE BUILD_VERSION_HASH
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )
  if("${BUILD_VERSION_HASH}" STREQUAL "")
    message(WARNING "Failed to retrieve current Git commit hash. You probably don't have Git in your system's PATH or you build from a copy of the repository.")
    set(BUILD_VERSION_HASH "unknown")
  endif()

  # Check if build tree is dirty (i.e. modified or untracked files).
  execute_process(
    COMMAND git status -s
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    OUTPUT_VARIABLE GIT_STATUS_OUTPUT
    OUTPUT_STRIP_TRAILING_WHITESPACE
  )
  if(NOT "${GIT_STATUS_OUTPUT}" STREQUAL "")
    message(STATUS "${CMAKE_CURRENT_SOURCE_DIR} has pending changes:\n${GIT_STATUS_OUTPUT}")
    if(USE_DIRTY_BUILD_CHECK)
      message(STATUS "Tagging the build as dirty.")
      set(BUILD_VERSION_HASH "${BUILD_VERSION_HASH}_dirty")
    else()
      message(STATUS "Not tagging the build as dirty, because USE_DIRTY_BUILD_CHECK is set to false.")
    endif()
  endif()
endif()

foreach(VERSION_FILENAME ${VERSION_FILENAMES})
  if(EXISTS "${VERSION_FILENAME}.in")
    configure_file("${VERSION_FILENAME}.in" "${VERSION_FILENAME}.new" @ONLY)
    file(SHA256 "${VERSION_FILENAME}.new" new_hash)

    if(EXISTS "${VERSION_FILENAME}")
      file(SHA256 "${VERSION_FILENAME}" old_hash)
    else()
      set(old_hash "file doesn't exist")
    endif()
    if(NOT "${old_hash}" STREQUAL "${new_hash}")
      message(STATUS "Updating version ${BUILD_VERSION_MAJOR}.${BUILD_VERSION_MINOR}.${BUILD_VERSION_PATCH}.${BUILD_VERSION_HASH}")
      file(REMOVE "${VERSION_FILENAME}")
      file(RENAME "${VERSION_FILENAME}.new" "${VERSION_FILENAME}")
    else()
      message(STATUS "Keeping version ${BUILD_VERSION_MAJOR}.${BUILD_VERSION_MINOR}.${BUILD_VERSION_PATCH}.${BUILD_VERSION_HASH}")
      file(REMOVE "${VERSION_FILENAME}.new")
    endif()
  endif()
endforeach()
