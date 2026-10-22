# Opening prices and campaign pacing

Sawmill construction is **700 cash**, within the requested 500–800 range. Its first connecting belt costs75, so the complete linked purchase is775. The linked shipping warehouse costs375 (300+75).

## Cash prices

| Facility | Previous | Current |
|---|---:|---:|
| 제재소 | 1,500 | 700 |
| 컨베이어 | 100 | 75 |
| 창고 | 450 | 300 |
| 광산 | 20,000 | 12,000 |
| 구리 제련소 | 45,000 | 30,000 |
| 전선 공장 | 550,000 | 400,000 |
| 석탄 발전기 | 1,750,000 | 1,500,000 |
| 철 제련소 | 1,250,000 | 1,100,000 |
| Smelting research | 60,000 | 40,000 |

The corresponding production, income and manager upgrade arrays scale by each facility's price reduction, rounded up to5 cash increments. Forest income 75 / production 120 and transport upgrade prices stay unchanged. Resource sale values, production cycles, input/output quantities, construction materials, starting cash, projects and rocket requirements remain unchanged. All changes are cash costs; upgrades still require no materials in world mode.

## Same operating policy, shorter opening

Both old and new campaigns start from an empty seed 42 world with 2250 cash, use real paid game commands, and follow the same zero-delay sequential operating policy in `tools/campaign_balance.gd`. The same reserve-release policy is used in both runs. No new reaction delays, cash grants or inventory transfers were added. The new simulation still runs each real 0.25-second tick.

| Checkpoint | Previous elapsed | Current elapsed | Current cumulative cash paid |
|---|---:|---:|---:|
| first linked sawmill | 4m 15.75s | 2m 23.25s | 3,220 |
| first automatic sale | 6m 46.75s | 3m 55.25s | 3,595 |
| built copper producer | 14m 35s | 9m 44.5s | 17,915 |
| smelting research | 21m 37s | 13m 59s | 82,965 |
| power online | 38m 28.25s | 28m 30.75s | 2,397,345 |
| automation unlocked | 1h 2m 58s | 51m 53.25s | 55,302,430 |
| space chain complete | 2h 6m 42.25s | 1h 54m 54.25s | 4,833,363,625 |
| launch | 3h 55m 15.5s | 3h 43m 16.75s | 14,684,037,475 |

The seed 42 first rocket moves from **3h 55m 15.5s** to **3h 43m 16.75s**, a **5.09%** shorter campaign. Seed 43 finishes in **3h 42m 44.5s**. The opening reaches automation sooner while the overall reference remains close to the previous 3h 55m and within the 3–4 hour target. No compensating late-production slowdown or increased rocket cost was needed.

A separate no-investment control reaches the linked sawmill at 2m 18s (previously 4m 36s) and automatic plank sales at 4m 19s (previously 7m 43s). Buying the first income and production upgrades changes those times to 2m 23.25s and 3m 55.25s: the investments slightly delay the mill but accelerate the completed sales line. This preserves a meaningful choice between saving and reinvesting.

## Paid ledgers and reproduction

| Seed | Launch | Successful commands | Cash paid | Refunds | Cash held |
|---|---:|---:|---:|---:|---:|
| 42 | 3h 43m 16.75s | 7,029 | 14,684,037,475 | 183,964 | 196,917,916 |
| 43 | 3h 42m 44.5s | 6,938 | 14,684,032,000 | 181,263 | 196,972,687 |

Every checkpoint satisfies `2250 + earned + refunds - spent = cash`. The six rocket quantities are unchanged. Both final cities pass save validation. Full snapshots and detailed command traces remain local and are excluded from publication. Both independent fresh replays passed, matching money, production, sold units and rocket delivery. CI generates its own trace, replays it, and publishes only the Web game artifact.

These are **automatic, zero-delay policy references**, not measured human averages or global optimal times. The policy reconfigures routes frequently and enters thousands of commands without touch/planning time. Human completion time depends on layout, parallel production and interaction time. The previous reference uses the same assumption, so the before/after comparison is consistent.

Catalog SHA256: `a124f9103ff46d8a6bef98e2cf4dedea571224413d3ccaaf70f54cc3ead026bd`.

```sh
# With the pinned Godot 4.5 binary and writable XDG directories:
godot --headless --path . --script tests/test_opening_prices.gd
godot --headless --path . --script tools/campaign_balance.gd
godot --headless --path . --script tools/campaign_balance.gd -- --seed=43
godot --headless --path . --script tools/campaign_balance.gd -- --opening-baseline
godot --headless --path . --script tools/campaign_balance.gd -- --replay=res://docs/balance/2026-10-22-opening-prices-zero-latency.json
godot --headless --path . --script tools/campaign_balance.gd -- --replay=res://docs/balance/2026-10-22-opening-prices-zero-latency-seed43.json
```
