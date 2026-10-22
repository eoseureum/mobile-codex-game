extends SceneTree
## Reproducible command-only, sequential batch campaign. No state mutation.
const Factory=preload("res://scripts/core/factory.gd")
const World=preload("res://scripts/core/world_map.gd")
const Store=preload("res://scripts/core/save_store.gd")
const PREFIX="res://docs/balance/2026-10-22-campaign"
var g
var sources={}
var actions=[]
var checkpoints=[]
var spent=0
var refunds=0
var failed=false
var money_resource="plank"
var funding=false
var busy={}
var input_ports={}
var output_ports={}
var next_progress=600.0
var review_seconds=0.0
var seed_value=42
var wall_start=0
var limits=21600.0
var replay_path=""
var opening_baseline=false
func _initialize():call_deferred("run")
func run():
	wall_start=Time.get_ticks_msec()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--review-seconds="):review_seconds=float(arg.get_slice("=",1))
		if arg.begins_with("--seed="):seed_value=int(arg.get_slice("=",1))
		if arg.begins_with("--replay="):replay_path=arg.get_slice("=",1)
		if arg=="--opening-baseline":opening_baseline=true
	if not replay_path.is_empty():replay();return
	g=Factory.new();g.fresh(0,true,seed_value)
	if opening_baseline:probe_opening();return
	checkpoint("fresh empty world")
	var forest=build("forest",Vector2i(62,64))
	wait_cash(g.data.facilities.forest.incomeCosts[0]);cmd({"type":"upgradeIncome","entityId":forest.id})
	wait_cash(g.data.facilities.forest.upgradeCosts[0]);cmd({"type":"upgrade","entityId":forest.id})
	checkpoint("early cash-only investments")
	wait_cash(g.data.facilities.sawmill.cost+g.data.facilities.belt.cost)
	cmd({"type":"buildLinked","sourceId":forest.id,"kind":"sawmill","x":64,"y":64})
	var saw=g.at(64,64)
	checkpoint("first linked sawmill")
	wait_cash(g.data.facilities.warehouse.cost+g.data.facilities.belt.cost)
	cmd({"type":"buildLinked","sourceId":saw.id,"kind":"warehouse","x":66,"y":64})
	var depot=g.at(66,64)
	for r in g.data.resources:cmd({"type":"setReserve","resource":r,"quantity":0})
	sources.plank={"entity":saw.id,"collector":depot.id,"routes":[],"passive":true}
	wait_for(func():return g.recorded("first_auto_sale"),"first automatic sale")
	checkpoint("first automatic sale")
	# Upgrade the first complete line before reaching the next cash scale.
	for i in range(4):
		wait_cash(g.data.facilities.forest.upgradeCosts[int(forest.level)-1]);cmd({"type":"upgrade","entityId":forest.id})
		wait_cash(g.data.facilities.warehouse.incomeCosts[int(depot.get("incomeLevel",0))]);cmd({"type":"upgradeIncome","entityId":depot.id})
	wait_cash(g.data.facilities.belt.cost*3)
	prepare_output_ports(depot)
	cmd({"type":"setWarehouseSales","entityId":depot.id,"enabled":false})
	ensure("plank",30)
	checkpoint("mining unlocked")
	ensure("copper",25);money_resource="copper"
	ensure("stone",10);ensure("coal",5)
	ensure_cash(g.data.research.cash)
	cmd({"type":"research"});checkpoint("smelting research")
	ensure("copperIngot",10);money_resource="copperIngot"
	ensure("wire",20);money_resource="wire"
	construct("generator")
	ensure("coal",10)
	var generator=find_kind("generator")
	# Its dedicated coal mine keeps the grid alive while batch supply routes move.
	wait_for(func():return g.recorded("first_power"),"first power")
	checkpoint("power online")
	ensure("iron",30);money_resource="iron";invest()
	ensure("ironIngot",20);money_resource="ironIngot";invest()
	ensure("machinePart",20);money_resource="machinePart";invest()
	checkpoint("automation unlocked")
	ensure("structure",30);money_resource="structure";invest();construct("generator")
	checkpoint("advanced unlocked")
	ensure("electronics",20);money_resource="electronics";invest()
	ensure("precision",20);money_resource="precision";invest()
	ensure("fuel",20);money_resource="fuel"
	checkpoint("space chain complete")
	ensure_cash(g.data.facilities.launchpad.cost+100000)
	var rocket_stock=g.data.rocket.duplicate()
	for r in g.data.facilities.launchpad.materials:rocket_stock[r]=int(rocket_stock.get(r,0))+int(g.data.facilities.launchpad.materials[r])
	ensure_materials(rocket_stock)
	checkpoint("rocket stock ready")
	var pad=construct("launchpad")
	for r in g.data.rocket:
		if failed:break
		ensure(r,int(g.data.rocket[r]))
		feed(pad,r,int(g.data.rocket[r]))
		wait_for(func():return int(g.state.rocket.delivered.get(r,0))>=int(g.data.rocket[r]),"rocket delivery "+r)
		disconnect_route(r)
		checkpoint("delivered "+r)
	cmd({"type":"launch"})
	checkpoint("launch")
	var validation=Store.new().validate(Store.new().snapshot(g))
	if not validation.is_empty():fail("save validation: "+validation)
	write_result()
	print("CAMPAIGN ","FAIL" if failed else "PASS"," / minutes ",g.state.clock.elapsedS/60.0," / actions ",actions.size()," / spent ",spent," / wall seconds ",(Time.get_ticks_msec()-wall_start)/1000.0)
	quit(1 if failed else 0)
