#!/usr/bin/env zsh

set -euo pipefail

repo_root="${0:A:h}/../.."
plugin_path="${repo_root}/tab-start.plugin.zsh"
fzf_tab_dir="${FZF_TAB_TEST_DIR:-}"

if [[ -z "$fzf_tab_dir" ]]; then
  for candidate in \
    "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fzf-tab" \
    "$HOME/.oh-my-zsh/custom/plugins/fzf-tab"; do
    if [[ -r "$candidate/fzf-tab.zsh" ]]; then
      fzf_tab_dir="$candidate"
      break
    fi
  done
fi

if [[ ! -r "$fzf_tab_dir/fzf-tab.zsh" ||
      ! -r "$fzf_tab_dir/test/comptest" ||
      ! -x "$fzf_tab_dir/test/select" ]]; then
  print -u2 -- "fzf-tab test checkout unavailable; set FZF_TAB_TEST_DIR"
  exit 1
fi

test_root="$(mktemp -d)"
trap 'command rm -rf "$test_root"' EXIT
mkdir -p "$test_root/dir with space"
ln -s 'dir with space' "$test_root/linked dir"
touch "$test_root/script file"
chmod +x "$test_root/script file"
cd "$test_root"

typeset -gr ZTST_testdir="$fzf_tab_dir/test"
source "$fzf_tab_dir/test/comptest"
typeset -gi ZTST_verbose=0
typeset -gi ZTST_fd=2
comptestinit -z "${commands[zsh]:-zsh}"

comptesteval "
source ${(q)plugin_path}
source ${(q)fzf_tab_dir}/fzf-tab.zsh

unalias -m '*' 2>/dev/null || true
alias tab-start-test-alias='echo alias target'

TAB_START_INCLUDE_COMMANDS=0
TAB_START_INCLUDE_ALIASES=1
TAB_START_INCLUDE_DIRECTORIES=1
TAB_START_FILES_MAX_DEPTH=1
TAB_START_INCLUDE_HISTORY=1
TAB_START_ESCAPE_PATHS=1
typeset -gi TAB_START_TEST_PICK=1

zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' menu no
zstyle ':fzf-tab:*' default-color '<LC><C0><RC>'
zstyle ':fzf-tab:*' single-group color header
zstyle ':fzf-tab:*' group-colors '<LC><C1><RC>' '<LC><C2><RC>' '<LC><C3><RC>' '<LC><C4><RC>'

_tab_start_test_select() {
  print -r -u2 -- \"<MESSAGE>groups=\${(j:,:)_ftb_groups}</MESSAGE>\"
  ${(q)fzf_tab_dir}/test/select -n \"\$TAB_START_TEST_PICK\" -h \"\$#_ftb_headers\" -q \"\$_ftb_query\"
}
zstyle ':fzf-tab:*' debug-command _tab_start_test_select

_tab_start_test_complete_report() {
  local -A history=(
    2 'echo newest \"two words\"'
  )

  print -lr '<WIDGET><fzf-tab-complete>'
  zle fzf-tab-complete 2>&1
  print -lr - \"<LBUFFER>\$LBUFFER</LBUFFER>\" \"<RBUFFER>\$RBUFFER</RBUFFER>\"
  zle clear-screen
  zle -R
}
zle -N _tab_start_test_complete_report
bindkey '^I' _tab_start_test_complete_report
"

run_case() {
  local pick="$1"
  local escape_paths="$2"
  local expected_line="$3"
  local output

  comptesteval "TAB_START_TEST_PICK=$pick; TAB_START_ESCAPE_PATHS=$escape_paths"
  output="$(comptest $'\t')"
  [[ "$output" == *"line: {${expected_line}}{}"* ]]
  [[ "$output" == *'MESSAGE:{groups=alias,dir,script,history}'* ]]
  [[ "$output" == *'C2:{·dir  dir with space/}'* ]]
  [[ "$output" == *'C2:{·dir  linked dir/ -> dir with space}'* ]]
  [[ "$output" == *'C3:{·script  script file}'* ]]
}

run_case 1 1 'tab-start-test-alias '
run_case 2 1 'dir\ with\ space/'
run_case 3 1 'linked\ dir/'
run_case 4 1 'script\ file'
run_case 5 1 'echo newest "two words"'
run_case 4 0 'script file'

zpty -d zsh
