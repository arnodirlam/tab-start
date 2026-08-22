#!/usr/bin/env zsh

set -euo pipefail

cd "${0:A:h}/../.."

autoload -Uz compinit
compinit -D -u
source ./tab-start.plugin.zsh

typeset -ga captured_groups
typeset -gA captured_group_names captured_candidate_counts captured_candidates
typeset -gA captured_displays captured_has_file captured_has_raw captured_suffix

reset_captures() {
  captured_groups=()
  captured_group_names=()
  captured_candidate_counts=()
  captured_candidates=()
  captured_displays=()
  captured_has_file=()
  captured_has_raw=()
  captured_suffix=()
}

compadd() {
  local group_name=""
  local explanation=""
  local display_name=""
  local suffix="unset"
  local -i has_file=0
  local -i has_raw=0
  local -i index=0
  local -a candidates displays

  while (( $# )); do
    case "$1" in
      -V|-J)
        group_name="$2"
        shift 2
        ;;
      -X)
        explanation="$2"
        shift 2
        ;;
      -d)
        display_name="$2"
        shift 2
        ;;
      -S)
        suffix="$2"
        shift 2
        ;;
      -f)
        has_file=1
        shift
        ;;
      -Q)
        has_raw=1
        shift
        ;;
      --)
        shift
        candidates=("$@")
        break
        ;;
      *)
        shift
        ;;
    esac
  done

  [[ -n "$explanation" && -n "$display_name" ]]
  displays=("${(@P)display_name}")
  (( ${#candidates[@]} == ${#displays[@]} ))

  captured_groups+=("$explanation")
  captured_group_names[$explanation]="$group_name"
  captured_candidate_counts[$explanation]="${#candidates[@]}"
  captured_has_file[$explanation]="$has_file"
  captured_has_raw[$explanation]="$has_raw"
  captured_suffix[$explanation]="$suffix"

  for (( index = 1; index <= ${#candidates[@]}; index += 1 )); do
    captured_candidates[${explanation}:${index}]="${candidates[$index]}"
    captured_displays[${explanation}:${index}]="${displays[$index]}"
  done
  return 0
}

captured_index_of() {
  local group="$1"
  local expected="$2"
  local -i index

  for (( index = 1; index <= ${captured_candidate_counts[$group]}; index += 1 )); do
    if [[ "${captured_candidates[${group}:${index}]}" == "$expected" ]]; then
      REPLY="$index"
      return 0
    fi
  done
  return 1
}

typeset -gr history_with_tab=$'echo collision\targument'
typeset -gr history_with_literal_backslash='echo collision\targument'
typeset -gr history_with_newline=$'echo first line\nsecond line'
typeset -gr history_with_stx=$'echo control\x02byte'
typeset -gr history_with_nul=$'echo control\x00byte'
typeset -gr directory_with_newline=$'dir\nwith newline'
typeset -gr script_with_newline=$'script\nwith newline'
typeset -gr directory_with_stx=$'dir\x02with stx'
typeset -gr script_with_stx=$'script\x02with stx'

run_completion_with_test_history() {
  # Hide the read-only special parameter with deterministic, dynamically scoped data.
  local -hA history=(
    11 '-leading "quoted value"'
    12 "$history_with_tab"
    13 "$history_with_literal_backslash"
    14 "$history_with_newline"
    15 "$history_with_stx"
    16 "$history_with_nul"
    17 "$history_with_tab"
  )

  reset_captures
  _tab_start_complete
}

test_root="$(mktemp -d)"
cleanup() {
  local test_status=$?
  trap - EXIT
  command rm -rf "$test_root"
  exit "$test_status"
}
trap cleanup EXIT
mkdir -p "$test_root/dir with space" "$test_root/sub" "$test_root/$directory_with_newline" "$test_root/$directory_with_stx"
ln -s 'dir with space' "$test_root/linked dir"
touch "$test_root/script with space" "$test_root/sub/nested-script" "$test_root/$script_with_newline" "$test_root/$script_with_stx"
chmod +x "$test_root/script with space" "$test_root/sub/nested-script" "$test_root/$script_with_newline" "$test_root/$script_with_stx"
cd "$test_root"

unalias -m '*' 2>/dev/null || true
alias tab-start-test-alias='echo alias target'
commands[tab-start-test-command]="$test_root/bin/tab-start-test-command"

TAB_START_INCLUDE_COMMANDS=1
TAB_START_INCLUDE_ALIASES=1
TAB_START_INCLUDE_DIRECTORIES=1
TAB_START_FILES_MAX_DEPTH=1
TAB_START_INCLUDE_HISTORY=1
TAB_START_ESCAPE_PATHS=1
CURRENT=1
BUFFER=""
curcontext=':complete:-command-:'

run_completion_with_test_history

[[ "${(j: :)captured_groups}" == "command alias dir script history" ]]
[[ "${captured_group_names[command]}" == "tab-start-command" ]]
[[ "${captured_group_names[alias]}" == "tab-start-alias" ]]
[[ "${captured_group_names[dir]}" == "tab-start-dir" ]]
[[ "${captured_group_names[script]}" == "tab-start-script" ]]
[[ "${captured_group_names[history]}" == "tab-start-history" ]]

captured_index_of command tab-start-test-command
command_index="$REPLY"
[[ "${captured_displays[command:${command_index}]}" == "command  tab-start-test-command -> $test_root/bin/tab-start-test-command" ]]
[[ "${captured_has_raw[command]}" == "1" ]]
[[ "${captured_suffix[command]}" == "unset" ]]

captured_index_of alias tab-start-test-alias
alias_index="$REPLY"
[[ "${captured_displays[alias:${alias_index}]}" == "alias  tab-start-test-alias -> echo alias target" ]]
[[ "${captured_has_raw[alias]}" == "1" ]]

captured_index_of dir 'dir with space'
dir_index="$REPLY"
[[ "${captured_displays[dir:${dir_index}]}" == "dir  dir with space/" ]]
[[ "${captured_has_file[dir]}" == "0" ]]
[[ "${captured_has_raw[dir]}" == "0" ]]
[[ "${captured_suffix[dir]}" == "/" ]]
captured_index_of dir 'linked dir'
linked_dir_index="$REPLY"
[[ "${captured_displays[dir:${linked_dir_index}]}" == "dir  linked dir/ -> dir with space" ]]
! captured_index_of dir "$directory_with_newline"
! captured_index_of dir "$directory_with_stx"

captured_index_of script 'script with space'
script_index="$REPLY"
[[ "${captured_displays[script:${script_index}]}" == "script  script with space" ]]
[[ "${captured_has_file[script]}" == "0" ]]
[[ "${captured_has_raw[script]}" == "0" ]]
[[ "${captured_suffix[script]}" == "" ]]
! captured_index_of script 'sub/nested-script'
! captured_index_of script "$script_with_newline"
! captured_index_of script "$script_with_stx"

[[ "${captured_candidate_counts[history]}" == "3" ]]
[[ "${captured_candidates[history:1]}" == "$history_with_tab" ]]
[[ "${captured_displays[history:1]}" == 'history  echo collision\targument' ]]
[[ "${captured_candidates[history:2]}" == "$history_with_literal_backslash" ]]
[[ "${captured_displays[history:2]}" == 'history  echo collision\\targument' ]]
[[ "${captured_displays[history:1]}" != "${captured_displays[history:2]}" ]]
[[ "${captured_candidates[history:3]}" == '-leading "quoted value"' ]]
! captured_index_of history "$history_with_newline"
! captured_index_of history "$history_with_stx"
! captured_index_of history "$history_with_nul"
[[ "${captured_has_raw[history]}" == "1" ]]
[[ "${captured_suffix[history]}" == "" ]]

TAB_START_INCLUDE_COMMANDS=0
TAB_START_INCLUDE_ALIASES=0
TAB_START_INCLUDE_HISTORY=0
TAB_START_ESCAPE_PATHS=0
reset_captures
_tab_start_complete

[[ "${(j: :)captured_groups}" == "dir script" ]]
[[ "${captured_has_raw[dir]}" == "1" ]]
[[ "${captured_has_raw[script]}" == "1" ]]