func cmd(c):
	if failed:return "FAILED"
	var before=int(g.state.cash)
	var result=g.command(c)
	if result!="OK":fail("command "+JSON.stringify(c)+" returned "+result);return result
	spent+=maxi(0,before-int(g.state.cash));refunds+=maxi(0,int(g.state.cash)-before)
	actions.append({"atS":g.state.clock.elapsedS,"command":c.duplicate(true)})
	return result
func step():
	g.tick()
	if g.state.clock.elapsedS>=next_progress:
		print("CAMPAIGN PROGRESS ",g.state.clock.elapsedS/60.0,"m / ",g.state.stage," / cash ",g.state.cash," / entities ",g.state.entities.size()," / funding ",funding," / busy ",busy.keys())
		next_progress+=600;write_result()
	if g.state.clock.elapsedS>limits:fail("campaign exceeded simulated time limit")
func wait_for(condition,label,timeout=3600.0,progress_resource=""):
	var last_productive=float(g.state.clock.elapsedS)
	var last_count=g.produced(progress_resource) if not progress_resource.is_empty() else 0
	var deadline=float(g.state.clock.elapsedS)+timeout
	while not failed and not condition.call():
		if g.state.clock.elapsedS>=deadline:fail("timeout: "+label);break
		if not progress_resource.is_empty():
			if g.produced(progress_resource)!=last_count:last_count=g.produced(progress_resource);last_productive=g.state.clock.elapsedS
			if g.state.clock.elapsedS-last_productive>300:fail("no production for 300s: "+label);break
		var review_at=g.state.clock.elapsedS+g.DT if review_seconds<=0 else (floor(g.state.clock.elapsedS/review_seconds)+1)*review_seconds
		while g.state.clock.elapsedS<minf(review_at,deadline) and not failed:step()
func wait_cash(amount):wait_for(func():return g.state.cash>=amount,"cash "+str(amount))
func fail(reason):
	if failed:return
	failed=true;printerr("CAMPAIGN FAILURE ",reason," at ",g.state.clock.elapsedS,"s")
	write_result();quit(1)
func checkpoint(label):
	if failed:return
	var row={"label":label,"atS":g.state.clock.elapsedS,"cash":g.state.cash,"spent":spent,"refunds":refunds,"earned":g.state.totals.earned,"entities":g.state.entities.size(),"stage":g.state.stage,"produced":g.state.totals.produced.duplicate(true)}
	checkpoints.append(row);print("CHECKPOINT ",JSON.stringify(row));write_result()
