# TAB on empty prompt: fuzzy-pick command/alias/path/history entry and insert.
#
# Optional config vars (set before `source $ZSH/oh-my-zsh.sh`):
#   TAB_START_BINDKEY='^I'            # set "none" to skip automatic bindkey
#   TAB_START_PROMPT='tab> '
#   TAB_START_HEADER=$'TAB on empty prompt: pick alias/command/path/history entry\nEsc cancels, Enter inserts'
#   TAB_START_INCLUDE_COMMANDS=1       # 1 or 0
#   TAB_START_INCLUDE_ALIASES=1        # 1 or 0
#   TAB_START_INCLUDE_DIRECTORIES=1    # 1 or 0
#   TAB_START_INCLUDE_FILES=1          # 1 or 0
#   TAB_START_INCLUDE_HISTORY=1        # 1 or 0
#   TAB_START_ESCAPE_PATHS=1           # 1 or 0 (file/directory insertion)
: "${TAB_START_BINDKEY:=^I}"
: "${TAB_START_PROMPT:=tab> }"
: "${TAB_START_HEADER:=$'TAB on empty prompt: pick command/alias/path/history entry\nEsc cancels, Enter inserts'}"
: "${TAB_START_INCLUDE_COMMANDS:=1}"
: "${TAB_START_INCLUDE_ALIASES:=1}"
: "${TAB_START_INCLUDE_DIRECTORIES:=1}"
: "${TAB_START_INCLUDE_FILES:=1}"
: "${TAB_START_INCLUDE_HISTORY:=1}"
: "${TAB_START_ESCAPE_PATHS:=1}"

TAB_START_SGR_RESET=$'\x1b[0m'
TAB_START_SGR_BOLD=$'\x1b[1m'
typeset -g TAB_START_FALLBACK_WIDGET="expand-or-complete"

__tab_start_is_enabled() {
  [[ "${1:-1}" != "0" ]]
}

__tab_start_sanitize_display() {
  REPLY="$1"
  REPLY="${REPLY//$'\t'/\\t}"
  REPLY="${REPLY//$'\n'/\\n}"
}

__tab_start_bold_name_entry() {
  local name="$1"
  local detail="$2"
  if [[ -z "$detail" ]]; then
    REPLY="${TAB_START_SGR_BOLD}${name}${TAB_START_SGR_RESET}"
  else
    REPLY="${TAB_START_SGR_BOLD}${name}${TAB_START_SGR_RESET} -> ${detail}"
  fi
}

__tab_start_parse_history_entry() {
  local line="$1"
  local trimmed event_number

  trimmed="${line#"${line%%[![:space:]]*}"}"
  event_number="${trimmed%%[^0-9]*}"
  if [[ -z "$event_number" ]]; then
    return 1
  fi

  trimmed="${trimmed#$event_number}"
  while [[ "$trimmed" == \** ]]; do
    trimmed="${trimmed#\*}"
  done
  if [[ "$trimmed" != [[:space:]]* ]]; then
    return 1
  fi

  trimmed="${trimmed#"${trimmed%%[![:space:]]*}"}"
  if [[ -z "$trimmed" ]]; then
    return 1
  fi

  REPLY="$trimmed"
}

