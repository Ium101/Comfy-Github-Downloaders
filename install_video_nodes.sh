#!/usr/bin/env bash
set -euo pipefail

echo "============================================"
echo " SmoothMix Wan 2.2 - Custom Nodes Installer"
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
PYTHON_EXE=""
PY_S_FLAG=""

echo "[1/3]  Locating ComfyUI installation..."
echo " Root         : $COMFYUI_DIR"
echo " custom_nodes : $CUSTOM_NODES_DIR"
echo ""

# ── Detect Python ─────────────────────────────────────────────────────────────
echo "[2/3]  Detecting Python runtime..."
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
if ! command -v git &>/dev/null; then
    echo " [ERROR] Git not found. Install: sudo apt install git  or  brew install git"
    exit 1
fi

# ── Per-node install function ─────────────────────────────────────────────────
install_node() {
    local REPO="$1"
    local FNAME
    FNAME="$(basename "$REPO")"
    local NODE_DIR="$CUSTOM_NODES_DIR/$FNAME"

    echo ""
    echo "── $FNAME"

    # Case A: valid git repo → sync to clean latest
    if [ -d "$NODE_DIR/.git" ]; then
        echo "  Repo found - syncing to latest clean state..."
        git -C "$NODE_DIR" fetch --prune
        git -C "$NODE_DIR" reset --hard origin/main
        git -C "$NODE_DIR" clean -fdx

    # Case B: stale folder, no .git → remove and re-clone
    elif [ -d "$NODE_DIR" ]; then
        echo "  Stale folder found (no .git) - removing and re-cloning..."
        rm -rf "$NODE_DIR"
        echo "  Cloning..."
        git clone --depth=1 "$REPO" "$NODE_DIR"

    # Case C: fresh clone
    else
        echo "  Cloning..."
        git clone --depth=1 "$REPO" "$NODE_DIR"
    fi

    # pip install
    if [ -f "$NODE_DIR/requirements.txt" ]; then
        echo "  Installing requirements..."
        "$PYTHON_EXE" -m pip install -r "$NODE_DIR/requirements.txt" --quiet --break-system-packages --no-cache-dir
    else
        echo "  No requirements.txt - skipping pip."
    fi

    # Purge __pycache__ and bytecode files (all paths, every run)
    echo "  Purging __pycache__ and .pyc files..."
    find "$NODE_DIR" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    find "$NODE_DIR" -type f \( -name "*.pyc" -o -name "*.pyo" \) -delete 2>/dev/null || true
}

# ── Install each node ─────────────────────────────────────────────────────────
echo "[3/3]  Installing custom nodes..."

install_node https://github.com/Alectriciti/comfyui-adaptiveprompts
install_node https://github.com/melMass/comfy_mtb
install_node https://github.com/rgthree/rgthree-comfy
install_node https://github.com/kijai/ComfyUI-MMAudio
install_node https://github.com/kijai/ComfyUI-WanVideoWrapper
install_node https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite
install_node https://github.com/GACLove/ComfyUI-VFI
install_node https://github.com/kijai/ComfyUI-KJNodes
install_node https://github.com/yolain/ComfyUI-Easy-Use
install_node https://github.com/scottmudge/ComfyUI-NAG
install_node https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes
install_node https://github.com/city96/ComfyUI-GGUF
install_node https://github.com/Smirnov75/ComfyUI-mxToolkit

echo ""
echo "============================================"
echo " All done! Please RESTART ComfyUI now."
echo "============================================"
echo ""
