#!/bin/sh -eE
set -e
clear
WORKSPACE_PATH=$1
PR_NUMBER=$2
python3 -m pip install click --user
python3 ./scripts/git_scripts.py -p "$WORKSPACE_PATH" -cpr $PR_NUMBER
