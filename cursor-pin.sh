#!/bin/bash
set -euo pipefail

DB="${CURSOR_STATE_DB:-$HOME/Library/Application Support/Cursor/User/globalStorage/state.vscdb}"
APP_USER_KEY="src.vs.platform.reactivestorage.browser.reactiveStorageServiceImpl.persistentStorage.applicationUser"

BASE_URL="${CURSOR_OPENAI_BASE_URL:-http://localhost:8317/v1}"
API_KEY="${CURSOR_OPENAI_API_KEY:-cursor-only}"
MODEL_ALIAS_FOR_CURSOR="${CURSOR_OPENAI_MODEL_ALIAS:-gpt-4o-mini}"

LOCK_DIR="${CURSOR_PIN_LOCK_DIR:-$HOME/.cursor-openai-proxy-pin.lock}"

log() { printf "%s %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { log "missing dependency: $1"; exit 1; }
}

acquire_lock() {
  local pid_file="$LOCK_DIR/pid"

  if mkdir "$LOCK_DIR" 2>/dev/null; then
    printf "%s" "$$" >"$pid_file" 2>/dev/null || true
    trap 'rm -rf "$LOCK_DIR" 2>/dev/null || true' EXIT
    return 0
  fi

  if [ -f "$pid_file" ]; then
    local pid
    pid="$(cat "$pid_file" 2>/dev/null || true)"
    if [ "$pid" = "$$" ]; then
      return 0
    fi
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      return 1
    fi

    log "stale lock detected, clearing: $LOCK_DIR"
    rm -rf "$LOCK_DIR" 2>/dev/null || true
    if mkdir "$LOCK_DIR" 2>/dev/null; then
      printf "%s" "$$" >"$pid_file" 2>/dev/null || true
      trap 'rm -rf "$LOCK_DIR" 2>/dev/null || true' EXIT
      return 0
    fi
  else
    log "lock without pid detected, clearing: $LOCK_DIR"
    rm -rf "$LOCK_DIR" 2>/dev/null || true
    if mkdir "$LOCK_DIR" 2>/dev/null; then
      printf "%s" "$$" >"$pid_file" 2>/dev/null || true
      trap 'rm -rf "$LOCK_DIR" 2>/dev/null || true' EXIT
      return 0
    fi
  fi

  return 1
}

pin_once() {
  [ -f "$DB" ] || { log "Cursor DB not found: $DB"; return 2; }

  # Ensure expected tables exist.
  local tables
  tables="$(sqlite3 "$DB" ".tables" 2>/dev/null || true)"
  if ! printf "%s" "$tables" | grep -q "ItemTable"; then
    log "Cursor DB missing ItemTable: $DB"
    return 3
  fi

  # Force Cursor to use local OpenAI-compatible proxy.
  python3 - "$DB" "$APP_USER_KEY" "$BASE_URL" "$API_KEY" "$MODEL_ALIAS_FOR_CURSOR" <<'PY'
import json
import subprocess
import sys
import urllib.request

db, app_user_key, base_url, api_key, model_alias_for_cursor = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]

def q(sql: str) -> str:
  return subprocess.check_output(["sqlite3", db, sql]).decode("utf-8")

def esc_sql_str(s: str) -> str:
  return s.replace("'", "''")

def set_kv(key: str, value: str) -> None:
  subprocess.check_call([
    "sqlite3",
    db,
    "insert or replace into ItemTable(key,value) values("
    f"'{esc_sql_str(key)}','{esc_sql_str(value)}');",
  ])

def get_json(key: str) -> dict:
  raw = q(f"select value from ItemTable where key='{esc_sql_str(key)}';")
  return json.loads(raw) if raw.strip() else {}

def set_json(key: str, obj: dict) -> None:
  set_kv(key, json.dumps(obj, separators=(",", ":")))

def fetch_models(base_url: str) -> list[str]:
  # base_url is expected like http://localhost:8317/v1
  url = base_url.rstrip("/") + "/models"
  try:
    with urllib.request.urlopen(url, timeout=2) as r:
      data = json.load(r)
    models = [m.get("id") for m in data.get("data", []) if isinstance(m, dict) and m.get("id")]
    # Keep stable ordering.
    return sorted(set(models))
  except Exception:
    return []

# 1) Always ensure an OpenAI key exists (Cursor may clear it while running).
set_kv("cursorAuth/openAIKey", api_key)

# 2) Force base URL + enable using OpenAI key.
app = get_json(app_user_key)
app["openAIBaseUrl"] = base_url
app["useOpenAIKey"] = True

# 3) Make Cursor less likely to pick unsupported models when using the proxy.
models = fetch_models(base_url)
# Cursor may enforce plan gating by model name even when using an API key.
# Use a "safe" OpenAI model alias that Cursor accepts (e.g. gpt-4o-mini) and let the local
# compat proxy translate it to a real upstream model.
app["availableAPIKeyModels"] = [model_alias_for_cursor]

def force_model(model_name: str) -> None:
  app.setdefault("aiSettings", {})
  app["aiSettings"]["composerModel"] = model_name
  app["aiSettings"]["cmdKModel"] = model_name
  app["aiSettings"]["backgroundComposerModel"] = model_name
  app["aiSettings"].setdefault("modelConfig", {})
  for feature in ["composer", "cmd-k", "background-composer", "plan-execution", "spec", "deep-search", "quick-agent"]:
    app["aiSettings"]["modelConfig"].setdefault(feature, {})
    app["aiSettings"]["modelConfig"][feature]["modelName"] = model_name
    app["aiSettings"]["modelConfig"][feature]["maxMode"] = False

force_model(model_alias_for_cursor)

set_json(app_user_key, app)
PY
}

daemon() {
  local interval="${1:-3}"
  while true; do
    if acquire_lock; then
      pin_once || true
    fi
    sleep "$interval"
  done
}

usage() {
  cat <<EOF
Usage:
  $(basename "$0") --once
  $(basename "$0") --daemon [interval_seconds]

Env:
  CURSOR_STATE_DB=...                 (default: $DB)
  CURSOR_OPENAI_BASE_URL=...          (default: $BASE_URL)
  CURSOR_OPENAI_API_KEY=...           (default: $API_KEY)
  CURSOR_OPENAI_MODEL_ALIAS=...       (default: $MODEL_ALIAS_FOR_CURSOR)
EOF
}

main() {
  need_cmd sqlite3
  need_cmd python3

  case "${1:-}" in
    --once)
      acquire_lock || exit 0
      pin_once
      ;;
    --daemon)
      shift || true
      daemon "${1:-3}"
      ;;
    *)
      usage
      exit 2
      ;;
  esac
}

main "$@"
