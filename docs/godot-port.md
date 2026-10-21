# Rust City Godot port

Port the existing pure factory game to native Godot 4.5-compatible GDScript, preserving the 500 starting balance, gradual production upgrades, actual directional material transport, protected reserves, independent operating-income upgrades, managers, automatic shipments, city construction, power, industrial progression and rocket launch. A real Godot scene renders a warm draggable grid and responsive touch controls. Production updates text/progress inside stable controls rather than rebuilding the panel.

The existing repository requires Compatibility rendering, a 960×540 reference viewport, single-threaded Web exports and review before merging. Preserve that contract; use responsive layout for portrait phones. Build and test on feature branch; open a reviewable PR rather than merging it. Existing private browser game remains available.

Core simulation is separate from scenes. Data and baseline campaign checkpoints are exported from the current JavaScript factory, then committed as ordinary JSON. A paid, time-stamped reference command trace verifies the GDScript simulation through a rocket launch without granting currency or inventory. New game, persistence, invalid imports, reserves, blocked production, cancellation, power and offline/resume receive direct tests.

Godot save format accepts the current factory JSON backup so existing cities can move over explicitly. It never accesses or overwrites Safari's old browser storage. Native saves use user:// with a previous-good backup, autosave and visibility handling. Export/import are explicit user actions. Offline production unlock/cap remains identical; loaded progress is simulated with the same fixed ticks.

GitHub Actions runs headless import and tests on pull requests. Main builds publish the single-threaded Web artifact through the repository's existing Pages workflow after review/merge. No native plugins, C#, secrets or engine caches are committed. Physical iPhone Safari is reported separately from headless/browser validation.
