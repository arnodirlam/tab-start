#!/usr/bin/env zsh

set -euo pipefail

cd "${0:A:h}/../.."

integer redisplay_calls=0
typeset -g FZF_REPLY=$'history\t2'

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

fc() {
  if [[ "$#" -eq 2 && "$1" == "-rl" && "$2" == "1" ]]; then
    print -r -- "  42*  dup command"
    print -r -- "  41  target command --with arg"
    print -r -- "  40  dup command"
    return 0
  fi
  return 1
}

commands[fzf]="/tmp/fzf"
fzf() {
  print -r -- "$FZF_REPLY"
  return 0
}

source ./tab-start.plugin.zsh

TAB_START_INCLUDE_COMMANDS=0
TAB_START_INCLUDE_ALIASES=0
TAB_START_INCLUDE_DIRECTORIES=0
TAB_START_INCLUDE_FILES=0
TAB_START_INCLUDE_HISTORY=1
BUFFER=""
LBUFFER=""

_tab_start_insert
[[ "$LBUFFER" == "target command --with arg" ]]
(( redisplay_calls == 1 ))

FZF_REPLY=$'command\t1'
LBUFFER=""
_tab_start_insert
[[ -z "$LBUFFER" ]]
(( redisplay_calls == 2 ))
