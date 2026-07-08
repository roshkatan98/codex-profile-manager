
# Codex smart wrapper - shell only, original binary untouched
# Requires codex_smart and codex_switch to be installed in PATH.
codex() {
  command codex_smart "$@"
}

codexr() {
  command codex_smart "$@"
}

# Optional shorter aliases. Remove these if you do not want them.
alias codex_status='codex_smart status'
alias codex_toggle='codex_switch'
