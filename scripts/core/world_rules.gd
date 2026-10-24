class_name RustWorldRules
extends RefCounted
const World=preload("res://scripts/core/world_map.gd")
static func init_entity(e:Dictionary):
	e.starter=false
	if e.kind=="warehouse":e.inventory={};e.autoSell=false;e.localSaleCredit=0.0
static func setup(game,seed_value:int):
	game.state.world=World.generate(seed_value)
	game.state.world.spawn={"x":62,"y":64}
	game.state.entities={};game.state.nextId=1;game.state.records=[]
	game.state.cash=game.data.facilities.forest.cost
	game.state.factory.startMode="empty";game.state.factory.pioneerForestId=""
	game.invalidate_index()
	game.upgrade_world()
	# Use the ordinary paid build so recovery and saved investment stay consistent.
	game.command({"type":"build","kind":"forest","x":62,"y":64})
static func pioneer_sale(game,e):
	if game.central_sales():return
	if e.id!=game.state.factory.get("pioneerForestId","") or e.kind!="forest":return
	e.pioneerCycles+=1
	var d=game.DIRS[int(e.direction)];var target=game.at(e.x+d.x,e.y+d.y)
	var linked=false
	if not target.is_empty():
		var snapshots={target.id:{"queue":target.queue,"inputs":target.inputs,"outputs":target.outputs}}
		linked=game.transport_space(target,"log",e,snapshots,{})>0
	# A partial line still earns enough to buy its missing shipping equipment.
	if linked and (game.recorded("first_auto_sale") or int(e.pioneerCycles)%2==0):return
	game.add(e.outputs,"log",-1);game.add(game.state.totals.sold,"log",1)
	game.sale(game.credit(game.sale_price(e,"log")),"market",e.id)
static func stock(game,r) -> int:
	var n=int(game.state.bag.get(r,0))
	if game.central_sales():return n
	for e in game.state.entities.values():
		if e.kind=="warehouse":n+=int(e.get("inventory",{}).get(r,0))
	return n
static func remove_materials(game,recipe:Dictionary):
	for r in recipe:
		var remaining=int(recipe[r]);var used=mini(remaining,int(game.state.bag.get(r,0)))
		game.add(game.state.bag,r,-used);remaining-=used
		for e in game.state.entities.values():
			if e.kind!="warehouse" or remaining<=0:continue
			used=mini(remaining,int(e.inventory.get(r,0)));game.add(e.inventory,r,-used);remaining-=used
static func deposit(game,resources:Dictionary,at:Vector2i,excluded=""):
	if game.central_sales():
		for r in resources:game.add(game.state.bag,r,resources[r])
		return
	var closest={};var distance=999999
	for e in game.state.entities.values():
		if e.kind!="warehouse" or e.id==excluded:continue
		var d=abs(int(e.x)-at.x)+abs(int(e.y)-at.y)
		if d<distance:closest=e;distance=d
	var target=closest.inventory if not closest.is_empty() else game.state.bag
	for r in resources:game.add(target,r,resources[r])
static func apply_clear(game,quote:Dictionary):
	for pos in quote.clear:game.state.world.nodes.erase(pos);game.state.world.cleared[pos]=true
	if not quote.clear.is_empty():deposit(game,quote.reward,World.parse_key(quote.clear[0]))
	if not quote.clear.is_empty():game.event("first_clearing")
static func migrate(game,seed_value) -> String:
	if game.world_mode():return "LOCKED"
	if not (seed_value is int or seed_value is float) or seed_value!=floor(seed_value) or seed_value<0 or seed_value>2147483647:return "INVALID"
	game.state.world=World.generate(int(seed_value))
	for e in game.state.entities.values():
		e.x+=55;e.y+=58;e.starter=e.id in ["e1","e2","e3"]
		game.state.world.nodes.erase(game.key(e.x,e.y))
		if e.kind=="forest":game.state.world.nodes[game.key(e.x,e.y)]="log"
		if e.kind=="mine":game.state.world.nodes[game.key(e.x,e.y)]=e.mineResourceId
		if e.kind=="warehouse":e.inventory={};e.autoSell=true;e.localSaleCredit=0.0
	var depot=game.state.entities.e3
	depot.inventory=game.state.bag.duplicate(true);game.state.bag={}
	game.state.world.spawn={"x":game.state.entities.e2.x,"y":game.state.entities.e2.y}
	game.state.world.revision+=1;game.invalidate_index();game.event("open_world")
	return "OK"
