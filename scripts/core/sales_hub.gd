extends RefCounted
const World=preload("res://scripts/core/world_map.gd")
const SITE=Rect2i(65,63,3,3)
static func active(game) -> bool:return game.world_mode() and game.state.factory.get("economyVersion",0)==2
static func hub(game) -> Dictionary:
	var value=game.state.entities.get(game.state.factory.get("salesHubId",""),{})
	return value if value is Dictionary else {}
static func rect(e) -> Rect2i:return Rect2i(int(e.x),int(e.y),3 if e.get("salesHub",false) else 1,3 if e.get("salesHub",false) else 1)
static func started(game) -> bool:
	for e in game.state.entities.values():
		if not e.get("salesHub",false):return true
	return false
static func install(game) -> bool:
	if not game.world_mode():return false
	if active(game):return retire_price_upgrades(game)
	var t=game.trade()
	if t.active!=null:
		game.add(game.state.bag,t.active.resource,t.active.reserved+t.active.loaded)
	t.active=null;t.repeat=false;t.lastOfferId=null
	for e in game.state.entities.values():
		if e.kind in ["warehouse","market"]:
			for store in [e.inputs,e.outputs,e.get("inventory",{})]:
				for r in store:game.add(game.state.bag,r,store[r])
			for r in e.queue:game.add(game.state.bag,r,1)
			game.credit(int(floor(e.investedCash*0.5)),false,false)
			game.state.entities.erase(e.id)
		elif game.is_project(e.kind):
			if not e.project.complete:
				for r in e.project.materials:game.add(game.state.bag,r,e.project.materials[r])
			for r in e.inputs:game.add(game.state.bag,r,e.inputs[r])
			e.inputs={};e.project.materials={}
	# Preserve occupied legacy buildings when reserving the new public building.
	for e in game.state.entities.values():
		if not SITE.has_point(Vector2i(int(e.x),int(e.y))):continue
		var place=free_ground(game)
		e.x=place.x;e.y=place.y
		if e.kind in ["forest","mine"]:
			game.state.world.nodes[game.key(e.x,e.y)]="log" if e.kind=="forest" else e.mineResourceId
			game.state.world.cleared.erase(game.key(e.x,e.y))
		game.invalidate_index()
	for y in range(SITE.position.y,SITE.end.y):
		for x in range(SITE.position.x,SITE.end.x):
			var pos=game.key(x,y)
			if game.state.world.nodes.has(pos):game.state.world.nodes.erase(pos);game.state.world.cleared[pos]=true
	var building=game.create_entity("market",SITE.position.x,SITE.position.y,{"salesHub":true,"investedCash":0})
	game.state.factory.economyVersion=2;game.state.factory.salesHubId=building.id
	game.state.factory.startMode="empty"
	var pioneer=game.state.entities.get(game.state.factory.get("pioneerForestId",""),{})
	if pioneer.get("kind","")!="forest":
		game.state.factory.pioneerForestId=""
		for e in game.state.entities.values():
			if e.kind=="forest":game.state.factory.pioneerForestId=e.id;pioneer=e;break
	if not pioneer.is_empty():pioneer.starter=true;pioneer.pioneerCycles=pioneer.get("pioneerCycles",0)
	# Old recent-income provenance must not point at removed warehouses.
	for sale in game.state.recentSales:
		if not game.state.entities.has(sale.get("entityId","")):sale.erase("entityId")
	if game.state.entities.size()==1:game.state.world.spawn={"x":64,"y":64}
	if game.state.totals.earned>0 or game.recorded("first_auto_sale"):game.event("first_sale")
	game.state.world.revision+=1
	game.invalidate_index();game.clear_effects()
	return true
static func retire_price_upgrades(game) -> bool:
	var building=hub(game);var level=int(building.get("incomeLevel",0))
	if level==0:return false
	var refund=0;var costs=game.data.facilities.market.incomeCosts
	for i in range(level):refund+=int(costs[i])
	refund=mini(refund,int(building.investedCash))
	# Retain pending investment until the whole refund fits; never discard it.
	if refund>game.MAX_MONEY-int(game.state.cash):return false
	building.incomeLevel=0;building.investedCash-=refund
	game.credit(refund,false,false)
	return true
