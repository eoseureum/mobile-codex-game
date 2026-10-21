# Open Resource World Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan in this session. The user has already asked to apply the discussed changes and delegated routine implementation decisions.

**Goal:** A playable large random resource map with permanent clearing, physical transport and the existing pixel floating UI.
**Architecture:** Keep legacy factory behavior behind absence of `state.world`. Add `world_map.gd` for deterministic terrain/quotes/routes and `world_rules.gd` for new-world commands/local warehouse economics. The factory exposes common simulation methods and dispatches world behavior. Save validation and UI support both modes.
**Tech Stack:** Godot 4.5 GDScript, Compatibility, single-threaded Web.
**Spec:** `docs/superpowers/specs/2026-10-21-open-world.md`.

## Global Constraints
- Preserve Godot 4.5, 960×540, touch targets ≥48 CSS px and single-thread Web.
- No silent deletion/migration of saves; preserve reference-campaign behavior.
- New production must not bypass physical logistics; clearing/route commands are atomic.

## Review Focus
- Different random seeds must preserve a viable starting line and nearby progression resources.
- Invalid and stale route/clear commands must neither spend money nor duplicate rewards.
- Disconnected warehouses/projects/rocket pads must receive no remote materials.
- Malformed world saves must fail safely before simulation sees bad types or positions.
- Wide/short phone layouts, terrain taps, route cancellation and real touch pan must remain usable.

### 1. World terrain and placement
Files: `scripts/core/world_map.gd`, `tests/test_world.gd`.
Interfaces: generate(seed), resource_at(world,x,y), valid_model(world), clear_quote(game,from,to), route_quote(game,from,to,clear).
- [x] Write/run failing tests for deterministic terrain, guaranteed starter cells, seed variation and map bounds.
- [x] Implement spaced clusters and two route previews; test unknown/occupied terrain and maximum route/area size.

### 2. Factory rules and physical inventory
Files: `scripts/core/world_rules.gd`, `scripts/core/factory.gd`, `tests/test_world.gd`, legacy `tests/test_runner.gd`.
Interfaces: fresh(now,open_world,seed), stock(r), material_store/remove_materials, world commands, local warehouse tick and stage progression.
- [x] Explicitly run reference campaign in legacy mode; baseline stays green.
- [x] Implement source-bound extraction, local inventory, delivered-only income and physically supplied projects/rocket.
- [x] Test disconnected production has no income, distant warehouse isolation, build locations, material conservation, atomic clear/routes and early pacing.

### 3. Persistence and migration
Files: `scripts/core/save_store.gd`, `tests/test_world.gd`.
- [x] Extend validation only after strict world structure checks; preserve original legacy validation.
- [x] Test both save modes, malformed terrain/stores/coords and next-tick roundtrip parity.
- [x] Add explicit migration command preserving existing resources and progression; test conservation and source consistency.

### 4. Touch UI and visible world
Files: `scripts/ui/main.gd`, `city_map.gd`, `pixel_art.gd`, new `world_overview.gd`, `tests/test_ui_layout.gd`, `tools/web_check.py`.
- [x] Render actual resource tiles and boundary-aware pan; retain floating controls and add clickable overview.
- [x] Add two-endpoint route/clear previews with confirmation, resource-specific construction and local warehouse inspection.
- [x] Replace world district purchases with industry information; preserve legacy UI and offer explicit migration.
- [x] Regenerate Korean font subset for new strings; verify real portrait/landscape WASM interactions and persistence.

### 5. Whole-branch verification and GitHub
- [x] Run Godot 4.5 import, legacy campaign, world suite and all UI checks.
- [x] Export Web and inspect screenshots/console; document migration and local controls.
- [ ] Push an exact review branch/PR including pending pixel work. Confirm Actions; deployment remains subject to runtime approval.

## Validation record

Godot 4.5: legacy paid reference campaign 156 checks; open-world terrain, paid mine growth, conservation and saves 15,389 checks; floating/tool layouts 78 checks; stable-production UI check passed. Single-thread Web export succeeded. Actual Chromium WASM touch route preview/confirmation, backup, persistence and both orientations passed with no script/console errors. GitHub CI remains the final review check. Physical iPhone Safari remains untested.
