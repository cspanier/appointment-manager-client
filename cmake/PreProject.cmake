if(NOT PRE_PROJECT_INCLUDED)
  set(PRE_PROJECT_INCLUDED 1)

  option(USE_DEVELOPMENT_VERSION "Tag all binaries of this build as non-official version" On)
  option(USE_DIRTY_BUILD_CHECK "Tag all binaries as dirty if there are any pending changes in Git." On)
  option(USE_CPP_TOOLSET_VERSION "The version of the compiler we're expected to use" 0)
  option(USE_CPP_TOOLSET_VERSION_CHECK "Enforce a hard check for the exact compiler version during CMake run-time" On)
  option(USE_CPP20_MODULES "Enable experimental support of C++20 modules to improve compile time." OFF)
  option(USE_TARGET_FOLDERS "Group targets in virtual folders within MSVS solution." OFF)
  option(USE_LEGACY_CPU_SUPPORT "Disable use of instruction sets (like AVX) not found on old CPUs" OFF)
  option(USE_MEMORY_SANITIZER
    "Enable use of memory sanitizer. This is supported only by Clang." OFF)
  option(USE_ADDRESS_SANITIZER
    "Enable use of address sanitizer. This is supported by MSVC and Clang." OFF)
  option(USE_UNDEFINED_BEHAVIOR_SANITIZER
    "Enable use of undefined behavior sanitizer. This is supported only by Clang." OFF)
  option(CLANG_TIDY_WITH_MSVC
    "Disable compile flag overrides which would break clang tidy in combination with MSVC." OFF)

  # Specifies a CMake file that overrides platform information. It is loaded
  # after CMake’s builtin compiler and platform information modules but before
  # that information is being used. The file may set platform information
  # variables that override CMake’s defaults.
  set(CMAKE_USER_MAKE_RULES_OVERRIDE
    "${CMAKE_SOURCE_DIR}/cmake/CompilerFlagOverrides.cmake")

  # Enable output of compile commands during generation. CMake then generates a
  # compile_commands.json file containing the exact compiler calls for all
  # translation units of the project in machine-readable form.
  # Note: This only works for Makefile and Ninja generators.
  set(CMAKE_EXPORT_COMPILE_COMMANDS ON CACHE BOOL
    "Enable generation of compile_commands.json file.")

  if("${CMAKE_GENERATOR}" MATCHES "Visual Studio" AND
    "${CMAKE_GENERATOR_TOOLSET}" STREQUAL "")
    message(WARNING "Visual Studio generators use the x86 host compiler by "
                    "default, even for 64-bit targets. This can result in "
                    "linker instability and out of memory errors. "
                    "To use the 64-bit host compiler, pass -Thost=x64 on the "
                    "CMake command line.")
  endif()
endif()
