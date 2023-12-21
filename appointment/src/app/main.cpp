#include <cstdlib>
#include <iostream>
#include <format>
#include <config.hpp>

int main(int argc, char* argv[])
{
  std::cout << std::format("Version {}\n", build_version_full);
  return EXIT_SUCCESS;
}
