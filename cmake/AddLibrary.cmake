function(shift_add_library target)
  set(argument_names "INSTALL_PREFIX;DOCDIRS;PUBLIC_SOURCE_DIRS;PRIVATE_SOURCE_DIRS")
  set(argument_names "${argument_names};MANIFEST;SOURCEEXTS;SOURCES;PRECOMPILED_HEADER")
  set(argument_names "${argument_names};LIBRARIES")
  set(argument_names "${argument_names};DEPENDENCIES;CXXFLAGS;LFLAGS")
  parse_arguments("${argument_names}" "STATIC;SHARED;OBJECT;INTERFACE" ${ARGN})
  message(STATUS "Adding library ${target}...")

  if(NOT ARG_STATIC AND NOT ARG_SHARED AND NOT ARG_OBJECT AND NOT ARG_INTERFACE)
    message(FATAL_ERROR "You need to specify the type of the library "
      "'${target}', which can be one of STATIC, SHARED, OBJECT, or INTERFACE.")
  endif()

  if("${ARG_INSTALL_PREFIX}" STREQUAL "")
    set(ARG_INSTALL_PREFIX "./")
  elseif(NOT "${ARG_INSTALL_PREFIX}" MATCHES ".*/$")
    # Add trailing slash, if not already present
    set(ARG_INSTALL_PREFIX "${ARG_INSTALL_PREFIX}/")
  endif()

  if(WIN32 AND ARG_SHARED AND NOT "${ARG_MANIFEST}" STREQUAL "" AND NOT EXISTS "${ARG_MANIFEST}")
    file(TOUCH "${ARG_MANIFEST}")
  endif()

  if(ARG_DOCDIRS)
    set(_docdirs ${ARG_DOCDIRS})
  else()
    set(_docdirs "${CMAKE_CURRENT_SOURCE_DIR}/doc")
  endif()
  find_sources(documentation_files
    ROOTS ${_docdirs}
    EXTS "*.md" "*.txt" "*.png" "*.jpg"
    GROUPPREFIX "doc/")
  list(APPEND sources ${documentation_files})

  if("${ARG_SOURCEEXTS}" STREQUAL "")
    set(ARG_SOURCEEXTS
      "*.h" "*.hpp" "*.hxx"
      "*.c" "*.cc" "*.cpp" "*.cxx"
      "*.ixx" "*.cppm"
      "*.inl"
      "*.def"
      "*.png" "*.svg" "*.jpg" "*.bmp" "*.ico"
      "*.in"
    )
    if(ARG_SHARED)
      set(ARG_SOURCEEXTS ${ARG_SOURCEEXTS}
        "*.manifest"
        "*.rc" "*.rc2"
      )
    endif()
  endif()

  if(ARG_PUBLIC_SOURCE_DIRS)
    find_sources(public_sources
      ROOTS ${ARG_PUBLIC_SOURCE_DIRS}
      EXTS ${ARG_SOURCEEXTS}
      GROUPPREFIX "include/"
      INSTALLDIR "${ARG_INSTALL_PREFIX}include")
    list(APPEND sources ${public_sources})
  endif()

  if(ARG_PRIVATE_SOURCE_DIRS)
    find_sources(private_sources
      ROOTS ${ARG_PRIVATE_SOURCE_DIRS}
      EXTS ${ARG_SOURCEEXTS}
      GROUPPREFIX "src/")
    list(APPEND sources ${private_sources})
  endif()

  list(APPEND sources ${ARG_SOURCES})
  if("${sources}" STREQUAL "")
    message(FATAL_ERROR "Target ${target} has no source files")
  endif()

  if(ARG_STATIC)
    set(type STATIC)
  elseif(ARG_INTERFACE)
    set(type INTERFACE)
  elseif(ARG_OBJECT)
    set(type OBJECT)
  elseif(ARG_SHARED)
    set(type SHARED)
  endif()

  add_library(${target} ${type} ${sources})
  if(NOT ARG_INTERFACE)
    target_link_libraries(${target} PUBLIC ${ARG_LIBRARIES})
    target_compile_definitions(${target} PRIVATE "${SHIFT_GLOBAL_DEFINITIONS}")
  
    foreach(dependency ${ARG_DEPENDENCIES})
      if("${dependency}" MATCHES "^shift.")
        if_not_target_find_package(${dependency})
      endif()
      if (TARGET ${dependency})
        target_link_libraries(${target} PUBLIC ${dependency})
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
          target_link_libraries(${target} PUBLIC ${${dependency}_LIBRARIES})
        endif()
      else()
        # Generator expressions cannot be evaluated with the code above,
        # so we assume it resolves to some target.
        target_link_libraries(${target} PUBLIC ${dependency})
      endif()
    endforeach()

    target_link_libraries(${target} PUBLIC $<$<AND:$<CXX_COMPILER_ID:GNU>,$<VERSION_LESS:$<CXX_COMPILER_VERSION>,9.0>>:stdc++fs>)
    target_link_libraries(${target} PUBLIC $<$<PLATFORM_ID:Linux>:Threads::Threads>)

    target_compile_definitions(${target}
      PRIVATE "$<$<CONFIG:Debug>:BUILD_CONFIG_DEBUG>"
      PRIVATE "$<$<CONFIG:MinSizeRel>:BUILD_CONFIG_MINSIZEREL>"
      PRIVATE "$<$<CONFIG:Release>:BUILD_CONFIG_RELEASE>"
      PRIVATE "$<$<CONFIG:RelWithDebInfo>:BUILD_CONFIG_RELWITHDEBINFO>"
      PRIVATE BUILD_BIN_FOLDER="bin"
    )
  endif()

  if(ARG_SHARED)
    # Automatically add a preprocessor macro to shared library builds
    STRING(TOUPPER "${target}_EXPORTS" export_define)
    STRING(REGEX REPLACE "\\." "_" export_define "${export_define}")
    target_compile_definitions(${target} PRIVATE ${export_define})
  endif()

  if(NOT ARG_INTERFACE)
    if((CMAKE_CXX_COMPILER_ID MATCHES "Clang" OR
        CMAKE_CXX_COMPILER_ID MATCHES "GNU") AND NOT MSVC)
      # -fPIC: Generate position independent code.
      set(ARG_CXXFLAGS "-fPIC ${ARG_CXXFLAGS}")
    endif()

    foreach(source_path ${ARG_PUBLIC_SOURCE_DIRS})
      target_include_directories(${target}
        PUBLIC $<BUILD_INTERFACE:${source_path}>
      )
    endforeach()
    foreach(source_path ${ARG_PRIVATE_SOURCE_DIRS})
      target_include_directories(${target} PRIVATE "${source_path}")
    endforeach()
    foreach(prefix_path ${CMAKE_PREFIX_PATH})
      target_include_directories(${target} PRIVATE "${prefix_path}/include")
    endforeach()

    set_target_properties(${target} PROPERTIES
      CXX_STANDARD 23
      CXX_STANDARD_REQUIRED ON
      CXX_EXTENSIONS OFF
      PREFIX ""
      COMPILE_FLAGS "${ARG_CXXFLAGS}"
      LINK_FLAGS "${ARG_LFLAGS}"
      LINKER_LANGUAGE CXX

      # Non-DLL platforms put shared libraries into this folder.
      LIBRARY_OUTPUT_DIRECTORY
        "${CMAKE_INSTALL_PREFIX}/${ARG_INSTALL_PREFIX}bin"
      LIBRARY_OUTPUT_DIRECTORY_DEBUG
        "${CMAKE_INSTALL_PREFIX}/${ARG_INSTALL_PREFIX}bin"
      LIBRARY_OUTPUT_DIRECTORY_MINSIZEREL
        "${CMAKE_INSTALL_PREFIX}/${ARG_INSTALL_PREFIX}bin"
      LIBRARY_OUTPUT_DIRECTORY_RELEASE
        "${CMAKE_INSTALL_PREFIX}/${ARG_INSTALL_PREFIX}bin"
      LIBRARY_OUTPUT_DIRECTORY_RELWITHDEBINFO
        "${CMAKE_INSTALL_PREFIX}/${ARG_INSTALL_PREFIX}bin"

      # DLL platforms put shared libraries into this folder.
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

      OUTPUT_NAME
        "${target}"
      OUTPUT_NAME_DEBUG
        "${target}"
      OUTPUT_NAME_MINSIZEREL
        "${target}"
      OUTPUT_NAME_RELEASE
        "${target}"
      OUTPUT_NAME_RELWITHDEBINFO
        "${target}"

      PDB_NAME
        "${target}"
      PDB_NAME_DEBUG
        "${target}"
      PDB_NAME_MINSIZEREL
        "${target}"
      PDB_NAME_RELEASE
        "${target}"
      PDB_NAME_RELWITHDEBINFO
        "${target}"

      VS_WINDOWS_TARGET_PLATFORM_VERSION "${CMAKE_SYSTEM_VERSION}"
    )
    if(ARG_STATIC OR ARG_OBJECT)
      set_target_properties(${target} PROPERTIES
        PDB_OUTPUT_DIRECTORY
          "${CMAKE_INSTALL_PREFIX}/${ARG_INSTALL_PREFIX}lib"
      )
    elseif(ARG_SHARED)
      set_target_properties(${target} PROPERTIES
        PDB_OUTPUT_DIRECTORY
          "${CMAKE_INSTALL_PREFIX}/${ARG_INSTALL_PREFIX}bin"
      )
    endif()
    set_target_folder(${target})
  else()
    target_include_directories(${target}
      INTERFACE
        $<BUILD_INTERFACE:${ARG_PUBLIC_SOURCE_DIRS}>
        $<INSTALL_INTERFACE:include>
      )
  endif()

  foreach(dependency ${ARG_DEPENDENCIES})
    if (TARGET ${dependency})
      add_dependencies(${target} ${dependency})
    endif()
  endforeach()

  if(NOT ARG_OBJECT)
  #   install(TARGETS ${target} RUNTIME
  #     DESTINATION ${CMAKE_INSTALL_BINDIR}
  #   )

  #   include(CMakePackageConfigHelpers)
  # 
  #   target_name_to_camel_case(${target} target_camelcase)
  # 
  #   # Generate the config file that includes the exports
  #   configure_package_config_file(${CMAKE_CURRENT_SOURCE_DIR}/Config.cmake.in
  #     "${CMAKE_CURRENT_BINARY_DIR}/${target_camelcase}Config.cmake"
  #     INSTALL_DESTINATION lib/cmake/${target_camelcase}
  #     NO_SET_AND_CHECK_MACRO
  #     NO_CHECK_REQUIRED_COMPONENTS_MACRO)
  #   # Generate the version file for the config file
  #   write_basic_package_version_file(
  #     "${CMAKE_CURRENT_BINARY_DIR}/${target_camelcase}ConfigVersion.cmake"
  #     VERSION "${PROJECT_VERSION}"
  #     COMPATIBILITY AnyNewerVersion)
  # 
  #     EXPORT "${CMAKE_PROJECT_NAME}")
  #   install(EXPORT "${CMAKE_PROJECT_NAME}"
  #     DESTINATION "${CMAKE_INSTALL_PREFIX}/cmake")
  #   install(
  #     TARGETS ${target}
  #     DESTINATION lib
  #     EXPORT ${target_camelcase}Targets)
  #   install(
  #     EXPORT ${target_camelcase}Targets
  #     FILE ${target_camelcase}Targets.cmake
  #     DESTINATION lib/cmake/${target_camelcase})
  #   install(
  #     FILES
  #       ${CMAKE_CURRENT_BINARY_DIR}/${target_camelcase}Config.cmake
  #       ${CMAKE_CURRENT_BINARY_DIR}/${target_camelcase}ConfigVersion.cmake
  #     DESTINATION lib/cmake/${target_camelcase})
  endif()

  if(ARG_PRECOMPILED_HEADER)
    target_precompile_headers(${target} PUBLIC "$<$<COMPILE_LANGUAGE:CXX>:${ARG_PRECOMPILED_HEADER}>")
  endif()

  if(WIN32 AND ARG_SHARED AND NOT "${ARG_MANIFEST}" STREQUAL "")
    configure_manifest(${target} "${ARG_MANIFEST}")
  endif()
endfunction()
