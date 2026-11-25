#!/usr/bin/env bash
set -euo pipefail

# ── Launch helper ─────────────────────────────────────────────────────────────
# A file-manager double-click can run a script with no terminal and no usable
# output, so it either dies silently or you can't see what happened. Here:
#   1) no terminal  -> re-open this script inside a terminal window
#                      (the window stays open at the end so you can read it)
#   2) none found   -> write all output to a .log file next to the script
shopt -s execfail
if [ ! -t 0 ] && [ ! -t 1 ] && [ -z "${AC_IN_TERMINAL:-}" ]; then
    _SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
    if [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
        export AC_IN_TERMINAL=1
        for _T in konsole gnome-terminal xfce4-terminal mate-terminal lxterminal xterm x-terminal-emulator; do
            command -v "$_T" >/dev/null 2>&1 || continue
            case "$_T" in
                gnome-terminal)               exec "$_T" -- bash "$_SELF" "$@" ;;
                xfce4-terminal|mate-terminal) exec "$_T" -x bash "$_SELF" "$@" ;;
                *)                            exec "$_T" -e bash "$_SELF" "$@" ;;
            esac
        done
        unset AC_IN_TERMINAL
    fi
    exec >>"${_SELF%.sh}.log" 2>&1
fi
if [ -n "${AC_IN_TERMINAL:-}" ]; then
    trap 'echo ""; read -r -s -n 1 -p " Press any key to close this window..." _ || true; echo ""' EXIT
fi

echo "======================================================"
echo " ComfyUI-Crystools | Installer"
echo "======================================================"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# This script lives ONE LEVEL ABOVE the real ComfyUI folder (which holds custom_nodes/).
if [ -d "$SCRIPT_DIR/ComfyUI/custom_nodes" ] || [ -f "$SCRIPT_DIR/ComfyUI/main.py" ]; then
    COMFYUI_DIR="$SCRIPT_DIR/ComfyUI"
else
    COMFYUI_DIR="$SCRIPT_DIR"   # fallback: script was placed inside the ComfyUI folder
fi
CUSTOM_NODES_DIR="$COMFYUI_DIR/custom_nodes"
NODE_DIR="$CUSTOM_NODES_DIR/ComfyUI-Crystools"
REPO_URL="https://github.com/crystian/ComfyUI-Crystools.git"
PYTHON_EXE=""
PY_S_FLAG=""
NODE_STATUS=""
DEPS_STATUS="not attempted"
INSTALLED=0
UPTODATE=0
ENABLED=0
FAILED=0

# Pass -f / --force to reinstall even if the node is already up to date.
FORCE=0
case "${1:-}" in
    -f|--force) FORCE=1 ;;
esac

echo "[1/5]  Locating ComfyUI installation..."
echo " Root         : $COMFYUI_DIR"
echo " custom_nodes : $CUSTOM_NODES_DIR"
echo ""
if [ ! -d "$CUSTOM_NODES_DIR" ]; then
    echo " [ERROR] custom_nodes folder not found. Is this script next to the ComfyUI folder?"
    exit 1
fi

# ── Detect Python ─────────────────────────────────────────────────────────────
echo "[2/5]  Detecting Python runtime..."
for ROOT in "$SCRIPT_DIR" "$COMFYUI_DIR"; do
    if [ -f "$ROOT/.venv/bin/python" ]; then
        PYTHON_EXE="$ROOT/.venv/bin/python"
        echo " Found: Desktop/venv  ($ROOT/.venv/bin/python)"
        break
    elif [ -f "$ROOT/venv/bin/python" ]; then
        PYTHON_EXE="$ROOT/venv/bin/python"
        echo " Found: venv  ($ROOT/venv/bin/python)"
        break
    elif [ -f "$ROOT/python_embeded/python" ]; then
        PYTHON_EXE="$ROOT/python_embeded/python"
        PY_S_FLAG="-s"
        echo " Found: Portable  ($ROOT/python_embeded/python)"
        break
    fi
done
if [ -z "$PYTHON_EXE" ]; then
    if command -v python3 &>/dev/null; then
        PYTHON_EXE="python3"
        echo " [WARN] Using system python3."
    elif command -v python &>/dev/null; then
        PYTHON_EXE="python"
        echo " [WARN] Using system python."
    else
        echo " [ERROR] No Python found. Is this script next to the ComfyUI folder?"
        exit 1
    fi
fi
echo ""

# ── Check Git ─────────────────────────────────────────────────────────────────
echo "[3/5]  Checking for Git..."
if ! command -v git &>/dev/null; then
    echo " [ERROR] Git not found. Install: sudo apt install git  or  brew install git"
    exit 1
fi
echo " Found: $(git --version)"
echo ""

# ── Clone / update / repair ───────────────────────────────────────────────────
echo "[4/5]  Installing custom node..."
echo ""
# ── Re-enable a disabled copy instead of keeping a duplicate ──────────────────
# Looks for custom_nodes/.disabled/<name> and custom_nodes/<name>.disabled
# (ComfyUI-Manager's two ways of disabling a node). A disabled copy is moved back
# to custom_nodes; if an active copy already exists, the disabled duplicate is removed.
restore_disabled() {
    local FNAME="$1"
    local NODE_DIR="$CUSTOM_NODES_DIR/$FNAME"
    local DIS
    local RC=0
    for DIS in "$CUSTOM_NODES_DIR/.disabled/$FNAME" "$NODE_DIR.disabled"; do
        if [ -e "$DIS" ] || [ -L "$DIS" ]; then
            if [ -e "$NODE_DIR" ] || [ -L "$NODE_DIR" ]; then
                echo "  Disabled duplicate found ($DIS) - active copy exists, removing the duplicate..."
                if ! rm -rf "$DIS"; then
                    echo "  [ERROR] Could not remove the disabled duplicate."
                    RC=1
                fi
            else
                echo "  Found disabled copy ($DIS) - moving it back to custom_nodes..."
                if mv "$DIS" "$NODE_DIR"; then
                    ENABLED=$((ENABLED + 1))
                else
                    echo "  [ERROR] Could not move the disabled copy back."
                    RC=1
                fi
            fi
        fi
    done
    return $RC
}