static func free_ground(game) -> Vector2i:
	for radius in range(1,129):
		for y in range(maxi(0,64-radius),mini(World.SIZE,65+radius)):
			for x in range(maxi(0,66-radius),mini(World.SIZE,67+radius)):
				if SITE.has_point(Vector2i(x,y)) or not game.at(x,y).is_empty():continue
				if World.resource_at(game.state.world,x,y).is_empty():return Vector2i(x,y)
	return Vector2i.ZERO # At most 1024 buildings in a 16384-tile world.
static func command(game,c:Dictionary) -> String:
	var type=c.get("type","");var e=game.state.entities.get(c.get("entityId",""),{})
	if type in ["configureWarehouse","setWarehouseSales","setReserve","setFilters","takeOrder","cancelOrder","setTradeRepeat"]:return "LOCKED"
	if e.get("salesHub",false) and type in ["demolish","pause","rotate"]:return "PROTECTED"
	if e.get("salesHub",false) and type in ["upgrade","upgradeManager","upgradeIncome"]:return "LOCKED"
	if type in ["upgrade","upgradeIncome","upgradeManager"] and not started(game):return "LOCKED"
	if type=="insertSawmill":
		if e.get("kind","")!="belt" or game.has_facility("sawmill"):return "LOCKED"
		if not e.inputs.is_empty() or not e.outputs.is_empty() or not e.queue.all(func(r):return r=="log"):return "INVALID"
		if not game.affordable(game.data.facilities.sawmill.cost):return "INSUFFICIENT_CASH"
		game.pay(game.data.facilities.sawmill.cost)
		var n=e.queue.size();e.kind="sawmill";e.level=1;e.managerLevel=0;e.incomeLevel=0
		e.inputs={"log":n} if n>0 else {};e.queue=[];e.job=null;e.flowCredit=0
		e.investedCash+=game.data.facilities.sawmill.cost
		game.event("first_sawmill");game.state.world.revision+=1;return "OK"
	if type=="collect":
		if e.is_empty() or game.recipe(e).output.is_empty() or game.transport(e):return "INVALID"
		if e.outputs.is_empty():return "EMPTY"
		for r in e.outputs:game.add(game.state.bag,r,e.outputs[r])
		e.outputs={};game.event("first_collection");return "OK"
	if type=="sellInventory":
		if not e.get("salesHub",false) or e.id!=hub(game).get("id"):return "INVALID"
		var resources=game.data.resources.keys()
		if c.has("resource"):
			if not c.resource is String or not game.data.resources.has(c.resource):return "INVALID"
			resources=[c.resource]
		var earned=0
		for r in resources:
			var price=game.sale_price(e,r)
			var n=mini(int(game.state.bag.get(r,0)),int(floor(float(game.MAX_MONEY-int(game.state.cash))/price)))
			if n<=0:continue
			game.add(game.state.bag,r,-n);game.add(game.state.totals.sold,r,n)
			earned+=game.credit(n*price)
		if earned==0:return "EMPTY"
		game.sale(earned,"market",e.id);game.event("first_sale");return "OK"
	if type=="research":
		if game.stage_index()<1 or game.state.unlocks.get("smelting",false) or game.produced("copper")<20:return "LOCKED"
		if not game.affordable(game.data.research.cash):return "INSUFFICIENT_CASH"
		game.pay(game.data.research.cash);game.state.unlocks.smelting=true;return "OK"
	return "PASS"

## Sell every payable item immediately, including older buffered deliveries.
static func sell_arrivals(game,e):
	var earned=0
	for r in e.inputs.keys():
		var price=game.sale_price(e,r)
		var n=mini(int(e.inputs[r]),int(floor(float(game.MAX_MONEY-int(game.state.cash))/price)))
		if n<=0:continue
		game.add(e.inputs,r,-n);game.add(game.state.totals.sold,r,n)
		earned+=game.credit(n*price)
	if earned>0:
		game.sale(earned,"market",e.id);game.event("first_auto_sale");game.event("first_sale")