static func command(game,c:Dictionary) -> String:
	if game.central_sales():
		var result=game.SalesHub.command(game,c)
		if result!="PASS":return result
	var e=game.state.entities.get(c.get("entityId",""),{})
	match c.get("type",""):
		"recoverCargo":
			if e.is_empty() or not game.transport(e):return "INVALID"
			if e.queue.is_empty():return "EMPTY"
			var recovered={}
			for r in e.queue:game.add(recovered,r,1)
			for r in recovered:
				if recovered[r]>game.MAX_MONEY-int(game.state.bag.get(r,0)):return "INSUFFICIENT_SPACE"
			for r in recovered:game.add(game.state.bag,r,recovered[r])
			e.queue=[];e.flowCredit=0
		"setSplitPort":
			var port=c.get("port",-1);var direction=c.get("direction",-1)
			if e.get("kind","")!="splitter" or port not in [0,1] or direction not in [0,1,2,3]:return "INVALID"
			if e.splitDirections[1-int(port)]==direction:return "INVALID"
			e.splitDirections[int(port)]=direction;e.direction=e.splitDirections[0]
		"expand","setMineResource":return "LOCKED"
		"build","buildLinked":
			var kind=c.get("kind","")
			var linked={}
			if c.type=="buildLinked":
				linked=World.linked_quote(game,c.get("sourceId",""),kind,c)
				if not linked.ok:return linked.code
			if not World.valid_point(c) or not game.data.facilities.has(kind):return "INVALID"
			if not game.at(c.x,c.y).is_empty():return "OCCUPIED"
			if not game.unlocked(kind):return "LOCKED"
			var r=World.resource_at(game.state.world,c.x,c.y)
			if (kind=="forest" and r!="log") or (kind=="mine" and r not in ["stone","coal","copper","iron"]):return "RESOURCE_REQUIRED"
			if kind=="mine" and r=="iron" and game.stage_index()<3:return "LOCKED"
			if kind not in ["forest","mine"] and not r.is_empty():return "BLOCKED"
			if game.state.entities.size()>=game.entity_limit():return "TOO_LARGE"
			if game.is_project(kind):
				for existing in game.state.entities.values():
					if existing.kind==kind:return "LOCKED"
			var f=game.data.facilities[kind]
			var materials=game.construction_materials(kind)
			var total=linked.cash if not linked.is_empty() else f.cost
			if not game.affordable(total,materials):return "INSUFFICIENT_CASH" if game.state.cash<total else "INSUFFICIENT_RESOURCE"
			game.pay(total,materials)
			var extra={"investedCash":f.cost}
			if kind=="forest" and game.state.factory.get("startMode","")=="empty" and game.state.factory.pioneerForestId.is_empty():
				extra.starter=true;extra.pioneerCycles=0;game.state.factory.pioneerForestId="e%d"%int(game.state.nextId)
			if kind=="warehouse" and game.shipping_depot().is_empty():extra.autoSell=true
			if kind=="mine":extra.mineResourceId=r
			if game.is_project(kind):extra.project={"materials":{},"remainingS":game.data.projects[kind].seconds,"complete":false}
			if not linked.is_empty():extra.direction=linked.targetDirection
			game.create_entity(kind,int(c.x),int(c.y),extra);game.event("first_"+kind)
			if not linked.is_empty():
				game.state.entities[c.sourceId].direction=linked.sourceDirection
				for cell in linked.cells:game.create_entity("belt",cell.x,cell.y,{"direction":cell.direction,"investedCash":game.data.facilities.belt.cost})
				game.event("first_route")
		"clearArea","buildRoute":
			if game.state.factory.get("startMode","")=="empty" and game.state.factory.pioneerForestId.is_empty() and (not game.SalesHub.started(game) if game.central_sales() else game.state.entities.is_empty()):return "LOCKED"
			var quote=World.clear_quote(game,c.get("from"),c.get("to")) if c.type=="clearArea" else World.route_quote(game,c.get("from"),c.get("to"),c.get("clear",false))
			if not quote.ok:return quote.code
			if game.state.cash<quote.cash:return "INSUFFICIENT_CASH"
			game.state.cash-=quote.cash;apply_clear(game,quote)
			if c.type=="buildRoute":
				var source=game.at(c.from.x,c.from.y)
				if not source.is_empty():
					source.direction=quote.sourceDirection
					if source.kind=="splitter":source.splitDirections=World.split_ports(game,source,source.direction)
				for cell in quote.cells:game.create_entity("belt",cell.x,cell.y,{"direction":cell.direction,"investedCash":game.data.facilities.belt.cost})
				game.event("first_route")
		"configureWarehouse":
			if e.get("kind","")!="warehouse" or (c.get("resource")!=null and not game.data.resources.has(c.resource)):return "INVALID"
			for r in e.outputs:game.add(e.inventory,r,e.outputs[r])
			e.outputs={};e.dispatchResource=c.get("resource")
		"setWarehouseSales":
			if e.get("kind","")!="warehouse" or not c.get("enabled") is bool:return "INVALID"
			e.autoSell=c.enabled
		"cancelOrder":
			var t=game.trade()
			if t.active==null and not t.repeat:return "LOCKED"
			if t.active!=null:game.add(game.shipping_depot().inventory,t.active.resource,t.active.reserved+t.active.loaded)
			t.active=null;t.repeat=false
		"demolish":
			if e.is_empty():return "INVALID"
			var recovery={}
			if game.trade().active!=null and e==game.shipping_depot():
				var shipment=game.trade().active
				game.add(recovery,shipment.resource,shipment.reserved+shipment.loaded)
				game.trade().active=null;game.trade().repeat=false
			for store in [e.inputs,e.outputs,e.get("inventory",{}),e.job.reserved if e.job!=null else {},e.project.materials if e.has("project") and not e.project.complete else {}]:
				for r in store:game.add(recovery,r,store[r])
			for r in e.queue:game.add(recovery,r,1)
			deposit(game,recovery,Vector2i(int(e.x),int(e.y)),e.id)
			game.credit(game.demolition_refund(e),false,false);game.state.entities.erase(e.id);game.invalidate_index()
			game.state.factory.startMode="empty"
			var pioneer=game.state.entities.get(game.state.factory.get("pioneerForestId",""),{})
			if pioneer.get("kind","")!="forest":
				game.state.factory.pioneerForestId=""
				for candidate in game.state.entities.values():
					if candidate.kind=="forest":
						candidate.starter=true;candidate.pioneerCycles=candidate.get("pioneerCycles",0)
						game.state.factory.pioneerForestId=candidate.id;break
			# Recent-sale provenance must never refer to a removed entity.
			for sale in game.state.recentSales:
				if sale.get("entityId","")==e.id:sale.erase("entityId")

		_:return "PASS"
	game.state.world.revision+=1
	return "OK"
