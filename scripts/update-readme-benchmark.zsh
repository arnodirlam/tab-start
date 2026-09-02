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

tmp_block="$(mktemp)"
tmp_readme="$(mktemp)"

cleanup() {
  rm -f "$tmp_block" "$tmp_readme"
}
trap cleanup EXIT

cd "$repo_root"
just benchmark "$benchmark_dir" "$runs" | awk '
  match($0, /benchmark environment: /) {
    footer = substr($0, RSTART + RLENGTH)
    next
  }

  match($0, /[0-9]+ ms\t/) {
    row = substr($0, RSTART)
    if (split(row, fields, "\t") != 3) {
      exit 3
    }
    sub(/ ms$/, "", fields[1])
    if (++rows == 1) {
      print "| Category | Baseline entries | Cost (ms, p95) |"
      print "| --- | --- | ---: |"
    }
    printf "| %s | %s | %s |\n", fields[2], fields[3], fields[1]
  }

  END {
    if (!footer || !rows) {
      exit 3
    }
    printf "\n_%s_\n", footer
  }
' >"$tmp_block" || {
  print -u2 -- "unable to generate benchmark block"
  exit 1
}

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
