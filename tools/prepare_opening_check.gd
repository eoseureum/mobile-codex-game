extends SceneTree
const Factory=preload("res://scripts/core/factory.gd")
const Store=preload("res://scripts/core/save_store.gd")
func _initialize():
	var game=Factory.new();game.fresh(0,true,42)
	if game.command({"type":"build","kind":"forest","x":62,"y":64})!="OK":quit(1);return
	while game.state.cash<game.data.facilities.sawmill.cost+game.data.facilities.belt.cost:game.advance(0.25)
	var camp_time=game.state.clock.elapsedS
	DirAccess.make_dir_recursive_absolute("res://build/fixtures")
	var file=FileAccess.open("res://build/fixtures/opening-ready.json",FileAccess.WRITE)
	file.store_string(Store.new().export_text(game));file.close()
	if game.command({"type":"buildLinked","kind":"sawmill","sourceId":"e1","x":64,"y":64})!="OK":quit(1);return
	while game.state.cash<game.data.facilities.warehouse.cost+game.data.facilities.belt.cost:game.advance(0.25)
	file=FileAccess.open("res://build/fixtures/warehouse-ready.json",FileAccess.WRITE)
	file.store_string(Store.new().export_text(game));file.close()
	print("PAID_BROWSER_FIXTURES / camp %.2fs / warehouse %.2fs / cash %d"%[camp_time,game.state.clock.elapsedS,game.state.cash]);quit()
