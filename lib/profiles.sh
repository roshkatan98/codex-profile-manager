#!/usr/bin/env bash

codexpm_account_ids() {
  local entry
  local -a entries
  read -r -a entries <<< "$CODEX_ACCOUNTS"
  for entry in "${entries[@]}"; do
    printf '%s\n' "${entry%%:*}"
  done
}

codexpm_account_count() {
  codexpm_account_ids | awk 'NF {count++} END {print count + 0}'
}

codexpm_account_path() {
  local wanted="$1" entry id
  local -a entries
  read -r -a entries <<< "$CODEX_ACCOUNTS"
  for entry in "${entries[@]}"; do
    id="${entry%%:*}"
    if [ "$id" = "$wanted" ]; then
      printf '%s\n' "${entry#*:}"
      return 0
    fi
  done
  return 1
}

codexpm_first_account() {
  codexpm_account_ids | head -n 1
}

codexpm_account_exists() {
  codexpm_account_path "$1" >/dev/null 2>&1
}

codexpm_read_active() {
  local active
  active="$(cat "$CODEX_ACTIVE_FILE" 2>/dev/null || true)"
  if ! codexpm_account_exists "$active"; then
    active="$(codexpm_first_account)"
  fi
  printf '%s\n' "$active"
}

codexpm_set_active() {
  local id="$1"
  codexpm_account_exists "$id" || {
    echo "Unknown account: $id" >&2
    echo "Known accounts: $(codexpm_account_ids | xargs)" >&2
    return 1
  }

  mkdir -p "$(dirname "$CODEX_ACTIVE_FILE")"
  printf '%s\n' "$id" > "$CODEX_ACTIVE_FILE"
  chmod 600 "$CODEX_ACTIVE_FILE"
}

codexpm_next_account() {
  local active="$1" first="" previous="" id
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    [ -n "$first" ] || first="$id"
    if [ "$previous" = "$active" ]; then
      printf '%s\n' "$id"
      return 0
    fi
    previous="$id"
  done < <(codexpm_account_ids)
  printf '%s\n' "$first"
}

codexpm_shared_candidates() {
  local spec candidate pattern
  local -a specs
  read -r -a specs <<< "$CODEX_SHARED_ITEMS"
  for spec in "${specs[@]}"; do
    pattern="$CODEX_ORIGINAL_HOME/$spec"
    while IFS= read -r candidate; do
      if [ -e "$candidate" ] || [ -L "$candidate" ]; then
        printf '%s\n' "$candidate"
      fi
    done < <(compgen -G "$pattern" || true)
  done
}

codexpm_is_shared_name() {
  local wanted="$1" candidate
  while IFS= read -r candidate; do
    [ "$(basename "$candidate")" = "$wanted" ] && return 0
  done < <(codexpm_shared_candidates)
  return 1
}

codexpm_profile_marker_path() {
  printf '%s/%s\n' "$1" "$CODEXPM_PROFILE_MARKER"
}

codexpm_write_profile_marker() {
  local id="$1" profile="$2" marker
  marker="$(codexpm_profile_marker_path "$profile")"
  cat > "$marker" <<EOF_MARKER
managed_by=codex-profile-manager
profile_id=$id
original_home=$CODEX_ORIGINAL_HOME
EOF_MARKER
  chmod 600 "$marker"
}

codexpm_profile_is_managed() {
  local id="$1" profile="$2" marker
  marker="$(codexpm_profile_marker_path "$profile")"

  [ -d "$profile" ] || return 1
  [ ! -L "$profile" ] || return 1
  [ -f "$marker" ] || return 1
  [ ! -L "$marker" ] || return 1
  grep -Fqx 'managed_by=codex-profile-manager' "$marker" || return 1
  grep -Fqx "profile_id=$id" "$marker" || return 1
  grep -Fqx "original_home=$CODEX_ORIGINAL_HOME" "$marker" || return 1
}

codexpm_link_shared_state() {
  local profile="$1" candidate name destination
  mkdir -p "$profile"

  while IFS= read -r candidate; do
    name="$(basename "$candidate")"
    [ "$name" != "auth.json" ] || continue
    destination="$profile/$name"

    if [ -L "$destination" ]; then
      if [ "$(readlink -f "$destination")" = "$(readlink -f "$candidate")" ]; then
        continue
      fi
      echo "Refusing to replace unexpected symlink: $destination" >&2
      return 1
    fi

    if [ -e "$destination" ]; then
      echo "Refusing to replace existing profile item: $destination" >&2
      return 1
    fi

    ln -s "$candidate" "$destination"
  done < <(codexpm_shared_candidates)

  chmod 700 "$profile"
}

