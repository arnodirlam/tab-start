# TAB on empty prompt: fuzzy-pick command/alias/path/history entry and insert.
# based on fzf-tab for rendering, navigation, selection, and insertion.
#
# Optional config vars (set before `source $ZSH/oh-my-zsh.sh`):
#   TAB_START_INCLUDE_COMMANDS=1       # 1 or 0
#   TAB_START_INCLUDE_ALIASES=1        # 1 or 0
#   TAB_START_INCLUDE_DIRECTORIES=1    # 1 or 0
#   TAB_START_FILES_MAX_DEPTH=2        # executable-file recursion depth (0 disables)
#   TAB_START_INCLUDE_HISTORY=1        # 1 or 0
#   TAB_START_ESCAPE_PATHS=1           # 1 or 0 (script/dir insertion)
: "${TAB_START_INCLUDE_COMMANDS:=1}"
: "${TAB_START_INCLUDE_ALIASES:=1}"
: "${TAB_START_INCLUDE_DIRECTORIES:=1}"
: "${TAB_START_FILES_MAX_DEPTH:=2}"
: "${TAB_START_INCLUDE_HISTORY:=1}"
: "${TAB_START_ESCAPE_PATHS:=1}"

zmodload zsh/parameter 2>/dev/null || true
zmodload zsh/stat 2>/dev/null || true

typeset -ga TAB_START_EXECUTABLE_FILES=()
typeset -ga TAB_START_HISTORY_ENTRIES=()
typeset -g TAB_START_ORIGINAL_COMMAND_COMPLETER="${TAB_START_ORIGINAL_COMMAND_COMPLETER:-}"

__tab_start_is_enabled() {
  [[ "${1:-1}" != "0" ]]
}

__tab_start_apply_fzf_defaults() {
  local context=':fzf-tab:complete:-command-:tab-start'
  local -a fzf_flags

  # Resolve flags at completion time so styles configured after plugin loading are preserved
  zstyle -a "$context" fzf-flags fzf_flags || fzf_flags=()

  # Truncate entries at the line end by default
  if (( ! ${fzf_flags[(Ie)--hscroll]} && ! ${fzf_flags[(Ie)--no-hscroll]} )); then
    zstyle "$context" fzf-flags "${fzf_flags[@]}" --no-hscroll
  fi
}

__tab_start_sanitize_display() {
  REPLY="$1"
  REPLY="${REPLY//\\/\\\\}"
  REPLY="${REPLY//\^/\\^}"
  REPLY="${(V)REPLY}"
}

__tab_start_name_entry() {
  local name="$1"
  local detail="$2"

  if [[ -z "$detail" ]]; then
    REPLY="$name"
  else
    REPLY="${name} -> ${detail}"
  fi
}

# Prefix descriptions so fzf-tab can distinguish identical text across groups.
__tab_start_group_display() {
  local group="$1"
  local entry="$2"

  __tab_start_sanitize_display "$entry"
  REPLY="${group}  ${REPLY}"
}

__tab_start_path_display() {
  local path="$1"
  local suffix="$2"
  local -a path_stat

  REPLY="${path}${suffix}"
  if [[ -L "$path" ]] && (( $+builtins[zstat] )) &&
      zstat -A path_stat -L -- "$path" 2>/dev/null && [[ -n "${path_stat[14]:-}" ]]; then
    REPLY+=" -> ${path_stat[14]}"
  fi
}

__tab_start_candidate_is_supported() {
  # fzf-tab line-frames captures and reserves NUL/STX inside each record.
  [[ "$1" != *$'\n'* && "$1" != *$'\0'* && "$1" != *$'\2'* ]]
}

__tab_start_collect_history_entries() {
  local history_event history_command
  local -a history_entries
  local -A seen_history_entries

  TAB_START_HISTORY_ENTRIES=()
  if (( ! ${+history} )); then
    return 1
  fi

  for history_event in ${(Onk)history}; do
    history_command="${history[$history_event]}"
    if [[ -z "$history_command" ]] || ! __tab_start_candidate_is_supported "$history_command"; then
      continue
    fi
    if [[ -n ${seen_history_entries[$history_command]+x} ]]; then
      continue
    fi
    seen_history_entries[$history_command]=1
    history_entries+=("$history_command")
  done

  TAB_START_HISTORY_ENTRIES=("${history_entries[@]}")
}

__tab_start_resolve_files_max_depth() {
  local configured_depth="${TAB_START_FILES_MAX_DEPTH:-2}"

  if [[ "$configured_depth" != <-> ]]; then
    REPLY="2"
    return
  fi
  REPLY="$configured_depth"
}

__tab_start_collect_executable_files() {
  local max_depth="$1"
  local file_name file_pattern
  local -a executable_files
  local -i depth_level
  local -i depth_segments

  executable_files=()
  if (( max_depth <= 0 )); then
    TAB_START_EXECUTABLE_FILES=()
    return
  fi

  for (( depth_level = 1; depth_level <= max_depth; depth_level += 1 )); do
    file_pattern=""
    for (( depth_segments = 1; depth_segments < depth_level; depth_segments += 1 )); do
      file_pattern+="*/"
    done
    file_pattern+="*(N-.)"
    for file_name in ${~file_pattern}; do
      if [[ -x "$file_name" ]]; then
        executable_files+=("$file_name")
      fi
    done
  done

  TAB_START_EXECUTABLE_FILES=("${(@ou)executable_files}")
}

