extends SceneTree
const Factory=preload("res://scripts/core/factory.gd")
const World=preload("res://scripts/core/world_map.gd")
const Store=preload("res://scripts/core/save_store.gd")
const Fixture=preload("res://tests/world_fixture.gd")
var failures=0
var checks=0
func check(v,s):checks+=1;if not v:failures+=1;printerr("FAIL: "+s)
func point(x,y):return {"x":x,"y":y}
func _initialize():
	var g=Factory.new();Fixture.connected(g)
	for e in g.state.entities.values():e.paused=true
	var west=g.create_entity("belt",64,66,{"direction":1,"queue":["log","log","log","log"]})
	var north=g.create_entity("belt",66,65,{"direction":1,"queue":["coal","coal","coal","coal"]})
	var junction=g.create_entity("belt",66,66,{"direction":1})
	var depot=g.create_entity("warehouse",67,66,{"autoSell":false})
	var quote=World.route_quote(g,point(64,66),point(66,66))
	check(quote.ok and quote.cells.size()==1 and quote.cash==100,"joining an existing trunk only charges the new belt")
	check(g.command({"type":"buildRoute","from":point(64,66),"to":point(66,66)})=="OK","a paid branch joins an existing conveyor")
	var cash=g.state.cash;var n=g.state.entities.size()
	check(g.command({"type":"buildRoute","from":point(66,65),"to":point(66,66)})=="OK","adjacent belts can be joined by turning the source")
	check(g.state.cash==cash and g.state.entities.size()==n and north.direction==2 and junction.direction==1,"joining keeps trunk direction, cargo and paid buildings")
	var before=JSON.stringify(g.state)
	check(g.command({"type":"buildRoute","from":point(66,65),"to":point(66,66)})=="EMPTY" and JSON.stringify(g.state)==before,"repeating a completed connection changes nothing")
	check(World.route_quote(g,point(67,66),point(66,66)).code=="WRONG_PORT","output-side reverse connections stay blocked")
	var restored=Store.new().parse(Store.new().export_text(g))
	check(not restored.is_empty() and restored.state.entities[north.id].direction==2 and restored.state.entities[junction.id].direction==1,"joined directions and queued cargo survive validated backup loading")
	var arrivals=[]
	for i in range(80):
		g.tick()
		for transfer in g.transfers:
			if transfer.targetId==junction.id:arrivals.append(transfer.resource)
	check(depot.inventory.get("log",0)==4 and depot.inventory.get("coal",0)==4,"mixed resources reach the shared warehouse without loss")
	check(arrivals.size()==8 and arrivals.slice(0,4).has("log") and arrivals.slice(0,4).has("coal"),"both branches get service at a shared intake")
	west.queue=["log","log","log","log"];north.queue=["coal","coal","coal","coal"];depot.paused=true
	g.advance(20)
	var total=0;var within=true
	for e in g.state.entities.values():
		if g.transport(e):total+=e.queue.size();within=within and e.queue.size()<=4
	check(total==8 and within,"a blocked junction preserves all cargo within belt capacity")
	check(ResourceLoader.exists("res://scripts/ui/conveyor_view.gd"),"conveyors expose identifiable item sprites and junction geometry")
	if not ResourceLoader.exists("res://scripts/ui/conveyor_view.gd"):quit(1);return
	var View=load("res://scripts/ui/conveyor_view.gd")
	check(View.inputs(g,junction)==[0,3],"junction drawing recognizes north and west input arms")
	junction.level=2;junction.queue=["log","coal","copper","stone","plank","wire","iron","copperIngot"]
	var cargo=View.cargo(junction)
	check(cargo.size()==3 and junction.queue.size()==8,"a readable preview shows front cargo without discarding hidden queue items")
	var positions={};var inside=true
	for i in range(cargo.size()):
		positions[cargo[i].offset]=true;inside=inside and abs(cargo[i].offset.x)<=0.4 and abs(cargo[i].offset.y)<=0.2
		check(cargo[i].resource==junction.queue[i],"cargo sprite follows actual queue resource")
	check(positions.size()==3 and inside,"front cargo fits in separate visible positions")
	print("CONVEYORS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
