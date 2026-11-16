# Horizon on SCCM Retro (Nintendo Switch)

Horizon is Minecraft: Java Edition 26.3 rewritten in Rust. This folder is Horizon built for the Switch's
ARM processor, packaged as an SCCM Retro custom port. It ships **no Minecraft files**: you prepare them
once on your PC from your own copy of Minecraft: Java Edition, then copy them to the Switch.

Commands below are for a Linux PC with the fish shell (they work in bash too unless marked).

## 1. Prepare the game files on your PC (once per Minecraft version)

**Easiest: with the Horizon launcher (AppImage).** Sign in, press Play once and wait for the title screen,
then quit. The launcher has built the files here:

```fish
find ~/.local/share/horizon-launcher/versions -maxdepth 4 -type d -path '*/.local/horizon-client/26.3'
```

Use that `26.3` folder in step 2 and skip the rest of this section.

**Without the launcher:**

1. Install Minecraft: Java Edition **26.3** with the official launcher and start it once.
2. Install a JDK 25 (on Arch/CachyOS: `sudo pacman -S jdk25-openjdk`, or `jdk-openjdk` if that is 25).
3. Download the official Horizon release for **Linux x86-64** from https://playhorizon.dev/download and
   extract it, for example to `~/horizon-pc`.
4. Get the 26.3 server jar (the preparer needs it and never downloads it):

   ```fish
   set url (jq -r .downloads.server.url ~/.minecraft/versions/26.3/26.3.json)
   curl -L -o ~/horizon-pc/server-26.3.jar $url
   ```

5. Prepare the resources and sounds:

   ```fish
   cd ~/horizon-pc
   ./horizon-prepare --prepare --minecraft-dir ~/.minecraft --server-jar ~/horizon-pc/server-26.3.jar
   ./horizon-prepare sounds --minecraft-dir ~/.minecraft
   ```

   The result is `~/horizon-pc/.local/horizon-client/26.3`. Keep it private: it is built from Mojang's files.

## 2. Install the port on the Switch

1. In SCCM Retro, open **Settings > Network**, set a **Remote access password**, and note the console's
   address (shown as `sccm@<address>`).
2. On the PC, download `horizon-sccm-aarch64.tar.gz` from the Actions run or the release, then:

   ```fish
   set sw sccm@192.168.1.50          # your Switch's address
   ssh $sw 'mkdir -p ~/Applications/ports'
   tar -xzf horizon-sccm-aarch64.tar.gz
   scp -r horizon $sw:Applications/ports/
   scp -r ~/horizon-pc/.local/horizon-client/26.3 $sw:Applications/ports/horizon/resources/   # or the launcher's 26.3 folder
   ssh $sw 'chmod +x ~/Applications/ports/horizon/run.sh ~/Applications/ports/horizon/horizon-client'
   ```

   (Or in Dolphin, open `sftp://sccm@192.168.1.50/` and drag the folders in.)
3. Restart SCCM Retro. A **Horizon (Minecraft)** tile appears under **Ports and Apps**.

## 3. Add mods by drag and drop

Two ways, both picked up every time the game starts:

- **Over Wi-Fi from the PC:** in Dolphin, open `sftp://sccm@<switch-address>/Applications/ports/horizon/game/`
  and drag `.hmod` files into `horizon-mods/`, resource packs into `resourcepacks/`, shader packs into
  `shaderpacks/`.
- **On the SD card:** put the card in the PC and drop files into `SCCM-Retro/Horizon/mods/`
  (`resourcepacks/`, `shaderpacks/` beside it). `run.sh` copies them over at the next start.

Every mod found is turned on automatically (a `mod.<id>:true` line in `game/horizon-mods.txt`). To turn one off,
change its line to `mod.<id>:false`: the script leaves lines you edited alone.

Content mods and WebAssembly mods work. **Native mods (Rust source) do not**: Horizon's PC launcher compiles them,
and the Switch has no compiler setup for that. Fabric and Forge `.jar` mods never run in Horizon.

## 4. Settings

`horizon-sccm.conf` in the port folder: your player name (single player and LAN are offline, no Microsoft
sign-in), fullscreen, the SD sync, auto-enable, and the render distance written on the very first start (6
chunks; change it in the game's options after that).

## Troubleshooting

- Logs: `~/Applications/ports/horizon/home/run.log` and the game's logs in `home/`.
- Running `run.sh` over SSH fails with "display not found": start it from the tile.
- A black screen or a graphics error at start: send `home/run.log` and the output of `vulkaninfo --summary`.
