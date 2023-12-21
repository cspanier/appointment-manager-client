cmake_minimum_required(VERSION 3.27 FATAL_ERROR)

# Setup vcpkg script with CMake (note: should be placed before project() call)
set(CMAKE_TOOLCHAIN_FILE ${CMAKE_CURRENT_SOURCE_DIR}/../dependencies/vcpkg/scripts/buildsystems/vcpkg.cmake CACHE STRING "Vcpkg toolchain file")

include("${CMAKE_SOURCE_DIR}/cmake/PreProject.cmake")
project(PsychotherapieSpanier
  VERSION 0.0.1
  DESCRIPTION "Backend server for psychotherapie-spanier.de"
  LANGUAGES CXX)

include("${CMAKE_SOURCE_DIR}/cmake/PostProject.cmake")
set(CMAKE_CXX_STANDARD 23)

find_package(fmt CONFIG REQUIRED)
find_package(Catch2 CONFIG REQUIRED)

# Platform specific threading library.
#set(THREADS_PREFER_PTHREAD_FLAG ON)
#find_package(Threads REQUIRED)
#find_package(GSL REQUIRED)

#find_package(ZLIB REQUIRED)
#find_package(BZip2 REQUIRED)
#find_package(Breakpad REQUIRED)

# set(ICU_DEBUG ON)
find_package(ICU REQUIRED
COMPONENTS
  data
  i18n
  io
  # le
  # lx
  # test
  tu
  uc
)

if(NOT CMAKE_SYSTEM_NAME STREQUAL "Windows")
  find_package(Iconv REQUIRED)
endif()

##############################################################################
# Boost
set(Boost_VERSION "1.83")
set(Boost_DEBUG Off)
if (NOT BOOST_ROOT)
  if (CMAKE_FIND_ROOT_PATH)
    set(BOOST_ROOT "${CMAKE_FIND_ROOT_PATH}" "${CMAKE_FIND_ROOT_PATH}/usr")
  else()
    set(BOOST_ROOT "${CMAKE_PREFIX_PATH}" "${CMAKE_PREFIX_PATH}/usr")
  endif()
endif()
if(${USE_SYSTEM_BOOST})
  message(STATUS "Using system Boost")
  set(Boost_NO_BOOST_CMAKE OFF)
  set(Boost_NO_SYSTEM_PATHS OFF)
  set(Boost_USE_STATIC_LIBS OFF)
else()
  message(STATUS "Using custom built Boost")
  set(Boost_NO_BOOST_CMAKE ON)
  set(Boost_NO_SYSTEM_PATHS ON)
  set(Boost_USE_STATIC_LIBS ON)
endif()
set(Boost_ADDITIONAL_VERSIONS "${Boost_VERSION}" "${Boost_VERSION}.0")
set(Boost_USE_MULTITHREADED ON)
set(Boost_USE_STATIC_RUNTIME OFF)
if("${SHIFT_SYSTEM_PROCESSOR}" STREQUAL "x86_64")
  set(Boost_ARCHITECTURE "-x64")
endif()
set(BOOST_LIBRARYDIR "")
foreach(library_dir IN LISTS BOOST_ROOT)
  list(APPEND BOOST_LIBRARYDIR "${library_dir}/lib")
  list(APPEND BOOST_LIBRARYDIR "${library_dir}/usr/lib")
  if (BOOST_LIBRARYDIR_SUFFIX)
    list(APPEND BOOST_LIBRARYDIR "${library_dir}/lib/${BOOST_LIBRARYDIR_SUFFIX}")
    list(APPEND BOOST_LIBRARYDIR "${library_dir}/usr/lib/${BOOST_LIBRARYDIR_SUFFIX}")
  endif()
endforeach()

# # When using Clang on Windows we need to fix the Boost compiler suffix.
# if("${CMAKE_CXX_COMPILER_ID}" MATCHES "Clang" AND MSVC)
#   set(Boost_COMPILER "-vc142")
#   message(STATUS "Fixing Boost_COMPILER=${Boost_COMPILER}")
# else
if("${CMAKE_CXX_COMPILER_ID}" MATCHES "GNU")
  set(Boost_COMPILER "-gcc8")
  message(STATUS "Fixing Boost_COMPILER=${Boost_COMPILER}")
endif()

if("${SHIFT_SYSTEM_PROCESSOR}" MATCHES "^arm.*")
  set(Boost_ARCHITECTURE "-a32")
  set(BOOST_THREAD "thread")
endif()
find_package(Boost ${Boost_VERSION} REQUIRED
  COMPONENTS
    # ${BOOST_STACKTRACE_STATIC_LIB}
    # coroutine
    # context
    program_options
    date_time
    locale
    system
  )

##############################################################################