static func progression(game):
	var previous=game.stage_index();var next=previous
	if game.produced("plank")>=30:next=maxi(next,1)
	if game.state.unlocks.get("smelting",false):next=maxi(next,2)
	for e in game.state.entities.values():
		if e.kind=="generator" and game.produced("wire")>=10:next=maxi(next,3)
	if game.produced("machinePart")>=10 and game.recorded("first_power"):next=maxi(next,4)
	if game.produced("structure")>=10:next=maxi(next,5)
	if game.produced("electronics")>=10 and game.produced("precision")>=10:next=maxi(next,6)
	for i in range(previous+1,next+1):game.event("stage_"+game.data.stages[i])
	game.state.stage=game.data.stages[next];game.state.unlocks.offline=next>=4
static func project_step(game):
	for e in game.state.entities.values():
		if not game.is_project(e.kind) or e.paused or e.project.complete:continue
		var p=e.project;var definition=game.data.projects[e.kind]
		if game.central_sales():
			p.remainingS=maxf(0,p.remainingS-game.DT)
			if p.remainingS==0:p.complete=true;game.event("complete_"+e.kind);game.clear_effects()
			continue
		for r in definition.materials:
			var n=mini(int(definition.materials[r]-p.materials.get(r,0)),int(e.inputs.get(r,0)))
			game.add(e.inputs,r,-n);game.add(p.materials,r,n)
			# City construction shares the same pooled stock as building costs.
			# Keep old conveyor deliveries, then allocate only the missing amount.
			n=mini(int(definition.materials[r]-p.materials.get(r,0)),stock(game,r))
			if n>0:remove_materials(game,{r:n});game.add(p.materials,r,n)
		if game.has_stock(p.materials,definition.materials):
			p.remainingS=maxf(0,p.remainingS-game.DT)
			if p.remainingS==0:p.complete=true;game.event("complete_"+e.kind);game.clear_effects()