func write_result():
	if g==null:return
	var result={"catalogHash":FileAccess.get_file_as_string("res://data/catalog.json").sha256_text(),"seed":seed_value,"reviewSeconds":review_seconds,"failed":failed,"elapsedS":g.state.clock.elapsedS,"cash":g.state.cash,"earned":g.state.totals.earned,"spent":spent,"refunds":refunds,"launched":g.state.rocket.launched,"actions":actions,"checkpoints":checkpoints,"expectedProduction":g.state.totals.produced,"expectedSold":g.state.totals.sold,"rocketDelivered":g.state.rocket.delivered}
	var suffix="-managed" if review_seconds>0 else "-zero-latency"
	if seed_value!=42:suffix+="-seed%d"%seed_value
	FileAccess.open(PREFIX+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify(result))
	FileAccess.open(PREFIX+suffix+"-save.json",FileAccess.WRITE).store_string(JSON.stringify(Store.new().snapshot(g)))
func build(kind,pos):
	cmd({"type":"build","kind":kind,"x":pos.x,"y":pos.y})
	return g.at(pos.x,pos.y)
func find_kind(kind):
	for e in g.state.entities.values():
		if e.kind==kind:return e
	return {}
func choose_site():
	# Each cell reserves adjacent output and three distinct input approach cells.
	for radius in range(3,57):
		for y in range(64-radius,65+radius):
			for x in [64-radius,64+radius]:
				if x<3 or y<3 or x>123 or y>123:continue
				var valid=true
				for dy in range(-2,3):
					for dx in range(-2,4):
						if not g.at(x+dx,y+dy).is_empty() or not World.resource_at(g.state.world,x+dx,y+dy).is_empty():valid=false
				if valid:return Vector2i(x,y)
	fail("no open processing cell");return Vector2i(-1,-1)
func choose_node(r):
	var best=Vector2i(-1,-1);var distance=99999
	for key in g.state.world.nodes:
		if g.state.world.nodes[key]!=r:continue
		var p=World.parse_key(key)
		if not g.at(p.x,p.y).is_empty() or p.x>125:continue
		if not g.at(p.x+1,p.y).is_empty() or not World.resource_at(g.state.world,p.x+1,p.y).is_empty():continue
		var d=absi(p.x-64)+absi(p.y-64)
		if d<distance:distance=d;best=p
	if best.x<0:fail("no node for "+r)
	return best
func make_source(r):
	if sources.has(r) or failed:return
	var kind="forest" if r=="log" else "mine"
	if r not in ["log","stone","coal","copper","iron"]:
		for candidate in g.data.facilities:
			if g.data.facilities[candidate].output.has(r):kind=candidate;break
	var entity=construct(kind,r)
	if failed:return
	ensure_cash(g.data.facilities.warehouse.cost)
	var collector=build("warehouse",Vector2i(entity.x+1,entity.y))
	cmd({"type":"setWarehouseSales","entityId":collector.id,"enabled":false})
	prepare_output_ports(collector)
	sources[r]={"entity":entity.id,"collector":collector.id,"routes":[]}
	checkpoint("built "+r+" producer")
func construct(kind,r=""):
	if failed:return {}
	var upgrade_budget=0
	if not g.data.facilities[kind].input.is_empty() and kind!="generator":upgrade_budget=g.data.facilities[kind].upgradeCosts[0]+g.data.facilities[kind].upgradeCosts[1]
	ensure_cash(g.data.facilities[kind].cost+upgrade_budget+10000+(g.data.facilities.mine.cost if kind=="generator" else 0))
	ensure_materials(g.construction_materials(kind))
	ensure_cash(g.data.facilities[kind].cost)
	var pos=choose_node(r) if kind in ["forest","mine"] else choose_site()
	if kind=="generator":
		for material in g.construction_materials("mine"):ensure(material,int(g.construction_materials("mine")[material]))
		pos=choose_node("coal")
		build("mine",pos)
		pos+=Vector2i(1,0)
	var e=build(kind,pos)
	if failed:return {}
	if kind not in ["forest","mine","generator"] and not g.data.facilities[kind].input.is_empty():
		cmd({"type":"upgrade","entityId":e.id});cmd({"type":"upgrade","entityId":e.id});prepare_ports(e)
	return e
