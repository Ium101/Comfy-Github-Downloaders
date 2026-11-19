#!/usr/bin/env bash
set -euo pipefail

echo "============================================"
echo " AC ComfyUI Queue Manager | Installer"
echo "============================================"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# This script lives ONE LEVEL ABOVE the real ComfyUI folder (which holds custom_nodes/).
if [ -d "$SCRIPT_DIR/ComfyUI/custom_nodes" ] || [ -f "$SCRIPT_DIR/ComfyUI/main.py" ]; then
    COMFYUI_DIR="$SCRIPT_DIR/ComfyUI"
else
    COMFYUI_DIR="$SCRIPT_DIR"   # fallback: script was placed inside the ComfyUI folder
fi
CUSTOM_NODES_DIR="$COMFYUI_DIR/custom_nodes"
NODE_DIR="$CUSTOM_NODES_DIR/ac-comfyui-queue-manager"
REPO_URL="https://github.com/abdullahceylan/ac-comfyui-queue-manager.git"
PYTHON_EXE=""
PY_S_FLAG=""
NODE_STATUS=""
DEPS_STATUS="not attempted"
INSTALLED=0
UPTODATE=0
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
if [ -d "$NODE_DIR/.git" ]; then
    echo " Repo found - checking for updates..."
    if ! git -C "$NODE_DIR" fetch --prune; then
        echo " [ERROR] git fetch failed - could not check for updates."
        NODE_STATUS="failed"
    else
        REMOTE_REF="@{u}"
        git -C "$NODE_DIR" rev-parse --verify --quiet "@{u}" >/dev/null 2>&1 || REMOTE_REF="origin/main"
        LOCAL_SHA="$(git -C "$NODE_DIR" rev-parse HEAD 2>/dev/null || true)"
        REMOTE_SHA="$(git -C "$NODE_DIR" rev-parse "$REMOTE_REF" 2>/dev/null || true)"
        if [ "$FORCE" -ne 1 ] && [ -n "$LOCAL_SHA" ] && [ "$LOCAL_SHA" = "$REMOTE_SHA" ]            && git -C "$NODE_DIR" diff --quiet HEAD 2>/dev/null; then
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
            echo " [ERROR] git clone failed."
            NODE_STATUS="failed"
        fi
    fi
fi
echo ""

# ── Install dependencies ──────────────────────────────────────────
if [ "$NODE_STATUS" = "uptodate" ]; then
    echo "[5/5]  Dependencies skipped - already up to date."
    DEPS_STATUS="skipped - already up to date"
elif [ "$NODE_STATUS" != "failed" ]; then
    echo "[5/5]  Installing Python dependencies..."
    if [ -f "$NODE_DIR/requirements.txt" ]; then
        if "$PYTHON_EXE" -m pip install -r "$NODE_DIR/requirements.txt" --break-system-packages --no-cache-dir; then
            DEPS_STATUS="installed"
        else
            echo " [ERROR] pip install failed."
            DEPS_STATUS="FAILED"
            NODE_STATUS="failed"
        fi
    else
        echo " No requirements.txt - skipping pip install."
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
echo "============================================"
echo " Summary"
echo "============================================"
echo " Installed    : $INSTALLED"
echo " Up to date   : $UPTODATE"
echo " Dependencies : $DEPS_STATUS"
echo "============================================"
if [ "$FAILED" -gt 0 ]; then
    echo " Install did not complete - see messages above."
elif [ "$UPTODATE" -gt 0 ]; then
    echo " Already up to date - nothing was changed."
else
    echo " Done! Restart ComfyUI to activate the node."
fi
echo "============================================"
echo ""
if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
