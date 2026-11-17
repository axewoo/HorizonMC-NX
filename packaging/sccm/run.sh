#!/bin/bash
# Horizon (Minecraft: Java Edition 26.3 in Rust) as an SCCM Retro custom port.
#
# Folder layout, all inside this port folder (~/Applications/ports/horizon):
#   horizon-client          the game, built for aarch64 Linux by .github/workflows/sccm-port.yml
#   resources/26.3/         prepared resources, made on your PC by horizon-prepare (never shipped)
#   game/                   saves, options.txt, horizon-mods/, resourcepacks/, shaderpacks/
#   home/                   logs and crash reports (HORIZON_HOME)
#   horizon-sccm.conf       settings for this script
#   defaults/               Switch-tuned options.txt and horizon-graphics.txt for the first start
#
# Drag-and-drop mods: copy .hmod files to SCCM-Retro/Horizon/mods/ on the SD card (FAT32 side), or
# straight into game/horizon-mods/ over SFTP (sftp://sccm@<switch-ip>/). Both are picked up here.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
LOG="$HERE/home/run.log"
mkdir -p "$HERE/home" "$HERE/game/horizon-mods" "$HERE/game/resourcepacks" "$HERE/game/shaderpacks"
exec > >(tee "$LOG") 2>&1
echo "[run.sh] $(date) starting Horizon from $HERE"

PLAYER_NAME=Player
FULLSCREEN=1
SYNC_FROM_SD=1
AUTO_ENABLE_MODS=1
if [ -f "$HERE/horizon-sccm.conf" ]; then
  # shellcheck disable=SC1091
  . "$HERE/horizon-sccm.conf"
fi

RES="$HERE/resources/26.3"
if [ ! -f "$RES/.prepared" ] && [ -z "$(ls -A "$RES" 2>/dev/null)" ]; then
  echo "[run.sh] No prepared resources in $RES."
  echo "[run.sh] Prepare them on your PC with horizon-prepare and copy them here (see README-SCCM.md)."
fi

# The FAT32 side of the SD card: SCCM Retro keeps its SCCM-Retro folder there. Where it is mounted
# depends on the build, so look in the usual places.
find_sd_folder() {
  local d
  for d in /.boot/SCCM-Retro /boot/SCCM-Retro /media/*/SCCM-Retro /media/*/*/SCCM-Retro /run/media/*/*/SCCM-Retro /mnt/*/SCCM-Retro \
           /boot/SCCM-Retro /sdcard/SCCM-Retro "$HOME"/*/SCCM-Retro; do
    [ -d "$d" ] && { echo "$d"; return 0; }
  done
  return 1
}

if [ "$SYNC_FROM_SD" = 1 ]; then
  if SD="$(find_sd_folder)"; then
    INBOX="$SD/Horizon"
    mkdir -p "$INBOX/mods" "$INBOX/resourcepacks" "$INBOX/shaderpacks" 2>/dev/null
    echo "[run.sh] syncing from $INBOX"
    # Copy new and changed files only; never delete what was added over SFTP.
    cp -ru "$INBOX/mods/." "$HERE/game/horizon-mods/" 2>/dev/null
    cp -ru "$INBOX/resourcepacks/." "$HERE/game/resourcepacks/" 2>/dev/null
    cp -ru "$INBOX/shaderpacks/." "$HERE/game/shaderpacks/" 2>/dev/null
  else
    echo "[run.sh] SD card folder SCCM-Retro not found, skipping the mod sync"
  fi
fi

# Turn on every installed mod: a line mod.<id>:true in game/horizon-mods.txt. The id is the
# top-level `id` in the mod's horizon-mod.toml (inside the .hmod zip, or in a mod folder).
mod_id() {
  local src="$1" toml=""
  if [ -d "$src" ]; then
    [ -f "$src/horizon-mod.toml" ] && toml="$(cat "$src/horizon-mod.toml")"
  elif command -v unzip >/dev/null 2>&1; then
    toml="$(unzip -p "$src" horizon-mod.toml 2>/dev/null)"
  elif command -v python3 >/dev/null 2>&1; then
    toml="$(python3 -I -c 'import sys,zipfile; print(zipfile.ZipFile(sys.argv[1]).read("horizon-mod.toml").decode())' "$src" 2>/dev/null)"
  fi
  # The first top-level id = "..." line, before any [table].
  printf '%s\n' "$toml" | awk '/^\[/{exit} /^[ \t]*id[ \t]*=/{gsub(/.*=[ \t]*"|".*/,""); print; exit}'
}

