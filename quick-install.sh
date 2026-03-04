#!/bin/bash

# Quick install: uses system FFmpeg instead of compiling Plex's fork.
# Requires system FFmpeg with h264_v4l2m2m support.

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "$SCRIPT_DIR"

echo "=== Plex Hardware Transcoding Quick Install ==="
echo ""

# Check that Plex is installed
if [ ! -f "/usr/lib/plexmediaserver/Plex Transcoder" ] && [ ! -L "/usr/lib/plexmediaserver/Plex Transcoder" ] && [ ! -f "/usr/lib/plexmediaserver/Plex Transcoder Backup" ]; then
  echo "ERROR: Plex Transcoder not found at /usr/lib/plexmediaserver/"
  echo "Is Plex Media Server installed?"
  exit 1
fi
echo "[OK] Plex Media Server found"

# Install system ffmpeg if not present
if [ ! -f "/usr/bin/ffmpeg" ]; then
  echo "Installing system ffmpeg..."
  if ! sudo apt install -y ffmpeg; then
    echo "ERROR: Failed to install ffmpeg!"
    exit 1
  fi
fi

# Use /usr/bin paths explicitly (avoid custom builds in /usr/local/bin)
FFMPEG_PATH="/usr/bin/ffmpeg"
FFPROBE_PATH="/usr/bin/ffprobe"

if [ ! -f "$FFMPEG_PATH" ]; then
  echo "ERROR: $FFMPEG_PATH not found!"
  exit 1
fi
echo "[OK] FFmpeg found: $FFMPEG_PATH"

if [ ! -f "$FFPROBE_PATH" ]; then
  echo "ERROR: $FFPROBE_PATH not found!"
  exit 1
fi
echo "[OK] FFprobe found: $FFPROBE_PATH"

# Check for h264_v4l2m2m encoder support
if ! "$FFMPEG_PATH" -encoders 2>/dev/null | grep -q "h264_v4l2m2m"; then
  echo "ERROR: System FFmpeg does not support h264_v4l2m2m encoder!"
  echo "You may need to compile FFmpeg manually using ./compile.sh"
  exit 1
fi
echo "[OK] h264_v4l2m2m hardware encoder supported"

# Install python3-yaml dependency
if ! python3 -c "import yaml" 2>/dev/null; then
  echo "Installing python3-yaml..."
  if ! sudo apt install -y python3-yaml; then
    echo "ERROR: Failed to install python3-yaml!"
    exit 1
  fi
fi
echo "[OK] python3-yaml installed"

# Create config file pointing at system FFmpeg
if [ ! -f "$SCRIPT_DIR/ffmpeg-transcode.yaml" ]; then
  cp "$SCRIPT_DIR/ffmpeg-transcode-system.yaml" "$SCRIPT_DIR/ffmpeg-transcode.yaml"
  echo "[OK] Created ffmpeg-transcode.yaml (using $FFMPEG_PATH)"
else
  echo "[OK] ffmpeg-transcode.yaml already exists (not overwritten)"
fi

# Backup original Plex Transcoder
if [ ! -f "/usr/lib/plexmediaserver/Plex Transcoder Backup" ]; then
  echo "Backing up original Plex Transcoder..."
  sudo cp -p "/usr/lib/plexmediaserver/Plex Transcoder" "/usr/lib/plexmediaserver/Plex Transcoder Backup"
  if [ ! -f "/usr/lib/plexmediaserver/Plex Transcoder Backup" ]; then
    echo "ERROR: Failed to create backup!"
    exit 1
  fi
  echo "[OK] Backup created"
else
  echo "[OK] Backup already exists"
fi

# Install symlink
sudo rm -f "/usr/lib/plexmediaserver/Plex Transcoder"
sudo ln -s "$SCRIPT_DIR/ffmpeg-transcode" "/usr/lib/plexmediaserver/Plex Transcoder"
if [ -L "/usr/lib/plexmediaserver/Plex Transcoder" ]; then
  echo "[OK] Wrapper script installed"
else
  echo "ERROR: Failed to create symlink!"
  exit 1
fi

# Grant plex user access to the wrapper via group permissions
INSTALL_USER=$(stat -c '%U' "$SCRIPT_DIR")
INSTALL_GROUP=$(stat -c '%G' "$SCRIPT_DIR")
INSTALL_HOME=$(eval echo "~$INSTALL_USER")
sudo usermod -aG "$INSTALL_GROUP" plex
chmod g+rx "$INSTALL_HOME"
chmod -R g+rX "$SCRIPT_DIR"
echo "[OK] Granted plex user access via $INSTALL_GROUP group"

echo ""

# Restart Plex Media Server
echo "Restarting Plex Media Server..."
if sudo systemctl restart plexmediaserver; then
  echo "[OK] Plex Media Server restarted"
else
  echo "WARNING: Failed to restart Plex. You may need to restart it manually."
fi

echo ""
echo "=== Installation complete! ==="
echo "Plex will now use h264_v4l2m2m hardware encoding on this Raspberry Pi."
echo "Config: $SCRIPT_DIR/ffmpeg-transcode.yaml"
echo "To uninstall: ./uninstall.sh"
