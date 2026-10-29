#!/usr/bin/env zsh

set -euo pipefail

cd "${0:A:h}/../.."

autoload -Uz compinit
compinit -D -u
source ./tab-start.plugin.zsh

typeset -gr tab_start_test_preview_style='
  typeset -a tab_start_preview_words=()
  typeset tab_start_preview_alias="" tab_start_preview_command="" tab_start_preview_mode=""
  typeset tab_start_preview_target=""

  _tab_start_preview_run() {
    local output
    output="$("$@" </dev/null 2>&1)" && [[ -n "$output" ]] || return 1
    print -r -- "$output"
  }

  case "$group" in
    command)
      tab_start_preview_mode=help
      tab_start_preview_words=("$word")
      ;;
    alias)
      tab_start_preview_mode=help
      tab_start_preview_alias="${desc#"$word -> "}"
      if [[ "$tab_start_preview_alias" == "$desc" ]]; then
        tab_start_preview_words=("$word")
      else
        tab_start_preview_words=("${(@Q)${(z)tab_start_preview_alias}}")
      fi
      ;;
    mix|history)
      tab_start_preview_mode=command
      tab_start_preview_words=("${(@Q)${(z)word}}")
      tab_start_preview_command="${tab_start_preview_words[1]:-}"
      if (( ${#tab_start_preview_words[@]} > 1 )); then
        tab_start_preview_target="${tab_start_preview_words[-1]}"
      fi
      ;;
    dir)
      tab_start_preview_mode=command
      tab_start_preview_command=cd
      tab_start_preview_target="$word"
      ;;
    *)
      tab_start_preview_mode=path
      tab_start_preview_target="$word"
      ;;
  esac

  if [[ "$tab_start_preview_mode" == help ]]; then
    tab_start_preview_command="${tab_start_preview_words[1]:-}"
    if [[ -n "$tab_start_preview_command" ]] &&
        whence -w -- "$tab_start_preview_command" >/dev/null 2>&1 &&
        command man -w "$tab_start_preview_command" >/dev/null 2>&1; then
      _tab_start_preview_run env \
        MANWIDTH="${FZF_PREVIEW_COLUMNS:-80}" MANPAGER=cat PAGER=cat \
        man "$tab_start_preview_command"
    fi
  else
    case "$tab_start_preview_command" in
      mix)
        if [[ -n "${tab_start_preview_words[2]:-}" ]]; then
          command mix help "${tab_start_preview_words[2]}" 2>/dev/null
        fi
        ;;
      cd)
        if [[ -n "$tab_start_preview_target" ]]; then
          command tree -C -- "$tab_start_preview_target" 2>/dev/null | command head -200
        fi
        ;;
      ssh)
        if [[ -n "$tab_start_preview_target" ]]; then
          command dig "$tab_start_preview_target" 2>/dev/null
        fi
        ;;
      *)
        [[ -n "$tab_start_preview_target" ]] ||
          tab_start_preview_target="$tab_start_preview_command"
        if [[ -n "$tab_start_preview_target" ]]; then
          command bat --style=numbers --color=always --line-range :500 \
            -- "$tab_start_preview_target" 2>/dev/null ||
            command tree -C -- "$tab_start_preview_target" 2>/dev/null
        fi
        ;;
    esac
  fi
'
zstyle ':fzf-tab:complete:-command-:tab-start' fzf-preview "$tab_start_test_preview_style"

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
mkdir -p "$test_root/bin" "$test_root/dir with space" "$test_root/sub" "$test_root/$directory_with_newline" "$test_root/$directory_with_stx"
ln -s 'dir with space' "$test_root/linked dir"
touch "$test_root/script with space" "$test_root/sub/nested-script" "$test_root/$script_with_newline" "$test_root/$script_with_stx"
chmod +x "$test_root/script with space" "$test_root/sub/nested-script" "$test_root/$script_with_newline" "$test_root/$script_with_stx"
print -rl -- \
  '#!/usr/bin/env zsh' \
  'target="${argv[-1]}"' \
  '[[ -f "$target" ]] || exit 1' \
  'print -r -- "bat:$target"' > "$test_root/bin/bat"
print -rl -- \
  '#!/usr/bin/env zsh' \
  'target="${argv[-1]}"' \
  '[[ -d "$target" ]] || exit 1' \
  'print -r -- "tree:$target"' > "$test_root/bin/tree"
print -rl -- \
  '#!/usr/bin/env zsh' \
  'print -r -- "dig:${argv[-1]}"' > "$test_root/bin/dig"
print -rl -- \
  '#!/usr/bin/env zsh' \
  'if [[ "$1" == -w ]]; then' \
  '  [[ "${2:-}" == tab-start-test-man ]] || exit 1' \
  '  print -r -- /test/manpage' \
  '  exit 0' \
  'fi' \
  '[[ "$1" == tab-start-test-man ]] || exit 1' \
  'print -r -- "man:$1:${MANWIDTH:-}:${MANPAGER:-}:${PAGER:-}"' > "$test_root/bin/man"
