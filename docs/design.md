# Touch exploration prototype

Godot 4.5 / GDScript / Compatibility, targeting iPhone Safari and desktop web.
The existing 960×540 reference viewport remains the landscape baseline; portrait
uses a 540×960 baseline so controls and instructions stay readable. Expand the
visible world when the screen aspect differs, without distorting shapes.

- Reusable Player scene: CharacterBody2D, circle collider, child Camera2D.
- Touch-down or left-click sets a world-space destination using the inverse
  canvas transform. Only the first finger controls movement. No drag or pathfinding.
- Move at constant speed with move_and_slide; cap the last step to avoid overshoot.
  Stop on arrival or after 0.2 seconds blocked, and accept a new destination anytime.
- TileMapLayer: 40×28 cells, 48px tiles, grass, paths and solid stone tiles.
  Border and obstacles use TileSet physics. Spawn in an open central clearing.
- Simple drawn explorer, destination ring, and passive responsive instructions.
- Single-threaded web export with browser resize and touch-action disabled.
  Use the default web shell's safe viewport (without viewport-fit=cover).
  No C#, GDExtension, external assets or runtime dependencies.

Verification: real physics/input integration tests in Godot 4.5 headless; import
and release export; browser smoke checks for desktop click, portrait touch,
resize, rendering and console errors. Actual iPhone Safari needs a real device.
