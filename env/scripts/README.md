# Scripts

Build internals and developer helpers. Most are sourced by the top-level
`build.sh` / `test.sh` / `activate.sh` rather than run directly.

- `private/_build_env_vars.sh` - command-line flag parsing for `build.sh`; persists the chosen build state in `.env`
  and maintains the `build/<BuildType>` and `build/current` symlinks
- `private/_env_vars_file.sh` - read/update helpers for `.env`
- `private/_utils.sh` - shared colors, `time_script_with_threshold`, sourcing guards
- `install_uv.sh` - installs `uv` (apt or dnf based systems) and puts it on `PATH`
- `run-precommit.sh` - run pre-commit on staged files, or `--all`
- `verify_hardening.sh` - checks an ELF binary for PIE / RELRO / BIND_NOW / non-exec stack / stack protector
- `build_completion.sh`, `shell_completion.sh` - bash completion for `build.sh`; source `shell_completion.sh` from `~/.bashrc`
