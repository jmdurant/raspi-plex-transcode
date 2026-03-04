# raspi-plex-transcode

Hardware-accelerated video transcoding for Plex Media Server on Raspberry Pi 4, using the V4L2M2M hardware encoder.

## How it works

A Python wrapper script intercepts Plex's transcoder calls and modifies the FFmpeg arguments to use the Pi 4's hardware encoder (`h264_v4l2m2m`) instead of software encoding. This reduces CPU usage dramatically (typically ~35% vs 100%).

The wrapper:
- Replaces software video encoding with `h264_v4l2m2m` hardware encoding for both h264 and h265 sources
- Adjusts encoder parameters (bitrate, buffer size) for the hardware encoder
- Converts incompatible audio formats (FLAC, EAC3) to AAC
- Converts MKV container to MPEG-TS for streaming compatibility

## Requirements

- Raspberry Pi 4 (BCM2711 with hardware H.264 encoder)
- Plex Media Server installed
- GPU memory set to at least 128MB (the default)
  - Check `/boot/firmware/config.txt` on Debian Bookworm (`/boot/config.txt` on older releases)
  - Ensure `gpu_mem` is not set below 128

## Install (Recommended)

Compiles Plex's FFmpeg fork with hardware encoding support. This provides full compatibility with all Plex features including Live TV.

```
cd ~
git clone https://github.com/jmdurant/raspi-plex-transcode.git
cd raspi-plex-transcode
./compile.sh
./install.sh
```

Note: Compiling FFmpeg on a Raspberry Pi 4 takes 30-60 minutes.

## Quick Install (Alternative)

Uses the system FFmpeg package instead of compiling. Faster to set up but may not support all Plex features (e.g., Live TV tuner streams).

```
cd ~
git clone https://github.com/jmdurant/raspi-plex-transcode.git
cd raspi-plex-transcode
./quick-install.sh
```

## Scripts

- `compile.sh` — Download, patch, and compile Plex's FFmpeg fork with V4L2M2M support
- `install.sh` — Back up the original Plex Transcoder and install the wrapper (after running compile.sh)
- `quick-install.sh` — Install using system FFmpeg (no compile needed)
- `uninstall.sh` — Restore the original Plex Transcoder from backup

## Uninstalling

```
cd ~/raspi-plex-transcode
./uninstall.sh
```

This restores the original Plex Transcoder from the backup created during install.

## Configuration

The wrapper reads `ffmpeg-transcode.yaml` to determine how to modify Plex's FFmpeg arguments. The install scripts create this file automatically.

### Key settings

- **ffmpeg** — Path to the FFmpeg binary
- **ffprobe** — Path to the FFprobe binary
- **log** — Path to the transcode log file
- **debug** — Set to `true` to enable logging of all transcode calls (useful for troubleshooting)
- **strip_plex_args** — Set to `true` when using system FFmpeg to strip Plex-specific flags it doesn't understand

### Codec rules (by_codec)

The default configuration handles these codec conversions:

| Source | Target | Notes |
|--------|--------|-------|
| hevc (h265) | h264_v4l2m2m | Hardware-encoded at 5Mbps |
| h264 | h264_v4l2m2m | Hardware re-encode at 5Mbps |
| mpeg2video | h264_v4l2m2m | Live TV hardware encode at 5Mbps |
| flac | aac | Audio converted at 256k |
| eac3 | aac | Audio converted at 256k |

### Custom profiles

You can define custom profiles in the YAML config to override FFmpeg parameters based on input arguments or codecs. See `ffmpeg-transcode-example.yaml` for the full syntax.

Example — match files with "anime" in the path:
```yaml
'profile_select':
  'by_argument':
    -
      'argSection': 'input'
      'argName': '-i'
      'type': 'regex'
      'ignorecase': true
      'value': '.*anime.*'
      'profile': 'anime'
```

## Troubleshooting

Enable debug logging in `ffmpeg-transcode.yaml`:
```yaml
'debug': true
```

Then check the log after a transcode attempt:
```
cat /var/lib/plexmediaserver/plex-transcoder.log
```

## Supported distributions

- Debian Bookworm (Raspberry Pi OS)
- Raspbian
- Manjaro Linux ARM

## Resources

- Encoding options for `h264_v4l2m2m`: https://github.com/raspberrypi/firmware/issues/1612
- Plex hardware transcoding thread: https://forums.plex.tv/t/hardware-transcoding-for-raspberry-pi-4-plex-media-server/538779/236