__tab_start_complete_previous_command() {
  local completer="${TAB_START_ORIGINAL_COMMAND_COMPLETER:-_autocd}"

  if [[ -z "$completer" || "$completer" == "_tab_start_complete" ]]; then
    completer="_autocd"
  fi

  # Match Zsh's `_normal`, whose command-position mapping may contain arguments.
  eval "$completer"
}

_tab_start_complete() {
  setopt localoptions extendedglob

  if (( CURRENT != 1 )) || [[ -n ${BUFFER//[[:space:]]/} ]]; then
    __tab_start_complete_previous_command
    return $?
  fi

  __tab_start_apply_fzf_defaults

  local original_curcontext="${curcontext:-}"
  local curcontext="${original_curcontext%:*}:tab-start"
  local alias_name alias_value cmd_name cmd_path cmd_detail dir_name file_name
  local history_command entry_text
  local -a command_values command_displays
  local -a alias_values alias_displays
  local -a directory_values directory_displays
  local -a script_values script_displays
  local -a history_values history_displays
  local -a TAB_START_HISTORY_ENTRIES
  local -a path_quote_options
  local -i files_max_depth=0
  local -i result=1

  if __tab_start_is_enabled "$TAB_START_INCLUDE_COMMANDS"; then
    for cmd_name in ${(ou)${(k)commands}}; do
      if ! __tab_start_candidate_is_supported "$cmd_name"; then
        continue
      fi
      cmd_path="${commands[$cmd_name]}"
      cmd_detail="${cmd_path/#$HOME\//~\/}"
      __tab_start_name_entry "$cmd_name" "$cmd_detail"
      entry_text="$REPLY"
      __tab_start_group_display "command" "$entry_text"
      command_values+=("$cmd_name")
      command_displays+=("$REPLY")
    done
  fi

  if __tab_start_is_enabled "$TAB_START_INCLUDE_ALIASES"; then
    for alias_name in ${(ok)aliases}; do
      if ! __tab_start_candidate_is_supported "$alias_name"; then
        continue
      fi
      alias_value="${aliases[$alias_name]}"
      __tab_start_name_entry "$alias_name" "$alias_value"
      entry_text="$REPLY"
      __tab_start_group_display "alias" "$entry_text"
      alias_values+=("$alias_name")
      alias_displays+=("$REPLY")
    done
  fi

  if __tab_start_is_enabled "$TAB_START_INCLUDE_DIRECTORIES"; then
    for dir_name in *(N-/); do
      if ! __tab_start_candidate_is_supported "$dir_name"; then
        continue
      fi
      __tab_start_path_display "$dir_name" "/"
      entry_text="$REPLY"
      __tab_start_group_display "dir" "$entry_text"
      directory_values+=("$dir_name")
      directory_displays+=("$REPLY")
    done
  fi

  __tab_start_resolve_files_max_depth
  files_max_depth="$REPLY"
  __tab_start_collect_executable_files "$files_max_depth"
  for file_name in "${TAB_START_EXECUTABLE_FILES[@]}"; do
    if ! __tab_start_candidate_is_supported "$file_name"; then
      continue
    fi
    __tab_start_path_display "$file_name" ""
    entry_text="$REPLY"
    __tab_start_group_display "script" "$entry_text"
    script_values+=("$file_name")
    script_displays+=("$REPLY")
  done

  if __tab_start_is_enabled "$TAB_START_INCLUDE_HISTORY"; then
    if __tab_start_collect_history_entries; then
      for history_command in "${TAB_START_HISTORY_ENTRIES[@]}"; do
        __tab_start_group_display "history" "$history_command"
        history_values+=("$history_command")
        history_displays+=("$REPLY")
      done
    fi
  fi

  if ! __tab_start_is_enabled "$TAB_START_ESCAPE_PATHS"; then
    path_quote_options=(-Q)
  fi

  if (( ${#command_values[@]} )); then
    if compadd -V tab-start-command -X command -d command_displays -Q -- "${command_values[@]}"; then
      result=0
    fi
  fi
  if (( ${#alias_values[@]} )); then
    if compadd -V tab-start-alias -X alias -d alias_displays -Q -- "${alias_values[@]}"; then
      result=0
    fi
  fi
  if (( ${#directory_values[@]} )); then
    if compadd -V tab-start-dir -X dir -d directory_displays "${path_quote_options[@]}" -S / -q -- "${directory_values[@]}"; then
      result=0
    fi
  fi
  if (( ${#script_values[@]} )); then
    if compadd -V tab-start-script -X script -d script_displays "${path_quote_options[@]}" -S '' -- "${script_values[@]}"; then
      result=0
    fi
  fi
  if (( ${#history_values[@]} )); then
    if compadd -V tab-start-history -X history -d history_displays -Q -S '' -- "${history_values[@]}"; then
      result=0
    fi
  fi

  if (( result )); then
    curcontext="$original_curcontext"
    __tab_start_complete_previous_command
    return $?
  fi
  return 0
}

if (( ! $+functions[compdef] )); then
  print -u2 -- "tab-start: Zsh completion system unavailable; load after compinit"
else
  if [[ "${_comps[-command-]-}" != "_tab_start_complete" ]]; then
    TAB_START_ORIGINAL_COMMAND_COMPLETER="${_comps[-command-]:-_autocd}"
  fi
  compdef _tab_start_complete -command-

  # Without this scoped style, Zsh inserts a literal tab on an empty command line.
  zstyle ':completion:::::' insert-tab false
  # Preserve source order and newest-first history inside tab-start only.
  zstyle ':completion:complete:-command-:tab-start' sort false
fi
