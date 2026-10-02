# Cosy Island

A cosy island life game about crafting and decorating, made with Godot 4.

![Island overview](docs/screenshots/overview.png)

| Golden hour | Night | Time travel |
| --- | --- | --- |
| ![](docs/screenshots/golden_hour.png) | ![](docs/screenshots/night.png) | ![](docs/screenshots/time_travel.png) |

## Playing

1. Install [Godot 4.7](https://godotengine.org/download) (the standard build, not .NET).
2. Open this folder in Godot and press Play, or run `godot --path .` from here.

Add `-- --new` to start a fresh island, or `-- --seed=123` for a specific one.

### Controls

| Action | Controller (Switch layout) | Keyboard |
| --- | --- | --- |
| Move | Left stick | WASD / arrows |
| Use tool, shake tree, place | A | E / Space |
| Run, cancel | B | Shift / Esc |
| Pick up | Y | F |
| Pockets | X | Tab / I |
| Switch tool | D-pad left/right | Z / C |
| Rotate while placing | R | R |
| Island Phone (time travel, save) | + | Esc / P |

## What's in so far

- A random island from a seed: beach, cliffs, river with a bridge, ponds, ramps,
  a native fruit and flower.
- Chop wood, shake trees for fruit and branches, hit rocks for stone, clay and iron
  (one rock a day gives acorns).
- Pockets with stacking items and tools that wear out.
- Grid placement: pitch your tent anywhere flat.
- Real-time clock with day and night, and time travel from the Island Phone.
- Autosave.

See [docs/DESIGN.md](docs/DESIGN.md) for the full plan.