__tab_start_bound_widget_for_key() {
  local key="$1"
  local binding
  local -a words

  REPLY=""
  binding="$(bindkey "$key" 2>/dev/null)" || return
  words=(${(z)binding})
  if (( ${#words[@]} < 2 )); then
    return
  fi
  REPLY="${(Q)words[2]}"
  if [[ "$REPLY" == "undefined-key" || "$REPLY" == "_tab_start_insert" ]]; then
    REPLY=""
    return
  fi
  if (( ${+widgets} )) && (( ! ${+widgets[$REPLY]} )); then
    REPLY=""
  fi
}

__tab_start_dispatch_fallback() {
  local widget="${TAB_START_FALLBACK_WIDGET:-expand-or-complete}"
  if [[ "$widget" == "_tab_start_insert" ]]; then
    widget="expand-or-complete"
  fi
  if (( ${+widgets} )) && (( ! ${+widgets[$widget]} )); then
    widget="expand-or-complete"
  fi
  zle "$widget"
}

# Normalize header so both "line1\nline2" and "$'line1\nline2'" are supported.
__tab_start_resolve_header() {
  local header="$TAB_START_HEADER"
  if (( ${#header} >= 3 )) && [[ "${header[1,2]}" == "\$'" && "${header[-1]}" == "'" ]]; then
    header="${header[3,-2]}"
  fi
  REPLY="${(g::)header}"
}

# Relies on dynamic scope for `row_id`, `rows`, `types_by_id`, and `insert_by_id`.
__tab_start_add_row() {
  local kind="$1"
  local entry="$2"
  local insert_payload="$3"
  local sanitized_entry

  __tab_start_sanitize_display "$entry"
  sanitized_entry="$REPLY"
  (( row_id += 1 ))
  types_by_id[$row_id]="$kind"
  insert_by_id[$row_id]="$insert_payload"
  rows+="${kind}"$'\t'"${sanitized_entry}"$'\t'"${row_id}"$'\n'
}

_tab_start_insert() {
  if [[ -n ${BUFFER//[[:space:]]/} ]]; then
    __tab_start_dispatch_fallback
    return
  fi

  if ! (( $+commands[fzf] )); then
    __tab_start_dispatch_fallback
    return
  fi

  local alias_name alias_value cmd_name cmd_path cmd_display dir_name file_name
  local history_line history_command history_lines
  local selection picked_kind picked_id payload entry_text header_text
  local rows
  local -i row_id=0
  local -A types_by_id
  local -A insert_by_id
  local -A seen_history_entries
  rows=$'category\tentry\tid\n'

  if __tab_start_is_enabled "$TAB_START_INCLUDE_COMMANDS"; then
    for cmd_name in ${(ou)${(k)commands}}; do
      cmd_path="${commands[$cmd_name]}"
      cmd_display="${cmd_path/#$HOME\//~\/}"
      __tab_start_bold_name_entry "$cmd_name" "$cmd_display"
      entry_text="$REPLY"
      __tab_start_add_row "command" "$entry_text" "$cmd_name "
    done
  fi

  if __tab_start_is_enabled "$TAB_START_INCLUDE_ALIASES"; then
    for alias_name in ${(ok)aliases}; do
      alias_value="${aliases[$alias_name]}"
      __tab_start_bold_name_entry "$alias_name" "$alias_value"
      entry_text="$REPLY"
      __tab_start_add_row "alias" "$entry_text" "$alias_name "
    done
  fi

  if __tab_start_is_enabled "$TAB_START_INCLUDE_DIRECTORIES"; then
    for dir_name in *(N-/); do
      __tab_start_add_row "directory" "$dir_name" "$dir_name"
    done
  fi

  if __tab_start_is_enabled "$TAB_START_INCLUDE_FILES"; then
    for file_name in *(N-.); do
      __tab_start_add_row "file" "$file_name" "$file_name"
    done
  fi

  if __tab_start_is_enabled "$TAB_START_INCLUDE_HISTORY"; then
    if history_lines="$(fc -rl 1 2>/dev/null)"; then
      for history_line in ${(f)history_lines}; do
        if ! __tab_start_parse_history_entry "$history_line"; then
          continue
        fi
        history_command="$REPLY"
        if [[ -n ${seen_history_entries[$history_command]+x} ]]; then
          continue
        fi
        seen_history_entries[$history_command]=1
        __tab_start_add_row "history" "$history_command" "$history_command"
      done
    fi
  fi

  if (( row_id == 0 )); then
    __tab_start_dispatch_fallback
    return
  fi

  __tab_start_resolve_header
  header_text="$REPLY"

  selection="$(
    print -r -- "$rows" | fzf \
      --ansi \
      --prompt="$TAB_START_PROMPT" \
      --delimiter=$'\t' \
      --with-nth=1,2 \
      --nth=1,2 \
      --tiebreak=chunk,begin \
      --accept-nth=1,3 \
      --header-lines=1 \
      --header="$header_text"
  )"

  if [[ -z "$selection" ]]; then
    zle redisplay
    return
  fi

  picked_kind="${selection%%$'\t'*}"
  picked_id="${selection#*$'\t'}"
  if [[ -z "$picked_kind" || -z "$picked_id" ]] || (( ! ${+insert_by_id[$picked_id]} )); then
    zle redisplay
    return
  fi
  if [[ "${types_by_id[$picked_id]}" != "$picked_kind" ]]; then
    zle redisplay
    return
  fi

  payload="${insert_by_id[$picked_id]}"
  if [[ "$picked_kind" == "file" || "$picked_kind" == "directory" ]] && __tab_start_is_enabled "$TAB_START_ESCAPE_PATHS"; then
    LBUFFER+="${(q)payload}"
  else
    LBUFFER+="$payload"
  fi
  zle redisplay
}

zle -N _tab_start_insert
if [[ -n "$TAB_START_BINDKEY" && "$TAB_START_BINDKEY" != "none" ]]; then
  __tab_start_bound_widget_for_key "$TAB_START_BINDKEY"
  if [[ -n "$REPLY" ]]; then
    TAB_START_FALLBACK_WIDGET="$REPLY"
  fi
  bindkey "$TAB_START_BINDKEY" _tab_start_insert
fi
