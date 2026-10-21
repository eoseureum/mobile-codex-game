extends SceneTree
const Factory=preload("res://scripts/core/factory.gd")
const Store=preload("res://scripts/core/save_store.gd")
func _initialize():
	var game=Factory.new();game.fresh(0,true,42)
	if game.command({"type":"build","kind":"forest","x":62,"y":64})!="OK":quit(1);return
	game.advance(128)
	DirAccess.make_dir_recursive_absolute("res://build/fixtures")
	var file=FileAccess.open("res://build/fixtures/opening-ready.json",FileAccess.WRITE)
	file.store_string(Store.new().export_text(game));file.close()
	if game.command({"type":"buildLinked","kind":"sawmill","sourceId":"e1","x":64,"y":64})!="OK":quit(1);return
	while game.state.cash<550:game.advance(0.25)
	file=FileAccess.open("res://build/fixtures/warehouse-ready.json",FileAccess.WRITE)
	file.store_string(Store.new().export_text(game));file.close()
	print("PAID_BROWSER_FIXTURES / camp 128s / warehouse %.2fs / cash %d"%[game.state.clock.elapsedS,game.state.cash]);quit()
