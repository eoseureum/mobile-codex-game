extends SceneTree
const Factory=preload("res://scripts/core/factory.gd")
const Store=preload("res://scripts/core/save_store.gd")
const World=preload("res://scripts/core/world_map.gd")
var checks=0
var failures=0
func check(ok,message):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func _initialize():
	var g=Factory.new();g.fresh(0,true,42)
	var hubs=g.state.entities.values().filter(func(e):return e.get("salesHub",false))
	check(hubs.size()==1,"new city has one permanent central hub")
	if hubs.is_empty():print("SALES_HUB: %d checks, %d failures"%[checks,failures]);quit(1);return
	var hub=hubs[0]
	check(g.state.cash==0 and g.state.entities.size()==2,"new city starts with hub and a paid prebuilt logging camp")
	check(g.at(62,64).get("kind","")=="forest" and g.at(62,64).investedCash==2250,"starter camp retains its construction investment")
	var guard=Factory.new();load("res://tests/world_fixture.gd").empty(guard);guard.upgrade_world()
	check(guard.command({"type":"clearArea","from":{"x":62,"y":64},"to":{"x":62,"y":64}})=="LOCKED","first-camp funds cannot be consumed by terrain clearing")
	check(guard.command({"type":"buildRoute","from":{"x":63,"y":64},"to":{"x":65,"y":64}})=="LOCKED","first-camp funds cannot be spent on an empty conveyor route")
	for y in range(63,66):
		for x in range(65,68):check(g.at(x,y).get("id")==hub.id,"whole hub footprint is occupied")
	check(g.command({"type":"build","kind":"warehouse","x":64,"y":64})=="LOCKED","warehouse removed from construction")
	var camp=g.at(62,64)
	g.advance(12)
	check(g.state.cash==0 and g.state.totals.earned==0 and camp.outputs.get("log",0)==2,"logging makes items without onsite income")
	check(g.command({"type":"collect","entityId":camp.id})=="OK" and g.stock("log")==2 and camp.outputs.is_empty(),"collection moves finished logs to bag")
	check(g.command({"type":"collect","entityId":camp.id})=="EMPTY" and g.stock("log")==2,"repeat collection cannot duplicate items")
	check(g.command({"type":"sellInventory","entityId":hub.id,"resource":"log"})=="OK","hub sells a selected bag stack")
	check(g.stock("log")==0 and g.state.cash==70 and g.state.totals.sold.log==2,"manual sale reconciles units and money")
	check(g.command({"type":"sellInventory","entityId":camp.id})=="INVALID","bag sales require the hub")
	g.advance(18);g.command({"type":"collect","entityId":camp.id});g.command({"type":"sellInventory","entityId":hub.id})
	check(g.state.cash==175,"five actually produced logs fund first automation")
	check(g.command({"type":"buildRoute","from":{"x":62,"y":64},"to":{"x":65,"y":64}})=="OK" and g.state.cash==25,"two belts reach the side of the hub for 150 cash")
	g.advance(18)
	check(g.state.cash>25 and g.recorded("first_auto_sale") and g.stock("log")==0,"conveyor input sells automatically without entering bag")
	var inline_belt=g.at(64,64);g.state.cash=g.data.facilities.sawmill.cost;inline_belt.queue=["log","log"]
	var invested=inline_belt.investedCash
	check(g.command({"type":"insertSawmill","entityId":inline_belt.id})=="OK","first sawmill can replace the last belt in an automated line")
	check(inline_belt.kind=="sawmill" and inline_belt.inputs.get("log",0)==2 and inline_belt.queue.is_empty() and inline_belt.investedCash==invested+g.data.facilities.sawmill.cost,"inline conversion preserves queued logs, position and paid investment")
	g.advance(16)
	check(g.produced("plank")>0 and g.state.totals.sold.get("plank",0)>0 and g.state.cash>0,"inline sawmill keeps automatic sales without rebuilding the output route")
	for command in [{"type":"demolish"},{"type":"rotate","direction":0},{"type":"pause"}]:
		command.entityId=hub.id;check(g.command(command)=="PROTECTED","hub cannot be removed or disabled")
	g.state.cash=100000000;g.state.stage="space";g.state.unlocks.offline=true;g.state.totals.produced.wire=10;g.state.totals.produced.plank=20
	for kind in ["sawmill","mine","partsFactory","cabin"]:check(g.construction_materials(kind).is_empty(),kind+" construction needs no inventory")
	g.state.world.nodes.erase("80,80")
	check(g.command({"type":"build","kind":"cabin","x":80,"y":80})=="OK","cash-only city project can start without planks")
	g.advance(15)
	check(g.at(80,80).project.complete and g.stock("plank")==0,"cash-only project finishes after construction time")
	var store=Store.new();var parsed=store.parse(store.export_text(g))
	check(not parsed.is_empty(),"new economy save validates: "+store.last_error)
	var occupied=store.snapshot(g);var overlap=g.data.initial.entities.e1.duplicate(true)
	overlap.merge({"id":"e%d"%int(occupied.state.nextId),"kind":"belt","x":67,"y":65,"starter":false},true)
	occupied.state.entities[overlap.id]=overlap;occupied.state.nextId+=1
	check(not store.validate(occupied).is_empty(),"save rejects an overlapping non-anchor hub cell")
	var bad=store.snapshot(g);bad.state.entities[hub.id].salesHub=false
	check(not store.validate(bad).is_empty(),"save requires the permanent central hub")
	bad=store.snapshot(g);bad.state.factory.economyVersion=3
	check(not store.validate(bad).is_empty(),"unknown economy versions are rejected")
	bad=store.snapshot(g);bad.state.entities[hub.id]="broken"
	check(not store.validate(bad).is_empty(),"non-object hub data is rejected safely")
	for entry in [[64,63,1],[64,64,1],[64,65,1],[68,63,3],[68,64,3],[68,65,3],[65,62,2],[66,62,2],[67,62,2],[65,66,0],[66,66,0],[67,66,0]]:
		var delivery=Factory.new();delivery.fresh(0,true,42)
		var belt=delivery.create_entity("belt",entry[0],entry[1],{"direction":entry[2]});belt.queue=["log"]
		delivery.advance(0.75)
		var edge=Vector2i(entry[0],entry[1])+Factory.DIRS[entry[2]]
		check(delivery.transfers.size()==1 and delivery.transfers[0].targetX==edge.x and delivery.transfers[0].targetY==edge.y,"item motion lands at its real receiving edge")
		delivery.advance(1.25)
		check(delivery.state.cash==35 and belt.queue.is_empty(),"hub accepts a delivery at perimeter "+str(entry))
	var route=g.command({"type":"build","kind":"belt","x":67,"y":65})
	check(route=="OCCUPIED","building cannot overlap the far corner of the hub")
	var path=World.route_quote(g,{"x":64,"y":64},{"x":68,"y":64},false)
	check(path.ok,"route can detour around large hub")
	if path.ok:
		for cell in path.cells:check(not g.entity_rect(hub).has_point(Vector2i(cell.x,cell.y)),"route never crosses interior hub tiles")
	var before=JSON.stringify(g.state)
	check(g.command({"type":"sellInventory","entityId":hub.id,"resource":[]})=="INVALID" and JSON.stringify(g.state)==before,"malformed sale is atomic")
	check(g.command({"type":"sellInventory","entityId":hub.id,"resource":"not-an-item"})=="INVALID","unknown item cannot be sold")
	var old=Factory.new();load("res://tests/world_fixture.gd").connected(old)
	old.state.entities.e3.inventory={"log":50,"plank":2};old.state.entities.e3.inputs={"plank":3};old.state.entities.e3.outputs={"log":4}
	old.state.totals.produced.log=60
	check(old.command({"type":"takeOrder","offerId":old.offers()[0].id})=="OK","migration fixture has an accepted order")
	old.trade().active.loaded=2;old.trade().active.reserved=3
	old.state.bag={"log":7}
	var project=old.create_entity("cabin",80,80,{"investedCash":2000,"project":{"materials":{"plank":5},"remainingS":10.0,"complete":false}})
	project.inputs.plank=4;old.state.world.nodes.erase("80,80")
	var moved=old.create_entity("sawmill",67,65,{"level":2,"outputs":{"plank":6},"investedCash":900});old.state.world.nodes.erase("67,65")
	var expected_cash=old.state.cash+int(old.state.entities.e3.investedCash/2)
	check(old.upgrade_world(),"old world upgrades to central sales")
	check(old.stock("log")==66 and old.stock("plank")==14,"warehouse buffers, bag, project cargo and order escrow are conserved")
	check(old.trade().active==null and not old.trade().repeat and old.state.cash==expected_cash,"warehouse removal refunds cash and closes orders")
	check(old.state.entities.values().filter(func(e):return e.kind=="warehouse").is_empty(),"upgrade removes all warehouses")
	check(not old.entity_rect(old.sales_hub()).has_point(Vector2i(moved.x,moved.y)) and moved.level==2 and moved.outputs.plank==6,"overlapping building relocates with upgrades and products intact")
	check(project.project.materials.is_empty() and project.inputs.is_empty() and project.project.remainingS==10,"existing project retains time and releases material investment")
	before=JSON.stringify(old.state)
	check(not old.upgrade_world() and JSON.stringify(old.state)==before,"repeated migration cannot duplicate items, refunds or buildings")
	parsed=store.parse(store.export_text(old));check(not parsed.is_empty(),"migrated city validates: "+store.last_error)
	if not parsed.is_empty():
		var clone=Factory.new();clone.state=parsed.state
		check(not clone.upgrade_world(),"reload keeps upgraded economy without re-running migration")
		old.advance(10);clone.advance(10)
		check(JSON.parse_string(JSON.stringify(old.state))==JSON.parse_string(JSON.stringify(clone.state)),"migrated city has identical continuation after save reload")
	var full=Factory.new();load("res://tests/world_fixture.gd").empty(full)
	for i in range(World.MAX_ENTITIES):
		var x=i%32;var y=int(i/32);full.state.world.nodes.erase(full.key(x,y));full.create_entity("belt",x,y)
	check(full.upgrade_world() and full.state.entities.size()==World.MAX_ENTITIES+1,"full legacy city gains a hub without deleting a player building")
	check(store.validate(store.snapshot(full)).is_empty(),"full migrated city remains saveable with its extra public building")
	var saturated=Factory.new();saturated.fresh(0,true,42)
	var instant=Factory.new();instant.fresh(0,true,42)
	instant.state.cash=10000
	var untouched=JSON.stringify(instant.state)
	check(instant.command({"type":"upgradeIncome","entityId":instant.sales_hub().id})=="LOCKED" and JSON.stringify(instant.state)==untouched,"removed hub price upgrade cannot spend money or change state")
	instant.state.cash=0
	var instant_hub=instant.sales_hub();instant_hub.inputs={"log":1000,"plank":1000};instant.state.bag={"log":7}
	var expected=1000*(instant.sale_price(instant_hub,"log")+instant.sale_price(instant_hub,"plank"))
	instant.advance(Factory.DT)
	check(instant_hub.inputs.is_empty() and instant.state.cash==expected,"entire mixed backlog sells in one tick without processing or storage limits")
	check(instant.stock("log")==7 and instant.state.totals.sold.log==1000 and instant.state.totals.sold.plank==1000,"instant sales reconcile cash and units without touching bag")
	var incoming=instant.create_entity("belt",64,64,{"direction":1});incoming.queue=["log"];incoming.flowCredit=1
	instant.advance(Factory.DT)
	check(incoming.queue.is_empty() and instant_hub.inputs.is_empty() and instant.state.cash==expected+35,"arrival is credited during the transfer tick")
	for kind in ["upgrade","upgradeManager"]:
		check(instant.command({"type":kind,"entityId":instant_hub.id})=="LOCKED","obsolete hub speed purchases cannot consume money")
	instant.state.cash=Factory.MAX_MONEY
	incoming.queue=["log"];incoming.flowCredit=1;instant.advance(Factory.DT)
	check(incoming.queue==["log"] and instant_hub.inputs.is_empty(),"cash cap leaves unpaid arrivals on the conveyor")
	var multi=Factory.new();multi.fresh(0,true,42)
	for entry in [[64,63,1],[64,64,1],[64,65,1],[68,63,3],[68,64,3],[68,65,3],[65,62,2],[66,62,2],[67,62,2],[65,66,0],[66,66,0],[67,66,0]]:
		var feed=multi.create_entity("belt",entry[0],entry[1],{"direction":entry[2],"level":2,"flowCredit":3})
		feed.queue=["log","log","log"]
	multi.advance(Factory.DT)
	check(multi.state.cash==36*35 and multi.state.totals.sold.get("log",0)==36 and multi.transfers.size()==36,"all twelve sides sell 36 simultaneous arrivals without a shared processing limit")
	var ledger=0
	for receipt in multi.state.recentSales:ledger+=receipt.cash
	check(ledger==multi.state.cash and multi.state.totals.earned==ledger,"simultaneous arrival receipts count income exactly once")
	multi.create_entity("dispatchOffice",80,80,{"project":{"complete":true,"materials":{},"remainingS":0}});multi.clear_effects()
	check(multi.sale_price(multi.sales_hub(),"log")==42,"dispatch office retains a useful twenty-percent price bonus instead of obsolete sales speed")
	var upgraded=Factory.new();upgraded.fresh(0,true,42)
	upgraded.sales_hub().incomeLevel=3;upgraded.sales_hub().investedCash=250;upgraded.state.cash=750
	upgraded.state.totals.earned=123;upgraded.state.bag={"log":2}
	check(upgraded.sale_price(upgraded.sales_hub(),"log")==35,"old saved price levels no longer multiply sale prices")
	parsed=store.parse(store.export_text(upgraded))
	check(not parsed.is_empty(),"old upgraded hub still validates for migration")
	var loaded=Factory.new();loaded.state=parsed.state
	check(loaded.upgrade_world() and loaded.state.cash==1000 and loaded.sales_hub().incomeLevel==0 and loaded.sales_hub().investedCash==0,"retired price upgrades refund the paid 55, 90 and 105 exactly once")
	check(loaded.state.totals.earned==123 and loaded.state.recentSales.is_empty(),"upgrade refund is not counted as production or sale income")
	untouched=JSON.stringify(loaded.state)
	check(not loaded.upgrade_world() and JSON.stringify(loaded.state)==untouched,"reloading retired upgrades cannot duplicate the refund")
	loaded.command({"type":"sellInventory","entityId":loaded.sales_hub().id})
	check(loaded.state.cash==1070 and loaded.stock("log")==0,"manual sale uses base price after upgraded-save migration")
	var feeder=loaded.create_entity("belt",64,64,{"direction":1,"flowCredit":1});feeder.queue=["log"];loaded.advance(Factory.DT)
	check(loaded.state.cash==1105 and feeder.queue.is_empty(),"automatic arrival uses the same base price after migration")
	var capped=Factory.new();capped.fresh(0,true,42)
	capped.sales_hub().incomeLevel=3;capped.sales_hub().investedCash=1250;capped.state.cash=Factory.MAX_MONEY-100
	untouched=JSON.stringify(capped.state)
	check(not capped.upgrade_world() and JSON.stringify(capped.state)==untouched and capped.sale_price(capped.sales_hub(),"log")==35,"full refund is deferred without losing principal when cash is near its cap")
	capped.state.cash=Factory.MAX_MONEY-250
	check(capped.upgrade_world() and capped.state.cash==Factory.MAX_MONEY and capped.sales_hub().incomeLevel==0 and capped.sales_hub().investedCash==1000,"pending refund completes once space exists and preserves other paid hub investment")
	check(store.validate(store.snapshot(capped)).is_empty(),"retired upgraded save remains valid at the money cap")
	saturated.state.cash=Factory.MAX_MONEY-35;saturated.state.bag={"log":3}
	check(saturated.command({"type":"sellInventory","entityId":saturated.sales_hub().id})=="OK" and saturated.stock("log")==2 and saturated.state.cash==Factory.MAX_MONEY,"money cap keeps unsold bag items")
	saturated.state.cash=Factory.MAX_MONEY-35;saturated.sales_hub().inputs.log=3;saturated.advance(1)
	check(saturated.sales_hub().inputs.get("log",0)==2 and saturated.state.cash==Factory.MAX_MONEY,"automatic sales retain unpaid items at money cap")
	var district=Factory.new();district.fresh(0,false);district.state.bag={"log":12,"plank":6};district.state.entities.e1.outputs.log=3
	check(district.upgrade_world() and district.central_sales(),"older district cities also upgrade to the warehouse-free world")
	check(district.stock("log")==12 and district.stock("plank")==6 and district.state.entities.e1.outputs.log==3,"district upgrade preserves bag and machine output independently")
	check(store.validate(store.snapshot(district)).is_empty(),"upgraded district save validates")
	print("SALES_HUB: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
