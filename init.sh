#!/bin/bash

set -eE
set -o pipefail

function rename_files_and_folders() {
  # Set the words to be replaced
  local old=$1
  local new=$2
  exclude_pattern=".git" # Add any other folders you want to exclude (e.g., .git, .svn)

  # Step 1: Replace text inside all files (case-sensitive, excluding specified folders)
  echo "Replacing text inside files..."
  find . -type f ! -path "*/$exclude_pattern/*" -exec sed -i "s/${old}/${new}/g" {} +

  # Step 2: Rename folders (case-sensitive, excluding specified folders)
  echo "Renaming folders..."
  find . -depth -type d ! -path "*/$exclude_pattern/*" -name "*${old}*" | while IFS= read -r dir; do
    new_dir=$(echo "$dir" | sed "s/${old}/${new}/g")
    mv "$dir" "$new_dir"
  done

  # Step 3: Rename files (case-sensitive, excluding specified folders)
  echo "Renaming files..."
  find . -type f ! -path "*/$exclude_pattern/*" -name "*${old}*" | while IFS= read -r file; do
    new_file=$(echo "$file" | sed "s/${old}/${new}/g")
    mv "$file" "$new_file"
  done

  echo "Done!"
}

project_name=$(basename "$PWD")      # this folder name
project_name_upper=${project_name^^} # this folder name uppercase
rename_files_and_folders starterkit $project_name
rename_files_and_folders STARTERKIT $project_name_upper
# Self delete the init.sh script
rm -f ./init.sh 2>&1 >/dev/null
git add --all
git commit --amend -m "init project"
git push -f
