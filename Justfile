set shell := ["bash", "-euo", "pipefail", "-c"]

_default:
    @just --list

check:
    env ZDOTDIR=/tmp zsh -f scripts/tests/01-syntax.zsh
    env ZDOTDIR=/tmp zsh -f scripts/tests/02-completion-registration.zsh
    env ZDOTDIR=/tmp zsh -f scripts/tests/03-completion-provider.zsh
    env ZDOTDIR=/tmp zsh -f scripts/tests/04-executable-files-depth.zsh
    env ZDOTDIR=/tmp zsh -f scripts/tests/05-fzf-tab-integration.zsh

benchmark dir='' runs='30':
    benchmark_dir='{{dir}}'; \
    if [[ -z "$benchmark_dir" ]]; then benchmark_dir="${BENCHMARK_DIR:-.}"; fi; \
    zsh -i scripts/benchmark.zsh "$benchmark_dir" {{runs}}

update-readme-benchmark dir='' runs='30':
    benchmark_dir='{{dir}}'; \
    if [[ -z "$benchmark_dir" ]]; then benchmark_dir="${BENCHMARK_DIR:-.}"; fi; \
    zsh -f scripts/update-readme-benchmark.zsh "$benchmark_dir" {{runs}}
