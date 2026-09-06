# Installing Leaf Voxel

Current package: `leaf-voxel-0.2.1.zip` — 37 files, 326,472 bytes,
SHA-256 `6f85c9493d6706de5f5bc6ae77e5df2cb5f2c90049cdc5da9579fbd459f68502`.
Build it with `python3 scripts/package.py`, and verify a copy with:

```sh
shasum -a 256 -c leaf-voxel-0.2.1.zip.sha256
```

## Requirements

- Gen1Recomp with **mod API 2**, on LÖVE 11.5. Tested engine: **0.2.56**.
- On the Miniloong Pocket 1: [Leaf-Gen1Recomp](https://github.com/Helaas/Leaf-Gen1Recomp)
  plus Leaf's PortMaster runtime.
- Your own cartridge dump, already imported. No ROM, asset cache or save is
  distributed with this mod.

## The short version: it may already be installed

The [Leaf-Gen1Recomp release](https://github.com/Helaas/Leaf-Gen1Recomp/releases)
bundles this mod and installs it into a new profile on first launch, enabled for
Red, Blue and Yellow at the settings below. If you installed the port from that
release, there is nothing to do here — skip to
[Checking it took](#checking-it-took).

Everything below is for installing into an existing profile, or onto a
Gen1Recomp that did not come from that release.

## 1. Install the mod

Either import `leaf-voxel-0.2.1.zip` through Gen1Recomp's **Mods → Import mod
.zip**, or copy its `LEAF_VOXEL/` folder into the game's user-data mods
directory:

```
<card>/.userdata/mlp1/gen1recomp/love/pokemon-love2d/mods/LEAF_VOXEL
```

`<card>` is whichever SD card holds your Gen1Recomp profile — on the MLP1 that
is the card with a `.userdata/mlp1/portmaster/` folder. Do not hard-code a mount
point: the two slots can swap between boots, so `/mnt/sdcard` is not reliably
the same card twice. To find it over adb:

```sh
for c in /mnt/sdcard /media/sdcard1; do
  [ -d "$c/.userdata/mlp1/gen1recomp/love/pokemon-love2d" ] && echo "$c"
done
```

Upgrading over an existing copy is fine. Installing or removing the mod never
replaces the game archive, and saves and imported data are kept. A mod-change
notice when loading an existing save is expected.

## 2. Enable it

In **Mods**, set **Show for** to the cartridge you play (or **All games**), then
tick **Leaf Voxel** for that cartridge.

**Disable every other voxel renderer first.** Leaf Voxel declares conflicts with
`DRAMALESS_SHAPE`, `DRAMATIC_SHAPE`, `TERRARIUM`, `BATTLE_ART_VOXEL_FORK` and
`potato_voxel`; the launcher marks a conflicting mod **Conflict** instead of
**Ready** while both are installed and enabled.

## Checking it took

Open **Mods** and set **Show for** to **All games**. The card should read
**Leaf Voxel — Ready**, tagged `EXPERIMENTAL` and `GEN 1`, with a tick under
each cartridge you enabled it for.

If the panel says *"No mods installed"*, check the tab strip first: this is a
GEN 1 mod, so the page hides it while a Gen 2 cartridge (Gold, Silver, Crystal)
is selected. **All games** always shows it.

## 3. Settings

### The mod's own options need no changes

Both options it adds already ship at the values in use:

| Option | Value | Note |
| --- | --- | --- |
| `RES` | **1/3** | package default; 1/2 and 1/4 available for comparison |
| `BATTLE` | **LIGHT** | package default; CLASSIC is the original field |

`VOXEL: ON` is not a manual step either — the mod seeds the voxel pipeline into
the save's options when a save is loaded or created.

### Engine settings worth matching

These live in Gen1Recomp's own options, not in the mod, and are what differs
from a stock profile. `scripts/apply-settings.lua` writes exactly this set:

```sh
lua scripts/apply-settings.lua path/to/options.lua --enable-for red
./scripts/apply-settings-adb.sh --write --enable-for red   # over adb
```

It merges into an existing profile, leaves everything else untouched, and
refuses to write if it cannot reproduce the engine's format byte for byte.
Close Gen1Recomp first — the engine rewrites `options.lua` as it exits.

Performance:

| Setting | Value |
| --- | --- |
| FPS cap | **30** |
| Performance | **low** |
| Faithful resolution | **2** |
| Logic clock | **60** |
| Animations | **on** |

Battle presentation:

| Setting | Value |
| --- | --- |
| Battle layout | **wide** |
| Battle fit | **fill** |
| Battle HUD | **extended** |
| Battle style | **shift** |
| Battle background | **white** |

Display and world:

| Setting | Value |
| --- | --- |
| Colours | **ADVANCED** (`redpp`) |
| Void fill | **trees** |
| Video mode | **borderless** |
| UI layout | **dynamic** / letterbox **auto** |
| Screen position | **center**, zoom **0** |
| Ruleset | **gen1_faithful** |

Speeds and volumes are taste and do not affect the renderer.

> **These are not the configuration the published figures were measured on.**
> [HARDWARE.md](HARDWARE.md) records the 0.2.1 battle-presentation run against
> *original* battle layout, *fixed* battle size and *standard* HUD, while the
> table above uses wide/fill/extended. Treat the frame figures as indicative
> for this configuration rather than as measurements of it.

## What the package deliberately does not carry

Mod enablement and the engine settings above live in Gen1Recomp's `options.lua`,
so they cannot be baked into a mod ZIP.

That file is not distributed here on purpose: alongside the settings it holds
playthrough ids, save-slot state, an arena fingerprint, a save-sync display name
and other mods' player ids. Those identify one install and one save, and none of
them belong in a package handed to someone else. Use the applier script above,
or copy your own `options.lua` between your own devices, where those identifiers
are already yours.