func ensure_materials(materials):
	var loops=0
	while not failed and not all_stock(materials):
		for r in materials:
			if g.stock(r)<int(materials[r]):ensure(r,int(materials[r]))
		loops+=1
		if loops>20:fail("unable to accumulate simultaneous materials "+JSON.stringify(materials))
func all_stock(materials):
	for r in materials:
		if g.stock(r)<int(materials[r]):return false
	return true
func ensure_cash(amount):
	if failed or g.state.cash>=amount:return
	if funding:fail("funding reserve exhausted while requesting "+str(amount));return
	funding=true
	if not sources.has(money_resource):wait_cash(amount);funding=false;return
	var source=sources[money_resource];var collector=g.state.entities[source.collector]
	while not failed and g.state.cash<amount:
		var unit=g.sale_price(collector,money_resource)
		var quantity=clampi(int(ceil(float(amount-g.state.cash)/unit)),5,40)
		ensure(money_resource,quantity)
		cmd({"type":"setWarehouseSales","entityId":collector.id,"enabled":true})
		wait_for(func():return g.state.cash>=amount or int(collector.inventory.get(money_resource,0))==0,"finance sales")
		cmd({"type":"setWarehouseSales","entityId":collector.id,"enabled":false})
	funding=false
func ensure(r,quantity):
	if failed:return
	make_source(r)
	if failed:return
	var source=sources[r];var e=g.state.entities[source.entity];var collector=g.state.entities[source.collector]
	if collector.autoSell:cmd({"type":"setWarehouseSales","entityId":collector.id,"enabled":false})
	while quantity>g.storage_capacity(collector) and not failed:
		ensure_cash(g.data.facilities.warehouse.upgradeCosts[int(collector.level)-1]);cmd({"type":"upgrade","entityId":collector.id})
	var recipe=g.recipe(e)
	while int(collector.inventory.get(r,0))<quantity and not failed:
		if busy.has(r):fail("recursive production "+r);return
		busy[r]=true
		var batch_limit=40 if g.stage_index()>=6 and not funding else 20
		var batch=mini(batch_limit,quantity-int(collector.inventory.get(r,0)))
		var input_capacity=0
		for ingredient in recipe.input:input_capacity=maxi(input_capacity,batch*int(recipe.input[ingredient]))
		while g.capacity(e)<input_capacity and not failed:
			ensure_cash(g.data.facilities[e.kind].upgradeCosts[int(e.level)-1]+10000)
			cmd({"type":"upgrade","entityId":e.id})
		var target=mini(quantity,int(collector.inventory.get(r,0))+batch)
		if not recipe.input.is_empty() and not source.get("passive",false):
			for ingredient in recipe.input:
				var need=batch*int(recipe.input[ingredient])
				ensure(ingredient,need)
			for ingredient in recipe.input:
				var amount=batch*int(recipe.input[ingredient])
				var before_produced=g.produced(r)
				feed(e,ingredient,amount)
				wait_for(func():return int(e.inputs.get(ingredient,0))+int(e.job.reserved.get(ingredient,0) if e.job!=null else 0)+(g.produced(r)-before_produced)*int(recipe.input[ingredient])/int(recipe.output[r])>=amount,"deliver "+ingredient+" to "+e.kind,300)
				disconnect_route(ingredient)
		wait_for(func():return int(collector.inventory.get(r,0))>=target,"produce "+r,7200,r)
		if not source.get("passive",false):
			for ingredient in recipe.input:stop_dispatch(ingredient)
		busy.erase(r)
