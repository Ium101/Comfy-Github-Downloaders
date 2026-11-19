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

# ── Result tracking (used by the summary at the end) ──────────────────────────
INSTALLED=0
UPTODATE=0
FAILED=0
WARNED=0
WARN_LIST=""

# Pass -f / --force to reinstall every node even if it is already up to date.
FORCE=0
case "${1:-}" in
    -f|--force) FORCE=1 ;;
esac

# ── Per-node install function ─────────────────────────────────────────────────
install_node() {
    local REPO="$1"
    local FNAME
    FNAME="$(basename "$REPO")"
    local NODE_DIR="$CUSTOM_NODES_DIR/$FNAME"
    local NODE_STATUS=""
    local PIP_WARN=0

    echo ""
    echo "── $FNAME"

    # Case A: valid git repo → sync to clean latest
    if [ -d "$NODE_DIR/.git" ]; then
        echo "  Repo found - checking for updates..."
        if ! git -C "$NODE_DIR" fetch --prune; then
            echo "  [ERROR] git fetch failed - could not check for updates, skipping."
            NODE_STATUS="failed"
        else
            local REMOTE_REF="@{u}"
            git -C "$NODE_DIR" rev-parse --verify --quiet "@{u}" >/dev/null 2>&1 || REMOTE_REF="origin/main"
            local LOCAL_SHA REMOTE_SHA
            LOCAL_SHA="$(git -C "$NODE_DIR" rev-parse HEAD 2>/dev/null || true)"
            REMOTE_SHA="$(git -C "$NODE_DIR" rev-parse "$REMOTE_REF" 2>/dev/null || true)"
            if [ "$FORCE" -ne 1 ] && [ -n "$LOCAL_SHA" ] && [ "$LOCAL_SHA" = "$REMOTE_SHA" ]                && git -C "$NODE_DIR" diff --quiet HEAD 2>/dev/null; then
                echo "  Already up to date - skipping."
                NODE_STATUS="uptodate"
            else
                echo "  Update available or repair needed - syncing to latest clean state..."
                NODE_STATUS="updated"
                git -C "$NODE_DIR" reset --hard "$REMOTE_REF" || NODE_STATUS="update_failed"
                git -C "$NODE_DIR" clean -fdx || true
                if [ "$NODE_STATUS" = "update_failed" ]; then
                    echo "  [ERROR] git sync failed - node may be outdated."
                fi
            fi
        fi
    else
        # Case B: stale folder, no .git → remove and re-clone
        if [ -d "$NODE_DIR" ]; then
            echo "  Stale folder found (no .git) - removing and re-cloning..."
            if ! rm -rf "$NODE_DIR"; then
                echo "  [ERROR] Cannot remove $NODE_DIR - skipping."
                NODE_STATUS="failed"
            fi
        fi
        # Case C: fresh clone
        if [ "$NODE_STATUS" != "failed" ]; then
            echo "  Cloning..."
            if git clone --depth=1 "$REPO" "$NODE_DIR"; then
                NODE_STATUS="installed"
            else
                echo "  [ERROR] git clone failed - skipping."
                NODE_STATUS="failed"
            fi
        fi
    fi

    if [ "$NODE_STATUS" != "failed" ] && [ "$NODE_STATUS" != "uptodate" ]; then
        if [ -f "$NODE_DIR/requirements.txt" ]; then
            echo "  Installing requirements..."
            if ! "$PYTHON_EXE" -m pip install -r "$NODE_DIR/requirements.txt" --quiet --break-system-packages --no-cache-dir; then
                echo "  [WARN] pip install reported errors."
                PIP_WARN=1
            fi
        else
            echo "  No requirements.txt - skipping pip."
        fi
        # Purge __pycache__ and bytecode files (all paths, every run)
        echo "  Purging __pycache__ and .pyc files..."
        find "$NODE_DIR" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
        find "$NODE_DIR" -type f \( -name "*.pyc" -o -name "*.pyo" \) -delete 2>/dev/null || true
    fi

    # Tally for the summary
    case "$NODE_STATUS" in
        installed|updated)    INSTALLED=$((INSTALLED + 1)) ;;
        uptodate)             UPTODATE=$((UPTODATE + 1)) ;;
        failed|update_failed) FAILED=$((FAILED + 1)) ;;
    esac
    if [ "$PIP_WARN" -eq 1 ]; then
        WARNED=$((WARNED + 1))
        WARN_LIST="$WARN_LIST $FNAME"
    fi
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
echo " Summary"
echo "============================================"
echo " Installed       : $INSTALLED"
echo " Up to date      : $UPTODATE"
echo " Dep. warnings   : $WARNED"
if [ "$WARNED" -gt 0 ]; then
    echo " Check deps for  :$WARN_LIST"
fi
echo "============================================"
if [ "$FAILED" -gt 0 ]; then
    echo " [WARN] Some nodes failed - see messages above."
fi
if [ "$INSTALLED" -gt 0 ]; then
    echo " Please RESTART ComfyUI now."
else
    echo " Nothing changed - no restart needed."
fi
echo "============================================"
echo ""
if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
