set shell := ["bash", "-euo", "pipefail", "-c"]

default:
    @just --list

check:
    env ZDOTDIR=/tmp zsh -f scripts/check.zsh

benchmark runs='30':
    env ZDOTDIR=/tmp zsh -f scripts/benchmark.zsh {{runs}}
