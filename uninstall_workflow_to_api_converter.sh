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
echo " ComfyUI Workflow-to-API Converter | Uninstaller"
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

REMOVED=0
SKIPPED=0
FAILED=0

# ── Nodes to remove (same repos as the installer) ─────────────────────────────
NODES=(
    https://github.com/SethRobinson/comfyui-workflow-to-api-converter-endpoint.git
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
    if ! present "$NODE_DIR" && ! present "$NODE_DIR.disabled" && ! present "$CUSTOM_NODES_DIR/.disabled/$FNAME"; then
        echo "  Not installed - skipping."
        SKIPPED=$((SKIPPED + 1))
        return 0
    fi

    delete_dir "$NODE_DIR"
    delete_dir "$NODE_DIR.disabled"
    delete_dir "$CUSTOM_NODES_DIR/.disabled/$FNAME"
}

echo "[1/3]  Locating ComfyUI installation..."
echo " Root         : $COMFYUI_DIR"
echo " custom_nodes : $CUSTOM_NODES_DIR"
echo ""
if [ ! -d "$CUSTOM_NODES_DIR" ]; then
    echo " [ERROR] custom_nodes folder not found. Is this script next to the ComfyUI folder?"
    exit 1
fi

# ── Summary of what will be removed ──────────────────────────────────────────────────────────────
echo "[2/3]  These custom node folders will be DELETED (if present):"
for REPO in "${NODES[@]}"; do
    echo "   - $(basename "$REPO" .git)"
done
echo ""
echo " NOTE: other workflows may depend on some of these nodes."
echo "       Python packages installed in the environment are NOT removed."
echo "       Close ComfyUI before continuing."
echo ""
# ── Remove each node ──────────────────────────────────────────────────────────
echo "[3/3]  Removing custom nodes..."
for REPO in "${NODES[@]}"; do
    remove_node "$REPO"
done

echo ""
echo "======================================================"
echo " Done!  Removed: $REMOVED  |  Not installed: $SKIPPED"
if [ "$FAILED" -gt 0 ]; then
    echo " [WARN] Some folders could not be removed - see messages above."
fi
echo " Please RESTART ComfyUI now."
echo "======================================================"
echo ""
if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