func feed(target,r,quantity):
	if failed:return
	var source=sources[r];var collector=g.state.entities[source.collector]
	if source.get("target","")==target.id and not source.routes.is_empty():
		set_port_active(source.get("active_port",""),true)
		cmd({"type":"configureWarehouse","entityId":collector.id,"resource":r});return
	disconnect_route(r)
	# Inputs can receive batch recipe quantities up to 60; capacity is a paid upgrade.
	while g.capacity(target)<quantity and target.kind not in ["launchpad","generator"] and not failed:
		ensure_cash(g.data.facilities[target.kind].upgradeCosts[int(target.level)-1]);cmd({"type":"upgrade","entityId":target.id})
	for resource in sources:
		if resource!=r and g.state.entities[sources[resource].collector].dispatchResource==null:disconnect_route(resource)
	var destination=Vector2i(target.x,target.y)
	if input_ports.has(target.id):
		var ports=input_ports[target.id]
		if not ports.allocations.has(r):ports.allocations[r]=ports.points[ports.allocations.size()]
		destination=ports.allocations[r]
	var from={"x":collector.x,"y":collector.y};var to={"x":destination.x,"y":destination.y}
	var quote=World.failure("BLOCKED")
	var departure={}
	for port_id in output_ports.get(collector.id,[]):
		var port=g.state.entities[port_id]
		var point={"x":port.x,"y":port.y}
		var candidate=World.route_quote(g,point,to,false)
		if candidate.ok and (not quote.ok or candidate.cash<quote.cash):quote=candidate;from=point;departure=port
	if not quote.ok:fail("route "+r+" to "+target.kind+": "+quote.code);return
	cmd({"type":"rotate","entityId":collector.id,"direction":World.direction(Vector2i(collector.x,collector.y),Vector2i(departure.x,departure.y))})
	ensure_cash(quote.cash)
	var before=g.state.entities.keys()
	cmd({"type":"buildRoute","from":from,"to":to})
	for id in g.state.entities:
		if id not in before:source.routes.append(id)
	source.target=target.id;source.active_port=departure.id
	set_port_active(departure.id,true)
	cmd({"type":"configureWarehouse","entityId":collector.id,"resource":r})
	# Routes remain live while all ingredient deliveries proceed together.
func stop_dispatch(r):
	if not sources.has(r):return
	if g.state.entities[sources[r].collector].dispatchResource!=null:cmd({"type":"configureWarehouse","entityId":sources[r].collector,"resource":null})
	for id in output_ports.get(sources[r].collector,[]):set_port_active(id,false)
func disconnect_route(r):
	if not sources.has(r) or failed:return
	var source=sources[r]
	stop_dispatch(r)
	for id in source.routes:
		if g.state.entities.has(id):cmd({"type":"demolish","entityId":id})
	source.routes=[]

func replay():
	var trace=JSON.parse_string(FileAccess.get_file_as_string(replay_path))
	if trace==null or trace.get("failed",true) or trace.get("launched",0)!=1:
		printerr("REPLAY requires completed trace");quit(1);return
	if trace.catalogHash!=FileAccess.get_file_as_string("res://data/catalog.json").sha256_text():
		printerr("REPLAY catalog differs from recorded campaign");quit(1);return
	g=Factory.new();g.fresh(0,true,int(trace.seed))
	var expenses={}
	for action in trace.actions:
		while g.state.clock.elapsedS<action.atS:g.tick()
		var before=int(g.state.cash);var result=g.command(action.command)
		if result!="OK":printerr("REPLAY command failed ",action," ",result);quit(1);return
		var paid=maxi(0,before-int(g.state.cash));var returned=maxi(0,int(g.state.cash)-before)
		spent+=paid;refunds+=returned
		var kind=action.command.type
		if not expenses.has(kind):expenses[kind]={"commands":0,"spent":0,"refunds":0}
		expenses[kind].commands+=1;expenses[kind].spent+=paid;expenses[kind].refunds+=returned
	while g.state.clock.elapsedS<trace.elapsedS:g.tick()
	var valid=spent==trace.spent and refunds==trace.refunds and g.state.cash==trace.cash and g.state.totals.earned==trace.earned and g.state.rocket.launched==1
	for pair in [[g.state.totals.produced,trace.expectedProduction],[g.state.totals.sold,trace.expectedSold],[g.state.rocket.delivered,trace.rocketDelivered]]:
		valid=valid and JSON.parse_string(JSON.stringify(pair[0]))==JSON.parse_string(JSON.stringify(pair[1]))
	var validation=Store.new().validate(Store.new().snapshot(g));valid=valid and validation.is_empty()
	print("EXPENSES ",JSON.stringify(expenses))
	print("REPLAY ","PASS" if valid else "FAIL"," / ",trace.actions.size()," commands / ",g.state.clock.elapsedS/60.0," minutes / spent ",spent," / ",validation)
	quit(0 if valid else 1)

