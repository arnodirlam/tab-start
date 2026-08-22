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

## Troubleshooting

- `tab-start: Zsh completion system unavailable`: load the plugin after `compinit`.
- Blank `TAB` inserts a literal tab: confirm `${_comps[-command-]}` resolves to `_tab_start_complete` after plugin loading.
- Native completion appears instead of fzf-tab: confirm fzf-tab is installed, enabled, and owns the `TAB` binding.
- Startup picker feels slow: command enumeration is usually the largest cost; test with `TAB_START_INCLUDE_COMMANDS=0`.

## Benchmarks

Benchmarks are local to current interactive shell environment and measure tab-start candidate preparation only. Native `compadd`, fzf-tab capture/rendering, and interactive selection are excluded.

<!-- benchmark:start -->
```text
2026-08-21, zsh 5.9, Darwin 25.5.0, 2474 commands, 576 aliases, 12 dirs, 359 files (7 executable, depth 2), 2311 history entries (670 unique), 30 runs, 95th percentile, candidate generation only
346 ms	commands + aliases + dirs + executable files + history
172 ms	commands + aliases + dirs + executable files
34 ms	aliases + dirs + executable files
5 ms	dirs + executable files
```
<!-- benchmark:end -->

## Development

This repo includes a [Justfile](./Justfile) and pinned tools in [`.tool-versions`](./.tool-versions). Zsh remains a system dependency locally and is installed explicitly in CI.

- `just check`: runs syntax, provider, and real fzf-tab capture/apply integration checks.
- `just benchmark [dir] [runs]`: benchmarks candidate generation in `dir` (defaults: `.` and `30`).
- `just update-readme-benchmark [dir] [runs]`: refreshes benchmark block.

Set `FZF_TAB_TEST_DIR=/path/to/fzf-tab` when integration test cannot find standard Oh My Zsh installation.

## License

Project licensed under MIT License. See [LICENSE](./LICENSE).
