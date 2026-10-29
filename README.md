# tab-start

`tab-start` adds starter entries to Zsh completion when you press `TAB` on a blank prompt. [fzf-tab](https://github.com/Aloxaf/fzf-tab) renders those entries and provides grouping, fuzzy search, and selection.

It helps you quickly insert:
- commands
- aliases
- directories in the current working directory
- executable files under the current working directory (recursive, configurable depth)
- history entries

Normal completion remains unchanged for non-empty prompts.

## Requirements

- Zsh 5+
- [fzf-tab](https://github.com/Aloxaf/fzf-tab) and its `fzf` dependency

## Installation

### Oh My Zsh

Clone both custom plugins if fzf-tab is not already installed:

```zsh
git clone https://github.com/arnodirlam/tab-start \
  "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/tab-start"
git clone https://github.com/Aloxaf/fzf-tab \
  "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fzf-tab"
```

Add `tab-start` before `fzf-tab` in `~/.zshrc`:

```zsh
plugins=(... tab-start fzf-tab)
```

Then reload Zsh:

```zsh
exec zsh -l
```

fzf-tab must load after `compinit` and remain the final plugin that binds `TAB`. Plugins that wrap widgets, such as syntax highlighting or autosuggestions, should follow fzf-tab according to its installation guidance.

### Manual loading

Load tab-start after `compinit`; fzf-tab may load before or after tab-start:

```zsh
autoload -Uz compinit
compinit
source /path/to/tab-start.plugin.zsh
source /path/to/fzf-tab.plugin.zsh
```

## Behavior

- Blank prompt + `TAB`: tab-start contributes enabled groups to normal Zsh completion, then fzf-tab opens its picker.
- Nonblank prompt + `TAB`: tab-start delegates to the command-position completer that was configured previously.
- No enabled or available entries: previous completer runs.

fzf-tab owns picker behavior. Its defaults include:

- `Enter`: insert selection.
- `Esc`: cancel.
- `F1` / `F2`: switch backward and forward between groups.

Insertion behavior:

- `command` and `alias`: inserted with one trailing space.
- `dir`: shell-escaped by default with trailing `/`.
- `script`: shell-escaped by default without trailing space.
- `history`: supported single-line entries are inserted exactly, without additional quoting or trailing space.

Directory and script rows use their fzf-tab group color. Directory symlink arrows and targets use the same color as the rest of the row.

Entries containing newlines or fzf-tab's reserved NUL/STX control characters are omitted because they cannot cross its capture format safely.

## Configuration

Set variables before `source $ZSH/oh-my-zsh.sh` in `~/.zshrc`.

| Variable | Default | Description |
| --- | --- | --- |
| `TAB_START_INCLUDE_COMMANDS` | `1` | Include command entries. |
| `TAB_START_INCLUDE_ALIASES` | `1` | Include alias entries. |
| `TAB_START_INCLUDE_DIRECTORIES` | `1` | Include cwd directories. |
| `TAB_START_FILES_MAX_DEPTH` | `2` | Executable-file recursion depth. Set to `0` to disable executable files. |
| `TAB_START_INCLUDE_HISTORY` | `1` | Include deduplicated history entries, newest first. |
| `TAB_START_ESCAPE_PATHS` | `1` | Let Zsh shell-escape directory and executable-file values. |

Example:

```zsh
TAB_START_INCLUDE_COMMANDS=1
TAB_START_INCLUDE_ALIASES=1
TAB_START_INCLUDE_DIRECTORIES=1
TAB_START_FILES_MAX_DEPTH=2
TAB_START_INCLUDE_HISTORY=1
TAB_START_ESCAPE_PATHS=1
```

Prompt text, headers, colors, previews, and picker key bindings are configured through [fzf-tab's zstyles](https://github.com/Aloxaf/fzf-tab/wiki/Configuration):

```zsh
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':fzf-tab:*' switch-group F1 F2
```

### Previews

tab-start uses one fzf-tab context for all groups. A preview dispatcher can normalize the selected row and provide group- or command-specific previews. This example handles Mix tasks, shows man pages for commands and alias targets, reproduces fzf's `_fzf_comprun` path previews, and applies matching behavior to history entries:

```zsh
zstyle ':fzf-tab:complete:-command-:tab-start' fzf-preview '
  typeset -a tab_start_preview_words=()
  typeset tab_start_preview_alias="" tab_start_preview_command="" tab_start_preview_mode=""
  typeset tab_start_preview_target=""

  _tab_start_preview_run() {
    local output
    output="$("$@" </dev/null 2>&1)" && [[ -n "$output" ]] || return 1
    print -r -- "$output"
  }

  case "$group" in
    command)
      tab_start_preview_mode=help
      tab_start_preview_words=("$word")
      ;;
    alias)
      tab_start_preview_mode=help
      tab_start_preview_alias="${desc#"$word -> "}"
      if [[ "$tab_start_preview_alias" == "$desc" ]]; then
        tab_start_preview_words=("$word")
      else
        tab_start_preview_words=("${(@Q)${(z)tab_start_preview_alias}}")
      fi
      ;;
    mix|history)
      tab_start_preview_mode=command
      tab_start_preview_words=("${(@Q)${(z)word}}")
      tab_start_preview_command="${tab_start_preview_words[1]:-}"
      if (( ${#tab_start_preview_words[@]} > 1 )); then
        tab_start_preview_target="${tab_start_preview_words[-1]}"
      fi
      ;;
    dir)
      tab_start_preview_mode=command
      tab_start_preview_command=cd
      tab_start_preview_target="$word"
      ;;
    *)
      tab_start_preview_mode=path
      tab_start_preview_target="$word"
      ;;
  esac

  if [[ "$tab_start_preview_mode" == help ]]; then
    tab_start_preview_command="${tab_start_preview_words[1]:-}"
    if [[ -n "$tab_start_preview_command" ]] &&
        whence -w -- "$tab_start_preview_command" >/dev/null 2>&1 &&
        command man -w "$tab_start_preview_command" >/dev/null 2>&1; then
      _tab_start_preview_run env \
        MANWIDTH="${FZF_PREVIEW_COLUMNS:-80}" MANPAGER=cat PAGER=cat \
        man "$tab_start_preview_command"
    fi
  else
    case "$tab_start_preview_command" in
      mix)
        if [[ -n "${tab_start_preview_words[2]:-}" ]]; then
          command mix help "${tab_start_preview_words[2]}" 2>/dev/null
        fi
        ;;
      cd)
        if [[ -n "$tab_start_preview_target" ]]; then
          command tree -C -- "$tab_start_preview_target" 2>/dev/null | command head -200
        fi
        ;;
      ssh)
        if [[ -n "$tab_start_preview_target" ]]; then
          command dig "$tab_start_preview_target" 2>/dev/null
        fi
        ;;
      *)
        [[ -n "$tab_start_preview_target" ]] ||
          tab_start_preview_target="$tab_start_preview_command"
        if [[ -n "$tab_start_preview_target" ]]; then
          command bat --style=numbers --color=always --line-range :500 \
            -- "$tab_start_preview_target" 2>/dev/null ||
            command tree -C -- "$tab_start_preview_target" 2>/dev/null
        fi
        ;;
    esac
  fi
'
zstyle ':fzf-tab:complete:-command-:tab-start' \
  fzf-flags --preview-window=wrap,wrap-word,border-sharp
```

Command and alias previews use man pages only; highlighted commands are not executed. Alias expansion comes from tab-start's displayed `name -> value` detail because fzf-tab preview processes do not inherit interactive aliases. For history rows, the dispatcher treats the first shell word as the command and the last as its preview target; Mix always uses the second word as its task. Missing `man`, `bat`, `tree`, or `dig` commands produce an empty preview for the affected entry without interrupting the picker. When `bat` is missing but `tree` is available, the path fallback uses `tree`. Picker flags apply to the whole tab-start context.

## Troubleshooting

- `tab-start: Zsh completion system unavailable`: load the plugin after `compinit`.
- Blank `TAB` inserts a literal tab: confirm `${_comps[-command-]}` resolves to `_tab_start_complete` after plugin loading.
- Native completion appears instead of fzf-tab: confirm fzf-tab is installed, enabled, and owns the `TAB` binding.
- Startup picker feels slow: command enumeration is usually the largest cost; test with `TAB_START_INCLUDE_COMMANDS=0`.

## Benchmarks

<!-- benchmark:start -->
| Category | Baseline entries | Cost (ms, p95) |
| --- | --- | ---: |
| commands | 2541 | 109 |
| aliases | 613 | 22 |
| directories | 12 | 1 |
| executable files | 7 executable / 360 scanned (depth 2) | 5 |
| history | 686 unique / 2394 total | 62 |

_zsh 5.9, Apple M1 Pro, 10 logical CPUs, 32 GiB RAM, 30 runs, 95th percentile, candidate generation only_
<!-- benchmark:end -->

Benchmarks are local to current interactive shell environment. Each row enables only its named category and measures tab-start candidate preparation. Native `compadd`, fzf-tab capture/rendering, and interactive selection are excluded.

## Development

This repo includes a [Justfile](./Justfile) and pinned tools in [`.tool-versions`](./.tool-versions). Zsh remains a system dependency locally and is installed explicitly in CI.

- `just check`: runs syntax, provider, and real fzf-tab capture/apply integration checks.
- `just benchmark [dir] [runs]`: benchmarks candidate generation in `dir` (defaults: `$BENCHMARK_DIR` or `.`, and `30`).
- `just update-readme-benchmark [dir] [runs]`: refreshes benchmark block with same defaults.

Set `FZF_TAB_TEST_DIR=/path/to/fzf-tab` when integration test cannot find standard Oh My Zsh installation.

## License

Project licensed under MIT License. See [LICENSE](./LICENSE).
