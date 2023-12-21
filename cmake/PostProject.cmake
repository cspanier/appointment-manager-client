if(NOT POST_PROJECT_INCLUDED)
  set(POST_PROJECT_INCLUDED 1)

  if(USE_CPP20_MODULES)
    # See https://www.kitware.com/import-cmake-c20-modules/
    if(${CMAKE_MAJOR_VERSION} EQUAL 3 AND ${CMAKE_MINOR_VERSION} GREATER_EQUAL 28)
      # NOP
    elseif(${CMAKE_MAJOR_VERSION} EQUAL 3 AND ${CMAKE_MINOR_VERSION} EQUAL 27)
      set(CMAKE_EXPERIMENTAL_CXX_MODULE_CMAKE_API "aa1f7df0-828a-4fcd-9afc-2dc80491aca7")
      set(CMAKE_EXPERIMENTAL_CXX_MODULE_DYNDEP 1)
    elseif(${CMAKE_MAJOR_VERSION} EQUAL 3 AND ${CMAKE_MINOR_VERSION} EQUAL 26)
      set(CMAKE_EXPERIMENTAL_CXX_MODULE_CMAKE_API "2182bf5c-ef0d-489a-91da-49dbc3090d2a")
      set(CMAKE_EXPERIMENTAL_CXX_MODULE_DYNDEP 1)
    else()
      message(FATAL_ERROR "Unknown CMake version")
    endif()
  endif()

  if(NOT CMAKE_TOOLCHAIN_FILE)
    # If you encounter this error it means that you forgot to pass
    # -DCMAKE_TOOLCHAIN_FILE=<path-to-toolchain-file> to CMake.
    message(FATAL_ERROR "CMAKE_TOOLCHAIN_FILE is empty.\n"
      "Please define this CMake variable to something like "
      "\"cmake/Toolchain-[processor]-[system name]-[compiler].cmake\"")
  endif()

  # We define our own target processor variable because CMAKE_SYSTEM_PROCESSOR
  # is not fully portable and relies on system specific values.
  if("${CMAKE_SYSTEM_PROCESSOR}" MATCHES "^(x86_64|AMD64)$")
    set(SHIFT_SYSTEM_PROCESSOR x86_64)
  elseif("${CMAKE_SYSTEM_PROCESSOR}" MATCHES "^arm.*")
    set(SHIFT_SYSTEM_PROCESSOR arm)
  else()
    message(FATAL_ERROR "CMAKE_SYSTEM_PROCESSOR has an unsupported value of "
      "\"${CMAKE_SYSTEM_PROCESSOR}\".")
  endif()

  if(NOT CMAKE_SYSTEM_NAME STREQUAL "Linux" AND
     NOT CMAKE_SYSTEM_NAME STREQUAL "Windows")
    message(FATAL_ERROR "Unsupported platform \"${CMAKE_SYSTEM_NAME}\".")
  endif()

  if(USE_CPP_TOOLSET_VERSION_CHECK)
    if(MSVC AND NOT "${CMAKE_CXX_COMPILER_ID}" MATCHES "Clang")
      # This experimental code block attempts to make sure we're using the correct compiler version.
      execute_process(COMMAND link.exe /help
        OUTPUT_VARIABLE MSVC_VERSION
        ERROR_VARIABLE MSVC_VERSION
      )
      string(REGEX MATCHALL "[0-9]+" MSVC_VERSION_COMPONENTS "${MSVC_VERSION}")
      list(GET MSVC_VERSION_COMPONENTS 0 MSVC_VERSION_MAJOR)
      list(GET MSVC_VERSION_COMPONENTS 1 MSVC_VERSION_MINOR)
      list(GET MSVC_VERSION_COMPONENTS 2 MSVC_VERSION_PATCH)
      set(MSVC_VERSION ${MSVC_VERSION_MAJOR}.${MSVC_VERSION_MINOR}.${MSVC_VERSION_PATCH})
      if(NOT "${USE_CPP_TOOLSET_VERSION}" VERSION_EQUAL "${MSVC_VERSION}")
        message(FATAL_ERROR
          "Unexpected Microsoft Visual C++ compiler version (expected version '${USE_CPP_TOOLSET_VERSION}', "
          "but found version '${MSVC_VERSION}')\n"
          "If you get this error it usually means you upgraded your compiler without also changing the "
          "'cpp-toolset-version' field in the appropriate 'scripts/config-target-*.json' file.\n"
          "You can skip this check by setting 'USE_CPP_TOOLSET_VERSION_CHECK' to false in one of your "
          "'scripts/config-user-*.json' files and selecting it in/passing it to 'scripts/cmake.cmd'.")
      endif()
      # message(STATUS "########## Expected Tool Version ${USE_CPP_TOOLSET_VERSION}")
      # message(STATUS "########## Detected MSVC Version ${MSVC_VERSION_MAJOR}.${MSVC_VERSION_MINOR}.${MSVC_VERSION_PATCH} (${MSVC_VERSION_COMPONENTS})")
      # message(STATUS "########## Internal MSVC Version ${CMAKE_CXX_COMPILER_VERSION}")
    endif()
  endif()

  # Build a short compiler name and version used in binary file names.
  if(NOT SHIFT_COMPILER_ACRONYM)
    if(MSVC AND "${CMAKE_CXX_COMPILER_ID}" MATCHES "Clang")
      message(STATUS "Detected Clang in MSVC emulation mode. We cannot get the exact compiler version so we guess it.")
      set(compiler_acronym "clang80")
    elseif(MSVC AND CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL 19.30)
      set(compiler_acronym "vc143")
    elseif(MSVC AND CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL 19.20)
      set(compiler_acronym "vc142")
    elseif(MSVC AND CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL 19.10)
      set(compiler_acronym "vc141")
    elseif(MSVC AND CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL 19.0)
      set(compiler_acronym "vc140")
    elseif(CMAKE_COMPILER_IS_GNUCXX)
      execute_process(COMMAND ${CMAKE_CXX_COMPILER} -dumpfullversion -dumpversion
        OUTPUT_VARIABLE GCC_VERSION)
      string(REGEX MATCHALL "[0-9]+" GCC_VERSION_COMPONENTS ${GCC_VERSION})
      list(GET GCC_VERSION_COMPONENTS 0 GCC_VERSION_MAJOR)
      list(GET GCC_VERSION_COMPONENTS 1 GCC_VERSION_MINOR)
      set(compiler_acronym "gcc${GCC_VERSION_MAJOR}${GCC_VERSION_MINOR}")
    elseif(${CMAKE_CXX_COMPILER_ID} MATCHES "Clang")
      execute_process(COMMAND ${CMAKE_CXX_COMPILER} --version
        OUTPUT_VARIABLE CLANG_VERSION)
      string(REGEX MATCHALL "[0-9]+" CLANG_VERSION_COMPONENTS ${CLANG_VERSION})
      list(GET CLANG_VERSION_COMPONENTS 0 CLANG_VERSION_MAJOR)
      list(GET CLANG_VERSION_COMPONENTS 1 CLANG_VERSION_MINOR)
      set(compiler_acronym "clang${CLANG_VERSION_MAJOR}${CLANG_VERSION_MINOR}")
    else()
      message(FATAL_ERROR "Unknown or unsupported compiler.")
    endif()
    set(SHIFT_COMPILER_ACRONYM ${compiler_acronym} CACHE INTERNAL
      "Compiler short name and version.")
  endif()

  ##############################################################################

  # vcpkg adds the path to debug variants of all libraries in front of the
  # CMAKE_PREFIX_PATH variable. This causes obvious issues with find_library. 
  set(CMAKE_PREFIX_PATH_DEBUG ${CMAKE_PREFIX_PATH})
  foreach(config ${CMAKE_CONFIGURATION_TYPES})
    set(CMAKE_PREFIX_PATH_${config} ${CMAKE_PREFIX_PATH})
    if(NOT "${config}" STREQUAL "DEBUG")
      list(FILTER CMAKE_PREFIX_PATH_${config} EXCLUDE REGEX ".*\/debug")
    endif()
  endforeach()

  ##############################################################################

  # Define a custom directory where to look for modules to be loaded by the
  # include() or find_package() commands before checking the default modules
  # that come with CMake.
  set(CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")

  include("${CMAKE_SOURCE_DIR}/cmake/UtilityMacros.cmake")
  include("${CMAKE_SOURCE_DIR}/cmake/AddExecutable.cmake")
  include("${CMAKE_SOURCE_DIR}/cmake/AddLibrary.cmake")
  include("${CMAKE_SOURCE_DIR}/cmake/AddTest.cmake")
  include("${CMAKE_SOURCE_DIR}/cmake/AddDocumentation.cmake")
  
  include("${CMAKE_SOURCE_DIR}/cmake/ShiftFindLibrary.cmake")
  include("${CMAKE_SOURCE_DIR}/cmake/ShiftFindHeader.cmake")

  # Enable testing in this folder and below.
  enable_testing()

  # Enable use of virtual folders in Microsoft Visual Studio project generators.
  set_property(GLOBAL PROPERTY USE_FOLDERS ON)

  # Override the default installation location unless the user manually
  # specified a different path.
  if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
    set(CMAKE_INSTALL_PREFIX "${CMAKE_SOURCE_DIR}/production" CACHE PATH
      "Install directory used by install()." FORCE)
  endif()

  ##############################################################################

  set(SHIFT_GLOBAL_DEFINITIONS
    # Define "_DEBUG" in Debug builds
    $<$<CONFIG:Debug>:_DEBUG>

    # Define "_RELEASE" only in full Release builds.
    $<$<CONFIG:Release>:_RELEASE>

    # Disable automatic linking to Boost libraries (which is handled by CMake
    # instead).
    "BOOST_ALL_NO_LIB"

    # This macro is useful for when updating the compiler to a version not yet
    # known to Boost.
    # "BOOST_CONFIG_SUPPRESS_OUTDATED_MESSAGE"

    # Prefer use of Boost Coroutine version 2 in various Boost libraries.
    "BOOST_COROUTINES_V2"

    # Remove auto_ptr from the Boost locale interfaces and prevent deprecated
    # warnings.
    "BOOST_LOCALE_HIDE_AUTO_PTR"

    # Enable custom assert handlers defined in 'shift/platform/private/assert.cpp'.
    "BOOST_ENABLE_ASSERT_DEBUG_HANDLER"

    # Prefer use of std::filesystem over boost::filesystem in boost::process.
    "BOOST_PROCESS_USE_STD_FS"

    # Boost ASIO deallocates user memory using its own allocator for some
    # unknown reason, which throws an exception.
    # ToDo: Find the actual cause instead!
    "BOOST_ASIO_DISABLE_ALIGNOF"
  )
  if(USE_CPP20_MODULES)
    list(APPEND SHIFT_GLOBAL_DEFINITIONS
      "USE_CPP20_MODULES"
    )
  endif()

  if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    list(APPEND SHIFT_GLOBAL_DEFINITIONS
      "SHIFT_PLATFORM_LINUX"

      # Rarely used by external code (e.g. AMD Tootle)
      "_LINUX"

      # Compilers supporting auto-tss cleanup may define BOOST_THREAD_USE_LIB.
      # ToDo: This should have no effect because we disabled automatic linking
      # using BOOST_ALL_NO_LIB above.
      "BOOST_THREAD_USE_LIB=1"

      # Enable Valgrind support for Boost Context and Boost Coroutine (v1).
      # This is required to identify stack regions as such, so they are
      # correctly handled by Valgrind.
      # This causes a crash in Boost since 1.69.
      # See https://github.com/boostorg/asio/issues/262
      # "BOOST_USE_VALGRIND=1"
    )

    set(CMAKE_THREAD_PREFER_PTHREAD TRUE)
    set(THREADS_PREFER_PTHREAD_FLAG TRUE)

    find_package(Threads REQUIRED)
  elseif(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    list(APPEND SHIFT_GLOBAL_DEFINITIONS
      "SHIFT_PLATFORM_WINDOWS"
      "WIN32"
      "_WINDOWS"
      # We need to define both WINVER and _WIN32_WINNT.
      "WINVER=0x0A00"  # Windows 10
      "_WIN32_WINNT=0x0A00"  # Windows 10
      "_CONSOLE"
      # Enable Unicode character set, which selects W-variants for WinAPI
      # functions.
      # "UNICODE"
      # "_UNICODE"

      # Drastically reduce the number of implicite includes introduced by
      # Windows.h to improve compile speed.
      "WIN32_LEAN_AND_MEAN"

      # Prevent Windows.h from defining macros min and max, which collide with
      # std::min and std::max.
      "NOMINMAX"

      # Enables math defines which are not in Standard C/C++, but were
      # introduced by Microsoft long ago. Some code today depends on them to be
      #  defined. This includes M_PI, M_PI_2, M_SQRT2, M_E, ...
      # "_USE_MATH_DEFINES"

      # See type_traits header:
      # You've instantiated std::aligned_storage<Len, Align> with an extended
      # alignment (in other words, Align > alignof(max_align_t)).
      # Before VS 2017 15.8, the member type would non-conformingly have an
      # alignment of only alignof(max_align_t). VS 2017 15.8 was fixed to handle
      # this correctly, but the fix inherently changes layout and breaks binary
      # compatibility (*only* for uses of aligned_storage with extended
      # alignments).
      # Please define either
      # (1) _ENABLE_EXTENDED_ALIGNED_STORAGE to acknowledge that you understand
      # this message and that you actually want a type with an extended
      # alignment, or
      # (2) _DISABLE_EXTENDED_ALIGNED_STORAGE to silence this message and get
      # the old non-conformant behavior.
      "_ENABLE_EXTENDED_ALIGNED_STORAGE"

      # This macro enables use of a pre-compiled Boost stacktrace library.
      # Without Boost stacktrace is a header-only library, but requires
      # additional system dependencies.
      # "BOOST_STACKTRACE_LINK"

      # Without BOOST_STACKTRACE_LINK being defined this selects the stacktrace
      # implementation to use.
      "BOOST_STACKTRACE_USE_WINDBG"
    )

      # Add processor macros as required external headers.
    if("${SHIFT_SYSTEM_PROCESSOR}" STREQUAL "x86_32")
      list(APPEND SHIFT_GLOBAL_DEFINITIONS
        # ToDo: Who needs this?
        "_WIN32"
        # Used by winnt.h
        "_X86_"
      )
    elseif("${SHIFT_SYSTEM_PROCESSOR}" STREQUAL "x86_64")
      list(APPEND SHIFT_GLOBAL_DEFINITIONS
        # ToDo: Who needs this?
        "WIN64"
        # ToDo: Who needs this?
        "_WIN64"
        # Used by winnt.h
        "_AMD64_"
      )
    endif()
  endif()
endif()