if [ "$AUTO_ENABLE_MODS" = 1 ]; then
  LIST="$HERE/game/horizon-mods.txt"
  touch "$LIST"
  for m in "$HERE"/game/horizon-mods/*.hmod "$HERE"/game/horizon-mods/*/; do
    [ -e "$m" ] || continue
    id="$(mod_id "${m%/}")"
    [ -n "$id" ] || { echo "[run.sh] no mod id in $m"; continue; }
    # Respect a mod you turned off by hand (mod.<id>:false).
    if ! grep -q "^mod\.$id:" "$LIST"; then
      echo "mod.$id:true" >> "$LIST"
      echo "[run.sh] turned on mod $id"
    fi
  done
fi

# First start only: the settings tested on a Switch OLED (about 75 fps, render distance 6 with
# far terrain to 16). Change them in the game's options afterwards; they are never overwritten.
for f in options.txt horizon-graphics.txt; do
  if [ ! -f "$HERE/game/$f" ] && [ -f "$HERE/defaults/$f" ]; then
    cp "$HERE/defaults/$f" "$HERE/game/$f"
    echo "[run.sh] first start: copied the Switch defaults for $f"
  fi
done

export HORIZON_HOME="$HERE/home"
export HORIZON_LAUNCHER_NO_SELF_UPDATE=1
export RUST_BACKTRACE=1
# The Switch's Tegra X1 has Vulkan through NVIDIA's L4T driver; wgpu picks it, then falls back to GL.
ARGS=(--resources "$RES" --game-dir "$HERE/game" --name "$PLAYER_NAME" --home "$HERE/home")

# Online play: session.json, made on the PC by `horizon-launcher account session <name>` (README, section 5).
# Its Minecraft token lasts about a day; the game deletes the file it reads, so it gets a copy.
SESSION="$HERE/session.json"
if [ -f "$SESSION" ]; then
  age=$(( $(date +%s) - $(stat -c %Y "$SESSION") ))
  if [ "$age" -lt $(( 23 * 3600 )) ]; then
    install -m 600 "$SESSION" "$HERE/home/.session-once.json"
    ARGS+=(--session-file "$HERE/home/.session-once.json")
    echo "[run.sh] signed in from session.json ($(( age / 60 )) min old)"
  else
    echo "[run.sh] session.json is over 23 h old: playing offline as $PLAYER_NAME; refresh it from the PC"
  fi
fi

# Offline skin: skin.png (64x64 or 64x32) beside this script, SKIN_MODEL=classic or slim.
if [ -f "$HERE/skin.png" ]; then
  export HORIZON_OFFLINE_SKIN="$HERE/skin.png" HORIZON_OFFLINE_SKIN_MODEL="${SKIN_MODEL:-classic}"
fi
[ "$FULLSCREEN" = 1 ] && ARGS+=(--fullscreen)

# Keep the screen on while the game runs. The game reads the Joy-Cons itself, so the desktop never sees
# input and counts the player as idle; when the screen timeout then switched the panel off under the
# fullscreen game, the Switch's X server crashed (seen on battery, never on the charger). Every 20 s,
# reset X's idle time while the game (this PID, after exec) lives, and hold logind's idle inhibitor.
if [ "${KEEP_SCREEN_AWAKE:-1}" = 1 ]; then
  game=$$
  ( while kill -0 "$game" 2>/dev/null; do
      xset s reset 2>/dev/null
      command -v xdotool >/dev/null && xdotool mousemove_relative -- 0 0 2>/dev/null
      sleep 20
    done ) &
  if command -v systemd-inhibit >/dev/null; then
    INHIBIT=(systemd-inhibit --what=idle --who=Horizon --why="Playing Horizon" --mode=block)
  fi
fi

echo "[run.sh] exec ./horizon-client ${ARGS[*]} $*"
exec "${INHIBIT[@]}" "$HERE/horizon-client" "${ARGS[@]}" "$@"
