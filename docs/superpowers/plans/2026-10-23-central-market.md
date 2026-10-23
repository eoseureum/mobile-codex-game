# Central Market Implementation Plan

> **For agentic workers:** Use the scoped core/UI tasks below, then one independent review of the integrated branch. Checkboxes record verified deliverables.

**Goal:** Replace warehouses and onsite income with collection, a personal bag and conveyor sales at one central hub.

**Architecture:** A versioned `sales_hub.gd` owns setup, migration, collection and bag sales. Existing production/logistics use footprint-aware indexing; UI reads the same commands and inventory model.

**Tech Stack:** Godot 4.5, GDScript, single-threaded Compatibility Web, touch UI.

**Spec:** `docs/superpowers/specs/2026-10-23-central-market-design.md`

## Global Constraints

- Preserve historical save validation and resources; no reset or full rocket benchmark.
- World building/project/research costs use cash; production and rocket recipes remain physical.
- Central hub occupies (65,63) through (67,65), is unique and permanent.
- Keep compact floating panels, stable controls and Korean glyph coverage.

## Review Focus

- Migration repeated after reload must not duplicate stock, refunds or hubs.
- All nine footprint tiles must block building and every perimeter must accept deliveries.
- Collection and selling must never credit the same item twice, including malformed commands.
- Zero-cash first-camp play must reach the first belts through real collection and sales.
- Old construction cargo and active shipments must survive the warehouse removal.

### Task 1: Versioned economy and footprint

Files: `scripts/core/sales_hub.gd`, `factory.gd`, `world_rules.gd`, `world_map.gd`, `tests/test_sales_hub.gd`.
Interfaces: `game.central_sales() -> bool`, `game.sales_hub() -> Dictionary`, `game.entity_rect(e) -> Rect2i`, `game.upgrade_world() -> bool`; commands `collect {entityId}`, `sellInventory {entityId, resource?}`, existing `buildRoute`.
- [ ] Write and run failing tests for no production income, collect/sell conservation, cash-only building/projects, nine-cell occupancy and conveyor arrivals.
- [ ] Implement setup, 8/s central sales, commands and footprint-aware routing/indexing. Test malformed requests and permanent-hub restrictions.

### Task 2: Save upgrade and recovery

Files: `sales_hub.gd`, `save_store.gd`, `tests/test_sales_hub.gd`, historical fixture helper.
- [ ] Test stocked warehouses, accepted shipping cargo, unfinished projects and occupied hub area; test repeated upgrade and save round trips.
- [ ] Upgrade only validated actual loaded/imported worlds, preserve historical regression fixtures, validate new hub state and project semantics.

### Task 3: Touch UI and visual hub

Files: `scripts/ui/main.gd`, `production_card.gd`, `opening_ux.gd`, `paged_panels.gd`, `facility_tabs.gd`, `city_map.gd`, `world_overview.gd`, `facility_motion.gd`, `pixel_art.gd`, new UI tests and browser check.
- [ ] Test collection/sale buttons, hidden warehouse/orders controls, compact stable cards and footprint selection.
- [ ] Add fixed collection controls, bag, hub sale stacks, central route suggestion and 3×3 pixel building. Run mobile layouts and Korean font check.
- [ ] Add first-kind production-recipe preview with install/cancel, atomic cancellation and linked/inline coverage; add optional repeat recipe inspection before later placement. Preserve direct later construction.

### Task 4: Integrate and deploy

Files: `.github/workflows/deploy.yml`, regression tests/fixtures, focused browser check.
- [ ] Preserve historical baselines with explicit historical fixtures, add new default-economy coverage and update Web smoke checks.
- [ ] Run targeted core/save/UI tests and required modern regressions, export Web and exercise actual touch collection, manual sale and belt automation.
- [ ] Independent whole-change review; fix substantive findings, prepare PR, merge after CI, verify public build. No full rocket simulation.
