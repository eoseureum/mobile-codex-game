# Background production implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve production time when switching tabs, locking the screen or reopening a saved world, from the first logging camp.

**Architecture:** Replay the existing deterministic quarter-second factory simulation for elapsed time, bounded to the existing 7,200-second allowance. Connect browser visibility/page lifecycle events to idempotent pause/resume methods and use elapsed wall time to recover a suspended frame even when lifecycle events are missed. Retain queued catch-up ownership and world-switch guards.

**Tech Stack:** Godot 4.5, GDScript, JavaScriptBridge, single-threaded Compatibility Web.

**Spec:** Current user request and the behavior decisions in this document; routine implementation decisions were delegated earlier in the conversation.

## Global constraints

- Safari can suspend or discard a tab; continuous JavaScript execution cannot be guaranteed. Reconcile actual elapsed time on return or saved-world selection.
- Apply from stage zero, including restored saves; no save schema or economy changes. Keep legacy offline flags compatible with existing validation.
- Use real inputs, fuel, power, storage limits and transport. Never grant a flat cash or resource reward.
- Only the selected world advances. Preserve title behavior, the two-hour cap, and repeated-focus/world-switch protection.
- No complete rocket campaign timing; use bounded lifecycle and existing regression checks.

## Review focus

- Duplicate blur/hidden events must not overwrite the beginning of an absence.
- A frozen frame without a focus event must recover elapsed time once.
- Nested focus events during catch-up must retain one owner and prevent switching worlds.
- Starting from title or loading a different world must reset frame timing.
- Browser suspension/discard must preserve the active save and allow the chosen city to catch up.

## Task: reconcile elapsed production

**Files:** `scripts/ui/main.gd`, `scripts/ui/paged_panels.gd`, `tests/test_background_production.gd`, `tools/background_web_check.py`, workflow and README.

**Interfaces:** `WorldLibrary.save_world(id, game, saved_at_ms=-1)` accepts the accounted timestamp without changing the file format. Main keeps `_catch_up(seconds)` and adds `_pause_production()` / `_resume_production()` for notifications and browser callbacks. Track `last_frame_at` only for the active world. Save formats and factory `tick()` remain unchanged.

- [x] Add failing native checks: stage-zero 18-second absence yields 3 logs without cash; duplicate pauses retain duration; app pause/resume; missed-event frame gap; chosen-world reload; two-hour cap; real belt sales; storage limits; existing nested focus protection.
- [x] Run Godot 4.5 and confirm the expected missing-production failures.
- [x] Remove the obsolete catch-up unlock gate, normalize lifecycle events, reconcile wall time, and register browser visibility/pagehide/pageshow callbacks. Keep the callback alive and unregister it when Main leaves the tree.
- [x] Make the existing two-hour availability text truthful at early stages; document browser-local replay behavior.
- [x] Run targeted checks, existing start/storage/production/touch regressions and export. Exercise actual Web with a second tab and browser freeze/unfreeze; compare elapsed production, not browser screenshots alone.
- [ ] Obtain independent code review, prepare a PR, wait for CI, and use existing authorization to merge/deploy. Verify the public pack and a bounded background/resume flow.

### Review-driven checkpoint correction

A paused or discarded page can contain an unprocessed frame gap. Save the timestamp represented by the state, rather than the save call's current time. While a queued replay is in progress, retain its last complete checkpoint instead of persisting partial progress with a current timestamp. Three additional checks failed before this correction and pass afterward; the background suite now has 19 checks. An independent reviewer confirmed the original 18-second discarded-page reproduction now restores three logs.

### Verification

Nine focused existing/new suites pass, including background (19), world flow (23), world library (60), title UI (592), and production/touch/income regressions. Full rocket campaigns are not run. Headless Chromium reports both tabs visible; the Web check explicitly freezes the actual runtime and reloads the actual page rather than claiming that changing the headless foreground tab hides it. Physical iPhone Safari validation remains separate.

Actual local Web: a 14.78-second runtime suspension recovered 15.00 simulation seconds; reload and Continue recovered 18.25 seconds after 18.29 seconds elapsed. Real camp outputs increased with no inventory collection or money granted, and no engine errors.
