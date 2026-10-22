# Factory interaction, transport and pacing implementation plan

> **For agentic workers:** Use executing-plans for the core/UI changes; independent conveyor, font and economy domains run concurrently under dispatching-parallel-agents.

**Goal:** Address the ten reported problems, preserving saved cities and providing a measured 3–4 hour first-rocket reference.

**Architecture:** Keep game commands authoritative. Improve the existing world mode, retaining the historical district catalog for deterministic legacy compatibility. Draw conveyor topology from connection masks, and make visual cargo account for pending transfers exactly once. UI actions use the existing command API; routine actions require no modal confirmation. Build the font from both code and catalog labels. Record a command-based, paid campaign simulation with an explicit operating policy.

**Tech Stack:** Godot 4.5 GDScript, single-threaded Web, Python/fontTools/Playwright test tools.

**Spec:** User's ten-point bug/pacing report in this conversation.

## Global constraints
- Preserve cash, production history, inventories and existing cities; never reset a user's save.
- Upgrades cost cash; construction can cost materials. Keep start funding limited to one logging camp.
- First-rocket target: 180–240 in-game minutes for the documented normal management policy; label optimized runs separately.
- Maintain 48px touch targets, compact floating cards and pinch controls.
- Keep confirmation only for save replacement and new-city reset, where data would be discarded.

## Review focus
- Removing the only logging camp must allow a valid save and affordable recovery.
- Rotating a loaded belt preserves its cargo and updates its visible shape immediately.
- All 16 port masks, their orientations and splitter outputs render without phantom branches.
- One transferred item must never appear as both queued and in flight.
- Catalog-only Korean syllables must exist in the committed font.

## Tasks
1. Core ownership/upgrade rules (`factory.gd`, `world_rules.gd`, `save_store.gd`, `test_factory_polish.gd`): failing tests for starter removal/recovery, income upgrade effectiveness and cash-only upgrades; then implement and validate save round trips. Isolate historical district catalog.
2. UI actions (`main.gd`, `production_card.gd`, `facility_tabs.gd`): expose rotation/removal, execute routine build/upgrade/remove without modal confirmation, and show warehouse storage/throughput changes as before→after values. Test actual button activation and compact geometry.
3. Conveyor visuals (`pixel_art.gd`, `conveyor_view.gd`, shape tests/atlas): generate textures from all connection masks; group actual queued units after subtracting incoming visual units. Root integrates the draw loop and caps transfer visuals below a simulation tick. Test icon conservation and orientation.
4. Font pipeline (`build_font.py`, font test, font asset): include data JSON strings and all scripts; verify every displayed Korean character has a glyph, including 나무꾼 휴게소 and 구리괴.
5. Pacing (`catalog.json`, command-based campaign tool/report): provide early cash reinvestment, gradual growth and measured 180–240 minute progression without injected money, materials or unlocks. Report time, spending, cash and throughput at checkpoints; distinguish policy assumptions from human play data.
6. Integration: native regressions and actual Web touch tests, paid first-line flow, rotation/removal, no routine modals, transport capture and glyph review. Prepare PR; check CI and deploy the approved ongoing game update, then verify the public build.

## Execution record
- Core regression first failed10/14checks (cash-only upgrades, pioneer income, removal/recovery); implementation passed14/14. Historical-order compatibility failed1/20then passed20/20; original gifted-camp recovery failed2/24then passed24/24.
- Conveyor topology regressions passed293checks across16masks, rotations, transparent edges and splitter outputs; cargo/merge tests passed26checks.
- Font regression identified seven missing Korean syllables from catalog-only labels. Rebuilt font passed233checks with system fallbacks disabled.
- Native integration:15suites,14,628checks passed before the final late-industry retune; impacted world suites rerun after each rate change. UI_CHECK passed.
- Real single-threaded Godot Web: paid construction/linked expansions, automatic sales, validated backups and reload, conveyor merging/cargo, one-touch rotation/removal, and pinch/pan all passed in a touch-enabled390×844Chromium viewport. This is browser automation, not a physical iPhone session.
- Routine build/remove actions execute directly; backup replacement/new-city reset retain confirmation because they replace saved progress.
- Ruling: the last pioneer camp recovers enough construction value to rebuild, while normal buildings refund50%; original gifted camps receive that construction value once. This prevents a cashless, productionless city after removal; the tradeoff is a smaller relocation penalty for this one income source.
- Ruling: preserve historical district data separately and accept exact historical shipment quotes during validation. Existing districts and already accepted rewards remain deterministic while current world production is retuned.
- Ruling: campaign measurements describe a documented paid operating policy, not measured human playtime or a proven global optimum. No artificial reaction delay is used to force the target.

- Final review: three Important recovery edges reproduced (legacy camp removed first; no-plank sawmill reconstruction; editing remaining factory after forest removal). Single fix pass: six regression failures observed, then36/36core checks passed. Full final native integration:15suites/14,644checks passed.
- Final catalog hash:b76ce4e70fac40ba2ec45eb9aa444fd8a207e033591b919caebf12973c40a9ba. Two paid zero-delay sequential campaigns completed in235m15.5sand235m2.75s. This is a simulated policy reference;7kcommands include automatic route housekeeping, so human playtime may differ.

- Publication scope: automatic approval rejected publishing a full campaign city snapshot as potentially private game-state data. Both full snapshots were excluded from the public change; local files are preserved. Code, aggregate results and replay command traces remain the verification artifacts.