codexpm_create_profile() {
  local id="$1" profile="$2" copy_auth="${3:-0}"
  local created=0

  codexpm_validate_id "$id" || {
    echo "Invalid account id: $id" >&2
    return 1
  }

  [ ! -e "$profile" ] && [ ! -L "$profile" ] || {
    echo "Profile already exists: $profile" >&2
    return 1
  }

  mkdir -p "$profile"
  created=1
  chmod 700 "$profile"

  if [ "$copy_auth" = "1" ]; then
    [ -f "$CODEX_ORIGINAL_HOME/auth.json" ] || {
      echo "Missing original auth.json: $CODEX_ORIGINAL_HOME/auth.json" >&2
      [ "$created" = "0" ] || rm -rf -- "${profile:?}"
      return 1
    }
    cp -pL "$CODEX_ORIGINAL_HOME/auth.json" "$profile/auth.json"
    chmod 600 "$profile/auth.json"
  fi

  if ! codexpm_link_shared_state "$profile"; then
    [ "$created" = "0" ] || rm -rf -- "${profile:?}"
    return 1
  fi

  codexpm_write_profile_marker "$id" "$profile"
}

codexpm_add_account_to_config() {
  local id="$1" profile="$2" old_accounts target
  codexpm_account_exists "$id" && {
    echo "Account already configured: $id" >&2
    return 1
  }

  old_accounts="$CODEX_ACCOUNTS"
  CODEX_ACCOUNTS="$CODEX_ACCOUNTS $id:$profile"
  CODEX_ACCOUNTS="${CODEX_ACCOUNTS# }"

  if ! codexpm_validate_config; then
    CODEX_ACCOUNTS="$old_accounts"
    return 1
  fi

  target="$(codexpm_config_write_target)"
  if ! codexpm_write_config "$target"; then
    CODEX_ACCOUNTS="$old_accounts"
    return 1
  fi
}

codexpm_remove_account_from_config() {
  local wanted="$1" entry id old_accounts target
  local -a entries remaining=()

  old_accounts="$CODEX_ACCOUNTS"
  read -r -a entries <<< "$CODEX_ACCOUNTS"
  for entry in "${entries[@]}"; do
    id="${entry%%:*}"
    if [ "$id" != "$wanted" ]; then
      remaining+=("$entry")
    fi
  done

  CODEX_ACCOUNTS="${remaining[*]}"
  if ! codexpm_validate_config; then
    CODEX_ACCOUNTS="$old_accounts"
    return 1
  fi

  target="$(codexpm_config_write_target)"
  if ! codexpm_write_config "$target"; then
    CODEX_ACCOUNTS="$old_accounts"
    return 1
  fi
}

codexpm_delete_profile() {
  local id="$1" profile="$2"

  if [ "$profile" = "/" ] || [ "$profile" = "$HOME" ] || [ "$profile" = "$CODEX_ORIGINAL_HOME" ]; then
    echo "Refusing to delete unsafe profile path: $profile" >&2
    return 1
  fi

  case "$profile/" in
    "$CODEX_ORIGINAL_HOME"/*)
      echo "Refusing to delete a profile inside the original Codex home: $profile" >&2
      return 1
      ;;
  esac

  codexpm_profile_is_managed "$id" "$profile" || {
    echo "Refusing to delete an unverified profile directory: $profile" >&2
    return 1
  }

  rm -rf -- "${profile:?}"
}

codexpm_migrate_profile_links() {
  local profile="$1" id="${2:-}" item name target
  [ -d "$profile" ] || return 0
  [ ! -L "$profile" ] || {
    echo "Refusing to migrate symlinked profile directory: $profile" >&2
    return 1
  }

  for item in "$profile"/* "$profile"/.[!.]*; do
    [ -e "$item" ] || [ -L "$item" ] || continue
    name="$(basename "$item")"
    [ "$name" != "auth.json" ] || continue
    [ "$name" != "$CODEXPM_PROFILE_MARKER" ] || continue

    if [ -L "$item" ] && ! codexpm_is_shared_name "$name"; then
      target="$(readlink -f "$item" 2>/dev/null || true)"
      case "$target" in
        "$CODEX_ORIGINAL_HOME"/*) rm -f "$item" ;;
        *) : ;;
      esac
    fi
  done

  codexpm_link_shared_state "$profile"
  if [ -n "$id" ]; then
    codexpm_write_profile_marker "$id" "$profile"
  fi
}
