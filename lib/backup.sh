#!/usr/bin/env bash

codexpm_backup_home() {
  local skip="${1:-0}" size_kb free_kb required_kb stamp destination

  [ "$skip" != "1" ] || {
    echo "Backup skipped by request."
    return 0
  }

  [ -d "$CODEX_ORIGINAL_HOME" ] || {
    echo "Original Codex home does not exist: $CODEX_ORIGINAL_HOME" >&2
    return 1
  }

  mkdir -p "$CODEX_BACKUP_DIR"
  size_kb="$(du -sk "$CODEX_ORIGINAL_HOME" | awk '{print $1}')"
  free_kb="$(df -Pk "$CODEX_BACKUP_DIR" | awk 'NR==2 {print $4}')"
  required_kb=$((size_kb + size_kb / 10 + 1024))

  if [ "$free_kb" -lt "$required_kb" ]; then
    cat >&2 <<EOF_SPACE
Not enough free space for a safe backup.
Codex home size: ${size_kb} KB
Required free space: ${required_kb} KB
Available free space: ${free_kb} KB
Backup directory: $CODEX_BACKUP_DIR

Set CODEX_BACKUP_DIR to another disk, or rerun with --skip-backup only after making your own backup.
EOF_SPACE
    return 1
  fi

  stamp="$(date +%Y%m%d_%H%M%S)"
  destination="$CODEX_BACKUP_DIR/codex-home.$stamp"
  cp -a "$CODEX_ORIGINAL_HOME" "$destination"
  echo "Backup created: $destination"
}
