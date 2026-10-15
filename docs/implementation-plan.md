# Implementation plan

1. Write a Godot integration runner checking centered spawn, target arrival,
   retargeting, touch/mouse coordinates after camera movement, solid tile collision,
   and portrait/landscape resize. Run against the empty scene to establish failure.
2. Implement Player, tile map, Main and passive HUD; run physics/input checks.
3. Configure single-threaded Web export and safe browser layout. Add PR CI import,
   tests and export without deploying PRs. Run Godot 4.5 import and web export.
4. Serve exported files locally and exercise desktop/mobile browser input and
   rotation. Record evidence and limitations in docs/validation.md.
5. Review diff, commit on feat/touch-topdown-web, push and create PR into main.
   Do not merge or enable auto-merge.