func prepare_ports(target):
	var points=[]
	for direction in [0,2,3]:
		var pos=Vector2i(target.x,target.y)+g.DIRS[direction]
		ensure_cash(g.data.facilities.belt.cost)
		var belt=build("belt",pos)
		cmd({"type":"rotate","entityId":belt.id,"direction":(direction+2)%4})
		points.append(pos)
	input_ports[target.id]={"points":points,"allocations":{}}

func invest():
	# Reinvest after each cash scale: an upstream upgrade may cost at most half
	# one newly saleable product. All costs still come from actual batch sales.
	var ceiling=g.price(money_resource)*0.5
	for e in g.state.entities.values():
		if g.data.facilities[e.kind].cycle<=0:continue
		var costs=g.data.facilities[e.kind].upgradeCosts
		while not failed and e.level<g.data.facilities[e.kind].maxLevel and costs[int(e.level)-1]<=ceiling:
			ensure_cash(costs[int(e.level)-1]+10000)
			cmd({"type":"upgrade","entityId":e.id})
	checkpoint("reinvest "+money_resource)

func prepare_output_ports(collector):
	var ports=[]
	for direction in [0,1,2]:
		var pos=Vector2i(collector.x,collector.y)+g.DIRS[direction]
		if not g.at(pos.x,pos.y).is_empty() or not World.resource_at(g.state.world,pos.x,pos.y).is_empty():continue
		ensure_cash(g.data.facilities.belt.cost)
		var belt=build("belt",pos)
		cmd({"type":"rotate","entityId":belt.id,"direction":direction})
		ports.append(belt.id)
		cmd({"type":"pause","entityId":belt.id})
	output_ports[collector.id]=ports

func set_port_active(id,active):
	if not id.is_empty() and g.state.entities[id].paused==active:cmd({"type":"pause","entityId":id})

func probe_opening():
	var code=g.command({"type":"build","kind":"forest","x":62,"y":64})
	if code!="OK":printerr(code);quit(1);return
	while g.state.cash<g.data.facilities.sawmill.cost+g.data.facilities.belt.cost:g.tick()
	code=g.command({"type":"buildLinked","sourceId":"e1","kind":"sawmill","x":64,"y":64})
	var sawmill_at=g.state.clock.elapsedS
	if code!="OK":printerr(code);quit(1);return
	while g.state.cash<g.data.facilities.warehouse.cost+g.data.facilities.belt.cost:g.tick()
	code=g.command({"type":"buildLinked","sourceId":g.at(64,64).id,"kind":"warehouse","x":66,"y":64})
	if code!="OK":printerr(code);quit(1);return
	g.command({"type":"setReserve","resource":"plank","quantity":0})
	while not g.recorded("first_auto_sale"):g.tick()
	print("OPENING NO INVESTMENTS / linked sawmill ",sawmill_at,"s / first automatic sale ",g.state.clock.elapsedS,"s / cash ",g.state.cash)
	quit(0)