print -rl -- \
  '#!/usr/bin/env zsh' \
  'exit 1' > "$test_root/bin/tab-start-test-man"
print -rl -- \
  '#!/usr/bin/env zsh' \
  'if [[ "$1" == help && -n "${2:-}" ]]; then' \
  '  print -r -- "help:$2"' \
  '  exit 0' \
  'fi' \
  '[[ "$1" == help ]] || exit 1' \
  'print -r -- "mix                   # Runs the default task"' \
  'print -r -- "mix deps.get          # Fetches dependencies"' \
  'print -r -- "unexpected output"' \
  'print -r -- "mix malformed output"' > "$test_root/bin/mix"
chmod +x \
  "$test_root/bin/bat" \
  "$test_root/bin/tree" \
  "$test_root/bin/dig" \
  "$test_root/bin/man" \
  "$test_root/bin/tab-start-test-man" \
  "$test_root/bin/mix"
cd "$test_root"
path=("$test_root/bin" $path)
rehash

typeset tab_start_resolved_preview
zstyle -s ':fzf-tab:complete:-command-:tab-start' fzf-preview tab_start_resolved_preview
[[ "$(FZF_PREVIEW_COLUMNS=120 group=command word=tab-start-test-man eval "$tab_start_resolved_preview")" == 'man:tab-start-test-man:120:cat:cat' ]]
[[ "$(FZF_PREVIEW_COLUMNS=120 group=alias word=tsm desc='tsm -> tab-start-test-man subcommand' eval "$tab_start_resolved_preview")" == 'man:tab-start-test-man:120:cat:cat' ]]
[[ -z "$(group=command word=mix eval "$tab_start_resolved_preview")" ]]
[[ -z "$(group=command word=tab-start-test-missing eval "$tab_start_resolved_preview")" ]]
[[ "$(group=mix word='mix deps.get' eval "$tab_start_resolved_preview")" == 'help:deps.get' ]]
[[ "$(group=history word='mix "deps.get" --only test' eval "$tab_start_resolved_preview")" == 'help:deps.get' ]]
[[ "$(group=dir word='dir with space' eval "$tab_start_resolved_preview")" == 'tree:dir with space' ]]
[[ "$(group=script word='script with space' eval "$tab_start_resolved_preview")" == 'bat:script with space' ]]
[[ "$(group=history word='cd "dir with space"' eval "$tab_start_resolved_preview")" == 'tree:dir with space' ]]
export TAB_START_PREVIEW_VALUE='not shown'
[[ -z "$(group=history word='export TAB_START_PREVIEW_VALUE' eval "$tab_start_resolved_preview")" ]]
[[ "$(group=history word='ssh example.com' eval "$tab_start_resolved_preview")" == 'dig:example.com' ]]
[[ "$(group=history word='bat "script with space"' eval "$tab_start_resolved_preview")" == 'bat:script with space' ]]
[[ -z "$(group=history word='echo no-preview' eval "$tab_start_resolved_preview")" ]]

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
[[ "${captured_displays[command:${command_index}]}" == "tab-start-test-command -> $test_root/bin/tab-start-test-command" ]]
[[ "${captured_has_raw[command]}" == "1" ]]
[[ "${captured_suffix[command]}" == "unset" ]]

captured_index_of alias tab-start-test-alias
alias_index="$REPLY"
[[ "${captured_displays[alias:${alias_index}]}" == "tab-start-test-alias -> echo alias target" ]]
[[ "${captured_has_raw[alias]}" == "1" ]]

captured_index_of dir 'dir with space'
dir_index="$REPLY"
[[ "${captured_displays[dir:${dir_index}]}" == "dir with space/" ]]
[[ "${captured_has_file[dir]}" == "0" ]]
[[ "${captured_has_raw[dir]}" == "0" ]]
[[ "${captured_suffix[dir]}" == "/" ]]
captured_index_of dir 'linked dir'
linked_dir_index="$REPLY"
[[ "${captured_displays[dir:${linked_dir_index}]}" == "linked dir/ -> dir with space" ]]
! captured_index_of dir "$directory_with_newline"
! captured_index_of dir "$directory_with_stx"

captured_index_of script 'script with space'
script_index="$REPLY"
[[ "${captured_displays[script:${script_index}]}" == "script with space" ]]
[[ "${captured_has_file[script]}" == "0" ]]
[[ "${captured_has_raw[script]}" == "0" ]]
[[ "${captured_suffix[script]}" == "" ]]
! captured_index_of script 'sub/nested-script'
! captured_index_of script "$script_with_newline"
! captured_index_of script "$script_with_stx"

[[ "${captured_candidate_counts[history]}" == "3" ]]
[[ "${captured_candidates[history:1]}" == "$history_with_tab" ]]
[[ "${captured_displays[history:1]}" == 'echo collision\targument' ]]
[[ "${captured_candidates[history:2]}" == "$history_with_literal_backslash" ]]
[[ "${captured_displays[history:2]}" == 'echo collision\\targument' ]]
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
