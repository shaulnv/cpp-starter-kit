// std
#include <filesystem>
#include <string>
// 3rd party
#include <cxxopts.hpp>
#include <fmt/format.h>
// project
#include "starterkit/starterkit.h"
#include "starterkit/version.h"

namespace fs = std::filesystem;

auto main(int argc, char **argv) -> int {
  cxxopts::Options options(*argv, "A program to welcome the world!");

  auto name = std::string{"bob"};
  auto home_dir = fs::path{"/home/bob"};

  // clang-format off
  options.add_options()
    ("h,help", "Show help")
    ("v,version", "Print the current version number")
    ("name", "user name", cxxopts::value(name))
    ("path", "home directory", cxxopts::value(home_dir))
  ;
  // clang-format on

  auto result = options.parse(argc, argv);

  if (result["help"].as<bool>()) {
    fmt::println("{}", options.help());
    return 0;
  }

  if (result["version"].as<bool>()) {
    fmt::println("version: {}", STARTERKIT_VERSION);
    return 0;
  }

  fmt::println("starterkit/{}, user name: {}, home directory: {}, answer: {}", STARTERKIT_VERSION,
               name, home_dir.string(), starterkit_lib_answer());

  return 0;
}
