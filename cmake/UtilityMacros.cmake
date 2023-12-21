# clears all passed variables
macro(clear_vars)
  foreach(var ${ARGN})
    unset(${var} CACHE)
  endforeach()
endmacro()

###############################################################################

# Transform target names like "test.shift.core" to "TestShiftCore"
macro(target_name_to_camel_case target result_var)
  set(_result "")
  # message(STATUS "### target_name_to_camel_case target=${target}")
  # CMake does not support a dynamic number of capture groups with
  # "([^.]*\\.)*([^.]*)"
  STRING(REGEX MATCH "([^.]*\\.)([^.]*\\.)?([^.]*\\.)?([^.]*)" "" "${target}")
  foreach(_i RANGE 1 4)
    if(CMAKE_MATCH_${_i})
      # message(STATUS "### target_name_to_camel_case CMAKE_MATCH_${_i}=${CMAKE_MATCH_${_i}}")
      string(SUBSTRING "${CMAKE_MATCH_${_i}}" 0 1 _head)
      STRING(TOUPPER "${_head}" _head)
      string(SUBSTRING "${CMAKE_MATCH_${_i}}" 1 -1 _tail)
      string(APPEND _result "${_head}" "${_tail}")
    endif()
  endforeach()

  string(REPLACE "." "" ${result_var} "${_result}")
  # message(STATUS "### target_name_to_camel_case result=${${result_var}}")
endmacro()

###############################################################################

macro(if_not_target_find_package target)
  if(NOT TARGET ${target})
    target_name_to_camel_case(${target} target_camelcase)
    find_package(${target_camelcase} REQUIRED)
    unset(target_camelcase)
  endif()
endmacro()

###############################################################################

function(parse_arguments arg_names option_names)
  set(DEFAULT_ARGS)
  foreach(arg_name ${arg_names})
    set(ARG_${arg_name} PARENT_SCOPE)
  endforeach()
  foreach(option ${option_names})
    set(ARG_${option} FALSE PARENT_SCOPE)
  endforeach()

  set(current_arg_name DEFAULT_ARGS)
  set(current_arg_list)
  foreach(arg ${ARGN})
    set(larg_names ${arg_names})
    list(FIND larg_names "${arg}" is_arg_name)
    if(is_arg_name GREATER -1)
      set(ARG_${current_arg_name} ${current_arg_list} PARENT_SCOPE)
      set(current_arg_name ${arg})
      set(current_arg_list)
    else()
      set(loption_names ${option_names})
      list(FIND loption_names "${arg}" is_option)
      if(is_option GREATER -1)
        set(ARG_${arg} TRUE PARENT_SCOPE)
      else()
        set(current_arg_list ${current_arg_list} ${arg})
      endif()
    endif()
  endforeach()
  set(ARG_${current_arg_name} ${current_arg_list} PARENT_SCOPE)
endfunction()

###############################################################################

# This macro globs c++ sources and groups them for msvs to reflect the
# directory structure.
function(find_sources result)
  parse_arguments("ROOTS;EXTS;GROUPPREFIX;INSTALLDIR" "" ${ARGN})
  if("${ARG_EXTS}" STREQUAL "")
    message(FATAL_ERROR "Missing argument EXTS")
  endif()

  set(_result)
  foreach (root ${ARG_ROOTS})
    set(globbing_exprs)
    foreach(source_ext ${ARG_EXTS})
      list(APPEND globbing_exprs "${root}/${source_ext}")
    endforeach()

    # glob files from directory.
    file(GLOB_RECURSE sources_of_dir RELATIVE "${root}/"
      ${globbing_exprs})

    foreach(source ${sources_of_dir})
      # add to list of sources.
      list(APPEND _result "${root}/${source}")

      # add source group, that reflects the directory structure.
      get_filename_component(source_path "${source}" PATH)
      string(REGEX REPLACE "/" "\\\\" vs_source_path "${ARG_GROUPPREFIX}${source_path}")
      source_group("${vs_source_path}" FILES "${root}/${source}")

      if(ARG_INSTALLDIR)
        install(FILES "${root}/${source}"
          DESTINATION "${CMAKE_INSTALL_PREFIX}/${ARG_INSTALLDIR}/${source_path}")
      endif()
    endforeach()
  endforeach()
  set(${result} "${_result}" PARENT_SCOPE)
endfunction()

###############################################################################

# This macro excludes c++ sources from the build. It is useful for MSVS project
# files to list source files meant for platforms other than Windows.
function(exclude_sources)
  # loop through all optional arguments.
  foreach(source_file_pattern ${ARGN})
    # message(STATUS "Excluding ${source_file_pattern}")
    file(GLOB source_file "${source_file_pattern}")

    # loop through all files to exclude.
    foreach(source_file ${source_file})
      set_source_files_properties(${source_file} PROPERTIES
        HEADER_FILE_ONLY TRUE)
    endforeach()
  endforeach()
