function(shift_add_test target)
  set(argument_names "INSTALL_PREFIX;SOURCE_DIRS;SOURCEEXTS;MANIFEST")
  set(argument_names "${argument_names};LIBRARIES;DEPENDENCIES")
  set(argument_names "${argument_names};QT5MODULES;CXXFLAGS")
  parse_arguments("${argument_names}" "" "${ARGN}")
  message(STATUS "Adding test ${target}...")

  target_name_to_camel_case(${target} target_camelcase)

  if("${ARG_INSTALL_PREFIX}" STREQUAL "")
    set(ARG_INSTALL_PREFIX "./")
  elseif(NOT "${ARG_INSTALL_PREFIX}" MATCHES ".*/$")
    set(ARG_INSTALL_PREFIX "${ARG_INSTALL_PREFIX}/")
  endif()

  if(WIN32 AND NOT "${ARG_MANIFEST}" STREQUAL "" AND NOT EXISTS "${ARG_MANIFEST}")
    file(TOUCH "${ARG_MANIFEST}")
  endif()
 
  if(ARG_SOURCE_DIRS)
    set(source_roots ${ARG_SOURCE_DIRS})
  else()
    set(source_roots ${CMAKE_CURRENT_SOURCE_DIR})
    message(STATUS "SOURCE_DIRS (${ARG_SOURCE_DIRS}) not set, so falling back to use ${source_roots}...")
  endif()
  find_sources(sources
    ROOTS
      "${source_roots}"
    EXTS
      "*.h" "*.hpp" "*.hxx"
      "*.c" "*.cc" "*.cpp" "*.cxx"
      "*.ixx" "*.cppm"
      "*.in"
      "*.manifest"
      "*.rc" "*.rc2"
  )

  if(MSVC)
    # Do NOT use multi-byte character set string encoding on MSVC.
    remove_definitions(-D_MBCS)
  endif()

  if(NOT sources)
    message(WARNING "No test cases found in folder(s) ${source_roots}")
  endif()
  add_executable(${target} ${sources})
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

  foreach(dependency ${ARG_DEPENDENCIES})
    if (TARGET ${dependency})
      add_dependencies(${target} ${dependency})
    endif()
  endforeach()

  target_include_directories(${target}
    PRIVATE
      "${CMAKE_CURRENT_SOURCE_DIR}/public"
      "${CMAKE_CURRENT_SOURCE_DIR}/private"
      "${CMAKE_CURRENT_SOURCE_DIR}/test"
  )
  foreach(prefix_path ${CMAKE_PREFIX_PATH})
    target_include_directories(${target} PRIVATE "${prefix_path}/include")
  endforeach()
  if(${CMAKE_CXX_COMPILER_ID} MATCHES "Clang")
    # libc++ include directory is set after qt moc file generation because of
    # missing C++11 support in QT4 moc.
    target_include_directories(${target} PRIVATE ${LIBCXX_INCLUDE_DIRS})
  endif()

  foreach(qt6module ${ARG_QT5MODULES})
    target_include_directories(${target} PRIVATE "${Qt6${qt6module}_INCLUDE_DIRS}")
    target_compile_definitions(${target} PRIVATE ${Qt6${qt6module}_DEFINITIONS})
    target_link_libraries(${target} PRIVATE "${Qt6${qt6module}_LIBRARIES}")
  endforeach()

  target_link_libraries(${target} PRIVATE $<$<AND:$<CXX_COMPILER_ID:GNU>,$<VERSION_LESS:$<CXX_COMPILER_VERSION>,9.0>>:stdc++fs>)
  target_link_libraries(${target} PRIVATE $<$<PLATFORM_ID:Linux>:Threads::Threads>)

  target_compile_definitions(${target}
    PRIVATE "$<$<CONFIG:Debug>:BUILD_CONFIG_DEBUG>"
    PRIVATE "$<$<CONFIG:MinSizeRel>:BUILD_CONFIG_MINSIZEREL>"
    PRIVATE "$<$<CONFIG:Release>:BUILD_CONFIG_RELEASE>"
    PRIVATE "$<$<CONFIG:RelWithDebInfo>:BUILD_CONFIG_RELWITHDEBINFO>"
    PRIVATE SHIFT_TEST_MODULE_NAME=${target}
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

    VS_WINDOWS_TARGET_PLATFORM_VERSION "${CMAKE_SYSTEM_VERSION}"
  )
  set_target_folder(${target})

  if(WIN32 AND NOT "${ARG_MANIFEST}" STREQUAL "")
    configure_manifest(${target} "${ARG_MANIFEST}")
  endif()

  add_test(NAME ${target}
    WORKING_DIRECTORY "${CMAKE_INSTALL_PREFIX}/${ARG_INSTALL_PREFIX}test"
    COMMAND $<TARGET_FILE:${target}> --log_level=all
  )

  install(TARGETS ${target} RUNTIME
    DESTINATION ${CMAKE_INSTALL_BINDIR})
endfunction()
