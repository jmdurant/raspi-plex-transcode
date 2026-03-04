#!/bin/bash

set -e

# Ensure the script directory is the current working directory
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "$SCRIPT_DIR"

# Check that the compiled ffmpeg binary exists
if [ ! -f "$SCRIPT_DIR/plex-media-server-ffmpeg/ffmpeg" ]; then
  echo "Compiled ffmpeg not found! Run ./compile.sh first."
  exit 1
fi

# Check that the original plex transcoder exists
if [ ! -f "/usr/lib/plexmediaserver/Plex Transcoder" ] && [ ! -L "/usr/lib/plexmediaserver/Plex Transcoder" ] && [ ! -f "/usr/lib/plexmediaserver/Plex Transcoder Backup" ]; then
  echo "Plex Transcoder not found at /usr/lib/plexmediaserver/Plex Transcoder"
  echo "Is Plex Media Server installed?"
  exit 1
fi

# Create backup of original plex transcoder
if [ ! -f "/usr/lib/plexmediaserver/Plex Transcoder Backup" ]; then
  sudo cp -p "/usr/lib/plexmediaserver/Plex Transcoder" "/usr/lib/plexmediaserver/Plex Transcoder Backup"
  if [ ! -f "/usr/lib/plexmediaserver/Plex Transcoder Backup" ]; then
    echo "Failed to create backup of the original plex transcoder!"
    exit 1
  fi
fi

# Replace currently existing plex transcoder by a symlink to the wrapper script
sudo rm -f "/usr/lib/plexmediaserver/Plex Transcoder"
if [ -f "/usr/lib/plexmediaserver/Plex Transcoder" ]; then
  echo "Failed to remove original plex transcoder!"
  exit 1
fi
sudo ln -s "$SCRIPT_DIR/ffmpeg-transcode" "/usr/lib/plexmediaserver/Plex Transcoder"
if [ -f "/usr/lib/plexmediaserver/Plex Transcoder" ]; then
  echo "Wrapper script successfully installed!"
else
  echo "Failed to create symlink to wrapper script!"
  exit 1
fi

# Ensure a configuration file exists
if [ ! -f "$SCRIPT_DIR/ffmpeg-transcode.yaml" ]; then
  cp "$SCRIPT_DIR/ffmpeg-transcode-example.yaml" "$SCRIPT_DIR/ffmpeg-transcode.yaml"
fi

# Restart Plex Media Server
echo "Restarting Plex Media Server..."
if sudo systemctl restart plexmediaserver; then
  echo "Plex Media Server restarted successfully!"
else
  echo "WARNING: Failed to restart Plex. You may need to restart it manually."
fi
