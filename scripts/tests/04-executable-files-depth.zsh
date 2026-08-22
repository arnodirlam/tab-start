#!/usr/bin/env zsh

set -euo pipefail

cd "${0:A:h}/../.."

autoload -Uz compinit
compinit -D -u
source ./tab-start.plugin.zsh

test_root="$(mktemp -d)"
trap 'command rm -rf "$test_root"' EXIT
mkdir -p "$test_root/sub/deeper"

touch "$test_root/root_exec" "$test_root/root_non_exec"
touch "$test_root/sub/exec1" "$test_root/sub/non_exec" "$test_root/sub/deeper/exec2"
chmod +x "$test_root/root_exec" "$test_root/sub/exec1" "$test_root/sub/deeper/exec2"

cd "$test_root"

contains_entry() {
  local expected="$1"
  local entry

  for entry in "${TAB_START_EXECUTABLE_FILES[@]}"; do
    if [[ "$entry" == "$expected" ]]; then
      return 0
    fi
  done
  return 1
}

unset TAB_START_FILES_MAX_DEPTH
__tab_start_resolve_files_max_depth
[[ "$REPLY" == "2" ]]
__tab_start_collect_executable_files "$REPLY"
contains_entry root_exec
contains_entry sub/exec1
! contains_entry root_non_exec
! contains_entry sub/deeper/exec2

TAB_START_FILES_MAX_DEPTH=3
__tab_start_resolve_files_max_depth
[[ "$REPLY" == "3" ]]
__tab_start_collect_executable_files "$REPLY"
contains_entry sub/deeper/exec2

TAB_START_FILES_MAX_DEPTH=invalid
__tab_start_resolve_files_max_depth
[[ "$REPLY" == "2" ]]

TAB_START_FILES_MAX_DEPTH=0
__tab_start_resolve_files_max_depth
[[ "$REPLY" == "0" ]]
__tab_start_collect_executable_files "$REPLY"
(( ${#TAB_START_EXECUTABLE_FILES[@]} == 0 ))
