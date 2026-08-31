#!/usr/bin/env zsh

set -euo pipefail

cd "${0:A:h}/../.."

autoload -Uz compinit
compinit -D -u

typeset -gi previous_calls=0
typeset -g previous_context=""

_tab_start_test_previous() {
  (( previous_calls += 1 ))
  previous_context="${curcontext:-}"
  return 0
}

compdef _tab_start_test_previous -command-
zstyle ':fzf-tab:*' fzf-flags --color=fg:1
source ./tab-start.plugin.zsh

[[ "${_comps[-command-]}" == "_tab_start_complete" ]]
[[ "$TAB_START_ORIGINAL_COMMAND_COMPLETER" == "_tab_start_test_previous" ]]

typeset insert_tab_value sort_value
typeset -a fzf_flags
zstyle -s ':completion:::::' insert-tab insert_tab_value
zstyle -s ':completion:complete:-command-:tab-start' sort sort_value
__tab_start_apply_fzf_defaults
zstyle -a ':fzf-tab:complete:-command-:tab-start' fzf-flags fzf_flags
[[ "$insert_tab_value" == "false" ]]
[[ "$sort_value" == "false" ]]
[[ "${(j: :)fzf_flags}" == "--color=fg:1 --no-hscroll" ]]

zstyle ':fzf-tab:complete:-command-:tab-start' fzf-flags --color=fg:2 --hscroll
__tab_start_apply_fzf_defaults
zstyle -a ':fzf-tab:complete:-command-:tab-start' fzf-flags fzf_flags
[[ "${(j: :)fzf_flags}" == "--color=fg:2 --hscroll" ]]

zstyle ':fzf-tab:complete:-command-:tab-start' fzf-flags --color=fg:3 --no-hscroll
__tab_start_apply_fzf_defaults
zstyle -a ':fzf-tab:complete:-command-:tab-start' fzf-flags fzf_flags
[[ "${(j: :)fzf_flags}" == "--color=fg:3 --no-hscroll" ]]

CURRENT=1
BUFFER="echo value"
_tab_start_complete
(( previous_calls == 1 ))

CURRENT=2
BUFFER=""
_tab_start_complete
(( previous_calls == 2 ))

TAB_START_INCLUDE_COMMANDS=0
TAB_START_INCLUDE_ALIASES=0
TAB_START_INCLUDE_DIRECTORIES=0
TAB_START_FILES_MAX_DEPTH=0
TAB_START_INCLUDE_HISTORY=0
CURRENT=1
BUFFER=""
curcontext=':complete:-command-:'
_tab_start_complete
(( previous_calls == 3 ))
[[ "$previous_context" == ':complete:-command-:' ]]

# Reloading must not replace the saved command-position completer with itself.
source ./tab-start.plugin.zsh
[[ "$TAB_START_ORIGINAL_COMMAND_COMPLETER" == "_tab_start_test_previous" ]]
[[ "${_comps[-command-]}" == "_tab_start_complete" ]]
