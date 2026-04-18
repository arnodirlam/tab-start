#!/usr/bin/env zsh

set -euo pipefail

cd "${0:A:h}/.."

zsh -n tab-start.plugin.zsh

env ZDOTDIR=/tmp zsh -f -c '
  set -euo pipefail

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

  source ./tab-start.plugin.zsh

  [[ "$TAB_START_FALLBACK_WIDGET" == "menu-complete" ]]

  BUFFER="echo hello"
  LBUFFER=""
  _tab_start_insert
  (( fallback_calls == 1 ))
'

env ZDOTDIR=/tmp zsh -f -c '
  set -euo pipefail

  integer fallback_calls=0

  zle() {
    if [[ "$1" == "-N" || "$1" == "redisplay" ]]; then
      return 0
    fi
    if [[ "$1" == "menu-complete" ]]; then
      (( fallback_calls += 1 ))
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
    print -u2 -- "unexpected fzf invocation"
    return 1
  }

  source ./tab-start.plugin.zsh

  TAB_START_INCLUDE_COMMANDS=0
  TAB_START_INCLUDE_ALIASES=0
  TAB_START_INCLUDE_DIRECTORIES=0
  TAB_START_INCLUDE_FILES=0
  BUFFER=""
  LBUFFER=""
  _tab_start_insert
  (( fallback_calls == 1 ))
'
