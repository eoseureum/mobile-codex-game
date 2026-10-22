extends SceneTree
const Factory=preload("res://scripts/core/factory.gd")
const Store=preload("res://scripts/core/save_store.gd")
var checks=0
var failures=0
func check(value,message):
	checks+=1
	if not value:failures+=1;printerr("FAIL: "+message)
func buy(g,kind,x,y):
	var result=g.command({"type":"build","kind":kind,"x":x,"y":y})
	check(result=="OK","paid construction: "+kind+" / "+result)
func _initialize():
	var g=Factory.new();g.fresh(0,true,42)
	check(g.state.entities.is_empty(),"new city starts with no buildings")
	check(g.state.cash==g.data.facilities.forest.cost,"starting cash buys exactly one logging camp")
	if not g.state.entities.is_empty():quit(1);return
	var store=Store.new()
	check(store.validate(store.snapshot(g)).is_empty(),"empty city can be saved")
	g.advance(30)
	check(g.state.totals.earned==0 and g.produced("log")==0,"empty land does not create money or logs")
	check(not g.unlocked("sawmill") and not g.unlocked("warehouse"),"first construction is a logging camp")
	check(g.command({"type":"build","kind":"warehouse","x":64,"y":64})=="LOCKED","cannot spend starting cash on a dead-end warehouse")
	check(g.command({"type":"clearArea","from":{"x":62,"y":64},"to":{"x":62,"y":64}})=="LOCKED","cannot consume first camp budget by clearing land")
	buy(g,"forest",62,64)
	check(g.state.cash==0 and g.state.entities.size()==1,"first camp spends the entire initial budget")
	check(g.unlocked("sawmill") and g.unlocked("warehouse"),"first camp opens the next construction choices")
	g.advance(g.data.facilities.forest.cycle)
	check(g.produced("log")==1 and g.state.totals.sold.get("log",0)==1 and g.state.cash==g.price("log"),"first real log sells after one production cycle")
	check(store.validate(store.snapshot(g)).is_empty(),"single camp city can be saved")
	var cash_before=g.state.cash
	g.command({"type":"pause","entityId":g.at(62,64).id});g.advance(8)
	check(g.state.cash==cash_before,"paused camp creates no income")
	g.command({"type":"pause","entityId":g.at(62,64).id})
	while g.state.cash<g.data.facilities.sawmill.cost+g.data.facilities.belt.cost:g.advance(0.25)
	buy(g,"sawmill",64,64)
	buy(g,"belt",63,64)
	check(g.state.cash<g.price("log"),"player may buy a sawmill before a warehouse")
	g.advance(40)
	check(g.state.cash>0 and g.produced("plank")>0,"partial line keeps both starter sales and processing running")
	while g.state.cash<g.data.facilities.warehouse.cost+g.data.facilities.belt.cost:g.advance(0.25)
	buy(g,"warehouse",66,64)
	buy(g,"belt",65,64)
	var depot=g.at(66,64)
	check(depot.get("autoSell",false),"first purchased warehouse automatically sells surplus")
	for i in range(480):
		if g.recorded("first_auto_sale"):break
		g.advance(0.25)
	check(g.recorded("first_auto_sale"),"paid starter line reaches actual plank sales without manual transfers")
	var sold_logs=g.state.totals.sold.get("log",0);var planks=g.produced("plank");cash_before=g.state.cash
	g.advance(40)
	check(g.state.totals.sold.get("log",0)==sold_logs,"working plank sales switch connected camp to full factory supply")
	check(g.produced("plank")-planks>=int(40/g.data.facilities.forest.cycle)*3-3 and g.state.cash-cash_before>40/g.data.facilities.forest.cycle*g.price("log"),"processing provides a clear income and throughput increase")
	check(g.stage_index()>=1,"paid empty-start city reaches mining through planks")
	check(g.state.totals.earned==g.state.cash+g.data.facilities.sawmill.cost+g.data.facilities.warehouse.cost+2*g.data.facilities.belt.cost,"all cash reconciles to actual sales and paid purchases")
	check(store.validate(store.snapshot(g)).is_empty(),"variable building IDs validate after factory growth")
	var clone=Factory.new();var saved=store.parse(store.export_text(g));clone.state=saved.state
	g.advance(10);clone.advance(10)
	check(JSON.parse_string(JSON.stringify(g.state))==JSON.parse_string(JSON.stringify(clone.state)),"save roundtrip preserves automatic camp and factory behavior")
	check(not g.offers().is_empty(),"shipments use a purchased warehouse regardless of entity ID")
	check(g.command({"type":"setReserve","resource":"plank","quantity":0})=="OK","can release plank stock for shipment")
	check(g.command({"type":"takeOrder","offerId":g.offers()[0].id})=="OK","can accept an order at a purchased depot")
	g.advance(1)
	check(g.command({"type":"cancelOrder"})=="OK","order cancellation refunds the actual purchased depot")
	var another=g.create_entity("forest",59,69);cash_before=g.state.cash;g.command({"type":"pause","entityId":g.at(62,64).id});g.command({"type":"pause","entityId":depot.id});g.advance(8)
	check(g.state.cash==cash_before and another.outputs.get("log",0)>0,"later disconnected camps do not gain starter on-site sales")
	check(g.command({"type":"demolish","entityId":g.at(64,64).id})=="OK","purchased sawmill is removable even when its ID is e2")
	check(g.command({"type":"demolish","entityId":g.at(62,64).id})=="OK","first income source can be redesigned")
	var bad=store.snapshot(g);bad.state.factory.pioneerForestId=depot.id
	check(not store.validate(bad).is_empty(),"save rejects on-site sales assigned to a non-forest")
	var early=Factory.new();early.fresh(0,true,42);buy(early,"forest",62,64);
	while early.state.cash<900:early.advance(0.25)
	buy(early,"warehouse",64,64);var first_depot=early.at(64,64)
	buy(early,"warehouse",66,64)
	check(early.shipping_depot().id==first_depot.id,"building warehouse e3 never replaces an earlier shipping depot")
	check(first_depot.autoSell and not early.at(66,64).autoSell,"only first purchased warehouse defaults to auto sales")
	print("EMPTY_START: %d checks, %d failures / elapsed %.2fs / earned %d"%[checks,failures,g.state.clock.elapsedS,g.state.totals.earned]);quit(1 if failures else 0)
