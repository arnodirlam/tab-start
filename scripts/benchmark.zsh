#!/usr/bin/env zsh

set -euo pipefail
zmodload zsh/datetime

cd "${0:A:h}/.."

typeset -i runs=30
if [[ $# -gt 0 ]]; then
  if [[ "$1" != <-> || "$1" -le 0 ]]; then
    print -u2 -- "usage: scripts/benchmark.zsh [runs]"
    exit 1
  fi
  runs="$1"
fi

zle() { return 0; }
bindkey() { return 0; }

fzf() {
  awk 'NR==2{split($0,a,"\t"); print a[1] "\t" a[3]; exit}'
}

commands[fzf]="/tmp/fzf"
source ./tab-start.plugin.zsh

benchmark_case() {
  local label="$1"
  local include_commands="$2"
  local include_aliases="$3"
  local include_directories="$4"
  local include_files="$5"
  local -a samples
  local -a sorted
  local sample
  local start end elapsed sum avg min max p95
  local p95_index
  integer i

  TAB_START_INCLUDE_COMMANDS="$include_commands"
  TAB_START_INCLUDE_ALIASES="$include_aliases"
  TAB_START_INCLUDE_DIRECTORIES="$include_directories"
  TAB_START_INCLUDE_FILES="$include_files"

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
  sum=0.0
  for sample in "${samples[@]}"; do
    (( sum += sample ))
  done

  avg=$(( sum / runs ))
  min="${sorted[1]}"
  max="${sorted[-1]}"
  p95_index=$(( (runs * 95 + 99) / 100 ))
  if (( p95_index < 1 )); then
    p95_index=1
  fi
  if (( p95_index > runs )); then
    p95_index="$runs"
  fi
  p95="${sorted[$p95_index]}"

  printf '%-34s avg=%8.3f ms  min=%8.3f  p95=%8.3f  max=%8.3f\n' \
    "$label" "$avg" "$min" "$p95" "$max"
}

print -r -- "tab-start benchmark (${runs} runs)"
benchmark_case "all (commands + aliases + dirs + files)" 1 1 1 1
benchmark_case "commands + aliases" 1 1 0 0
benchmark_case "dirs + files" 0 0 1 1
