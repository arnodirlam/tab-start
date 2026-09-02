#!/usr/bin/env zsh

set -eo pipefail
zmodload zsh/datetime

# Interactive startup supplies commands, aliases, and history; hooks only add noise here.
precmd_functions=()
preexec_functions=()
chpwd_functions=()
periodic_functions=()
unfunction TRAPDEBUG TRAPZERR 2>/dev/null || true
trap - DEBUG ZERR

script_dir="${0:A:h}"
repo_root="${script_dir}/.."
benchmark_dir="${BENCHMARK_DIR:-$repo_root}"

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

source "$repo_root/tab-start.plugin.zsh"

typeset -gi benchmark_candidate_count=0
compadd() {
  while (( $# )); do
    if [[ "$1" == "--" ]]; then
      shift
      (( benchmark_candidate_count += $# ))
      return 0
    fi
    shift
  done
  return 1
}
TAB_START_ORIGINAL_COMMAND_COMPLETER=:

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
  local history_event history_command
  local -A seen_history_entries
  local -i history_total=0
  local -i history_unique=0

  if (( ${+history} )); then
    for history_event in ${(Onk)history}; do
      history_command="${history[$history_event]}"
      if [[ -z "$history_command" ]] || ! __tab_start_candidate_is_supported "$history_command"; then
        continue
      fi
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

count_total_files_within_depth() {
  local max_depth="$1"
  local file_name file_pattern
  local -a all_files unique_files
  local -i depth_level
  local -i depth_segments

  all_files=()
  if (( max_depth <= 0 )); then
    REPLY="0"
    return
  fi

  for (( depth_level = 1; depth_level <= max_depth; depth_level += 1 )); do
    file_pattern=""
    for (( depth_segments = 1; depth_segments < depth_level; depth_segments += 1 )); do
      file_pattern+="*/"
    done
    file_pattern+="*(N-.)"
    for file_name in ${~file_pattern}; do
      all_files+=("$file_name")
    done
  done

  unique_files=("${(@ou)all_files}")
  REPLY="${#unique_files[@]}"
}

benchmark_hardware_details() {
  local cpu_model=""
  local cpu_count=""
  local memory_bytes=""
  local -a details

  case "$(uname -s)" in
    Darwin)
      cpu_model="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || true)"
      cpu_count="$(sysctl -n hw.logicalcpu 2>/dev/null || true)"
      memory_bytes="$(sysctl -n hw.memsize 2>/dev/null || true)"
      ;;
    Linux)
      cpu_model="$(awk -F ': ' '/^model name/ { print $2; exit }' /proc/cpuinfo 2>/dev/null || true)"
      cpu_count="$(getconf _NPROCESSORS_ONLN 2>/dev/null || true)"
      memory_bytes="$(awk '/^MemTotal:/ { print $2 * 1024; exit }' /proc/meminfo 2>/dev/null || true)"
      ;;
  esac

  [[ -n "$cpu_model" ]] && details+=("$cpu_model")
  [[ "$cpu_count" == <-> ]] && details+=("${cpu_count} logical CPUs")
  if [[ "$memory_bytes" == <-> ]]; then
    details+=("$(( (memory_bytes + 536870912) / 1073741824 )) GiB RAM")
  fi

  REPLY="${(j:, :)details}"
}

typeset -i benchmark_commands_count benchmark_aliases_count benchmark_dirs_count
typeset -i benchmark_files_count benchmark_total_files_count benchmark_history_total_count
typeset -i benchmark_history_unique_count benchmark_files_max_depth
typeset -a benchmark_directory_entries benchmark_file_entries
load_directory_history
benchmark_commands_count=${#${(k)commands}}
benchmark_aliases_count=${#${(k)aliases}}
benchmark_directory_entries=(*(N-/))
__tab_start_resolve_files_max_depth
benchmark_files_max_depth="$REPLY"
TAB_START_FILES_MAX_DEPTH="$benchmark_files_max_depth"
__tab_start_collect_executable_files "$benchmark_files_max_depth"
benchmark_file_entries=("${TAB_START_EXECUTABLE_FILES[@]}")
count_total_files_within_depth "$benchmark_files_max_depth"
benchmark_total_files_count="$REPLY"
benchmark_dirs_count=${#benchmark_directory_entries[@]}
benchmark_files_count=${#benchmark_file_entries[@]}
count_history_entries
benchmark_history_total_count="$REPLY"
benchmark_history_unique_count="$HISTORY_UNIQUE_COUNT"

print_benchmark_case() {
  local label="$1"
  local baseline="$2"
  local include_commands="$3"
  local include_aliases="$4"
  local include_directories="$5"
  local files_max_depth="$6"
  local include_history="$7"
  local -a samples
  local -a sorted
  local start end elapsed p95
  local p95_index
  integer i

  TAB_START_INCLUDE_COMMANDS="$include_commands"
  TAB_START_INCLUDE_ALIASES="$include_aliases"
  TAB_START_INCLUDE_DIRECTORIES="$include_directories"
  TAB_START_FILES_MAX_DEPTH="$files_max_depth"
  TAB_START_INCLUDE_HISTORY="$include_history"

  samples=()
  for (( i = 1; i <= runs; i += 1 )); do
    CURRENT=1
    BUFFER=""
    curcontext=':complete:-command-:'
    benchmark_candidate_count=0
    start=$EPOCHREALTIME
    _tab_start_complete
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

  printf '%.0f ms\t%s\t%s\n' "$p95" "$label" "$baseline"
}

benchmark_hardware_details
benchmark_environment="zsh ${ZSH_VERSION}"
if [[ -n "$REPLY" ]]; then
  benchmark_environment+=", $REPLY"
fi
print -r -- "benchmark environment: ${benchmark_environment}, ${runs} runs, 95th percentile, candidate generation only"
print_benchmark_case "commands" "$benchmark_commands_count" 1 0 0 0 0
print_benchmark_case "aliases" "$benchmark_aliases_count" 0 1 0 0 0
print_benchmark_case "directories" "$benchmark_dirs_count" 0 0 1 0 0
print_benchmark_case "executable files" "${benchmark_files_count} executable / ${benchmark_total_files_count} scanned (depth ${benchmark_files_max_depth})" 0 0 0 "$benchmark_files_max_depth" 0
print_benchmark_case "history" "${benchmark_history_unique_count} unique / ${benchmark_history_total_count} total" 0 0 0 0 1
