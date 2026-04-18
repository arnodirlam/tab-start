#!/usr/bin/env zsh

set -euo pipefail
zmodload zsh/datetime

script_dir="${0:A:h}"
repo_root="${script_dir}/.."
benchmark_dir="$repo_root"

typeset -i runs=30
if [[ $# -gt 0 ]]; then
  if [[ "$1" == <-> ]]; then
    if [[ "$1" -le 0 ]]; then
      print -u2 -- "usage: scripts/benchmark.zsh [directory] [runs]"
      exit 1
    fi
    runs="$1"
  else
    benchmark_dir="$1"
    shift
    if [[ $# -gt 0 ]]; then
      if [[ "$1" != <-> || "$1" -le 0 ]]; then
        print -u2 -- "usage: scripts/benchmark.zsh [directory] [runs]"
        exit 1
      fi
      runs="$1"
    fi
  fi
fi

if [[ ! -d "$benchmark_dir" ]]; then
  print -u2 -- "benchmark directory does not exist: $benchmark_dir"
  exit 1
fi
benchmark_dir="${benchmark_dir:A}"
directory_history_file=""

zle() { return 0; }
bindkey() { return 0; }

fzf() {
  awk '
    NR == 2 { split($0, a, "\t"); selection = a[1] "\t" a[3] }
    END { if (selection != "") print selection }
  '
}

commands[fzf]="/tmp/fzf"
source "$repo_root/tab-start.plugin.zsh"

cd "$benchmark_dir"

resolve_directory_history_file() {
  local candidate
  candidate="$HOME/.directory_history/${benchmark_dir#/}/history"
  if [[ -r "$candidate" ]]; then
    REPLY="$candidate"
  else
    REPLY=""
  fi
}

load_directory_history() {
  resolve_directory_history_file
  directory_history_file="$REPLY"
  if [[ -n "$directory_history_file" ]]; then
    fc -R "$directory_history_file" 2>/dev/null || true
  fi
}

count_history_entries() {
  local history_line history_command history_lines
  local -A seen_history_entries
  local -i history_total=0
  local -i history_unique=0

  if history_lines="$(fc -rl 1 2>/dev/null)"; then
    for history_line in ${(f)history_lines}; do
      if ! __tab_start_parse_history_entry "$history_line"; then
        continue
      fi
      history_command="$REPLY"
      (( history_total += 1 ))
      if [[ -n ${seen_history_entries[$history_command]+x} ]]; then
        continue
      fi
      seen_history_entries[$history_command]=1
      (( history_unique += 1 ))
    done
  fi

  REPLY="$history_total"
  HISTORY_UNIQUE_COUNT="$history_unique"
}

typeset -i commands_count aliases_count dirs_count files_count history_total_count history_unique_count
typeset -a directory_entries file_entries
load_directory_history
commands_count=${#${(k)commands}}
aliases_count=${#${(k)aliases}}
directory_entries=(*(N-/))
file_entries=(*(N-.))
dirs_count=${#directory_entries[@]}
files_count=${#file_entries[@]}
count_history_entries
history_total_count="$REPLY"
history_unique_count="$HISTORY_UNIQUE_COUNT"

print_benchmark_case() {
  local label="$1"
  local include_commands="$2"
  local include_aliases="$3"
  local include_directories="$4"
  local include_files="$5"
  local include_history="$6"
  local -a samples
  local -a sorted
  local start end elapsed p95
  local p95_index
  integer i

  TAB_START_INCLUDE_COMMANDS="$include_commands"
  TAB_START_INCLUDE_ALIASES="$include_aliases"
  TAB_START_INCLUDE_DIRECTORIES="$include_directories"
  TAB_START_INCLUDE_FILES="$include_files"
  TAB_START_INCLUDE_HISTORY="$include_history"

  samples=()
  for (( i = 1; i <= runs; i += 1 )); do
    BUFFER=""
    LBUFFER=""
    start=$EPOCHREALTIME
    _tab_start_insert
    end=$EPOCHREALTIME
    elapsed=$(( (end - start) * 1000.0 ))
    samples+=("$elapsed")
  done

  sorted=( ${(on)samples} )
  p95_index=$(( (runs * 95 + 99) / 100 ))
  if (( p95_index < 1 )); then
    p95_index=1
  fi
  if (( p95_index > runs )); then
    p95_index="$runs"
  fi
  p95="${sorted[$p95_index]}"

  printf '%.0f ms\t%s\n' "$p95" "$label"
}

print -r -- "$(date +%F), zsh ${ZSH_VERSION}, $(uname -s) $(uname -r), ${commands_count} commands, ${aliases_count} aliases, ${dirs_count} dirs, ${files_count} files, ${history_total_count} history entries (${history_unique_count} unique), ${runs} runs, 95th percentile"
print_benchmark_case "commands + aliases + dirs + files + history" 1 1 1 1 1
print_benchmark_case "commands + aliases + dirs + files" 1 1 1 1 0
print_benchmark_case "aliases + dirs + files" 0 1 1 1 0
print_benchmark_case "dirs + files" 0 0 1 1 0
