extends RefCounted
## Historical pre-central-sales worlds remain supported as regression baselines.
static func empty(game,seed_value=42):
	game.fresh(0,true,seed_value)
	game.state.entities={};game.state.nextId=1
	game.state.cash=game.data.facilities.forest.cost;game.state.records=[]
	game.state.factory.erase("economyVersion");game.state.factory.erase("salesHubId")
	game.state.factory.startMode="empty";game.state.factory.pioneerForestId=""
	game.state.world.spawn={"x":62,"y":64}
	game.state.world.revision=0
	game.invalidate_index();game.clear_effects()

## Existing populated world saves remain supported after the empty-city opening.
static func connected(game):
	game.fresh(0,false)
	game.state.world=load("res://scripts/core/world_map.gd").generate(42)
	for id in ["e1","e2","e3"]:
		var e=game.state.entities[id];e.x=62+(int(id.substr(1))-1)*2;e.y=64;e.starter=true
	game.state.entities.e3.inventory={};game.state.entities.e3.autoSell=true;game.state.entities.e3.localSaleCredit=0.0
	for x in [63,65]:game.create_entity("belt",x,64,{"starter":true})
	game.invalidate_index()
