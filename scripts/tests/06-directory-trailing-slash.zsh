#!/usr/bin/env zsh

set -euo pipefail

cd "${0:A:h}/../.."

integer redisplay_calls=0

zle() {
  if [[ "$1" == "-N" ]]; then
    return 0
  fi
  if [[ "$1" == "redisplay" ]]; then
    (( redisplay_calls += 1 ))
    return 0
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
  local line id
  while IFS= read -r line; do
    [[ "$line" == $'dir\t'* ]] || continue
    id="${line##*$'\t'}"
    print -r -- "dir	${id}"
    return 0
  done
  return 1
}

source ./tab-start.plugin.zsh

tmp_dir="$(mktemp -d)"
trap 'command rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/dir with space"
cd "$tmp_dir"

TAB_START_INCLUDE_COMMANDS=0
TAB_START_INCLUDE_ALIASES=0
TAB_START_INCLUDE_DIRECTORIES=1
TAB_START_FILES_MAX_DEPTH=0
TAB_START_INCLUDE_HISTORY=0
BUFFER=""
LBUFFER=""
expected_payload="dir with space/"

TAB_START_ESCAPE_PATHS=1
_tab_start_insert
expected_escaped="${(q)expected_payload}"
[[ "$LBUFFER" == "$expected_escaped" ]]
(( redisplay_calls == 1 ))

TAB_START_ESCAPE_PATHS=0
BUFFER=""
LBUFFER=""
_tab_start_insert
[[ "$LBUFFER" == "$expected_payload" ]]
(( redisplay_calls == 2 ))
