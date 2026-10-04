# Starter Kit

C++20 project template: Conan 2 + CMake, doctest, native and WebAssembly targets.
`starterkit` is a placeholder that `./init.sh` replaces with the real project name.

## Repo orientation

- `src/` + `include/starterkit/` — library (pure logic, platform-agnostic as far as possible)
- `cli/` — command-line executable on top of the library
- `tests/` — doctest suite; mirrors the `src/` layout
- `env/cmake/` — CMake helpers (CPM, tools, colors). `env/profiles/` — Conan profiles
  (`native`, `clang`, `clang-tidy`, `wasm`). `env/scripts/` — build internals
  (`private/_build_env_vars.sh` is the source of truth for build flags)
- `conanfile.py` — third-party dependencies and the top-level build recipe

## Build system gotchas

- **Entrypoints**: `./build.sh` builds, `./test.sh` runs `ctest` against the active build folder
  (args pass through, e.g. `./test.sh -R <regex>`), `./run.sh` runs the CLI. Prefer these over
  calling `conan` / `cmake` / `ctest` directly. `./build.sh --help` lists flags.
- Build flags are cached between runs; pass them again only to change them.
- `activate.sh` **must be sourced**, not executed.
- Build output lands under `build/`, one folder per profile and build type.

## C++ conventions

- **East const**: `auto const result`, `T const&`.
- **Left-`auto const`**: `auto const x = ...;` and let the initializer carry the type. Spell the
  type on the right only when the call doesn't already yield it. Never write it on both sides.
- **Brace-init** for construction (`T x{a, b}`) — catches narrowing and avoids the most vexing parse.
  Use parens only to avoid an `initializer_list` constructor (`std::vector<int> v(10, 0)`).
- **Keyword operators**: `and` / `or` / `not` rather than `&&` / `||` / `!`.
- **Chrono literals**: `using namespace std::literals::chrono_literals;` then `250ms`.
- **Prefer `std::unordered_*`** unless sorted iteration is genuinely needed; sort explicitly where
  output order matters.
- **Declarative over imperative**: build a value from its initializer list (so it can be `const`)
  instead of accumulating into it; use designated initializers (`Foo{.a = x, .b = y}`).
- **`explicit` single-argument constructors**; no implicit conversion operators; structured
  bindings when iterating key/value containers.
- **`tl::expected` for expected errors, exceptions for exceptional ones**: if the immediate caller
  is expected to inspect and act on the failure, return `tl::expected<T, E>` (`[[nodiscard]]`);
  if it just propagates to abort or retry higher up, throw. Never conflate "could not determine"
  with "determined empty". Don't wrap internal calls in defensive try/catch.
- **Magic numbers**: tag a constant that should later move to config with
  `// NOLINT: TODO move to config`.
- **File name and primary class name stay in sync** (`grpc_server.h` <-> `GrpcServer`).
- **Macros go at the top of the file**, after the includes and outside any namespace.

### Coroutines (if you add asio)

- Never immediately invoke a capturing lambda coroutine (`co_spawn(ex, [&]() -> awaitable<T> {...}(), tok)`):
  the lambda temporary dies at the end of the full expression while the frame still uses its
  captures. Pass the lambda un-invoked, or use a named coroutine taking its inputs by value.
- Coroutine parameters by value (or `std::reference_wrapper`), never by bare reference, unless
  every call site `co_await`s inline.
- Let cancellation propagate as `operation_aborted`; don't poll for it.

## Documentation and comments

- **Public API in Doxygen style**: `/** @brief ... */` for multi-line, `//!` for one-liners;
  use `@param`, `@return`, `@note`.
- **A comment justifies, it never describes.** Default to none; add one for a non-obvious *why*,
  a subtle invariant, or a cryptic token. Don't restate the code, don't narrate history ("previously
  we did X"), don't define a thing by what it isn't, and say each thing once, at its definition.
  History and rationale belong in the commit body.
- **`DEV:` scratch comments**: while iterating you may write verbose rationale comments, but mark
  each with a `DEV:` prefix and strip all of them before committing.

## Testing

- doctest; tests mirror the `src/` layout.
- Write the regression test first and confirm it fails without the fix.
- Inject controlled dependencies (timers, IO) through existing seams rather than using real
  wall-clock waits.

## Shell conventions

- New scripts: `set -Eeuo pipefail` and an `ERR` trap that reports file:line.
- **Never silence a failure you have not reasoned about.** `|| true` / `|| :` turn a broken step
  into a passing one. Use one only when the command is genuinely advisory *and* something else
  checks the same ground, and say why on the same line or the line above:

  ```sh
  rm -f "$tmp" || true  # MASK-OK: best-effort cleanup; the build result is checked below
  ```

  Prefer `cmd || rc=$?` followed by an explicit warning.

## Pre-commit

Hooks are configured in `.pre-commit-config.yaml` (clang-format, black, isort, typos, ...). See `.claude/skills/pre-commit/SKILL.md`.

- Never bypass the hooks with `--no-verify`. When a formatter rewrites files mid-commit, re-`git add`
  the result and commit again.
- To keep a construct on one line against `clang-format`, end the line with a token matched by
  `OneLineFormatOffRegex` in `.clang-format` (`// LOG_NOFORMAT`, `// OL_NOFORMAT`) rather than
  using `// clang-format off/on` blocks.

## Git workflow

- Feature branches go to your `origin` fork; PRs target `upstream`.
- **Rebase onto the latest `upstream/master`; never merge master into a feature branch.**
  `git fetch upstream && git rebase upstream/master`, then `git push --force-with-lease`.
- PR titles follow Conventional Commits (`<type>(<scope>): <description>`, imperative, lowercase,
  no trailing period). PR bodies use `## Problem`, `## Solution`, `## Testing`.

## Commit messages

No AI-tool signature in commit messages. Subjects carry a marker for the nature of the change:

- `(+)` Add — new functionality, file, API
- `(-)` Fix — a reachable bug goes from wrong to right (hardening an unreachable path is `(+)`)
- `(*)` Alteration — deliberate behavior change that is neither a fix nor a refactor
- `(~)` Refactor — structural change with no behavior change, however large the diff
- `(=)` Aesthetic — comments, typos, formatting, docs

Mixed changes are split: land the `(~)` refactor first (each commit must build on its own), then
the logical change on top, so its diff is small. Fold a follow-up that is really "how an earlier
commit should have been written" into that commit (local, unmerged history only). Agent
instructions (`AGENTS.md`, `CLAUDE.md`, skills) are code and take the marker of their effect.

The commit body carries the rationale: what was wrong, root cause, alternatives rejected, how it
was verified.
