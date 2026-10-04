---
name: pre-commit
description: Run pre-commit checks, install hooks, and fix or suppress lint issues. Use when asked to lint files, run checkers, fix lint errors, or configure pre-commit hooks.
---

# Pre-commit Checks

```bash
pre-commit run                          # staged files
pre-commit run --all-files              # everything
pre-commit run --files path/to/file     # specific files
pre-commit run typos --files x.md       # one hook
pre-commit install                      # install the git hook (once per clone)
```

Hook definitions live in `.pre-commit-config.yaml`; run `source ./activate.sh` first so
`pre-commit` is on the path.

## Fixing issues

Prefer fixing over suppressing.

- **Formatters** (`clang-format`, `black`, `isort`, `trailing-whitespace`, and `shfmt`/`cmake-format` where configured)
  rewrite files: re-stage and re-run to verify.
- **shellcheck** (where configured): the warning is almost always a real bug or portability issue; fix the script.
- **typos**: fix it; for a genuine domain term add it to the typos config's `extend-words`.
- **Failure masks** (`|| true`, `|| :`): ask whether the failure is really
  harmless. If not, handle it (`cmd || rc=$?` plus a loud warning). If it is, keep the mask and
  justify it on the same line or the line above: `cmd || true  # MASK-OK: <why>`.

Suppress only when the warning is a false positive or inherent to the framework, and always put
the reason on the line above:

```bash
# shellcheck disable=SC2034  # used by the sourcing script
EXPORTED_VAR="value"
```

## Skipping and troubleshooting

- One run: `SKIP=typos pre-commit run --all-files`.
- Stale hooks after a config change: `pre-commit clean && pre-commit install`.
- Never use `git commit --no-verify`.
