extends SceneTree
const F=preload("res://scripts/core/factory.gd")
const W=preload("res://scripts/core/world_map.gd")
var checks=0
var failures=0
func check(ok,message):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func city():
	var g=F.new();g.fresh(0,true,42);g.state.cash=1000000000
	g.state.stage=g.data.stages[6];g.state.unlocks.offline=true
	for y in range(30,51):
		for x in range(30,51):g.state.world.nodes.erase(g.key(x,y))
	return g
func _initialize():
	var g=city();var source=g.create_entity("wireFactory",40,40);var target=g.create_entity("market",40,39)
	source.outputs={"wire":2}
	check(g.command({"type":"buildRoute","from":{"x":40,"y":40},"to":{"x":40,"y":39}})=="OK","adjacent factory connection needs no conveyor")
	check(source.direction==0 and source.outputs.wire==2,"direct connection changes only final direction without emitting intermediate cargo")
	g=city();source=g.create_entity("belt",41,40);target=g.create_entity("generator",40,40)
	check(W.route_quote(g,{"x":41,"y":40},{"x":40,"y":40}).ok,"fuel may enter a generator from any side")
	g=city();source=g.create_entity("splitter",40,40,{"direction":3,"splitDirections":[3,0]})
	g.create_entity("belt",39,40,{"direction":3});g.create_entity("market",43,40)
	check(g.command({"type":"buildRoute","from":{"x":40,"y":40},"to":{"x":43,"y":40}})=="OK","add branch using unused splitter outlet")
	check(3 in source.splitDirections and 1 in source.splitDirections,"adding a down branch preserves live left outlet")
	check(g.command({"type":"setSplitPort","entityId":source.id,"port":1,"direction":0})=="OK" and source.splitDirections==[3,0],"splitter ports are individually editable")
	check(g.command({"type":"setSplitPort","entityId":source.id,"port":1,"direction":3})=="INVALID" and source.splitDirections==[3,0],"duplicate outlet rejected without any mutation")
	var secondary=g.create_entity("belt",40,39,{"direction":2,"queue":["log"]})
	var snapshots={source.id:{"queue":[],"inputs":{},"outputs":{}}}
	check(g.transport_space(source,"log",secondary,snapshots,{})==0,"neither splitter output can be mistaken for an input")
	check(W.route_quote(g,{"x":40,"y":39},{"x":40,"y":40}).code=="WRONG_PORT","routing rejects entry through secondary splitter output")
	var before=JSON.stringify(g.state)
	check(g.command({"type":"buildRoute","from":{"x":40,"y":40},"to":{"x":43,"y":43}})=="PORT_OCCUPIED" and JSON.stringify(g.state)==before,"a third branch cannot silently replace two occupied ports")
	g=city();source=g.create_entity("belt",40,40,{"direction":1,"queue":["wire","coal","wire"]});target=g.create_entity("copperSmelter",41,40)
	check(g.status(source).contains("전선"),"blocked conveyor identifies the incompatible head item")
	check(g.command({"type":"recoverCargo","entityId":source.id})=="OK","recover conveyor without demolishing it")
	check(source.queue.is_empty() and g.state.bag.get("wire",0)==2 and g.state.bag.get("coal",0)==1,"recovery conserves all queued items")
	check(g.command({"type":"recoverCargo","entityId":source.id})=="EMPTY" and g.state.bag.wire==2,"repeated recovery cannot duplicate cargo")
	g=city();source=g.create_entity("belt",40,40,{"direction":1,"queue":["wire","fuel"]});target=g.create_entity("launchpad",41,40)
	g.state.rocket.delivered.wire=g.data.rocket.wire
	g.advance(2)
	check(g.state.rocket.delivered.get("fuel",0)==1 and source.queue.is_empty() and g.state.bag.get("wire",0)==1,"completed rocket material returns to bag without trapping delivery cargo")
	check(g.state.rocket.delivered.wire==g.data.rocket.wire,"selective delivery cannot overfill rocket")
	g=city();target=g.create_entity("launchpad",40,40)
	g.state.rocket.delivered.wire=g.data.rocket.wire-1
	g.create_entity("belt",39,40,{"direction":1,"queue":["wire"]})
	g.create_entity("belt",40,39,{"direction":2,"queue":["wire"]})
	g.advance(2)
	check(g.state.rocket.delivered.wire==g.data.rocket.wire and g.state.bag.get("wire",0)==1,"simultaneous final deliveries preserve excess without overfilling")
	g=city();source=g.create_entity("partsFactory",40,40);g.state.power.ratio=0
	check(F.Insight.observe(g,source).nominal>0,"hardware maximum stays meaningful during a blackout")
	print("FACTORY_UX: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
