// 3rd party
#include <doctest/doctest.h>
// project
#include <starterkit/starterkit.h>

namespace {
  int factorial(int number) {  // NOLINT(misc-no-recursion)
    return number <= 1 ? number : factorial(number - 1) * number;
  }
}  // namespace

TEST_CASE("testing the factorial function") {
  CHECK(factorial(1) == 1);
  CHECK(factorial(2) == 2);
  CHECK(factorial(3) == 6);
  CHECK(factorial(10) == 3628800);
}

TEST_CASE("The answer to life, the universe, and everything") {
  CHECK(starterkit_lib_answer() == 42);
}
