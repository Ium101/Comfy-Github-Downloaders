#!/usr/bin/env bash
# ============================================================
#  Installs / updates ComfyUI-Crystools and its requirements.
#  Place this file in the folder that contains "custom_nodes",
#  or one level above it (next to the inner ComfyUI folder).
# ============================================================
set -u

NODE_NAME="ComfyUI-Crystools"
REPO_URL="https://github.com/crystian/ComfyUI-Crystools.git"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INSTALLED=0
SKIPPED=0

fail() {
    echo
    echo "Installation did not complete."
    echo
    exit 1
}

echo "============================================================"
echo "  ComfyUI-Crystools Installer"
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
    fail
fi

NODE_DIR="$NODES_DIR/$NODE_NAME"
DISABLED_A="$NODES_DIR/.disabled/$NODE_NAME"
DISABLED_B="$NODES_DIR/$NODE_NAME.disabled"

# ---------- Sanity checks ----------
if ! command -v git >/dev/null 2>&1; then
    echo "[ERROR] git was not found. Install it first (e.g. sudo pacman -S git / sudo apt install git)."
    fail
fi

# ---------- Locate Python ----------
PYTHON_EXE=""
if [ -n "${VIRTUAL_ENV:-}" ] && [ -x "$VIRTUAL_ENV/bin/python" ]; then
    PYTHON_EXE="$VIRTUAL_ENV/bin/python"
fi
if [ -z "$PYTHON_EXE" ]; then
    for p in \
        "$SCRIPT_DIR/venv/bin/python" "$SCRIPT_DIR/.venv/bin/python" \
        "$SCRIPT_DIR/../venv/bin/python" "$SCRIPT_DIR/../.venv/bin/python" \
        "$NODES_DIR/../venv/bin/python" "$NODES_DIR/../.venv/bin/python" \
        "$NODES_DIR/../../venv/bin/python" "$NODES_DIR/../../.venv/bin/python"; do
        if [ -x "$p" ]; then
            PYTHON_EXE="$p"
            break
        fi
    done
fi
if [ -z "$PYTHON_EXE" ]; then
    for p in python3 python; do
        if command -v "$p" >/dev/null 2>&1; then
            PYTHON_EXE="$(command -v "$p")"
            break
        fi
    done
fi
if [ -z "$PYTHON_EXE" ]; then
    echo "[ERROR] Python not found. Use ComfyUI's venv or install python3."
    fail
fi
echo "[INFO] Python: $PYTHON_EXE"
echo

# ---------- Disabled copy handling ----------
for d in "$DISABLED_A" "$DISABLED_B"; do
    if [ -e "$d" ]; then
        if [ -e "$NODE_DIR" ]; then
            echo "[INFO] Removing duplicate disabled copy: $d"
            rm -rf -- "$d"
        else
            echo "[INFO] Found disabled copy, moving it back to custom_nodes ..."
            mv -- "$d" "$NODE_DIR"
        fi
    fi
done

# ---------- Helpers ----------
install_deps() {
    # Purge stale bytecode
    find "$NODE_DIR" -type d -name "__pycache__" -prune -exec rm -rf {} + 2>/dev/null

    if [ -f "$NODE_DIR/requirements.txt" ]; then
        echo "[INFO] Installing requirements ..."
        if ! "$PYTHON_EXE" -m pip install -r "$NODE_DIR/requirements.txt"; then
            echo "[ERROR] pip failed to install the requirements."
            echo "        If it says externally-managed-environment, use ComfyUI's venv"
            echo "        (activate it first, or create one with: python3 -m venv venv)."
            fail
        fi
    else
        echo "[WARN] requirements.txt not found in $NODE_NAME, skipping pip step."
    fi
    INSTALLED=$((INSTALLED + 1))
}

fresh_install() {
    echo "[INFO] Cloning $NODE_NAME ..."
    if ! git clone "$REPO_URL" "$NODE_DIR"; then
        echo "[ERROR] git clone failed."
        rm -rf -- "$NODE_DIR"
        fail
    fi
    install_deps
}

update_node() {
    echo "[INFO] $NODE_NAME found, checking for updates ..."
    if ! git -C "$NODE_DIR" fetch --quiet origin; then
        echo "[ERROR] git fetch failed. Check your internet connection."
        fail
    fi

    local LOCAL REMOTE
    LOCAL="$(git -C "$NODE_DIR" rev-parse HEAD 2>/dev/null)"
    REMOTE="$(git -C "$NODE_DIR" rev-parse '@{u}' 2>/dev/null || git -C "$NODE_DIR" rev-parse origin/HEAD 2>/dev/null)"

    if [ -z "$REMOTE" ]; then
        echo "[ERROR] Could not determine the remote version."
        fail
    fi

    if [ "$LOCAL" = "$REMOTE" ]; then
        echo "[OK] $NODE_NAME is already up to date, nothing to do."
        SKIPPED=$((SKIPPED + 1))
        return
    fi

    echo "[INFO] New version available, updating ..."
    if ! git -C "$NODE_DIR" reset --hard "$REMOTE" >/dev/null; then
        echo "[ERROR] git reset failed."
        fail
    fi
    install_deps
}

# ---------- Decide: fresh install / stale folder / update ----------
if [ ! -e "$NODE_DIR" ]; then
    fresh_install
elif [ ! -d "$NODE_DIR/.git" ]; then
    echo "[WARN] $NODE_NAME folder exists but is not a git repository. Removing it ..."
    rm -rf -- "$NODE_DIR"
    if [ -e "$NODE_DIR" ]; then
        echo "[ERROR] Could not remove the old folder."
        fail
    fi
    fresh_install
else
    update_node
fi

# ---------- Summary ----------
echo
echo "============================================================"
echo "  Summary"
echo "============================================================"
echo "  Installed:          $INSTALLED"
echo "  Already up to date: $SKIPPED"
echo "============================================================"
echo
echo "Restart ComfyUI to load the node."
echo
exit 0
