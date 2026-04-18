#!/usr/bin/env zsh

set -euo pipefail

script_dir="${0:A:h}"
repo_root="${script_dir}/.."
readme_path="${repo_root}/README.md"
benchmark_dir="${1:-}"
if [[ -z "$benchmark_dir" ]]; then
  benchmark_dir="${BENCHMARK_DIR:-.}"
fi
runs="${2:-30}"

if [[ ! "$runs" == <-> || "$runs" -le 0 ]]; then
  print -u2 -- "usage: scripts/update-readme-benchmark.zsh [directory] [runs]"
  exit 1
fi

tmp_output="$(mktemp)"
tmp_filtered="$(mktemp)"
tmp_block="$(mktemp)"
tmp_readme="$(mktemp)"

cleanup() {
  rm -f "$tmp_output" "$tmp_filtered" "$tmp_block" "$tmp_readme"
}
trap cleanup EXIT

cd "$repo_root"
just benchmark "$benchmark_dir" "$runs" >"$tmp_output"

# Keep only the benchmark header and timing rows in case interactive shell hooks print noise.
awk '
  BEGIN {
    header_seen = 0
    timing_rows = 0
  }

  {
    if (!header_seen && match($0, /[0-9]{4}-[0-9]{2}-[0-9]{2}, /)) {
      print substr($0, RSTART)
      header_seen = 1
      next
    }

    if (match($0, /[0-9]+ ms\t/)) {
      print substr($0, RSTART)
      timing_rows += 1
    }
  }

  END {
    if (!header_seen || timing_rows == 0) {
      exit 3
    }
  }
' "$tmp_output" >"$tmp_filtered" || {
  print -u2 -- "unable to parse benchmark output"
  exit 1
}

{
  print -r -- '```text'
  cat "$tmp_filtered"
  print -r -- '```'
} >"$tmp_block"

awk -v block_file="$tmp_block" '
  BEGIN {
    while ((getline line < block_file) > 0) {
      block = block line ORS
    }
    close(block_file)
    in_block = 0
    replaced = 0
  }

  /<!-- benchmark:start -->/ {
    print
    printf "%s", block
    in_block = 1
    replaced = 1
    next
  }

  /<!-- benchmark:end -->/ {
    in_block = 0
    print
    next
  }

  !in_block {
    print
  }

  END {
    if (!replaced) {
      exit 2
    }
  }
' "$readme_path" >"$tmp_readme" || {
  print -u2 -- "unable to locate benchmark markers in README.md"
  exit 1
}

mv "$tmp_readme" "$readme_path"
