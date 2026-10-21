extends SceneTree
var Factory=load("res://scripts/core/factory.gd")
const Store=preload("res://scripts/core/save_store.gd")
const Fixture=preload("res://tests/world_fixture.gd")
var checks=0
var failures=0
func check(value,message):
	checks+=1
	if not value:failures+=1;printerr("FAIL: "+message)
func point(x,y):return {"x":x,"y":y}
func encoded(game):return JSON.stringify(game.state,"",false,true)
func _initialize():
	check(ResourceLoader.exists("res://scripts/core/world_map.gd"),"open resource world module exists")
	if failures:quit(1);return
	var probe=Factory.new();var has_world_api=false
	for method in probe.get_method_list():
		if method.name=="fresh" and method.args.size()>=3:has_world_api=true
	check(has_world_api,"factory exposes open-world initialization")
	if failures:quit(1);return
	var World=load("res://scripts/core/world_map.gd")
	var a=World.generate(42);var b=World.generate(42);var c=World.generate(43)
	check(a.nodes==b.nodes,"seed regenerates identical resource placement")
	check(a.nodes!=c.nodes,"different seeds produce different worlds")
	for seed in range(1,13):
		var w=World.generate(seed)
		check(w.width==128 and w.height==128,"large world dimensions")
		var counts={}
		for pos in w.nodes:
			var xy=World.parse_key(pos);check(xy.x>=0 and xy.y>=0 and xy.x<128 and xy.y<128,"resource stays inside world")
			counts[w.nodes[pos]]=counts.get(w.nodes[pos],0)+1
		for r in ["log","stone","coal","copper","iron"]:check(counts.get(r,0)>=10,"every seed has enough "+r)
		check(World.resource_at(w,62,64)=="log" and World.resource_at(w,64,64)=="" and World.resource_at(w,66,64)=="","starter sources and building area are guaranteed")
		for cy in range(8):
			for cx in range(8):
				var n=0
				for y in range(cy*16,(cy+1)*16):
					for x in range(cx*16,(cx+1)*16):
						if not World.resource_at(w,x,y).is_empty():n+=1
				check(n<=130,"resource clusters leave building space in every region")
	var g=Factory.new();Fixture.connected(g)
	check(g.world_mode() and g.state.cash==500 and g.state.entities.size()==5,"existing world save retains 500 and connected starter line")
	check(g.owned(120,120) and not g.owned(128,0),"whole map is buildable within bounds")
	g.command({"type":"pause","entityId":"e4"});g.advance(60)
	check(g.state.cash==500 and g.state.totals.get("operatingEarned",0)==0,"disconnected producers generate no money")
	Fixture.connected(g);g.advance(120)
	check(g.state.cash>=1500 and g.stock("plank")>=20,"first two minutes earn actual sales and protect construction stock")
	check(g.stage_index()>=1,"mining unlocks through production instead of land buying")
	check(g.command({"type":"expand","districtId":"forest"})!="OK","new world has no district purchases")
	var initial=encoded(g)
	check(g.command({"type":"build","kind":"forest","x":64,"y":66})=="RESOURCE_REQUIRED","logging requires actual forest tile")
	check(g.command({"type":"build","kind":"mine","x":64,"y":66})=="RESOURCE_REQUIRED","mining requires a vein")
	check(encoded(g)==initial,"failed extraction placement is atomic")
	Fixture.connected(g);g.advance(600)
	check(g.command({"type":"build","kind":"mine","x":75,"y":66})=="OK","first mine is purchased with actual earned money and planks")
	var mined=g.at(75,66)
	check(g.command({"type":"setMineResource","entityId":mined.id,"resource":"coal"})=="LOCKED","vein mineral cannot be switched")
	check(g.command({"type":"buildRoute","from":point(75,66),"to":point(66,64),"clear":true})=="OK","paid mine route reaches the starter shipping depot")
	var mine_cash=g.state.cash;g.advance(180)
	check(g.state.totals.sold.get("copper",0)>0 and g.state.cash-mine_cash>180*75,"mining creates delivered sales and visible midgame momentum")
	Fixture.connected(g)
	g.state.entities.e3.incomeLevel=10
	var improved_quote=World.clear_quote(g,point(59,69),point(59,69))
	check(improved_quote.cash>g.sale_price(g.state.entities.e3,"log")*2,"clearing fee follows improved sale prices")
	Fixture.connected(g)
	var before=encoded(g)
	check(g.command({"type":"clearArea","from":point(57,67),"to":point(61,71)})=="INSUFFICIENT_CASH","unaffordable bulk clearing is rejected")
	check(encoded(g)==before,"unaffordable clearing changes nothing")
	var quote=World.clear_quote(g,point(59,69),point(59,69))
	check(quote.ok and quote.cash>100 and quote.reward.get("log")==2,"tree clearing quotes modest recovery with nonprofitable fee")
	check(g.command({"type":"clearArea","from":point(59,69),"to":point(59,69)})=="OK","single tile can be cleared")
	check(World.resource_at(g.state.world,59,69)=="" and g.stock("log")==2 and g.produced("log")==0,"clearing leaves ground and is not ongoing production")
	before=encoded(g)
	check(g.command({"type":"clearArea","from":point(59,69),"to":point(59,69)})=="EMPTY" and encoded(g)==before,"clearing twice cannot duplicate recovery")
	for command in [
		{"type":"clearArea","from":point(62,64),"to":point(62,64)},
		{"type":"clearArea","from":point(-1,0),"to":point(0,0)},
		{"type":"clearArea","from":point(1.5,1),"to":point(2,2)},
		{"type":"clearArea","from":point(0,0),"to":point(127,127)},
		{"type":"buildRoute","from":point(-1,0),"to":point(2,2),"clear":true}]:
		before=encoded(g);check(g.command(command)!="OK" and encoded(g)==before,"invalid/occupied/oversized work is atomic")
	Fixture.connected(g)
	var route=World.route_quote(g,point(64,66),point(68,66),false)
	check(route.ok and route.cells.size()==5 and route.cash==500,"free-ground route quotes complete conveyor cost")
	g.state.cash=499;before=encoded(g)
	check(g.command({"type":"buildRoute","from":point(64,66),"to":point(68,66),"clear":false})=="INSUFFICIENT_CASH" and encoded(g)==before,"unaffordable route never places partial belts")
	g.state.cash=500
	check(g.command({"type":"buildRoute","from":point(64,66),"to":point(68,66),"clear":false})=="OK" and g.state.cash==0,"route places once with exact total cost")
	for x in range(64,69):check(g.at(x,66).kind=="belt" and int(g.at(x,66).direction)==1,"new belts point toward destination")
	Fixture.connected(g)
	var direct=World.route_quote(g,point(56,69),point(62,69),true)
	var detour=World.route_quote(g,point(56,69),point(62,69),false)
	check(direct.ok and direct.clear.size()>0 and detour.ok and detour.clear.is_empty(),"both clearing and avoiding forest routes exist")
	check(direct.cells.size()<detour.cells.size(),"clearing allows a shorter route")
	g.state.cash=direct.cash
	check(g.command({"type":"buildRoute","from":point(56,69),"to":point(62,69),"clear":true})=="OK","clearing and conveyor construction commit together")
	check(g.stock("log")==direct.reward.log,"combined route recovers each removed tree exactly once")
	before=encoded(g);check(g.command({"type":"buildRoute","from":point(56,69),"to":point(62,69),"clear":true})!="OK" and encoded(g)==before,"repeat route cannot duplicate cleared resources")
	# Test fixtures exercise local inventory without granting a campaign shortcut.
	Fixture.connected(g);g.state.factory.reserves.log=0
	var w1=g.create_entity("warehouse",64,66);var w2=g.create_entity("warehouse",70,66,{"dispatchResource":"log"})
	var target=g.create_entity("sawmill",71,66)
	w1.inventory.log=10;g.advance(12)
	check(w1.inventory.log==10 and target.job==null and target.outputs.is_empty(),"remote warehouse cannot teleport its inventory")
	w2.inventory.log=2;g.advance(12)
	check(target.outputs.get("plank",0)>0,"adjacent local warehouse supplies connected factory")
	Fixture.connected(g);g.state.entities.e3.inventory.plank=100;g.state.factory.reserves.plank=0
	var project=g.create_entity("cabin",67,64,{"project":{"materials":{},"remainingS":15.0,"complete":false}})
	g.advance(2);check(project.project.materials.is_empty(),"city project cannot take distant/global stock automatically")
	g.state.entities.e3.dispatchResource="plank";g.advance(45)
	check(project.project.complete,"physically delivered project materials complete construction")
	Fixture.connected(g);g.state.stage="space"
	var launch=g.create_entity("launchpad",74,64)
	g.state.entities.e3.inventory=g.data.rocket.duplicate(true);g.advance(1)
	check(g.state.rocket.delivered.is_empty(),"rocket does not receive warehouse stock remotely")
	var near=g.create_entity("warehouse",73,64,{"dispatchResource":"structure"});near.inventory.structure=5;g.state.factory.reserves.structure=0;g.advance(2)
	check(g.state.rocket.delivered.get("structure",0)>0,"rocket accepts actual conveyor input")
	Fixture.connected(g);g.advance(180);g.state.factory.reserves.plank=0
	check(g.command({"type":"takeOrder","offerId":g.offers()[0].id})=="OK","world shipment accepts a real depot order")
	g.advance(2);var active=g.trade().active;var cargo=active.loaded+active.reserved;var stock_before=g.state.entities.e3.inventory.get(active.resource,0)
	check(cargo>0,"shipment escrow contains actual local cargo")
	check(g.command({"type":"cancelOrder"})=="OK" and g.state.entities.e3.inventory.get(active.resource,0)==stock_before+cargo,"cancelled order refunds exact cargo to its depot")
	var store=Store.new();var saved=store.parse(store.export_text(g))
	check(not saved.is_empty(),"world save validates: "+store.last_error)
	if saved.is_empty():quit(1);return
	var clone=Factory.new();clone.state=saved.state;g.advance(30);clone.advance(30)
	check(JSON.parse_string(encoded(g))==JSON.parse_string(encoded(clone)),"world roundtrip preserves future production exactly")
	for field in ["bounds","terrain","warehouse","source"]:
		var bad=store.snapshot(g)
		match field:
			"bounds":bad.state.world.width="bad"
			"terrain":bad.state.world.nodes["128,0"]="log"
			"warehouse":bad.state.entities.e3.inventory.log=-1
			"source":bad.state.world.nodes.erase("62,64")
		check(not store.validate(bad).is_empty(),"bad world save rejected: "+field)
	g.fresh(0,false);g.advance(180)
	var old_cash=g.state.cash;var old_stock=g.state.bag.duplicate(true);var old_totals=g.state.totals.duplicate(true)
	check(g.command({"type":"migrateWorld","seed":42})=="OK","existing city explicitly migrates")
	check(g.world_mode() and g.state.cash==old_cash and g.state.totals==old_totals,"migration preserves cash and production history")
	for r in old_stock:check(g.stock(r)==old_stock[r],"migration preserves stored "+r)
	check(store.validate(store.snapshot(g)).is_empty(),"migrated city validates")
	print("WORLD: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
