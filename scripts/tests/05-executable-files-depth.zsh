#!/usr/bin/env zsh

set -euo pipefail

cd "${0:A:h}/../.."

integer fallback_calls=0

zle() {
  if [[ "$1" == "-N" || "$1" == "redisplay" ]]; then
    return 0
  fi
  if [[ "$1" == "menu-complete" ]]; then
    (( fallback_calls += 1 ))
    return 0
  fi
  if [[ "$1" == "expand-or-complete" ]]; then
    print -u2 -- "unexpected fallback widget: $1"
    return 1
  fi
  return 0
}

bindkey() {
  if [[ "$#" -eq 1 && "$1" == "^I" ]]; then
    print -r -- "\"^I\" menu-complete"
  fi
  return 0
}

commands[fzf]="/tmp/fzf"
fzf() {
  print -u2 -- "unexpected fzf invocation"
  return 1
}

source ./tab-start.plugin.zsh

tmp_dir="$(mktemp -d)"
trap 'command rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/sub/deeper"

touch "$tmp_dir/root_exec" "$tmp_dir/root_non_exec" "$tmp_dir/sub/exec1" "$tmp_dir/sub/non_exec" "$tmp_dir/sub/deeper/exec2"
chmod +x "$tmp_dir/root_exec" "$tmp_dir/sub/exec1" "$tmp_dir/sub/deeper/exec2"

cd "$tmp_dir"

TAB_START_INCLUDE_COMMANDS=0
TAB_START_INCLUDE_ALIASES=0
TAB_START_INCLUDE_DIRECTORIES=0
TAB_START_INCLUDE_HISTORY=0
TAB_START_ESCAPE_PATHS=0
unset TAB_START_FILES_MAX_DEPTH
BUFFER=""
LBUFFER=""

contains_entry() {
  local needle="$1"
  local entry
  for entry in "${TAB_START_EXECUTABLE_FILES[@]}"; do
    if [[ "$entry" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

__tab_start_resolve_files_max_depth
[[ "$REPLY" == "2" ]]
__tab_start_collect_executable_files "$REPLY"
contains_entry "root_exec"
contains_entry "sub/exec1"
! contains_entry "root_non_exec"
! contains_entry "sub/deeper/exec2"

TAB_START_FILES_MAX_DEPTH=3
__tab_start_resolve_files_max_depth
[[ "$REPLY" == "3" ]]
__tab_start_collect_executable_files "$REPLY"
contains_entry "sub/deeper/exec2"

TAB_START_FILES_MAX_DEPTH=0
BUFFER=""
LBUFFER=""
_tab_start_insert
(( fallback_calls == 1 ))
