function(shift_add_executable target)
  set(argument_names "INSTALL_PREFIX;DOCDIRS;SOURCEDIRS;MANIFEST;QMLDIRS;SOURCEEXTS;SOURCES")
  set(argument_names "${argument_names};PRECOMPILED_HEADER;LIBRARIES;DEPENDENCIES")
  set(argument_names "${argument_names};CXXFLAGS;LFLAGS")
  parse_arguments("${argument_names}" "WIN32" "${ARGN}")
  message(STATUS "Adding executable ${target}...")

  target_name_to_camel_case(${target} target_camelcase)

  if("${ARG_INSTALL_PREFIX}" STREQUAL "")
    set(ARG_INSTALL_PREFIX "./")
  elseif(NOT "${ARG_INSTALL_PREFIX}" MATCHES ".*/$")
    # Add trailing slash, if not already present
    set(ARG_INSTALL_PREFIX "${ARG_INSTALL_PREFIX}/")
  endif()

  if(WIN32 AND NOT "${ARG_MANIFEST}" STREQUAL "" AND NOT EXISTS "${ARG_MANIFEST}")
    file(TOUCH "${ARG_MANIFEST}")
  endif()

  if(ARG_DOCDIRS)
    set(_docdirs ${ARG_DOCDIRS})
  else()
    set(_docdirs "${CMAKE_CURRENT_SOURCE_DIR}/doc")
  endif()
  find_sources(documentation_files
    ROOTS ${_docdirs}
    EXTS
      "*.md" "*.txt"
      "*.png" "*.svg" "*.jpg" "*.gif"
    GROUPPREFIX "doc/")
  list(APPEND sources ${documentation_files})

  if(ARG_SOURCEDIRS)
    if("${ARG_SOURCEEXTS}" STREQUAL "")
      set(ARG_SOURCEEXTS
        "*.h" "*.hpp" "*.hxx"
        "*.c" "*.cc" "*.cpp" "*.cxx"
        "*.ixx" "*.cppm"
        "*.inl"
        "*.in"
        "*.manifest"
        "*.rc" "*.rc2"
        "*.png" "*.svg" "*.jpg" "*.bmp" "*.ico"
      )
    endif()
    find_sources(private_sources
      ROOTS ${ARG_SOURCEDIRS}
      EXTS ${ARG_SOURCEEXTS})
    list(APPEND sources ${private_sources})
  else()
    message(FATAL_ERROR "SOURCEDIRS argument not set")
  endif()

  if(ARG_QMLDIRS)
    set(qml_exts "*.qml" "*.js")
    find_sources(qml_sources
      ROOTS ${ARG_QMLDIRS}
      EXTS ${qml_exts}
      GROUPPREFIX "qml/")
    list(APPEND sources ${qml_sources})
  endif()

  list(APPEND sources ${ARG_SOURCES})

  if(MSVC)
    # Do NOT use multi-byte character set string encoding on MSVC.
    remove_definitions(-D_MBCS)
  endif()

  if(ARG_WIN32)
    set(BUILD_MODE WIN32)
  else()
    set(BUILD_MODE "")
  endif()
  add_executable(${target} ${BUILD_MODE} ${sources})
  target_link_libraries(${target} PRIVATE ${ARG_LIBRARIES})
  target_compile_definitions(${target} PRIVATE "${SHIFT_GLOBAL_DEFINITIONS}")

  foreach(dependency ${ARG_DEPENDENCIES})
    if("${dependency}" MATCHES "^shift.")
      if_not_target_find_package(${dependency})
    endif()
    if (TARGET ${dependency})
      target_link_libraries(${target} PRIVATE ${dependency})
    elseif(${dependency}_INCLUDE_DIRS OR
        ${dependency}_DEFINITIONS OR
        ${dependency}_LIBRARIES)
      if(${dependency}_INCLUDE_DIRS)
        target_include_directories(${target} PRIVATE ${${dependency}_INCLUDE_DIRS})
      endif()
      if(${dependency}_DEFINITIONS)
        target_compile_definitions(${target} PRIVATE ${${dependency}_DEFINITIONS})
      endif()
      if(${dependency}_LIBRARIES)
        target_link_libraries(${target} PRIVATE ${${dependency}_LIBRARIES})
      endif()
    else()
      # Generator expressions cannot be evaluated with the code above,
      # so we assume it resolves to some target.
      target_link_libraries(${target} PRIVATE ${dependency})
    endif()
  endforeach()

  target_link_libraries(${target} PRIVATE $<$<AND:$<CXX_COMPILER_ID:GNU>,$<VERSION_LESS:$<CXX_COMPILER_VERSION>,9.0>>:stdc++fs>)
  target_link_libraries(${target} PRIVATE $<$<PLATFORM_ID:Linux>:Threads::Threads>)

  foreach(dependency ${ARG_DEPENDENCIES})
    if (TARGET ${dependency})
      add_dependencies(${target} ${dependency})
    endif()
  endforeach()

  foreach(source_path ${ARG_SOURCEDIRS})
    target_include_directories(${target} PRIVATE "${source_path}")
  endforeach()
  foreach(prefix_path ${CMAKE_PREFIX_PATH})
    target_include_directories(${target} PRIVATE "${prefix_path}/include")
  endforeach()

  target_compile_definitions(${target}
    PRIVATE "$<$<CONFIG:Debug>:BUILD_CONFIG_DEBUG>"
    PRIVATE "$<$<CONFIG:MinSizeRel>:BUILD_CONFIG_MINSIZEREL>"
    PRIVATE "$<$<CONFIG:Release>:BUILD_CONFIG_RELEASE>"
    PRIVATE "$<$<CONFIG:RelWithDebInfo>:BUILD_CONFIG_RELWITHDEBINFO>"
    PRIVATE BUILD_BIN_FOLDER="bin"
  )

  if((CMAKE_CXX_COMPILER_ID MATCHES "Clang" OR
      CMAKE_CXX_COMPILER_ID MATCHES "GNU") AND NOT MSVC)
    # -fPIE: Generate code supporting address space layout randomization in executables.
    set(ARG_CXXFLAGS "-fPIE ${ARG_CXXFLAGS}")
  endif()

  set_target_properties(${target} PROPERTIES
    CXX_STANDARD 23
    CXX_STANDARD_REQUIRED ON
    CXX_EXTENSIONS OFF
    PREFIX ""
    COMPILE_FLAGS "${ARG_CXXFLAGS}"
    LINK_FLAGS "${ARG_LFLAGS}"
    LINKER_LANGUAGE CXX

    RUNTIME_OUTPUT_DIRECTORY
      "${CMAKE_INSTALL_PREFIX}/${ARG_INSTALL_PREFIX}bin"
    RUNTIME_OUTPUT_DIRECTORY_DEBUG
      "${CMAKE_INSTALL_PREFIX}/${ARG_INSTALL_PREFIX}bin"
    RUNTIME_OUTPUT_DIRECTORY_MINSIZEREL
      "${CMAKE_INSTALL_PREFIX}/${ARG_INSTALL_PREFIX}bin"
    RUNTIME_OUTPUT_DIRECTORY_RELEASE
      "${CMAKE_INSTALL_PREFIX}/${ARG_INSTALL_PREFIX}bin"
    RUNTIME_OUTPUT_DIRECTORY_RELWITHDEBINFO
      "${CMAKE_INSTALL_PREFIX}/${ARG_INSTALL_PREFIX}bin"

    RUNTIME_OUTPUT_NAME
      "${target}"
    RUNTIME_OUTPUT_NAME_DEBUG
      "${target}"
    RUNTIME_OUTPUT_NAME_MINSIZEREL
      "${target}"
    RUNTIME_OUTPUT_NAME_RELEASE
      "${target}"
    RUNTIME_OUTPUT_NAME_RELWITHDEBINFO
      "${target}"

    VS_WINDOWS_TARGET_PLATFORM_VERSION
      "${CMAKE_SYSTEM_VERSION}"
  )
  set_target_folder(${target})

  install(TARGETS ${target} RUNTIME
    DESTINATION ${CMAKE_INSTALL_BINDIR})
  #   EXPORT "${CMAKE_PROJECT_NAME}")
  # install(EXPORT "${CMAKE_PROJECT_NAME}"
  #   DESTINATION "${CMAKE_INSTALL_PREFIX}/cmake")

  if(ARG_PRECOMPILED_HEADER)
    target_precompile_headers(${target} PUBLIC "$<$<COMPILE_LANGUAGE:CXX>:${ARG_PRECOMPILED_HEADER}>")
  endif()

  if(WIN32 AND NOT "${ARG_MANIFEST}" STREQUAL "")
    configure_manifest(${target} "${ARG_MANIFEST}")
  endif()

  # Setup Google Breakpad toolchain on Linux
  # if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux" AND NOT SHIFT_NO_BREAKPAD_SYMBOLS)
  #   add_custom_target(${target}_breakpad ALL
  #     COMMAND ${CMAKE_SOURCE_DIR}/scripts/breakpad-process-binary.sh
  #       "$<TARGET_FILE:${target}>"
  #       "${CMAKE_SOURCE_DIR}"
  #       "$ENV{STRIP}"
  #     COMMENT "Producing Breakpad symbols for target ${target}..."
  #     VERBATIM
  #   )
  #   add_dependencies(${target}_breakpad ${target})
  # endif()
endfunction()
