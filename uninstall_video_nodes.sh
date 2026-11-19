#!/usr/bin/env bash
set -euo pipefail

echo "============================================"
echo " SmoothMix Wan 2.2 - Custom Nodes Uninstaller"
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

# Pass -y / --yes to skip the confirmation prompt.
AUTO_YES=0
case "${1:-}" in
    -y|--yes) AUTO_YES=1 ;;
esac

REMOVED=0
SKIPPED=0
FAILED=0

# ── Nodes to remove (same repos as the installer) ─────────────────────────────
NODES=(
    https://github.com/Alectriciti/comfyui-adaptiveprompts
    https://github.com/melMass/comfy_mtb
    https://github.com/rgthree/rgthree-comfy
    https://github.com/kijai/ComfyUI-MMAudio
    https://github.com/kijai/ComfyUI-WanVideoWrapper
    https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite
    https://github.com/GACLove/ComfyUI-VFI
    https://github.com/kijai/ComfyUI-KJNodes
    https://github.com/yolain/ComfyUI-Easy-Use
    https://github.com/scottmudge/ComfyUI-NAG
    https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes
    https://github.com/city96/ComfyUI-GGUF
    https://github.com/Smirnov75/ComfyUI-mxToolkit
)

# true if the path exists (also true for a broken symlink)
present() { [ -e "$1" ] || [ -L "$1" ]; }

# ── Delete one folder and count the result ────────────────────────────────────
delete_dir() {
    local TARGET="$1"
    present "$TARGET" || return 0
    echo "  Removing $TARGET ..."
    rm -rf "$TARGET" 2>/dev/null || true
    if present "$TARGET"; then
        echo "  [ERROR] Could not remove it - check permissions / close ComfyUI, then retry."
        FAILED=$((FAILED + 1))
    else
        echo "  Removed."
        REMOVED=$((REMOVED + 1))
    fi
}

# ── Per-node remove function ──────────────────────────────────────────────────
remove_node() {
    local REPO="$1"
    local FNAME
    FNAME="$(basename "$REPO" .git)"
    # Safety: never operate on custom_nodes itself
    if [ -z "$FNAME" ]; then
        echo "  [ERROR] Could not work out the folder name for $REPO - skipping."
        FAILED=$((FAILED + 1))
        return 0
    fi
    local NODE_DIR="$CUSTOM_NODES_DIR/$FNAME"

    echo ""
    echo "── $FNAME"

    # Not installed (neither the normal nor the ComfyUI-Manager ".disabled" folder)
    if ! present "$NODE_DIR" && ! present "$NODE_DIR.disabled"; then
        echo "  Not installed - skipping."
        SKIPPED=$((SKIPPED + 1))
        return 0
    fi

    delete_dir "$NODE_DIR"
    delete_dir "$NODE_DIR.disabled"
}

echo "[1/3]  Locating ComfyUI installation..."
echo " Root         : $COMFYUI_DIR"
echo " custom_nodes : $CUSTOM_NODES_DIR"
echo ""
if [ ! -d "$CUSTOM_NODES_DIR" ]; then
    echo " [ERROR] custom_nodes folder not found. Is this script next to the ComfyUI folder?"
    exit 1
fi

# ── Confirmation ──────────────────────────────────────────────────────────────
echo "[2/3]  These custom node folders will be DELETED (if present):"
for REPO in "${NODES[@]}"; do
    echo "   - $(basename "$REPO" .git)"
done
echo ""
echo " NOTE: other workflows may depend on some of these nodes."
echo "       Python packages installed in the environment are NOT removed."
echo "       Close ComfyUI before continuing."
echo ""
if [ "$AUTO_YES" -ne 1 ]; then
    CONFIRM=""
    read -r -p " Type Y to continue (anything else cancels): " CONFIRM || CONFIRM=""
    case "$CONFIRM" in
        y|Y) ;;
        *)
            echo ""
            echo " Cancelled - nothing was removed."
            exit 0
            ;;
    esac
fi
echo ""

# ── Remove each node ──────────────────────────────────────────────────────────
echo "[3/3]  Removing custom nodes..."
for REPO in "${NODES[@]}"; do
    remove_node "$REPO"
done

echo ""
echo "============================================"
echo " Done!  Removed: $REMOVED  |  Not installed: $SKIPPED"
if [ "$FAILED" -gt 0 ]; then
    echo " [WARN] Some folders could not be removed - see messages above."
fi
echo " Please RESTART ComfyUI now."
echo "============================================"
echo ""
if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
