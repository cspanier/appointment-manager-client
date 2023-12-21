function(shift_find_library target name)
  parse_arguments("NAMES;NAMES_DEBUG;NAMES_RELEASE;PATH_SUFFIXES;PATH_SUFFIXES_DEBUG;PATH_SUFFIXES_RELEASE;HINTS;HINTS_DEBUG;HINTS_RELEASE;PATHS;PATHS_DEBUG;PATHS_RELEASE" "" ${ARGN})

  # vcpkg adds the path to debug libraries in front of the path to release libraries.
  # Thus we have to filter the debug path from non-debug builds.
  set(CMAKE_PREFIX_PATH_DEBUG ${CMAKE_PREFIX_PATH})
  set(CMAKE_PREFIX_PATH_RELEASE ${CMAKE_PREFIX_PATH})
  list(FILTER CMAKE_PREFIX_PATH_RELEASE EXCLUDE REGEX ".*\/debug")

  # if("${target}" STREQUAL "CRASHPAD")
  #   message(STATUS "############################ target: ${target} #######################################")
  #   message(STATUS "########## CMAKE_PREFIX_PATH: ${CMAKE_PREFIX_PATH}")
  #   message(STATUS "########## CMAKE_PREFIX_PATH_DEBUG: ${CMAKE_PREFIX_PATH_DEBUG}")
  #   message(STATUS "########## CMAKE_PREFIX_PATH_RELEASE: ${CMAKE_PREFIX_PATH_RELEASE}")
  #   message(STATUS "########## ARG_PATH_SUFFIXES_RELEASE: ${ARG_PATH_SUFFIXES_RELEASE}")
  #   message(STATUS "########## ARG_PATH_SUFFIXES: ${ARG_PATH_SUFFIXES}")
  #   set(CMAKE_FIND_DEBUG_MODE ON)
  # endif()
  foreach(config DEBUG RELEASE)
    # if("${target}" STREQUAL "CRASHPAD")
    #   message(STATUS "++++++++++++ config: ${config} ##########")
    #   message(STATUS "++++++++++++ CMAKE_LIBRARY_ARCHITECTURE: ${CMAKE_LIBRARY_ARCHITECTURE}")
    #   message(STATUS "++++++++++++ CMAKE_LIBRARY_PATH: ${CMAKE_LIBRARY_PATH}")
    #   message(STATUS "++++++++++++ CMAKE_FRAMEWORK_PATH: ${CMAKE_FRAMEWORK_PATH}")
    #   message(STATUS "++++++++++++ ARG_PATHS_${config}: ${ARG_PATHS_${config}}")
    #   message(STATUS "++++++++++++ ARG_PATHS: ${ARG_PATHS}")
    #   message(STATUS "++++++++++++ CMAKE_PREFIX_PATH_${config}: ${CMAKE_PREFIX_PATH_${config}}")
    #   message(STATUS "++++++++++++ CMAKE_CROSS_PATH: ${CMAKE_CROSS_PATH}")
    # endif()
    FIND_LIBRARY(${target}_LIBRARY_${name}_${config}
      NAMES
        ${ARG_NAMES_${config}}
        ${ARG_NAMES}
      PATH_SUFFIXES
        ${ARG_PATH_SUFFIXES_${config}}
        ${ARG_PATH_SUFFIXES}
        lib
      # HINTS
      #   ${ARG_HINTS_${config}}
      #   ${ARG_HINTS}
      PATHS
        ${ARG_PATHS_${config}}
        ${ARG_PATHS}
        ${CMAKE_PREFIX_PATH_${config}}
        ${CMAKE_CROSS_PATH}
      NO_PACKAGE_ROOT_PATH
      NO_SYSTEM_ENVIRONMENT_PATH
      NO_CMAKE_INSTALL_PREFIX
      NO_CMAKE_SYSTEM_PATH
      CMAKE_IGNORE_PREFIX_PATH
      CMAKE_SYSTEM_IGNORE_PATH
      CMAKE_SYSTEM_IGNORE_PREFIX_PATH
      NO_DEFAULT_PATH
    )
    if("${${target}_LIBRARY_${name}_${config}}" MATCHES "${target}_LIBRARY_${name}_${config}-NOTFOUND")
      FIND_LIBRARY(${target}_LIBRARY_${name}_${config}
        NAMES
          ${ARG_NAMES_${config}}
          ${ARG_NAMES}
        PATH_SUFFIXES
          ${ARG_PATH_SUFFIXES_${config}}
          ${ARG_PATH_SUFFIXES}
          lib
        # HINTS
        #   ${ARG_HINTS_${config}}
        #   ${ARG_HINTS}
        PATHS
          ${ARG_PATHS_${config}}
          ${ARG_PATHS}
          ${CMAKE_PREFIX_PATH_${config}}
          ${CMAKE_CROSS_PATH}
      )
    endif()
    if("${${target}_LIBRARY_${name}_${config}}" STREQUAL "${target}_LIBRARY_${name}_${config}-NOTFOUND")
      message(WARNING "Cannot locate library '${name}' for target '${target}'.")
      set(${target}_FOUND 0)
    elseif(NOT DEFINED ${target}_FOUND)
      set(${target}_FOUND 1)
    endif()
  endforeach()
  # set(CMAKE_FIND_DEBUG_MODE OFF)

  list(APPEND ${target}_LIBRARIES
    debug "${${target}_LIBRARY_${name}_DEBUG}"
    optimized "${${target}_LIBRARY_${name}_RELEASE}"
  )
  return(PROPAGATE
    ${target}_FOUND
    ${target}_LIBRARIES
    ${target}_LIBRARY_${name}_DEBUG
    ${target}_LIBRARY_${name}_RELEASE
  )
endfunction()
