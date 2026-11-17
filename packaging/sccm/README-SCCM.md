# Horizon on SCCM Retro (Nintendo Switch)

Horizon is Minecraft: Java Edition 26.3 rewritten in Rust. This folder is Horizon built for the Switch's ARM
processor, packaged as an SCCM Retro custom port. It ships **no Minecraft files**: you prepare them once on your
PC from your own copy of Minecraft: Java Edition, then copy them to the Switch.

**Tested on a Switch OLED** (SCCM Retro, Switchroot Fedora 42, NVIDIA L4T driver 32.7.6, Vulkan): about
**75 fps** (13 ms frames) in a forest at render distance 6 with far terrain out to 16 chunks, Joy-Cons working
out of the box.

These numbers were measured with the Switch **overclocked in SCCM Retro**. At stock clocks expect fewer frames;
read [Overclocking safely](#overclocking-safely) before raising them. The tested console used:

| Setting (SCCM Retro) | Value |
| --- | --- |
| RAM | 2833 MHz at 1175 mV |
| CPU undervolt | preset 1 |
| CPU clock limit | none |
| GPU | stock |
| SD card | DDR200 mode (Samsung card) |
| Horizon graphics preset | custom (see section 3), not Extreme |
| Speedo (chip quality) | CPU 1653, GPU 1659, RAM 1676 |
| RAM chips | Samsung K4U6E3S4AA-MGCL, 4 GB (S tier in SCCM Retro) |
| Fan curve | custom in SCCM Retro (points 35, 40, 45, 50, 55, 60; stock 36, 40, 43, 44, 45, 47) |

**This is a good chip.** Speedo values and the RAM model are set at the factory and differ from one Switch to the
next; SCCM Retro shows yours. A console with lower speedos or another RAM model may not be stable at these
clocks and voltages, even though they ran fine here. Treat them as one console's result, not settings to copy
onto yours, and let SCCM's tuners find your own.

Commands below are for a Linux PC with the fish shell.

## 1. Prepare the game files on your PC

1. Install the **Horizon launcher** (AppImage) from https://playhorizon.dev/download, sign in, press **Play**
   once and wait for the title screen, then quit. It builds the files from your Minecraft 26.3 install.
2. Find them:

   ```fish
   find ~/.local/share/horizon-launcher/versions -maxdepth 4 -type d -path '*/.local/horizon-client/26.3'
   ```

   You get a folder like `versions/nightly-2026-11-13-9f42064/.local/horizon-client/26.3` (about 800 MB).

**The Switch build must match that launcher version.** The last part of the folder name (`9f42064`) is the
Horizon commit. The port's `HORIZON_COMMIT` file says which commit it was built from. When they differ the game
stops at start with "world resources failed to load ... re-run horizon-prepare". To build the port for another
launcher nightly, run the **SCCM Retro port** workflow in GitHub Actions with that commit as `horizon_ref` (and
add a patch for it in `packaging/sccm/patches/` if the one-line wait fix does not apply).

## 2. Install the port on the Switch

Copying 800 MB over Wi-Fi can freeze SCCM Retro, so put the SD card in the PC instead.

1. Download `horizon-sccm-aarch64` from the latest **SCCM Retro port** run in GitHub Actions to `~/Downloads`.
2. Shut down the Switch, put the SD card in the PC and open both of its partitions in Dolphin (the ext4 one,
   labelled `SWR-FED`, is SCCM's Linux).
3. Copy:

   ```fish
   cd ~/Downloads; rm -rf horizon horizon-sccm-aarch64.tar.gz
   unzip -o horizon-sccm-aarch64.zip; tar -xzf horizon-sccm-aarch64.tar.gz
   set res ~/.local/share/horizon-launcher/versions/nightly-2026-11-13-9f42064/.local/horizon-client/26.3
   set home /run/media/$USER/SWR-FED/home/sccm
   set port $home/Applications/ports/horizon
   set own (stat -c %u:%g $home)
   sudo mkdir -p $port/resources
   sudo cp -r horizon/. $port/
   sudo cp -r $res $port/resources/
   sudo chown -R $own $home/Applications
   sudo chmod +x $port/run.sh $port/horizon-client
   sync
   ```

4. Eject, boot SCCM Retro. A **Horizon (Minecraft)** tile appears under **Ports and Apps**.

**Updating** only replaces two small files, which is fine over Wi-Fi. Set a **Remote access password** in SCCM
Retro (Settings > Network) once, then:

```fish
set sw sccm@<switch-address>
scp horizon/run.sh horizon/horizon-client $sw:Applications/ports/horizon/
```

## 3. Recommended settings

The first start copies the tested settings from `defaults/` (never over settings you already have):

| Setting | Value |
| --- | --- |
| Render distance / simulation distance | 6 / 5 |
| Far terrain (LOD) distance | 16, full detail |
| VSync / max FPS / target FPS | off / 90 / 60 |
| Frame pacing | efficient |
| Culling | cave, entity, particle, leaf (hidden) and GPU culling on |
| Resolution | native 100 %, no FXAA, TAA, upscaling or frame generation |
| GUI scale | 2 |

Avoid the **Extreme** graphics preset: it asks for thousands of chunks and freezes the console. If that happens,
from the PC:

```fish
ssh $sw 'pkill -x horizon-client; cd ~/Applications/ports/horizon/game; rm options.txt horizon-graphics.txt'
```

The next start brings the Switch defaults back.

## Overclocking safely

SCCM Retro can overclock and undervolt the Switch, which is how the numbers above were reached. Its own tuners
(Settings > Overclocking and tuning: RAM overclock, CPU undervolt) find the fastest stable RAM speed and the
lowest stable CPU voltage for your console, never keep a setting that failed, and run only undocked on the
charger. Use them rather than typing values in, following SCCM's
[overclocking guide](https://guides.socalconsolemodding.com/sccm-retro-ram-overclock-tool/). If you tune by hand:

- Raise clocks **one step at a time** and play a while at each step. Stop at the first freeze, crash or glitch,
  and go back a step.
- Undervolt in small steps too: too low a voltage gives random crashes and can corrupt saves. Back up
  `game/saves/` first.
- Watch the temperature and keep the fan unobstructed. Docked and long sessions run hotter.
- **Don't push it to the limit.** A moderate overclock gives most of the gain; the last steps add heat and wear
  for little. Overclocking is at your own risk, and nobody here can replace a damaged console.
- If the console won't start properly, boot **SCCM Retro (Safe Mode)** once (stock speeds) and use **Reset to
  stock** in the overclocking settings.

## 4. Add mods by drag and drop

Both ways are picked up every time the game starts:

- **On the SD card:** drop files into `SCCM-Retro/Horizon/mods/` on the FAT32 side (`resourcepacks/` and
  `shaderpacks/` beside it). On the Switch that folder is `/.boot/SCCM-Retro/Horizon`.
- **Over Wi-Fi:** in Dolphin, open `sftp://sccm@<switch-address>/home/sccm/Applications/ports/horizon/game/` and
  drag `.hmod` files into `horizon-mods/`.

Every mod found is turned on (`mod.<id>:true` in `game/horizon-mods.txt`). To turn one off, change its line to
`mod.<id>:false`: the script keeps lines you edited.

Content and WebAssembly mods work. **Native mods (Rust source) do not**: the PC launcher compiles them. Fabric and
Forge `.jar` mods never run in Horizon.

## 5. Online servers and your skin

**Online servers** need your Microsoft account. The Switch can't sign in by itself, so the PC launcher hands it
a session: a Minecraft token that lasts about a day. Once per play day, with the Switch on, run on the PC
(`<you>` is your Minecraft name, the AppImage is the launcher you installed in step 1):

```fish
set app (find ~ -name 'horizon-launcher*.AppImage' 2>/dev/null | head -1)
set f ($app account session <you> --json | jq -r .session_file)
scp $f $sw:Applications/ports/horizon/session.json; rm -f $f
```

The next start plays as you, with your skin, on any server (add it under **Multiplayer**). After 23 hours the game
goes back to offline and the log says to refresh. The file holds a token for your account: keep a remote access
password set, and delete `session.json` to sign out.

**Offline** (single player, LAN, offline servers) you play as `PLAYER_NAME` from `horizon-sccm.conf`. For a skin,
copy a skin PNG (64×64) to the port folder as `skin.png`, and set `SKIN_MODEL=slim` there for thin arms:

```fish
scp ~/Downloads/my-skin.png $sw:Applications/ports/horizon/skin.png
```

## 6. Other settings

`horizon-sccm.conf` in the port folder: player name and skin model for offline play, fullscreen, the SD sync, the mod
auto-enable and keeping the screen awake.

## 7. Native mods

Native mods (`.hnmod`, Rust source) are built into the game by GitHub, since the Switch can't compile them. Run the
**SCCM Retro port** workflow with their registry links in `native_mods`, separated by spaces (the **Download** link
on the mod's page at playhorizon.dev/mods), and install the new `horizon-client` as in **Updating**.
`NATIVE_MODS.txt` in the package lists what it holds. Only mixin mods build this way, and a mod made for
another Horizon version may not apply; the run's log says which.

## Troubleshooting

**The screen goes black and SCCM restarts ("could not start plasma session") a minute or two into a session on
battery:** SCCM's battery screen timeout switched the screen off under the game, and the Switch's display server
crashed. `run.sh` keeps the screen awake while Horizon runs (`KEEP_SCREEN_AWAKE=1` in `horizon-sccm.conf`); if you
turned that off, play on the charger or raise the timeout in SCCM's settings.

Send these from the PC while the Switch is still on (the `/tmp` log is lost at shutdown):

```fish
ssh $sw 'cat /tmp/sccm_port_horizon.log; tail -80 ~/Applications/ports/horizon/home/run.log'
```

Crash reports are in `home/crash-reports/`, with function names and lines.
