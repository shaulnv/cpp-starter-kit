#!/bin/bash

set -eE
set -o pipefail

function rename_files_and_folders() {
  # Set the words to be replaced
  local old=$1
  local new=$2
  local exclude_pattern=".git" # Add any other folders you want to exclude (e.g., .git, .svn)

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

function fix_project_name() {
  local project_name=$1
  local project_name_upper=${project_name^^} # this folder name uppercase

  rename_files_and_folders starterkit $project_name
  rename_files_and_folders STARTERKIT $project_name_upper
}

function fix_readme() {
  local project_name=$1

  # Put the project name in the README.md file
  printf "# %s\n\n" "$project_name" >README.md.header
  # Keep only content from "### Project Structure" onwards
  awk '/^## Project Structure/{p=1}p' README.md >README.md.body
  # Concatenate all the pieces
  cat README.md.header README.md.body >README.md
  rm -f README.md.*
}

function fix_misc() {
  local project_url="\"$(git remote get-url origin | sed 's/\.git$//')\""

  # Fix the project's URL in the CMakeLists.txt file
  #   '__HELP_ME__' is used to help sed deal with the quotes of the URL
  sed -i "s|HOMEPAGE_URL .*|HOMEPAGE_URL __HELP_ME__${project_url}|; s/__HELP_ME__//" CMakeLists.txt
}

function init_project() {
  local project_name=$(basename "$PWD") # this folder name

  # Personalize the project
  fix_project_name $project_name
  fix_readme $project_name
  fix_misc
  # Self delete the init.sh script
  rm -f ./init.sh 2>&1 >/dev/null
  git add --all
  git commit --amend -m "init project"
  git push -f
}

init_project
