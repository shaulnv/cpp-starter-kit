# This library script is meant to be sourced

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source $script_dir/_utils.sh

# Function to add or replace a key=value pair in an .env file
update_env_vars_file() {
  local file=$1
  local key=$2
  local value=$3

  # Check if key already exists in the file
  if grep -q "^$key=" "$file" >/dev/null 2>&1; then
    # If key exists, replace the value using | as delimiter to avoid issues with paths
    sed -i "s|^$key=.*|$key=$value|" "$file"
  else
    # If key does not exist, add it to the end of the file
    echo "$key=$value" >>"$file"
  fi
}

# Function to load environment variables from .env file
load_env_vars() {
  source $root_dir/.env >/dev/null 2>&1 || true
}

load_env_vars
