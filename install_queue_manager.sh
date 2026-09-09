#!/usr/bin/env bash
set -euo pipefail

echo "============================================"
echo " AC ComfyUI Queue Manager | Installer"
echo "============================================"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMFYUI_DIR="$SCRIPT_DIR"
CUSTOM_NODES_DIR="$COMFYUI_DIR/custom_nodes"
NODE_DIR="$CUSTOM_NODES_DIR/ac-comfyui-queue-manager"
REPO_URL="https://github.com/abdullahceylan/ac-comfyui-queue-manager.git"
PYTHON_EXE=""

echo "[1/5]  Locating ComfyUI installation..."
echo " Root         : $COMFYUI_DIR"
echo " custom_nodes : $CUSTOM_NODES_DIR"
echo ""

# ── Detect Python ─────────────────────────────────────────────────────────────
echo "[2/5]  Detecting Python runtime..."
if [ -f "$COMFYUI_DIR/.venv/bin/python" ]; then
    PYTHON_EXE="$COMFYUI_DIR/.venv/bin/python"
    echo " Found: Desktop/venv  (.venv/bin/python)"
elif [ -f "$COMFYUI_DIR/python_embeded/python" ]; then
    PYTHON_EXE="$COMFYUI_DIR/python_embeded/python"
    echo " Found: Portable  (python_embeded/python)"
elif command -v python3 &>/dev/null; then
    PYTHON_EXE="python3"
    echo " [WARN] Using system python3."
elif command -v python &>/dev/null; then
    PYTHON_EXE="python"
    echo " [WARN] Using system python."
else
    echo " [ERROR] No Python found. Is this script in the ComfyUI root folder?"
    exit 1
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
    echo " Repo found - syncing to latest clean state..."
    git -C "$NODE_DIR" fetch --prune
    git -C "$NODE_DIR" reset --hard origin/main
    git -C "$NODE_DIR" clean -fdx
elif [ -d "$NODE_DIR" ]; then
    echo " Stale folder found (no .git) - removing and re-cloning..."
    rm -rf "$NODE_DIR"
    echo " Cloning into: $NODE_DIR"
    git clone "$REPO_URL" "$NODE_DIR"
else
    echo " Cloning into: $NODE_DIR"
    git clone "$REPO_URL" "$NODE_DIR"
fi
echo ""

# ── Install dependencies ──────────────────────────────────────────────────────
echo "[5/5]  Installing Python dependencies..."
if [ -f "$NODE_DIR/requirements.txt" ]; then
    "$PYTHON_EXE" -m pip install -r "$NODE_DIR/requirements.txt" --break-system-packages --no-cache-dir
else
    echo " No requirements.txt - skipping pip install."
fi

# ── Remove all __pycache__ folders and .pyc / .pyo files recursively ──────────
echo ""
echo " Purging __pycache__ and .pyc files..."
find "$NODE_DIR" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find "$NODE_DIR" -type f \( -name "*.pyc" -o -name "*.pyo" \) -delete 2>/dev/null || true

echo ""
echo "============================================"
echo " Done! Restart ComfyUI to activate the node."
echo "============================================"
echo ""
