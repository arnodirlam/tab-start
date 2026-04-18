set shell := ["bash", "-euo", "pipefail", "-c"]

default:
    @just --list

check:
    env ZDOTDIR=/tmp zsh -f scripts/tests/01-syntax.zsh
    env ZDOTDIR=/tmp zsh -f scripts/tests/02-fallback-widget.zsh
    env ZDOTDIR=/tmp zsh -f scripts/tests/03-no-sources-fallback.zsh
    env ZDOTDIR=/tmp zsh -f scripts/tests/04-history-selection.zsh
