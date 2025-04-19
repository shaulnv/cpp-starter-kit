// std
#include <exception>
#include <string>
// 3rd party
#include <fmt/base.h>

#include <magic_enum.hpp>
#include <structopt/app.hpp>
// project
#include "starterkit/starterkit.h"
#include "starterkit/version.h"

namespace {

  struct Options {
    // positional argument
    //   e.g., ./starterkit <file>
    std::string config_file;

    // optional argument
    //   e.g., -b "192.168.5.3"
    //   e.g., --bind_address "192.168.5.3"
    //
    // options can be delimited with `=` or `:`
    // note: single dash (`-`) is enough for short & long option
    //   e.g., -bind_address=localhost
    //   e.g., -b:192.168.5.3
    //
    // the long option can also be provided in kebab case:
    //   e.g., --bind-address 192.168.5.3
    std::optional<std::string> bind_address;

    // flag argument
    // Use `std::optional<bool>` and provide a default value.
    //   e.g., -v
    //   e.g., --verbose
    //   e.g., -verbose
    std::optional<bool> verbose = false;

    // directly define and use enum classes to limit user choice
    //   e.g., --log-level debug
    //   e.g., -l error
    enum class LogLevel { debug, info, warn, error, critical };
    std::optional<LogLevel> log_level = LogLevel::info;

    // pair argument
    // e.g., -u <name> <email>
    // e.g., --user <name> <email>
    using User = std::pair<std::string, std::string>;
    std::optional<User> user = User{"bob", "bob@example.com"};

    // use containers like std::vector
    // to collect "remaining arguments" into a list
    std::vector<std::string> files;
  };
  STRUCTOPT(Options, config_file, bind_address, verbose, log_level, user, files);

  auto main_impl(int argc, char **argv) -> int {
    auto const options = structopt::app("my_app", STARTERKIT_VERSION).parse<Options>(argc, argv);

    auto [name, email] = options.user.value_or(Options::User{"bob", "bob@example.com"});
    auto log_level = options.log_level.value_or(Options::LogLevel::info);
    fmt::println("starterkit/{}, user: {} <{}>, log level: {}, answer: {}", STARTERKIT_VERSION,
                 name, email, magic_enum::enum_name(log_level), starterkit_lib_answer());

    return 0;
  }
}  // namespace

auto main(int argc, char **argv) -> int {
  try {
    return main_impl(argc, argv);
  } catch (structopt::exception &e) {
    std::cout << e.what() << "\n";
    std::cout << e.help();
    return 2;
  } catch (std::exception &e) {
    fmt::println("ERROR: {}", e.what());
    return 1;
  }
}