endfunction()

###############################################################################

function(exclude_target_from_build target_name)
  set_target_properties(
    ${target_name} PROPERTIES
    EXCLUDE_FROM_DEFAULT_BUILD TRUE
    EXCLUDE_FROM_ALL TRUE
  )
endfunction()

###############################################################################

# Automatically sets the FOLDER target property according to the target name
# using dots ('.') as separator characters.
function(set_target_folder target)
  if (USE_TARGET_FOLDERS)
    string(TOLOWER "${target}" target_folder)
    # Replace name separators with slashes (a.b.c.3d.1.0 -> a/b/c.3d.1.0)
    string(REGEX REPLACE "\\.([a-zA-Z][^\\.]*)" "/\\1" target_folder "${target_folder}")
    # Handle special names which start with a number (a/b/c.3d.1.0 -> a/b/c/3d.1.0)
    string(REGEX REPLACE "\\.([0-9]+[^\\.0-9]+)" "/\\1" target_folder "${target_folder}")
    # Split off last name ("a/b/c/3d.1.0" -> "a/b/c")
    string(REGEX REPLACE "(.*)(/[^/]+)" "\\1" target_folder "${target_folder}")
    if(NOT "${target_folder}" STREQUAL "")
      set_target_properties(${target} PROPERTIES
        FOLDER "${target_folder}")
    endif()
  endif()
endfunction()

###############################################################################

# Includes all subdirectories which directly contain a CMakeLists.txt file.
macro(shift_add_subdirectories)
  file(GLOB folders RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} "${CMAKE_CURRENT_SOURCE_DIR}/*")
  foreach(folder ${folders})
    if(IS_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/${folder}" AND
      EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${folder}/CMakeLists.txt")
      add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/${folder})
    endif()
  endforeach()
endmacro()

###############################################################################

function(update_build_version target)
  set(version_filenames)
  foreach(version_filename ${ARGN})
    if(NOT EXISTS "${version_filename}")
      file(TOUCH "${version_filename}")
    endif()
    list(APPEND version_filenames ${version_filename})
  endforeach()

  add_custom_target(${target} ALL
    COMMAND ${CMAKE_COMMAND}
            "-DVERSION_FILENAMES=${version_filenames}"
            -DUSE_DEVELOPMENT_VERSION=${USE_DEVELOPMENT_VERSION}
            -DUSE_DIRTY_BUILD_CHECK=${USE_DIRTY_BUILD_CHECK}
            -DBUILD_VERSION_MAJOR=${PROJECT_VERSION_MAJOR}
            -DBUILD_VERSION_MINOR=${PROJECT_VERSION_MINOR}
            -DBUILD_VERSION_PATCH=${PROJECT_VERSION_PATCH}
            -DBUILD_VERSION_SHORT=${PROJECT_VERSION}
            -DCMAKE_HOST_SYSTEM_VERSION=${CMAKE_HOST_SYSTEM_VERSION}
            -DCMAKE_SYSTEM_PROCESSOR=${CMAKE_SYSTEM_PROCESSOR}
            -DCMAKE_SYSTEM_NAME=${CMAKE_SYSTEM_NAME}
            -DCMAKE_SYSTEM_VERSION=${CMAKE_SYSTEM_VERSION}
            -DSHIFT_SYSTEM_PROCESSOR=${SHIFT_SYSTEM_PROCESSOR}
            -DSHIFT_COMPILER_ACRONYM=${SHIFT_COMPILER_ACRONYM}
            -P ${CMAKE_SOURCE_DIR}/cmake/UpdateBuildVersion.cmake
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    COMMENT "Checking version information for target ${target}..."
    VERBATIM
  )
  set_target_folder(${target})
endfunction()

###############################################################################

function(configure_manifest target manifest_filename)
  if(WIN32 AND EXISTS "${manifest_filename}.in")
    configure_file("${manifest_filename}.in" "${manifest_filename}.new" @ONLY)
    file(SHA256 "${manifest_filename}.new" new_hash)

    if(EXISTS "${manifest_filename}")
      file(SHA256 "${manifest_filename}" old_hash)
    else()
      set(old_hash "file doesn't exist")
    endif()
    if(NOT "${old_hash}" STREQUAL "${new_hash}")
      message(STATUS "Updating manifest file '${manifest_filename}'.")
      file(REMOVE "${manifest_filename}")
      file(RENAME "${manifest_filename}.new" "${manifest_filename}")
    else()
      message(STATUS "Keeping manifest file '${manifest_filename}'.")
      file(REMOVE "${manifest_filename}.new")
    endif()
  endif()
endfunction()