static func trade_step(game):
	var t=game.trade();var depot=game.shipping_depot()
	if depot.is_empty():return
	if t.active==null:
		t.cooldownS=maxf(0,t.cooldownS-game.DT)
		if t.repeat and t.cooldownS==0:game.start_shipment(t.lastOfferId)
	if t.active==null:return
	var a=t.active
	if a.loaded<a.quantity:
		if depot.paused:return
		var surplus=maxi(0,int(depot.inventory.get(a.resource,0)-maxf(0,game.state.factory.reserves[a.resource])))
		var n=mini(int(a.quantity-a.loaded-a.reserved),surplus)
		game.add(depot.inventory,a.resource,-n);a.reserved+=n
		a.loadingCredit=minf(game.effects().loading,a.loadingCredit+game.DT*game.effects().loading)
		var loaded=mini(int(a.reserved),int(floor(a.loadingCredit+0.000000001)))
		a.reserved-=loaded;a.loaded+=loaded;a.loadingCredit=maxf(0,a.loadingCredit-loaded)
		return
	a.departureS=maxf(0,a.departureS-game.DT)
	if a.departureS>0:return
	var income=game.credit(a.reward);game.add(game.state.totals.sold,a.resource,a.quantity)
	t.rewardEarned=mini(game.MAX_MONEY,int(t.rewardEarned)+income);t.completed+=1;t.active=null;t.cooldownS=game.effects().cooldown
	game.event("first_shipment");game.sale(income,"shipment",depot.id)
static func warehouse_step(game):
	if game.central_sales():project_step(game);return
	var warehouses=[]
	for e in game.state.entities.values():
		if e.kind!="warehouse" or e.paused:continue
		warehouses.append(e)
		for r in e.inputs:game.add(e.inventory,r,e.inputs[r])
		e.inputs={}
	project_step(game)
	for e in warehouses:
		var r=e.get("dispatchResource")
		if r==null:continue
		var buffer=maxi(1,int(ceil(1.5*game.speed(e)*game.DT)))
		var n=mini(buffer-int(e.outputs.get(r,0)),int(e.inventory.get(r,0)-maxf(0,game.state.factory.reserves[r])))
		if n<=0:continue
		var d=game.DIRS[int(e.direction)];var target=game.at(e.x+d.x,e.y+d.y)
		if target.is_empty():continue
		var snapshots={target.id:{"queue":target.queue,"inputs":target.inputs,"outputs":target.outputs}}
		if game.transport_space(target,r,e,snapshots,{})<=0:continue
		game.add(e.inventory,r,-n);game.add(e.outputs,r,n)
	trade_step(game)
	var ids=game.data.resources.keys();var total_income=0
	for e in warehouses:
		if not e.autoSell:continue
		var income=0
		e.localSaleCredit=minf(2,e.localSaleCredit+game.DT*2*game.speed(e))
		while e.localSaleCredit>=1:
			var selected=-1
			for offset in range(ids.size()):
				var i=(int(e.saleCursor)+offset)%ids.size();var r=ids[i]
				if game.state.factory.reserves[r]>=0 and e.inventory.get(r,0)>game.state.factory.reserves[r]:selected=i;break
			if selected<0:break
			var r=ids[selected];income+=game.credit(game.sale_price(e,r));game.add(e.inventory,r,-1);game.add(game.state.totals.sold,r,1)
			e.localSaleCredit-=1;e.saleCursor=(selected+1)%ids.size()
			if r=="plank":game.event("first_auto_sale")
		if income>0:game.feedback_sale(income,e.id);total_income+=income
	if total_income>0:game.sale(total_income,"market")
