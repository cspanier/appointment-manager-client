macro(shift_find_header target name file)
  parse_arguments("PATH_SUFFIXES;PATHS;HINTS" "" ${ARGN})

  FIND_PATH(${target}_${name}_INCLUDE_DIR ${file}
    PATH_SUFFIXES
      ${ARG_PATH_SUFFIXES}
      include
    PATHS
      ${ARG_PATHS}
      ${CMAKE_PREFIX_PATH}
      ${CMAKE_CROSS_PATH}
    HINTS
      ${ARG_HINTS}
    NO_DEFAULT_PATH
  )
  if(NOT ${target}_${name}_INCLUDE_DIR)
    FIND_PATH(${target}_${name}_INCLUDE_DIR ${file}
      PATH_SUFFIXES
        ${ARG_PATH_SUFFIXES}
        include
      PATHS
        ${ARG_PATHS}
        ${CMAKE_PREFIX_PATH}
        ${CMAKE_CROSS_PATH}
      HINTS
        ${ARG_HINTS}
    )
    if(NOT ${target}_${name}_INCLUDE_DIR)
      message(WARNING "Cannot find header file \"${file}\".")
    endif()
  endif()
  if(SHIFT_DEBUG_CMAKE)
    message(STATUS "  ${target}_${name}_INCLUDE_DIR=${${target}_${name}_INCLUDE_DIR}")
  endif()
  list(APPEND ${target}_INCLUDE_DIRS ${${target}_${name}_INCLUDE_DIR})
  list(REMOVE_DUPLICATES ${target}_INCLUDE_DIRS)
endmacro()

function(shift_find_header_ex target file)
  shift_find_header(${target} none ${file} ${ARGN})
  return(PROPAGATE ${target}_INCLUDE_DIRS)
endfunction()
