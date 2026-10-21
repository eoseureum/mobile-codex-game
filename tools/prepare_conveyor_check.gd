extends SceneTree
const Factory=preload("res://scripts/core/factory.gd")
const Store=preload("res://scripts/core/save_store.gd")
const Fixture=preload("res://tests/world_fixture.gd")
func _initialize():
	# UI-only fixture: controlled local inventories, not campaign timing evidence.
	var g=Factory.new();Fixture.connected(g)
	for e in g.state.entities.values():e.paused=true
	g.state.stage="mining";g.state.world.spawn={"x":66,"y":66}
	g.state.factory.reserves.log=0;g.state.factory.reserves.coal=0
	g.create_entity("warehouse",64,66,{"direction":1,"dispatchResource":"log","autoSell":false,"inventory":{"log":100}})
	g.create_entity("warehouse",66,65,{"direction":2,"dispatchResource":"coal","autoSell":false,"inventory":{"coal":100}})
	g.create_entity("belt",65,66,{"direction":1})
	g.create_entity("belt",66,66,{"direction":1})
	g.create_entity("belt",67,66,{"direction":1})
	var depot=g.create_entity("warehouse",68,66,{"autoSell":false})
	g.advance(6)
	var store=Store.new();var text=store.export_text(g)
	if store.parse(text).is_empty():printerr(store.last_error);quit(1);return
	var f=FileAccess.open("res://build/fixtures/conveyor-flow.json",FileAccess.WRITE);f.store_string(text);f.close()
	depot.paused=true;g.advance(20)
	f=FileAccess.open("res://build/fixtures/conveyor-jam.json",FileAccess.WRITE);f.store_string(store.export_text(g));f.close()
	print("CONVEYOR_BROWSER_FIXTURES");quit()
