# Central sales hub

The player starts with enough cash for one logging camp and a permanent, free 3×3 central sales hub at (65,63). The camera initially shows the camp site at (62,64) and the hub together. Production creates items, never money. A right-hand collection action transfers finished output to the player's bag; tapping the hub lets the player sell one item stack or the whole bag. Conveyor-delivered items sell automatically at the hub, without passing through the bag. Every perimeter tile accepts conveyors.

All world building costs, including city projects, use cash only. Projects retain their existing cash price and construction duration. Production recipes and rocket delivery materials remain physical. Smelting research retains its production unlock condition but uses cash only, to avoid reintroducing a stockpile requirement after warehouses disappear.

The hub cannot be built again, rotated, paused or demolished. Its throughput starts at 8 items/second, increases gradually through existing cash upgrades, and benefits from the dispatch office. Cabin sales bonus remains 25%; the city workshop now adds 10% to sales, and the dispatch office improves automatic sales throughput by 20%. Factory recipes, building prices and resource prices otherwise stay unchanged. The earliest automation is an affordable 150-cash, two-belt route from the first camp to the hub, before the 700-cash sawmill.

Once the starter route works, its final belt can become the first sawmill for the normal 700 cash price. Its position, direction and queued logs are preserved, keeping automatic sales running through processing without a second output-connection chore. The hub is additional to the normal 1024 player-building limit, so an already full old city can migrate without losing a building.

Warehouse construction, warehouse controls, storage policies and shipping orders disappear from the new UI. The always-visible bag replaces the warehouse button. Production cards keep a fixed collection action so quantity updates do not move controls. The hub shows at most four resource stacks per page, with sales actions on the right. Logistics controls become available after the first camp; later industries appear through actual production and first sales. Avoid explanatory task cards.

## Approach

Use a versioned central-market economy alongside the historical economy, sharing existing production and conveyor code. This preserves old format validation and regression fixtures, while every actual loaded/imported world upgrades before play. Replacing every legacy code path immediately would make saved-city recovery unnecessarily risky; adding remote warehouse dispatch would preserve the system the user asked to remove.

On upgrade, warehouse and old local-market inventories, incoming/outgoing buffers and reserved shipping cargo move to the bag exactly once; removed buildings refund their usual half cash value. Existing city-project allocated materials return to the bag if unfinished, then projects become cash-only. The new hub footprint is reserved; any old building inside it moves to nearby free ground, retaining its ID, upgrades and contents. Resource facilities carry their resource node when moved. Migration is idempotent and retains other money, production, records and rocket progress. Old conveyor endpoints can be reconnected to the new hub.

The concrete footprint, starting hub placement, throughput and migration details above are implementation choices made under the user's standing delegation. Verify focused opening, sales, conservation, save/upgrade, multi-tile routing and mobile interaction; do not run a full rocket campaign.

## Production recipe preview (user follow-up)

Keep specialized factories. Before the first construction of each processing-facility kind, show a compact input → output preview with quantities, cycle time and power, and Install/Cancel actions. Neither inventory nor money changes until installation is confirmed. This also applies to the first linked or inline sawmill. Later placements go through directly; a separate production-recipe button in the build UI opens the same information before choosing a site. Use the existing first-building city record to remember the first placement, including across reloads. Extractors need no redundant empty-input confirmation; generator preview shows its coal and electricity behavior. Existing legacy district saves migrate through the supported world conversion automatically on actual load/import.
