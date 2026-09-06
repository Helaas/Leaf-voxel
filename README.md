# Leaf Voxel

A small MIT-licensed fork of [Dramaless Shape](https://github.com/artyrambles/DRAMALESS_SHAPE), targeting Gen1Recomp on the Miniloong Pocket 1 (RK3566, 1 GB RAM). Independent integration by [Helaas](https://github.com/Helaas).

**Experimental.** This is an overworld renderer. Battles use Gen1Recomp's original 2D presentation. Hardware measurements and the exact tested scope are recorded in [HARDWARE.md](HARDWARE.md).

The initial cut removes voxel battles, Stadium integration, the companion API, predictive area precaching, and the previous neighbourhood's mesh cache. Trees and stumps keep their rounded forms, using shared meshes and screen culling. Bins and potted plants use textured boxes; tall grass stays flat. It uses a small textured shader, and a world canvas at one third of the display dimensions. Shadows, water reflections, tilt shift, supersampling, wireframe, curvature, first/third-person movement, and window-light effects are disabled. Buildings use flat roofs and textured walls, while small furniture keeps its detailed models. Menus and dialogue remain at full resolution.

Mesh uploads use LÖVE's packed data API because Gen1Recomp's mod sandbox does not expose FFI. Outdoor buildings use direct roof and wall surfaces. The retained furniture generator yields within its inner loops to keep input responsive.

## Install

Requires Gen1Recomp with mod API 2 and LÖVE 11.5. Tested engine: **0.2.56**, using [Leaf-Gen1Recomp](https://github.com/Helaas/Leaf-Gen1Recomp) and Leaf's PortMaster runtime.

1. Build with `python3 scripts/package.py`, or use a provided ZIP.
2. Import the ZIP through Gen1Recomp's mod manager, or extract its `LEAF_VOXEL` folder into the game's user-data `mods` directory.
3. Disable other voxel renderers and enable **Leaf Voxel** for your cartridge.
4. Use **VOXEL: ON** in Options. **RES: 1/3** is the starting point; 1/2 and 1/4 remain available for comparison. The frame cap belongs to Gen1Recomp.

Installing or removing the mod does not require replacing the game archive. Keep your existing saves and imported data. A mod-change notice on loading an existing save is expected.

No ROM, imported asset cache, save, or replacement Pokémon artwork is distributed. Players supply their own compatible game dumps.

## Development

- `lua tools/run_tests.lua` checks packed vertex order, upload boundaries, eviction of obsolete jobs, scenery simplification, building surfaces, shared tree meshes and frustum culling. Tests use Lua 5.3+ for `string.pack`; the mod runs under LÖVE's LuaJIT.
- `scripts/benchmark.lua` is an engine `POKEPORT_DRIVER`. Use it only with a separate test copy of the user's data; it loads that copy and drives a repeatable route without saving. Its driver clock requires a 60 FPS cap.
- `python3 scripts/package.py` builds a deterministic source-only ZIP and SHA-256 file.

Forked from upstream commit `97ca3e1` (2.0.4 development line). The MIT license and upstream attribution are retained. See [CREDITS.md](CREDITS.md) and the inherited [CHANGELOG.md](CHANGELOG.md) for the original work.
