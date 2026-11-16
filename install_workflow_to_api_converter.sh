#!/usr/bin/env bash
set -euo pipefail

echo "======================================================"
echo " ComfyUI Workflow-to-API Converter | Installer"
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
NODE_DIR="$CUSTOM_NODES_DIR/comfyui-workflow-to-api-converter-endpoint"
REPO_URL="https://github.com/SethRobinson/comfyui-workflow-to-api-converter-endpoint.git"
PYTHON_EXE=""
PY_S_FLAG=""

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

# ── Install dependencies (optional - not required) ────────────────────────────
echo "[5/5]  Installing Python dependencies..."
if [ -f "$NODE_DIR/requirements.txt" ]; then
    "$PYTHON_EXE" -m pip install -r "$NODE_DIR/requirements.txt" --break-system-packages --no-cache-dir || \
        echo " [WARN] pip install failed - continuing anyway (requirements.txt is not required)."
else
    echo " No requirements.txt found - skipping pip install (not required)."
fi

# ── Remove all __pycache__ folders and .pyc / .pyo files recursively ──────────
echo ""
echo " Purging __pycache__ and .pyc files..."
find "$NODE_DIR" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find "$NODE_DIR" -type f \( -name "*.pyc" -o -name "*.pyo" \) -delete 2>/dev/null || true

echo ""
echo "======================================================"
echo " Done! Restart ComfyUI to activate the node."
echo "======================================================"
echo ""
