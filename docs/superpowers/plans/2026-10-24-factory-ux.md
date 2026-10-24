# Factory UX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Implement the fifteen approved UX, logistics, balance and rocket improvements.

**Architecture:** Retain the existing factory tick and save schema. Add small presentation/diagnostic helpers and keep commands authoritative. Changes to routes and cargo remain atomic and conserve resources.

**Tech Stack:** Godot 4.5 / GDScript / Compatibility Web.

**Spec:** docs/superpowers/specs/2026-10-24-factory-ux-design.md

## Global Constraints
- Korean touch UI; actions on the right, no added repetitive confirmations or quests.
- Retain existing save worlds, cash-only construction, unlimited central sales, two-hour catch-up.
- No third-party dependencies, C#, GDExtensions, secrets or generated game caches committed.

## Review Focus
- Adjacent links, hub footprint edges and paused targets obey the same transport ports as routing.
- Splitter reconfiguration preserves the other live port and rejects duplicate directions atomically.
- Cargo recovery and selective rocket delivery never duplicate, destroy or over-deliver items.
- Small portrait and wide landscape screens fit rocket information and controls without shifting page anchors.
- Save reload during/after launch retains completion and never restarts the transient animation.

### Task 1: Atomic logistics and diagnostics
Files: core/factory.gd, core/world_map.gd, core/world_rules.gd, new core/factory_insight.gd, tests/test_factory_ux.gd.
Interfaces: command rotate/setSplitPort/recoverCargo; Insight.issue(game,e), next_stage(game), observe(game,e).
- [x] Add and run failing regression cases for direct links, split ports, blocked queue status, recovery and completed-material rocket queues.
- [x] Implement commands and route preservation, actionable diagnostics and transient observed output accounting.
- [x] Run new suite plus conveyor, world, central sales and save tests; commit.

### Task 2: Stable controls, visible rules and economy information
Files: ui/main.gd, facility_tabs.gd, production_card.gd, paged_panels.gd, recipe_preview.gd; tests/test_factory_ux_ui.gd.
Interfaces: directional picker with independent splitter port selector, Insight fields consumed by cards and industry.
- [x] Add failing interaction/layout checks for atomic direction selection, price totals, cumulative counts, next era, stable build page geometry and all six rocket rows.
- [x] Implement compact stable cards, inline status and nominal/observed production, contextual city/energy/rocket information.
- [x] Run UI, layout, start menu and save regression suites; commit.

### Task 3: Strategic map and placement feedback
Files: ui/city_map.gd, world_overview.gd, main.gd; tests/test_factory_ux_ui.gd.
- [x] Check low-zoom selection cannot accidentally build and filters retain hidden-resource rules.
- [x] Add strategic zoom, resource/stopped filters, placement ports/input strip, clear stop indicators.
- [x] Verify pinch gestures and inspect portrait/landscape exported Web screenshots; commit.

### Task 4: Industrial economy
Files: data/catalog.json, tests/test_economy_curve.gd.
- [x] Pin modest raw-iron step, positive processing margins, affordable staged expansion and billion-scale launch price.
- [x] Reduce extreme industrial sale jumps with corresponding building/upgrade cost adjustments; preserve starter prices and inventory/cash.
- [x] Validate representative income/cost ratios and existing early-price regressions; commit.

### Task 5: Rocket delivery and ending
Files: ui/launch_sequence.gd, main.gd, city_map.gd, tests/test_factory_ux_ui.gd.
- [x] Verify launch action only becomes active when delivered quantities meet every requirement, final state persists and replay on reload is absent.
- [x] Add skip-able ignition/ascent and compact first-launch city record; continue city afterwards.
- [ ] Run final Web touch checks, request one fresh whole-branch review, fix material findings, prepare PR and deploy under existing session authorization.
