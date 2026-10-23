# Start screen and saved worlds

Godot 4.5, iPhone Safari, single-threaded Web. The user delegated routine design choices and requests a first screen with New Game and Continue; authentication is deferred.

## Behavior

- Every normal launch opens a pixel-art title screen without advancing or saving an unselected world.
- New Game creates a distinct random world with exactly the central sales hub and one logging camp, ₩0, an empty bag, no completed logs, and elapsed time zero.
- Continue shows independently saved worlds with their name, money, industry and last saved time; selecting one resumes that world and applies its offline allowance only then.
- Existing single-city saves are copied once into a deterministic legacy slot; preserve their contents and original save timestamp and keep the original file intact.
- Each world has its own validated atomic save and fallback backup. Invalid entries cannot block other worlds. No deletion or account system in this change.
- Management returns to the title after saving. Backup import creates a new world slot rather than overwriting another world.

## Architecture and alternatives

Choose a separate per-world file library over one monolithic save file: a damaged world stays isolated and existing validation remains reusable. Keep the existing SaveStore format and default path; allow an explicit path for library slots. Keep title UI as an independent Control and integrate it in Main with an explicit game_started guard and disabled map input while the menu is visible.

## Implementation

1. Storage module and targeted tests: configurable SaveStore path, independent slots, list/load/save/import, deterministic migration, safe IDs, bad-file isolation and fallback recovery.
2. Independent title UI: existing original pixel art, large touch controls, responsive non-scrolling paged world list and clear empty/loading/error states.
3. Main integration: initial menu, fresh/reset semantics, active world autosave, selected-world catch-up, safe return, separate import slot, focus/visibility guards.
4. Verification: targeted storage and menu lifecycle tests, existing Godot 4.5 regressions without rocket campaigns, font coverage, Web touch flow (multiple worlds, reload, selection and reset isolation), mobile screenshots, read-only review, PR/CI and authorized Pages deployment.

## Verification notes

- World library: 60 checks; title UI: 592 checks; integrated start/continue/import/focus lifecycle: 23 checks, all passing on Godot 4.5.
- Existing focused regressions: 907 upgrade accuracy, 115 sales-hub logic, 134 sales-hub UI, 252 font checks; the 16 other existing short suites passed. Historical full campaign runs were intentionally omitted at the user's request.
- Reproduced and fixed nested focus catch-up crossing into another world; one coroutine now owns the queued catch-ups and transitions wait for completion.
- Reproduced Resume freeing its emitting button; retired rows hide immediately and are freed after signal delivery. The UI regression now uses the actual button signal.
- Actual Web touch checks covered zero-inventory New, six independent slots, legacy backup import, reload and selection of an older saved city; the final bounded title/continue smoke passed after the UI disposal correction without engine errors.
- Browser storage remains local to the device/profile; authentication is deferred.
