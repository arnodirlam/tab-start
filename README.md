# tab-start

`tab-start` is an Oh My Zsh plugin that opens an `fzf` starter picker when you press `TAB` on an empty prompt.

It helps you quickly insert:
- commands
- aliases
- directories in the current working directory
- files in the current working directory
- history entries

On a non-empty prompt, `TAB` keeps normal completion behavior.

## Requirements

- Zsh 5+
- [fzf](https://github.com/junegunn/fzf)
- [Oh My Zsh](https://github.com/ohmyzsh/ohmyzsh)

## Installation

### Oh My Zsh (recommended)

1. Clone this repo into your custom plugins directory:

```bash
git clone https://github.com/arnodirlam/tab-start ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/tab-start
```

2. Add `tab-start` to your plugin list in `~/.zshrc`:

```zsh
plugins=(... tab-start)
```

3. Reload your shell:

```bash
exec zsh -l
```

### Existing dotfiles/local setup

If you keep this plugin in your own dotfiles tree, place `tab-start.plugin.zsh` at:

```text
${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/tab-start/tab-start.plugin.zsh
```

Then add `tab-start` in `plugins=(...)` and reload your shell.

## Behavior

- Empty prompt + `TAB`: opens `fzf` picker.
- Non-empty prompt + `TAB`: runs the widget that was previously bound to `TAB`.
- If `fzf` is missing: falls back to the widget that was previously bound to `TAB`.

Selection insertion behavior:
- `command` and `alias`: inserted as-is with trailing space.
- `file` and `directory`: shell-escaped by default.
- `history`: inserted as-is.

## Configuration

Set variables before `source $ZSH/oh-my-zsh.sh` in `~/.zshrc`.

| Variable | Default | Description |
| --- | --- | --- |
| `TAB_START_BINDKEY` | `^I` | Key binding for the widget. Set to `none` to disable auto-binding. |
| `TAB_START_PROMPT` | `tab> ` | `fzf` prompt text. |
| `TAB_START_HEADER` | `TAB on empty prompt...` | Header shown in `fzf`. Supports `\n` and `$'...'` style forms. |
| `TAB_START_INCLUDE_COMMANDS` | `1` | Include command entries. |
| `TAB_START_INCLUDE_ALIASES` | `1` | Include alias entries. |
| `TAB_START_INCLUDE_DIRECTORIES` | `1` | Include cwd directories. |
| `TAB_START_INCLUDE_FILES` | `1` | Include cwd files. |
| `TAB_START_INCLUDE_HISTORY` | `1` | Include history entries. |
| `TAB_START_ESCAPE_PATHS` | `1` | Escape inserted file/directory values with `${(q)...}`. |

Example:

```zsh
TAB_START_BINDKEY='^I'
TAB_START_PROMPT='start> '
TAB_START_HEADER=$'TAB on empty prompt: pick command/alias/path/history\nEsc cancels, Enter inserts'
TAB_START_INCLUDE_COMMANDS=1
TAB_START_INCLUDE_ALIASES=1
TAB_START_INCLUDE_DIRECTORIES=1
TAB_START_INCLUDE_FILES=1
TAB_START_ESCAPE_PATHS=1
TAB_START_INCLUDE_HISTORY=1
```

## Keybinding notes

Disable auto-binding:

```zsh
TAB_START_BINDKEY=none
```

Bind manually after plugin load:

```zsh
zle -N _tab_start_insert
bindkey '^I' _tab_start_insert
```

## Troubleshooting

- Header appears as literal `$'...'`:
  - `TAB_START_HEADER` is normalized internally, but set it before loading Oh My Zsh.
- Picker feels slow:
  - most cost is command enumeration; test with `TAB_START_INCLUDE_COMMANDS=0`.
- `TAB` does not open picker:
  - confirm plugin is in `plugins=(...)`.
  - run `bindkey '^I'` and check it maps to `_tab_start_insert`.

## Performance notes

Sample benchmark (2026-04-18, zsh 5.9, Darwin 25.4.0, 2213 commands, 2 aliases, 8 dirs, 7 files, 30 runs):

| Case | Phase | Avg (ms) | Min (ms) | P95 (ms) | Max (ms) |
| --- | --- | ---:| ---:| ---:| ---:|
| all (commands + aliases + dirs + files) | build | 94.459 | 91.356 | 100.026 | 104.390 |
| all (commands + aliases + dirs + files) | fzf filter | 8.113 | 7.759 | 8.421 | 8.431 |
| commands + aliases | build | 92.687 | 89.946 | 96.877 | 97.049 |
| dirs + files | build | 1.044 | 0.763 | 2.240 | 5.143 |

Most latency comes from command enumeration.

## Development

This repo includes a [Justfile](./Justfile) and pinned tools in [`.tool-versions`](./.tool-versions).
`zsh` is used as a system dependency locally and installed explicitly in CI.

- `just check`: runs syntax and behavior checks.
- `just benchmark`: runs local benchmark cases (defaults to 30 runs).

## License

This project is licensed under the MIT License.
See [LICENSE](./LICENSE).
