update_build_version(appointment.update_config
  "${CMAKE_CURRENT_SOURCE_DIR}/config/config.hpp"
)

shift_add_library(appointment.config INTERFACE
  PUBLIC_SOURCE_DIRS
    "${CMAKE_CURRENT_SOURCE_DIR}/config"
)
add_dependencies(appointment.config appointment.update_config)

shift_add_library(appointment.lib STATIC
  PUBLIC_SOURCE_DIRS
    ${CMAKE_CURRENT_SOURCE_DIR}/include
  PRIVATE_SOURCE_DIRS
    ${CMAKE_CURRENT_SOURCE_DIR}/src/lib
  DEPENDENCIES
    appointment.config
    Boost::boost
)

shift_add_executable(appointment
  SOURCEDIRS
    ${CMAKE_CURRENT_SOURCE_DIR}/src/app
  # MANIFEST
  #   "${CMAKE_CURRENT_SOURCE_DIR}/private/application.manifest"
  DEPENDENCIES
    appointment.lib
    appointment.config
    Boost::program_options
)

shift_add_test(test.appointment.lib
  SOURCE_DIRS
    ${CMAKE_CURRENT_SOURCE_DIR}/test
  # MANIFEST
  #   ${CMAKE_CURRENT_SOURCE_DIR}/test/application.manifest
  DEPENDENCIES
    appointment.lib
    Boost::boost
    Catch2::Catch2
    Catch2::Catch2WithMain
)
