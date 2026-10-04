# This library script is meant to be sourced

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root_dir=$(realpath "$script_dir/../../../")

# Color variables
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
no_color='\033[0m'

# ==============================================================================
# Timing Function
# ==============================================================================

# Re-executes the entire script under '/usr/bin/time -v' and reports timing
# details only if the execution time exceeds a given threshold.
#
# This function works by checking an environment variable. If the variable is
# not set, it re-launches the script that called it under 'time' and then exits.
# The new, timed process will have the variable set and will continue execution.
#
# Usage:
#   Place this call at the start of your script's execution flow, before
#   the main logic.
#
#   time_script_with_threshold <threshold_in_seconds> [original_script_args...]
#
#   e.g. in a script, 2 seconds threshold:
#   time_script_with_threshold 2 "$@"
#   main "$@"
#
time_script_with_threshold() {
  local threshold_seconds="$1"
  shift

  # A unique environment variable name acts as a guard against infinite loops.
  if [ -z "$_SCRIPT_IS_BEING_TIMED" ]; then
    export _SCRIPT_IS_BEING_TIMED=1

    if ! command -v bc &>/dev/null; then
      echo "Error: 'bc' is not installed. Please install it to use this feature (e.g., 'sudo apt-get install bc')." >&2
      exit 1
    fi

    local time_output_file
    time_output_file=$(mktemp)
    trap 'rm -f "$time_output_file"' EXIT # Ensure cleanup

    # Re-execute the script, capturing 'time' output. The parent process waits here.
    /usr/bin/time -v -o "$time_output_file" "$0" "$@"
    local exit_code=$?

    # --- After the child script finishes, the parent process continues here ---
    local elapsed_time_str
    elapsed_time_str=$(grep 'Elapsed (wall clock) time' "$time_output_file" | awk '{print $NF}')

    if [ -n "$elapsed_time_str" ]; then
      local total_seconds
      total_seconds=$(echo "$elapsed_time_str" | awk -F: '{ secs=0; for(i=1; i<=NF; i++) { secs = secs * 60 + $i } print secs }')
      local is_over_threshold
      is_over_threshold=$(echo "$total_seconds > $threshold_seconds" | bc -l)

      if [ "$is_over_threshold" -eq 1 ]; then
        echo "---"
        echo "--- Script took ${total_seconds}s (threshold is ${threshold_seconds}s). Details: ---"
        cat "$time_output_file"
        echo "---"
      fi
    else
      echo "Warning: Could not parse time output from '$time_output_file'." >&2
    fi

    # The parent process, which only handled the timing, now exits.
    exit $exit_code
  fi

  # --- The child process (the timed script) continues execution here ---
}

# Function to check if the script is sourced
ensure_sourced() {
  if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
    echo "Error: This script must be sourced, not executed."
    echo "Please run: source ${BASH_SOURCE[0]}"
    exit 1
  fi
}

# Function to activate python virtual environment
activate_venv() {
  source $root_dir/activate.sh --quiet
}

ensure_sourced