if ! restore_disabled "$(basename "$NODE_DIR")"; then
    NODE_STATUS="failed"
fi
if [ "$NODE_STATUS" = "failed" ]; then
    :   # could not re-enable the disabled copy - skip
elif [ -d "$NODE_DIR/.git" ]; then
    echo " Repo found - checking for updates..."
    if ! git -C "$NODE_DIR" fetch --prune; then
        echo " [ERROR] git fetch failed - could not check for updates."
        NODE_STATUS="failed"
    else
        # Compare against the upstream branch; fall back to origin/HEAD, then origin/main
        REMOTE_REF="@{u}"
        git -C "$NODE_DIR" rev-parse --verify --quiet "$REMOTE_REF" >/dev/null 2>&1 || REMOTE_REF="origin/HEAD"
        git -C "$NODE_DIR" rev-parse --verify --quiet "$REMOTE_REF" >/dev/null 2>&1 || REMOTE_REF="origin/main"
        LOCAL_SHA="$(git -C "$NODE_DIR" rev-parse HEAD 2>/dev/null || true)"
        REMOTE_SHA="$(git -C "$NODE_DIR" rev-parse "$REMOTE_REF" 2>/dev/null || true)"
        if [ "$FORCE" -ne 1 ] && [ -n "$LOCAL_SHA" ] && [ "$LOCAL_SHA" = "$REMOTE_SHA" ] \
           && git -C "$NODE_DIR" diff --quiet HEAD 2>/dev/null; then
            echo " Already up to date - skipping."
            NODE_STATUS="uptodate"
        else
            echo " Update available or repair needed - syncing to latest clean state..."
            NODE_STATUS="updated"
            git -C "$NODE_DIR" reset --hard "$REMOTE_REF" || NODE_STATUS="update_failed"
            git -C "$NODE_DIR" clean -fdx || true
            if [ "$NODE_STATUS" = "update_failed" ]; then
                echo " [ERROR] git sync failed - node may be outdated."
            fi
        fi
    fi
else
    if [ -d "$NODE_DIR" ]; then
        echo " Stale folder found (no .git) - removing and re-cloning..."
        if ! rm -rf "$NODE_DIR"; then
            echo " [ERROR] Cannot remove $NODE_DIR - close any programs using it."
            NODE_STATUS="failed"
        fi
    fi
    if [ "$NODE_STATUS" != "failed" ]; then
        echo " Cloning into: $NODE_DIR"
        if git clone "$REPO_URL" "$NODE_DIR"; then
            NODE_STATUS="installed"
        else
            echo " [ERROR] git clone failed. Check your internet connection."
            NODE_STATUS="failed"
        fi
    fi
fi
echo ""

# ── Install dependencies (only when the node was installed or updated) ───────
if [ "$NODE_STATUS" = "uptodate" ]; then
    echo "[5/5]  Dependencies skipped - already up to date."
    DEPS_STATUS="skipped - already up to date"
elif [ "$NODE_STATUS" != "failed" ]; then
    echo "[5/5]  Installing Python dependencies..."
    if [ -f "$NODE_DIR/requirements.txt" ]; then
        if "$PYTHON_EXE" $PY_S_FLAG -m pip install -r "$NODE_DIR/requirements.txt" --break-system-packages --no-cache-dir; then
            DEPS_STATUS="installed"
        else
            echo " [WARN] pip install failed - the node may not work until the requirements are installed."
            DEPS_STATUS="FAILED - see messages above"
        fi
    else
        echo " No requirements.txt found - skipping pip install."
        DEPS_STATUS="none needed"
    fi
fi

# ── Remove all __pycache__ folders and .pyc / .pyo files recursively ──────────
if [ "$NODE_STATUS" != "failed" ] && [ "$NODE_STATUS" != "uptodate" ]; then
    echo ""
    echo " Purging __pycache__ and .pyc files..."
    find "$NODE_DIR" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    find "$NODE_DIR" -type f \( -name "*.pyc" -o -name "*.pyo" \) -delete 2>/dev/null || true
fi

case "$NODE_STATUS" in
    installed|updated)    INSTALLED=1 ;;
    uptodate)             UPTODATE=1 ;;
    failed|update_failed) FAILED=1 ;;
esac

echo ""
echo "======================================================"
echo " Summary"
echo "======================================================"
echo " Installed    : $INSTALLED"
echo " Up to date   : $UPTODATE"
if [ "$ENABLED" -gt 0 ]; then
    echo " Re-enabled   : $ENABLED"
fi
echo " Dependencies : $DEPS_STATUS"
echo "======================================================"
if [ "$FAILED" -gt 0 ]; then
    echo " Install did not complete - see messages above."
elif [ "$ENABLED" -gt 0 ]; then
    echo " Node re-enabled - restart ComfyUI to activate it."
elif [ "$UPTODATE" -gt 0 ]; then
    echo " Already up to date - nothing was changed."
else
    echo " Done! Restart ComfyUI to activate the node."
fi
echo "======================================================"
echo ""
if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
