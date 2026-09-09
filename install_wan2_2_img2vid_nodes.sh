#!/usr/bin/env bash
set -euo pipefail

echo "============================================"
echo " WAN 2.2 Smooth Workflow img2vid"
echo " Custom Nodes Installer"
echo "============================================"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMFYUI_DIR="$SCRIPT_DIR"
CUSTOM_NODES_DIR="$COMFYUI_DIR/custom_nodes"
PYTHON_EXE=""
PY_S_FLAG=""

echo "[1/3]  Locating ComfyUI installation..."
echo " Root         : $COMFYUI_DIR"
echo " custom_nodes : $CUSTOM_NODES_DIR"
echo ""

# ── Detect Python ─────────────────────────────────────────────────────────────
echo "[2/3]  Detecting Python runtime..."
if [ -f "$COMFYUI_DIR/.venv/bin/python" ]; then
    PYTHON_EXE="$COMFYUI_DIR/.venv/bin/python"
    echo " Found: Desktop/venv  (.venv/bin/python)"
elif [ -f "$COMFYUI_DIR/venv/bin/python" ]; then
    PYTHON_EXE="$COMFYUI_DIR/venv/bin/python"
    echo " Found: venv  (venv/bin/python)"
elif [ -f "$COMFYUI_DIR/python_embeded/python" ]; then
    PYTHON_EXE="$COMFYUI_DIR/python_embeded/python"
    PY_S_FLAG="-s"
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
if ! command -v git &>/dev/null; then
    echo " [ERROR] Git not found. Install: sudo apt install git  or  brew install git"
    exit 1
fi

# ── Per-node install function ─────────────────────────────────────────────────
# $1 = repo URL
# $2 = (optional) custom installer script, relative to the node's own folder,
#      to run INSTEAD of the generic requirements.txt pip step. Use this for
#      nodes that ship their own install.py/install.bat and don't provide a
#      plain requirements.txt (e.g. because they need special dependency
#      handling, like CUDA-version-specific cupy wheels).
install_node() {
    local REPO="$1"
    local CUSTOM_INSTALLER="${2:-}"
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

    # Dependency install: a node's own installer (if specified) takes
    # priority over the generic requirements.txt step.
    if [ -n "$CUSTOM_INSTALLER" ] && [ -f "$NODE_DIR/$CUSTOM_INSTALLER" ]; then
        echo "  Running node's own installer ($CUSTOM_INSTALLER)..."
        ( cd "$NODE_DIR" && "$PYTHON_EXE" $PY_S_FLAG "$CUSTOM_INSTALLER" )
    elif [ -f "$NODE_DIR/requirements.txt" ]; then
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

# comfy-mtb          - ColorMatch, Pick From Batch
install_node https://github.com/melMass/comfy_mtb

# rgthree-comfy      - Label, Power Lora Loader, Seed
install_node https://github.com/rgthree/rgthree-comfy

# comfyui-kjnodes    - ImageResizeKJv2
install_node https://github.com/kijai/ComfyUI-KJNodes

# comfyui-easy-use   - easy cleanGpuUsed, easy showAnything
install_node https://github.com/yolain/ComfyUI-Easy-Use

# comfyui-gguf       - UnetLoaderGGUF
install_node https://github.com/city96/ComfyUI-GGUF

# comfyui-videohelpersuite - VHS_VideoCombine
install_node https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite

# comfyui-frame-interpolation - RIFE VFI
# NOTE: this repo ships NO plain requirements.txt (only requirements-no-cupy.txt /
# requirements-with-cupy.txt) and needs a CUDA-version-aware cupy install, so the
# generic pip step above always silently no-ops for it. We run its own install.py
# instead - that's what was causing ComfyUI to fail to import/recognize this node.
install_node https://github.com/Fannovel16/ComfyUI-Frame-Interpolation install.py

# comfyui-mxtoolkit  - mxSlider2D
install_node https://github.com/Smirnov75/ComfyUI-mxToolkit

echo ""
echo "============================================"
echo " All done! Please RESTART ComfyUI now."
echo "============================================"
echo ""
