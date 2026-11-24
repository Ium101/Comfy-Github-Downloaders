#!/usr/bin/env bash
# ============================================================
#  Removes ComfyUI-Crystools from custom_nodes (including any
#  disabled copy). Place this file in the folder that contains
#  "custom_nodes", or one level above it.
#  Python packages are NOT removed, since other nodes may use them.
# ============================================================
set -u

NODE_NAME="ComfyUI-Crystools"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REMOVED=0
HAD_ERROR=0

echo "============================================================"
echo "  ComfyUI-Crystools Uninstaller"
echo "============================================================"
echo

# ---------- Locate custom_nodes ----------
NODES_DIR=""
for c in "$SCRIPT_DIR/custom_nodes" "$SCRIPT_DIR/ComfyUI/custom_nodes"; do
    if [ -d "$c" ]; then
        NODES_DIR="$c"
        break
    fi
done
if [ -z "$NODES_DIR" ]; then
    echo "[ERROR] custom_nodes folder not found next to this script."
    echo "        Put this .sh in the folder that contains custom_nodes"
    echo "        (or one level above it)."
    echo
    exit 1
fi

NODE_DIR="$NODES_DIR/$NODE_NAME"
DISABLED_A="$NODES_DIR/.disabled/$NODE_NAME"
DISABLED_B="$NODES_DIR/$NODE_NAME.disabled"

echo "[INFO] Make sure ComfyUI is closed before continuing."
echo

remove_path() {
    local p="$1"
    if [ ! -e "$p" ] && [ ! -L "$p" ]; then
        return
    fi
    echo "[INFO] Removing $p ..."
    rm -rf -- "$p"
    if [ -e "$p" ] || [ -L "$p" ]; then
        echo "[ERROR] Could not remove it. Check permissions and try again."
        HAD_ERROR=1
    else
        echo "[OK] Removed."
        REMOVED=$((REMOVED + 1))
    fi
}

remove_path "$NODE_DIR"
remove_path "$DISABLED_A"
remove_path "$DISABLED_B"

NOT_FOUND=0
if [ "$REMOVED" -eq 0 ] && [ "$HAD_ERROR" -eq 0 ]; then
    NOT_FOUND=1
    echo "[OK] $NODE_NAME is not installed, nothing to remove."
fi

echo
echo "============================================================"
echo "  Summary"
echo "============================================================"
echo "  Removed:       $REMOVED"
echo "  Not installed: $NOT_FOUND"
echo "============================================================"
echo

exit "$HAD_ERROR"
