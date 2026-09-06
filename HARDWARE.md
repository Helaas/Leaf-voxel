# MLP1 performance — Leaf Voxel 0.1.0

Test date: 2026-09-06. Experimental overworld renderer, based on Dramaless Shape commit `97ca3e1` (2.0.4).

## Setup and method

- Miniloong Pocket 1: RK3566, Mali GPU, 978,824 kB RAM, Linux 5.10.209.
- Leaf's PortMaster LÖVE 11.5 runtime, GLES/Wayland, fullscreen 960×720; Gen1Recomp 0.2.56 with the Leaf input patches.
- Voxel world at **320×240**, nearest upscaling; UI at 960×720. `VOXEL: ON`, `RES: 1/3`, engine cap 60 FPS. Shadows and water reflections disabled.
- CPU/GPU governor and clocks were left as found. GPU samples report 800 MHz. Leaf launcher suspended during direct runtime tests; existing uipad left active.
- Stock 262,140 kB zram **and an existing 786,428 kB test swapfile** were enabled. These runs do not establish stock-swap-only behavior. The game process's `VmSwap` and system paging counters are recorded separately.
- User-imported Red data and saves were copied **on the device** into a separate `leaf-voxel-test` data root. No ROM, derived asset cache or save was copied off the device or included in the fork. Benchmarks never save.
- `scripts/benchmark.lua` loads the copied bedroom save, enters the named map after 15 seconds, and alternates movement direction every two seconds for a 120-second run. Wild encounters are suppressed **only by this test driver** to keep the graphics workload in the overworld. This is a short repeatable movement loop, not a traversal of the whole map or a gameplay/battle benchmark.
- Frame times are actual elapsed time between driver frames, reported in non-overlapping five-second windows. The engine's driver advances game logic by 1/60 per frame: runs below 60 FPS slow simulated time, so frame throughput alone must not be mistaken for correct gameplay speed.
- `scripts/sample-device.sh` records RSS, process swap, system paging counters, free memory and GPU load every two seconds. RSS numbers below use MiB (kB / 1024). Captures use the device's KMS scanout.

## Results

The final renderer clears the reference project's sustained **30 FPS** target on these two short outdoor routes, with no OOM or paging during the sampled periods. It does **not** maintain 60 FPS in the forest or the city.

| Final scene | Loaded five-second FPS windows | Largest window p95 frame time | Sampled peak RSS | GPU p75 | Process swap / system paging |
| --- | ---: | ---: | ---: | ---: | --- |
| Viridian Forest, original rounded trees | 52.33–54.32 (median 53.50) | 26.15 ms | 135.7 MiB | 97% | 0 / none |
| Celadon City, rounded trees + flat building surfaces | 48.48–55.91 (median 52.94) | 26.74 ms | 244.1 MiB | 88% | 0 / none |

Forest frame windows use t≥30s; city windows use t≥60s. Both enter the named map at t≈15s. Forest device sampling covers only the final 30 seconds (15 samples), so its RSS figure is **not a whole-run peak**. City has 58 samples spanning almost the full run. The city route briefly crosses Route 16 and returns while neighbors build; its slowest five-second window was 39.50 FPS, with a 119.88 ms worst frame during cold work. Forest's first voxel window was 53.07 FPS, with a 172.02 ms cold-build hitch. Both current-map meshes were visible within the first five-second window after entry.

The starting bedroom also renders, but startup/restore is excluded from the outdoor figures. The 120-second runs exit normally. Evidence: [forest frames](evidence/forest-rounded-final.log), [forest device samples](evidence/forest-rounded-final-device.log), [city frames](evidence/celadon-trees-final.log), [city device samples](evidence/celadon-trees-device.log).

![Rounded forest trees on MLP1](evidence/mlp1-forest-rounded.png)

## What changed

Removed voxel battles and companion/Stadium integrations, predictive precaching, the previous neighborhood's retained meshes and dense 3D grass. Trees and stumps preserve the original rounded hulls; one mesh is shared per distinct drawing, and only placements intersecting the camera frustum are drawn. Bins and potted plants use textured boxes. Buildings keep their authored footprints and textures, with flat roof and wall surfaces; pixel slopes and recessed windows are removed. Small furniture retains its detailed models.

The world shader is a small textured vertex-shading pass. Mesh generation packs binary vertex data through LÖVE's sandbox-permitted data API and uploads bounded batches. Outdoor buildings are assembled directly from tile-sized quads, avoiding a scan through the solid voxel volume. The retained furniture generator yields inside its expensive inner loops.

Earlier cuts boxed every tree and reached 60 FPS in the forest and towns, but lost the recognisable silhouettes. The final version restores the original rounded trees and accepts the measured frame-rate cost. Sharing their meshes avoids duplicating millions of vertices across the map; frustum tests exclude offscreen placements.

The building change remains: a diagnostic Celadon run with detailed voxel buildings took roughly 90 seconds after entry before its mesh appeared. Direct roof/wall surfaces reduced that to under five seconds. The retained `celadon-before-building-cut` logs use different tree geometry from the final measurements and are diagnostic context only.

## Earlier baseline

The separate [Leaf-Gen1Recomp hardware report](https://github.com/Helaas/Leaf-Gen1Recomp/blob/main/HARDWARE.md) records Dramaless 2.0.4 exhausting stock swap and being OOM-killed after roughly 90 seconds; with additional swap it survived but paged in 27/45 samples with GPU p75 99%. PotatoVoxel's low preset also saturated the GPU and became unresponsive. These are prior observations from that project's local `HARDWARE.md`, using its own route and procedure, rather than an A/B run of this driver.

## Normal controller smoke test

The game was also launched without `POKEPORT_DRIVER`, using the isolated data root. The existing uipad navigated the title menu, selected Continue, accepted the expected mod-change notice reached the voxel bedroom, moved with the D-pad and opened the full-resolution Start menu. This checks the normal frame loop and controller path separately from scripted throughput.

## Limits

Cold meshes are generated in the background; the engine displays its 2D fallback until the current map's mesh is ready, then the voxel view appears. Individual cold-build frames can still hitch. This prototype has not been played through the full game, tested with other mods, or checked across every palette, map, camera angle and resolution setting. Battles intentionally retain the engine's original 2D rendering.
