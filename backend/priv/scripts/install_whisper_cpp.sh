#!/usr/bin/env bash
# Install whisper.cpp + a small English model for the ForgeNexus local
# transcription provider. Run as root or with sudo.
#
# Usage:
#   sudo bash priv/scripts/install_whisper_cpp.sh [model]
#
# Defaults to the `small.en` model (~500 MB, fast, community-quality).
# Other good options: tiny.en (~75 MB, fastest), base.en (~150 MB),
# medium.en (~1.5 GB, highest quality on CPU), small (multilingual ~500 MB).
#
# After install, set in admin settings:
#   voice_transcription_enabled = true
#   voice_transcription_provider = local
set -euo pipefail

MODEL="${1:-small.en}"
INSTALL_DIR="/opt/whisper.cpp"

echo "=== ForgeNexus whisper.cpp installer ==="
echo "Installing to: $INSTALL_DIR"
echo "Model: $MODEL"
echo

# --- Dependencies ---
if command -v apt-get >/dev/null 2>&1; then
  echo "[1/5] Installing build dependencies (Debian/Ubuntu)..."
  apt-get update -y
  apt-get install -y --no-install-recommends \
    git build-essential cmake ffmpeg ca-certificates curl
elif command -v dnf >/dev/null 2>&1; then
  echo "[1/5] Installing build dependencies (Fedora/RHEL)..."
  dnf install -y git gcc gcc-c++ make cmake ffmpeg ca-certificates curl
elif command -v yum >/dev/null 2>&1; then
  echo "[1/5] Installing build dependencies (CentOS/RHEL legacy)..."
  yum install -y git gcc gcc-c++ make cmake ffmpeg ca-certificates curl
else
  echo "Unknown package manager — please install: git, build-essential, cmake, ffmpeg"
  exit 1
fi

# --- Clone ---
if [ -d "$INSTALL_DIR/.git" ]; then
  echo "[2/5] Updating existing whisper.cpp checkout..."
  git -C "$INSTALL_DIR" pull --ff-only
else
  echo "[2/5] Cloning whisper.cpp..."
  git clone https://github.com/ggerganov/whisper.cpp "$INSTALL_DIR"
fi

# --- Build ---
echo "[3/5] Building whisper.cpp..."
cd "$INSTALL_DIR"
make clean >/dev/null 2>&1 || true
make -j"$(nproc)"

# --- Locate binary ---
# Modern whisper.cpp puts the CLI in `build/bin/whisper-cli`; older versions ship `main`.
BIN_PATH=""
for candidate in "$INSTALL_DIR/main" "$INSTALL_DIR/build/bin/whisper-cli" "$INSTALL_DIR/whisper-cli"; do
  if [ -x "$candidate" ]; then
    BIN_PATH="$candidate"
    break
  fi
done

if [ -z "$BIN_PATH" ]; then
  echo "ERROR: could not find whisper.cpp binary after build"
  exit 1
fi

# Symlink to /opt/whisper.cpp/main for a stable path
if [ "$BIN_PATH" != "$INSTALL_DIR/main" ]; then
  ln -sf "$BIN_PATH" "$INSTALL_DIR/main"
fi

# --- Model ---
echo "[4/5] Downloading model: $MODEL"
bash "$INSTALL_DIR/models/download-ggml-model.sh" "$MODEL"

MODEL_PATH="$INSTALL_DIR/models/ggml-${MODEL}.bin"
if [ ! -f "$MODEL_PATH" ]; then
  echo "ERROR: model file not found at $MODEL_PATH after download"
  exit 1
fi

# --- Quick smoke test ---
echo "[5/5] Running a quick smoke test..."
SAMPLE="$INSTALL_DIR/samples/jfk.wav"
if [ -f "$SAMPLE" ]; then
  "$INSTALL_DIR/main" -m "$MODEL_PATH" -f "$SAMPLE" -otxt -nt -of /tmp/whisper_smoke > /dev/null 2>&1 || true
  if [ -f /tmp/whisper_smoke.txt ]; then
    echo "  Smoke test output: $(cat /tmp/whisper_smoke.txt | head -c 120)"
    rm -f /tmp/whisper_smoke.txt
  fi
fi

echo
echo "=== Install complete ==="
echo "Binary: $INSTALL_DIR/main"
echo "Model:  $MODEL_PATH"
echo
echo "Now in admin settings set:"
echo "  voice_transcription_enabled = true"
echo "  voice_transcription_provider = local"
echo
echo "Paths match the ForgeNexus defaults, so no other settings changes needed."
