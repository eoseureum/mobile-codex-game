# City project materials

City projects (cabin, city workshop, dispatch office) automatically allocate their missing construction materials from pooled warehouse inventory and the city bag. They retain their original cash cost, material quantities and construction duration. Regular factory recipes and rocket deliveries still require physical transport.

Partial projects retain delivered materials and consume only the remaining deficit. A shortage waits for later warehouse stock; a paused or completed project consumes nothing. Demolishing an unfinished project returns its allocated materials through the existing recovery path. The save format is unchanged.

The focused `tests/test_project_stock.gd` suite covers pooled stock, old partial deliveries, shortages, completion effects, save round trips and demolition. Full rocket campaigns are optional through the **Run full legacy and paid world campaigns** workflow-dispatch input; routine CI runs focused regressions and exports the Web build without repeating full-campaign timing.
