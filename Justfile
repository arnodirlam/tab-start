set shell := ["bash", "-euo", "pipefail", "-c"]

default:
    @just --list

check:
    env ZDOTDIR=/tmp zsh -f scripts/tests/01-syntax.zsh
    env ZDOTDIR=/tmp zsh -f scripts/tests/02-fallback-widget.zsh
    env ZDOTDIR=/tmp zsh -f scripts/tests/03-no-sources-fallback.zsh
    env ZDOTDIR=/tmp zsh -f scripts/tests/04-history-selection.zsh

benchmark dir='' runs='30':
    benchmark_dir='{{dir}}'; \
    if [[ -z "$benchmark_dir" ]]; then benchmark_dir="${BENCHMARK_DIR:-.}"; fi; \
    zsh -i scripts/benchmark.zsh "$benchmark_dir" {{runs}}

update-readme-benchmark dir='' runs='30':
    benchmark_dir='{{dir}}'; \
    if [[ -z "$benchmark_dir" ]]; then benchmark_dir="${BENCHMARK_DIR:-.}"; fi; \
    zsh -f scripts/update-readme-benchmark.zsh "$benchmark_dir" {{runs}}
