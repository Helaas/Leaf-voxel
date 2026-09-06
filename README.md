# Leaf Voxel

A small MIT-licensed fork of [Dramaless Shape](https://github.com/artyrambles/DRAMALESS_SHAPE), targeting Gen1Recomp on the Miniloong Pocket 1 (RK3566, 1 GB RAM). Independent integration by [Helaas](https://github.com/Helaas).

**Experimental.** A voxel overworld and a lightweight battle stage, using Gen1Recomp's original Pokémon sprites, menus and move effects. Hardware measurements and the exact tested scope are recorded in [HARDWARE.md](HARDWARE.md).

Trees and stumps keep their rounded forms, using shared meshes and screen culling. Bins and potted plants use textured boxes; tall grass stays flat. It uses a small textured shader, and a world canvas at one third of the display dimensions. Shadows, water reflections, tilt shift, supersampling, wireframe, curvature, first/third-person movement, and window-light effects are disabled. Buildings use flat roofs and textured walls, while small furniture keeps its detailed models. Menus and dialogue remain at full resolution. Stadium and companion integrations remain removed.

**LIGHT battles** use a static, shallow stage rendered once and cached. Pokémon stay at the engine's normal battle anchors, preserving native sprite animation and move effects. Classic and wide layouts are supported. This avoids rendering an entire voxel map during a battle.

Door fades now wait for the destination mesh before revealing it, with a four-second maximum extra hold and a short fade-in. Revisiting the last map can reuse its meshes: one departed map is retained only if its vertex buffers fit within 12 MiB (LÖVE also holds a CPU copy; this is not a total RAM cap). Trees and terrain now select the same cached mesh variant when crossing map boundaries. Cold neighbouring maps can still appear as their builds finish.

Mesh uploads use LÖVE's packed data API because Gen1Recomp's mod sandbox does not expose FFI. Outdoor buildings use direct roof and wall surfaces. The retained furniture generator yields within its inner loops to keep input responsive.

## Install

Requires Gen1Recomp with mod API 2 and LÖVE 11.5. Tested engine: **0.2.56**, using [Leaf-Gen1Recomp](https://github.com/Helaas/Leaf-Gen1Recomp) and Leaf's PortMaster runtime.

1. Build with `python3 scripts/package.py`, or use a provided ZIP.
2. Import the ZIP through Gen1Recomp's mod manager, or extract its `LEAF_VOXEL` folder into the game's user-data `mods` directory.
3. Disable other voxel renderers and enable **Leaf Voxel** for your cartridge.
4. Use **VOXEL: ON** in Options. **RES: 1/3** is the starting point; 1/2 and 1/4 remain available for comparison. The frame cap belongs to Gen1Recomp.
5. **BATTLE: LIGHT** enables the small stage by default. Choose **CLASSIC** for the original field. Turning VOXEL off restores the original presentation throughout.

Installing or removing the mod does not require replacing the game archive. Keep your existing saves and imported data. A mod-change notice on loading an existing save is expected.

No ROM, imported asset cache, save, or replacement Pokémon artwork is distributed. Players supply their own compatible game dumps.

## Development

- `lua tools/run_tests.lua` checks packed vertex order, upload boundaries, eviction of obsolete jobs, scenery simplification, building surfaces, shared tree meshes and frustum culling. Tests use Lua 5.3+ for `string.pack`; the mod runs under LÖVE's LuaJIT.
- `scripts/benchmark.lua` is an engine `POKEPORT_DRIVER`. Use it only with a separate test copy of the user's data; it loads that copy and drives a repeatable route without saving. Its driver clock requires a 60 FPS cap.
- `scripts/benchmark-scenes.lua` tests door fades and cached returns; set `LEAF_BENCH_KIND=battle` for native Surf/Bubblebeam, classic/wide layouts and the LIGHT/CLASSIC toggle. It creates a test party in memory only and never saves.
- `python3 scripts/package.py` builds a deterministic source-only ZIP and SHA-256 file.

Forked from upstream commit `97ca3e1` (2.0.4 development line). The MIT license and upstream attribution are retained. See [CREDITS.md](CREDITS.md) and the inherited [CHANGELOG.md](CHANGELOG.md) for the original work.
