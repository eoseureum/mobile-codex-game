extends SceneTree
const Fixture=preload("res://tests/world_fixture.gd")
const Factory=preload("res://scripts/core/factory.gd")
const Rules=preload("res://scripts/core/world_rules.gd")
const Store=preload("res://scripts/core/save_store.gd")
var checks=0
var failures=0
func check(ok,message):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func city():
	var g=Factory.new();Fixture.empty(g)
	g.state.cash=100000000;g.state.stage="advanced";g.state.unlocks.offline=true
	g.state.totals.produced={"plank":40,"wire":20,"machinePart":10}
	for x in range(80,88):g.state.world.nodes.erase(g.key(x,80))
	return g
func _initialize():
	for kind in ["cabin","cityWorkshop","dispatchOffice"]:
		var g=city();var recipe=g.data.projects[kind].materials
		var w1=g.create_entity("warehouse",80,80);var w2=g.create_entity("warehouse",81,80)
		for r in recipe:
			w1.inventory[r]=1;w2.inventory[r]=recipe[r]-1+3
			g.state.factory.reserves[r]=10000 # Construction can use protected stock, like other building costs.
		check(g.command({"type":"build","kind":kind,"x":87,"y":80})=="OK",kind+" placement uses normal building action")
		var e=g.at(87,80)
		Rules.project_step(g)
		check(g.has_stock(e.project.materials,recipe),kind+" pools remote warehouses without belts")
		for r in recipe:check(g.stock(r)==3,kind+" consumes only the missing "+r)
		check(e.project.remainingS==g.data.projects[kind].seconds-g.DT and not e.project.complete,kind+" retains construction time")
		for i in range(int(g.data.projects[kind].seconds/g.DT)):Rules.project_step(g)
		check(e.project.complete and g.recorded("complete_"+kind),kind+" completes and records its effect")
		var before=JSON.stringify(w2.inventory);Rules.project_step(g)
		check(JSON.stringify(w2.inventory)==before,kind+" completed project never charges twice")
	var g=city();var w=g.create_entity("warehouse",80,80)
	check(g.command({"type":"build","kind":"cabin","x":87,"y":80})=="OK","can place construction before all materials arrive")
	var e=g.at(87,80);e.project.materials.plank=5;e.inputs.plank=4;g.state.bag.plank=2;w.inventory.plank=3
	e.paused=true;Rules.project_step(g)
	check(e.project.materials.plank==5 and e.inputs.plank==4 and g.stock("plank")==5,"paused project leaves every source unchanged")
	e.paused=false;Rules.project_step(g)
	check(e.project.materials.plank==14 and e.inputs.is_empty() and g.stock("plank")==0,"old partial deliveries combine with bag and warehouse stock")
	check(e.project.remainingS==15,"shortage waits without advancing construction")
	var store=Store.new();var parsed=store.parse(store.export_text(g))
	check(not parsed.is_empty(),"partial project backup remains compatible: "+store.last_error)
	if not parsed.is_empty():
		var clone=Factory.new();clone.state=parsed.state
		clone.state.entities[w.id].inventory.plank=15
		Rules.project_step(clone)
		check(clone.state.entities[e.id].project.materials.plank==24 and clone.stock("plank")==5,"loaded project tops up exactly its remaining deficit")
		check(clone.command({"type":"demolish","entityId":e.id})=="OK" and clone.stock("plank")==29,"demolition returns unfinished allocated materials once")
		check(store.validate(store.snapshot(clone)).is_empty(),"demolished project save validates")
	w.inventory.plank=10;Rules.project_step(g)
	check(e.project.materials.plank==24 and g.stock("plank")==0,"new stock automatically resumes waiting construction")
	for i in range(59):Rules.project_step(g)
	check(e.project.complete and g.effects().operating==1.25,"completion activates the city benefit")
	check(store.validate(store.snapshot(g)).is_empty(),"completed project save validates")
	var second=city();var depot=second.create_entity("warehouse",80,80)
	depot.inventory.log=20;depot.inventory.structure=10
	var mill=second.create_entity("sawmill",86,80);second.create_entity("launchpad",87,80)
	Rules.warehouse_step(second)
	check(mill.inputs.is_empty() and mill.job==null and second.state.rocket.delivered.is_empty(),"regular production and rocket still require physical transport")
	if "--web-fixture" in OS.get_cmdline_user_args():
		var fixture=city();fixture.state.world.spawn={"x":87,"y":80}
		fixture.create_entity("warehouse",80,80).inventory.plank=7
		fixture.create_entity("warehouse",81,80).inventory.plank=17
		check(fixture.command({"type":"build","kind":"cabin","x":87,"y":80})=="OK","browser fixture uses actual project construction command")
		check(store.validate(store.snapshot(fixture)).is_empty(),"browser fixture validates")
		DirAccess.make_dir_recursive_absolute("res://build/fixtures")
		var file=FileAccess.open("res://build/fixtures/city-project.json",FileAccess.WRITE)
		file.store_string(store.export_text(fixture));file.close()
	print("PROJECT_STOCK: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
