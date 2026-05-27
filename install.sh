#!/usr/bin/env sh
# Arignan one-click installer for macOS and Linux.
# Usage: sh install.sh
# Downloads the latest wheel, creates a venv at ~/.arignan/venv, and runs setup.

set -e

ARIGNAN_HOME="$HOME/.arignan"
VENV_DIR="$ARIGNAN_HOME/venv"
WHEEL_URL="https://github.com/rogue-infinity/Open-Arignan/releases/latest/download/open_arignan-latest-py3-none-any.whl"

echo "=== Arignan Installer ==="
echo ""

# --- Python check ---
PYTHON=""
for candidate in python3 python; do
    if command -v "$candidate" >/dev/null 2>&1; then
        version=$("$candidate" -c "import sys; print(sys.version_info[:2])" 2>/dev/null || true)
        major=$("$candidate" -c "import sys; print(sys.version_info.major)" 2>/dev/null || true)
        minor=$("$candidate" -c "import sys; print(sys.version_info.minor)" 2>/dev/null || true)
        if [ "$major" -ge 3 ] && [ "$minor" -ge 10 ] 2>/dev/null; then
            PYTHON="$candidate"
            break
        fi
    fi
done

if [ -z "$PYTHON" ]; then
    echo "[error] Python 3.10 or later is required but was not found."
    echo ""
    echo "Install Python from: https://www.python.org/downloads/"
    echo "  macOS users can also use Homebrew:  brew install python@3.12"
    echo "  Ubuntu/Debian:  sudo apt install python3.12 python3.12-venv"
    exit 1
fi

echo "[1/5] Found Python: $($PYTHON --version)"

# --- Create venv ---
echo "[2/5] Creating virtual environment at $VENV_DIR ..."
mkdir -p "$ARIGNAN_HOME"
"$PYTHON" -m venv "$VENV_DIR"
VENV_PYTHON="$VENV_DIR/bin/python"
VENV_PIP="$VENV_DIR/bin/pip"

# --- Download and install wheel ---
echo "[3/5] Downloading and installing Arignan..."
"$VENV_PIP" install --upgrade pip --quiet

# Try to download the wheel; fall back to installing from the repo if unavailable
if command -v curl >/dev/null 2>&1; then
    if curl --fail --silent --location --output /tmp/open_arignan.whl "$WHEEL_URL" 2>/dev/null; then
        "$VENV_PIP" install /tmp/open_arignan.whl --quiet
        rm -f /tmp/open_arignan.whl
    else
        echo "  (Pre-built wheel not found, installing from source...)"
        SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
        "$VENV_PIP" install "$SCRIPT_DIR" --quiet
    fi
elif command -v wget >/dev/null 2>&1; then
    if wget --quiet --output-document /tmp/open_arignan.whl "$WHEEL_URL" 2>/dev/null; then
        "$VENV_PIP" install /tmp/open_arignan.whl --quiet
        rm -f /tmp/open_arignan.whl
    else
        SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
        "$VENV_PIP" install "$SCRIPT_DIR" --quiet
    fi
else
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    "$VENV_PIP" install "$SCRIPT_DIR" --quiet
fi

# --- Run setup_flow ---
echo "[4/5] Running Arignan setup (this will download models — may take a while)..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
"$VENV_PYTHON" "$SCRIPT_DIR/setup.py" --app-home "$ARIGNAN_HOME"

# --- Create launcher shortcut ---
echo "[5/5] Creating launch shortcut..."
PLATFORM="$(uname -s)"

if [ "$PLATFORM" = "Darwin" ]; then
    LAUNCHER="$HOME/Desktop/Arignan.command"
    cat > "$LAUNCHER" <<EOF
#!/usr/bin/env sh
export TOKENIZERS_PARALLELISM=false
"$VENV_DIR/bin/python" -m arignan.cli gui --app-home "$ARIGNAN_HOME" &
sleep 1
open http://127.0.0.1:7860
wait
EOF
    chmod +x "$LAUNCHER"
    echo "  Created: $LAUNCHER (double-click to launch)"
else
    DESKTOP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
    mkdir -p "$DESKTOP_DIR"
    LAUNCHER="$DESKTOP_DIR/arignan.desktop"
    LAUNCH_SCRIPT="$ARIGNAN_HOME/launch.sh"
    cat > "$LAUNCH_SCRIPT" <<EOF
#!/usr/bin/env sh
export TOKENIZERS_PARALLELISM=false
"$VENV_DIR/bin/python" -m arignan.cli gui --app-home "$ARIGNAN_HOME"
EOF
    chmod +x "$LAUNCH_SCRIPT"
    cat > "$LAUNCHER" <<EOF
[Desktop Entry]
Type=Application
Name=Open Arignan
Comment=Local-first knowledge assistant
Exec=$LAUNCH_SCRIPT
Terminal=true
Categories=Utility;
EOF
    echo "  Created desktop entry: $LAUNCHER"
fi

echo ""
echo "=== Setup complete! ==="
echo ""
if [ "$PLATFORM" = "Darwin" ]; then
    echo "To launch: double-click 'Arignan.command' on your Desktop"
else
    echo "To launch: look for 'Open Arignan' in your application launcher"
    echo "  or run: $ARIGNAN_HOME/launch.sh"
fi
echo ""
echo "You can also run from terminal:"
echo "  $VENV_DIR/bin/python -m arignan.cli gui --app-home $ARIGNAN_HOME"
