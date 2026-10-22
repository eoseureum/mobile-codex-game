class_name RustFactory
extends RefCounted

const World=preload("res://scripts/core/world_map.gd")
const WorldRules=preload("res://scripts/core/world_rules.gd")
const DT = 0.25
const MAX_MONEY = 9007199254740991
const DIRS = [Vector2i(0,-1), Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0)]
var modern_data: Dictionary
var legacy_data: Dictionary
var state: Dictionary = {}
var data: Dictionary:
	get: return modern_data if state.has("world") else legacy_data
var transfers: Array = []
var sales: Array = []
var _indexed_source={}
var _indexed_size=-1
var _positions={}
var _effects_cache={}

func _init():
	modern_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	legacy_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/legacy_catalog.json"))
	fresh()

func fresh(now_ms = -1,open_world=true,seed_value=-1):
	state = data.initial.duplicate(true)
	state.createdAtMs = int(Time.get_unix_time_from_system()*1000) if now_ms < 0 else now_ms
	invalidate_index();clear_effects()
	transfers.clear();sales.clear()
	if open_world:WorldRules.setup(self,int(seed_value) if seed_value>=0 else int(Time.get_unix_time_from_system()*1000)%2147483647)

func world_mode() -> bool:return state.has("world")
func invalidate_index():_indexed_size=-1
func clear_effects():_effects_cache={}
func stock(r) -> int:return WorldRules.stock(self,r) if world_mode() else int(state.bag.get(r,0))
func storage_capacity(e) -> int:return 200*int(e.level)
func construction_materials(kind) -> Dictionary:
	if world_mode() and state.factory.get("startMode","")=="empty":
		if kind=="forest" and state.factory.pioneerForestId.is_empty():return {}
		if kind=="sawmill" and not has_facility("sawmill"):return {}
	return data.facilities[kind].materials
func sale_price(e,r) -> int:return int(floor(price(r)*(1+0.12*e.get("incomeLevel",0))*effects().operating)) if world_mode() else price(r)

func add(store: Dictionary, resource, amount):
	store[resource] = store.get(resource,0) + amount
	if store[resource] == 0: store.erase(resource)

func has_stock(store: Dictionary, recipe: Dictionary) -> bool:
	for r in recipe:
		if store.get(r,0) < recipe[r]: return false
	return true

func remove(store: Dictionary, recipe: Dictionary):
	for r in recipe: add(store,r,-recipe[r])

func credit(amount, operating = false, earned = true):
	var paid = mini(int(amount),MAX_MONEY-int(state.cash))
	state.cash = int(state.cash)+paid
	if earned: state.totals.earned = mini(MAX_MONEY,int(state.totals.earned)+paid)
	if operating: state.totals.operatingEarned = mini(MAX_MONEY,int(state.totals.get("operatingEarned",0))+paid)
	return paid

func event(kind):
	if not recorded(kind): state.records.append({"type":kind,"atS":state.clock.elapsedS})

func recorded(kind) -> bool:
	for r in state.records:
		if r.type == kind: return true
	return false

func stage_index() -> int: return data.stages.find(state.stage)
func is_project(kind) -> bool: return data.projects.has(kind)
func has_facility(kind) -> bool:
	for e in state.entities.values():
		if e.kind==kind:return true
	return false
func transport(e) -> bool: return e.kind in ["belt","splitter"]
func speed(e) -> float: return 1.0+0.12*(e.level-1)+0.08*e.get("managerLevel",0)
func capacity(e) -> int: return int(20*e.level)
func key(x,y) -> String: return "%d,%d" % [x,y]
func price(r) -> int: return int(data.resources[r].price)
func produced(r) -> int: return int(state.totals.produced.get(r,0))
func recipe(e) -> Dictionary:
	var f = data.facilities[e.kind].duplicate()
	if e.kind == "mine": f.output = {e.mineResourceId:1}
	return f

func district_at(x,y) -> String:
	for id in data.districts:
		var d = data.districts[id]
		if x>=d.x and x<d.x+6 and y>=d.y and y<d.y+6: return id
	return ""

func owned(x,y) -> bool:
	if world_mode():return x>=0 and y>=0 and x<World.SIZE and y<World.SIZE
	var id = district_at(x,y)
	if id.is_empty(): return false
	var d = data.districts[id]
	var n = state.districts[id].size
	return (x<d.x+n and y<d.y+n) or key(x,y) in state.corridors

func at(x,y) -> Dictionary:
	if world_mode():
		if _indexed_size!=state.entities.size() or not is_same(_indexed_source,state.entities):
			_positions={};_indexed_source=state.entities;_indexed_size=state.entities.size()
			for entity in state.entities.values():_positions[key(entity.x,entity.y)]=entity
		return _positions.get(key(x,y),{})
	for e in state.entities.values():
		if e.x==x and e.y==y: return e
	return {}

func create_entity(kind,x,y,extra = {}) -> Dictionary:
	var e = data.initial.entities.e1.duplicate(true)
	e.merge({"id":"e%d" % int(state.nextId),"kind":kind,"x":x,"y":y,"automatic":true},true)
	if kind=="warehouse": e.dispatchResource=null
	if world_mode():WorldRules.init_entity(e)
	e.merge(extra,true)
	state.nextId+=1
	state.entities[e.id]=e
	return e

func unlocked(kind) -> bool:
	if not data.facilities.has(kind) or stage_index()<data.facilities[kind].tier: return false
	if world_mode() and state.factory.get("startMode","")=="empty" and state.factory.pioneerForestId.is_empty() and state.entities.is_empty():return kind=="forest"
	if kind=="sawmill": return world_mode() or state.districts.forest.size>=2
	if kind=="generator": return produced("wire")>=10
	if is_project(kind):
		if kind=="cabin": return produced("plank")>=20
		if kind=="cityWorkshop": return produced("wire")>=10
	return true

func known_resource(r) -> bool:
	if r=="log" or stock(r)>0 or produced(r)>0 or state.totals.sold.get(r,0)>0: return true
	if r in ["stone","coal","copper"] and unlocked("mine"): return true
	if r=="iron" and stage_index()>=3: return true
	for kind in data.facilities:
		if unlocked(kind) and kind!="mine" and data.facilities[kind].output.has(r): return true
	return false

func district_known(id) -> bool:
	if state.districts[id].size>0:return true
	if stage_index()<data.districts[id].tier:return false
	if id=="mines":return state.districts.forest.size>=2 and recorded("first_sawmill") and produced("plank")>=10
	if id=="logistics":return recorded("first_power") and produced("machinePart")>=10
	if id=="advanced":return produced("structure")>=10
	if id=="launch":return produced("electronics")>=10 and produced("precision")>=10
	return true

func expansion(id) -> Dictionary:
	var n=state.districts[id].size
	var d=data.districts[id]
	return {"cash":(500 if n==1 else 2500 if n==2 else 15000) if id=="forest" else d.cost if n==0 else d.expand,"materials":d.materials if n==0 else {}}

func affordable(cash,mats = {}) -> bool:
	if state.cash<cash:return false
	for r in mats:
		if stock(r)<mats[r]:return false
	return true
func pay(cash,mats = {}):
	state.cash-=cash
	WorldRules.remove_materials(self,mats) if world_mode() else remove(state.bag,mats)

func connect_district(id):
	var d=data.districts[id]
	var x=int(d.x)
	var y=int(d.y)+1
	var candidates=[]
	for other in data.districts:
		if other!=id and state.districts[other].size>0:
			var a=data.districts[other]
			var n=mini(int(state.districts[other].size)-1,1)
			candidates.append(Vector2i(int(a.x)+n,int(a.y)+n))
	candidates.sort_custom(func(a,b): return abs(a.x-x)+abs(a.y-y)<abs(b.x-x)+abs(b.y-y))
	if candidates.is_empty(): return
	var target=candidates[0]
	while x!=target.x:
		if not owned(x,y) and key(x,y) not in state.corridors: state.corridors.append(key(x,y))
		x+=signi(target.x-x)
	while y!=target.y:
		if not owned(x,y) and key(x,y) not in state.corridors: state.corridors.append(key(x,y))
		y+=signi(target.y-y)

func command(c: Dictionary) -> String:
	var type=c.get("type","")
	if type=="migrateWorld":return WorldRules.migrate(self,c.get("seed",int(state.createdAtMs)%2147483647))
	if world_mode():
		var result=WorldRules.command(self,c)
		if result!="PASS":
			if result=="OK":clear_effects();progression()
			return result
	var e=state.entities.get(c.get("entityId",""),{})
	match type:
		"build":
			var kind=c.get("kind","")
			if not data.facilities.has(kind) or not c.has_all(["x","y"]): return "INVALID"
			if not at(c.x,c.y).is_empty(): return "OCCUPIED"
			if not owned(c.x,c.y) or not unlocked(kind): return "LOCKED"
			var district=district_at(c.x,c.y)
			if key(c.x,c.y) in state.corridors and kind not in ["belt","splitter"]: return "LOCKED"
			if (kind=="forest" and district!="forest") or (kind=="mine" and district!="mines") or (kind=="launchpad" and district!="launch"): return "LOCKED"
			if kind=="mine" and (c.get("resource","copper") not in ["stone","coal","copper","iron"] or (c.get("resource","")=="iron" and stage_index()<3)): return "LOCKED"
			if is_project(kind):
				for existing in state.entities.values():
					if existing.kind==kind: return "LOCKED"
			var f=data.facilities[kind]
			if not affordable(f.cost,f.materials): return "INSUFFICIENT_CASH" if state.cash<f.cost else "INSUFFICIENT_RESOURCE"
			pay(f.cost,f.materials)
			var extra={"investedCash":f.cost}
			if kind=="mine": extra.mineResourceId=c.get("resource","copper")
			if is_project(kind): extra.project={"materials":{},"remainingS":data.projects[kind].seconds,"complete":false}
			create_entity(kind,c.x,c.y,extra)
			event("first_"+kind)
		"expand":
			var id=c.get("districtId","")
			if not data.districts.has(id): return "INVALID"
			var n=state.districts[id].size
			if n==6: return "LOCKED"
			if n==0:
				if stage_index()<data.districts[id].tier: return "LOCKED"
				if id=="mines" and (state.districts.forest.size<2 or not recorded("first_sawmill") or produced("plank")<10): return "LOCKED"
				if id=="logistics" and (produced("machinePart")<10 or not recorded("first_power")): return "LOCKED"
				if id=="advanced" and produced("structure")<10: return "LOCKED"
				if id=="launch" and (produced("electronics")<10 or produced("precision")<10): return "LOCKED"
			var offer=expansion(id)
			if not affordable(offer.cash,offer.materials): return "INSUFFICIENT_CASH" if state.cash<offer.cash else "INSUFFICIENT_RESOURCE"
			pay(offer.cash,offer.materials)
			state.districts[id].size=(2 if n==1 else 3 if n==2 else 6) if id=="forest" else (3 if n==0 else 6)
			if n==0: connect_district(id)
			event("land_%s_%d" % [id,state.districts[id].size])
		"research":
			if stage_index()<1 or state.unlocks.get("smelting",false) or produced("copper")<20: return "LOCKED"
			var offer=data.research
			if not affordable(offer.cash,offer.materials): return "INSUFFICIENT_CASH" if state.cash<offer.cash else "INSUFFICIENT_RESOURCE"
			pay(offer.cash,offer.materials)
			state.unlocks.smelting=true
		"upgrade","upgradeIncome","upgradeManager":
			if e.is_empty(): return "INVALID"
			var f=data.facilities[e.kind]
			var cash=0
			var mats={}
			if type=="upgrade":
				if e.level>=f.maxLevel or (transport(e) and stage_index()<4): return "LOCKED"
				cash=f.upgradeCosts[int(e.level)-1]
				mats=f.upgradeMaterials
			elif type=="upgradeIncome":
				if not income_facility(e) or e.get("incomeLevel",0)>=10: return "LOCKED"
				cash=f.incomeCosts[int(e.get("incomeLevel",0))]
			else:
				if e.kind in ["belt","splitter","launchpad"] or is_project(e.kind) or not recorded("first_auto_sale") or e.get("managerLevel",0)>=3: return "LOCKED"
				cash=f.managerCosts[int(e.get("managerLevel",0))]
				mats={"plank":3}
			if world_mode():mats={}
			if not affordable(cash,mats): return "INSUFFICIENT_CASH" if state.cash<cash else "INSUFFICIENT_RESOURCE"
			pay(cash,mats)
			var field="level" if type=="upgrade" else "incomeLevel" if type=="upgradeIncome" else "managerLevel"
			e[field]=e.get(field,0)+1
			e.investedCash+=cash
		"pause":
			if e.is_empty(): return "INVALID"
			e.paused=not e.paused
		"rotate":
			if e.is_empty() or int(c.get("direction",-1)) not in [0,1,2,3] or c.get("direction",-1)!=int(c.get("direction",-1)): return "INVALID"
			e.direction=c.direction
			if e.kind=="splitter": e.splitDirections=[c.direction,(int(c.direction)+1)%4]
		"demolish":
			if e.is_empty(): return "INVALID"
			if e.id in ["e1","e2","e3"]: return "PROTECTED"
			var stores=[e.inputs,e.outputs,e.job.reserved if e.job!=null else {}]
			if e.has("project") and not e.project.complete: stores.append(e.project.materials)
			for store in stores:
				for r in store: add(state.bag,r,store[r])
			for r in e.queue: add(state.bag,r,1)
			credit(floor(e.investedCash*0.5),false,false)
			state.entities.erase(e.id)
		"setMineResource":
			if e.get("kind","")!="mine" or c.get("resource","") not in ["stone","coal","copper","iron"]: return "INVALID"
			if c.resource=="iron" and stage_index()<3: return "LOCKED"
			for r in e.outputs: add(state.bag,r,e.outputs[r])
			e.outputs={}
			e.job=null
			e.mineResourceId=c.resource
		"configureWarehouse":
			if e.get("kind","")!="warehouse" or (c.get("resource")!=null and not data.resources.has(c.resource)): return "INVALID"
			for r in e.outputs: add(state.bag,r,e.outputs[r])
			e.outputs={}
			e.dispatchResource=c.resource
		"setReserve":
			if not data.resources.has(c.get("resource","")) or c.get("quantity",-2)<-1 or c.get("quantity",10001)>10000: return "INVALID"
			state.factory.reserves[c.resource]=int(c.quantity)
		"setFilters":
			if e.get("kind","")!="market" or not c.get("filters") is Dictionary: return "INVALID"
			for r in c.filters:
				if not data.resources.has(r) or not c.filters[r] is bool: return "INVALID"
			e.saleFilters.merge(c.filters,true)
		"takeOrder":
			if not start_shipment(c.get("offerId","")): return "LOCKED"
		"cancelOrder":
			var t=trade()
			if t.active==null and not t.repeat: return "LOCKED"
			if t.active!=null: add(state.bag,t.active.resource,t.active.reserved+t.active.loaded)
			t.active=null
			t.repeat=false
		"setTradeRepeat":
			if not c.get("enabled") is bool or trade().lastOfferId==null: return "INVALID"
			trade().repeat=c.enabled
		"launch":
			var launchpad=false
			for entity in state.entities.values():
				if entity.kind=="launchpad": launchpad=true
			if not launchpad or state.rocket.launched or not has_stock(state.rocket.delivered,data.rocket): return "LOCKED"
			state.rocket.launched=1
			event("first_launch")
		_: return "INVALID"
	clear_effects()
	progression()
	if world_mode():state.world.revision+=1
	return "OK"

func progression():
	if world_mode():WorldRules.progression(self);return
	var i=stage_index()
	var next=i
	if state.districts.mines.size>0: next=maxi(next,1)
	if state.unlocks.get("smelting",false): next=maxi(next,2)
	for e in state.entities.values():
		if e.kind=="generator" and produced("wire")>=10: next=maxi(next,3)
	if state.districts.logistics.size>0 and produced("machinePart")>=10 and recorded("first_power"): next=maxi(next,4)
	if state.districts.advanced.size>0 and produced("structure")>=10: next=maxi(next,5)
	if state.districts.launch.size>0 and produced("electronics")>=10 and produced("precision")>=10: next=maxi(next,6)
	for n in range(i+1,next+1): event("stage_"+data.stages[n])
	state.stage=data.stages[next]
	state.unlocks.offline=next>=4

func effects() -> Dictionary:
	if world_mode() and not _effects_cache.is_empty():return _effects_cache
	var result={"operating":1.0,"shipment":1.0,"loading":1.5,"cooldown":20.0}
	for e in state.entities.values():
		if not e.paused and is_project(e.kind) and e.project.complete:
			if e.kind=="cabin": result.operating=1.25
			if e.kind=="cityWorkshop": result.shipment=1.1
			if e.kind=="dispatchOffice": result.loading=1.8; result.cooldown=16.0
	if world_mode():_effects_cache=result
	return result

func income_facility(e) -> bool: return (e.kind=="market" or (e.kind=="warehouse" and e.autoSell) or (e.kind=="forest" and e.id==state.factory.get("pioneerForestId",""))) if world_mode() else data.facilities[e.kind].cycle>0 and not data.facilities[e.kind].output.is_empty()
func income_per_batch(e) -> float:
	var total=0.0
	var output=recipe(e).output
	for r in output: total+=output[r]*price(r)
	return total*0.25*(1+0.15*e.get("incomeLevel",0))*effects().operating

func production():
	var income=0
	for e in state.entities.values():
		var f=recipe(e)
		if f.cycle==0 or e.kind=="generator" or e.paused: continue
		var budget=DT*speed(e)*(state.power.ratio if f.power>0 else 1)
		if budget<=0: continue
		for guard in range(20):
			if e.job==null:
				if not has_stock(e.inputs,f.input) or not output_fits(e,f.output): break
				remove(e.inputs,f.input)
				e.job={"remaining":f.cycle,"reserved":f.input.duplicate(),"output":f.output.duplicate()}
			var used=minf(budget,maxf(0,e.job.remaining))
			e.job.remaining-=used
			budget-=used
			if e.job.remaining>0.00000001 or not output_fits(e,e.job.output): break
			for r in e.job.output:
				add(e.outputs,r,e.job.output[r])
				add(state.totals.produced,r,e.job.output[r])
			if world_mode():WorldRules.pioneer_sale(self,e)
			if not world_mode():
				var value=e.get("incomeCredit",0)+income_per_batch(e)
				var cash=floor(value+0.000000001)
				e.incomeCredit=maxf(0,value-cash)
				income+=credit(cash,true)
			e.job=null
			if budget<0.00000001: break
	if income>0: sale(income,"operating")

func output_fits(e,output) -> bool:
	for r in output:
		if e.outputs.get(r,0)+output[r]>capacity(e): return false
	return true

func power_step():
	var generation=0.0
	var demand=0.0
	for e in state.entities.values():
		if e.paused: continue
		demand+=data.facilities[e.kind].power*speed(e)
		if e.kind!="generator": continue
		if e.burnRemainingS<=0.00000001 and e.inputs.get("coal",0)>0:
			add(e.inputs,"coal",-1)
			e.burnRemainingS=10
		if e.burnRemainingS>0:
			generation+=12*speed(e)
			e.burnRemainingS=maxf(0,e.burnRemainingS-DT)
			event("first_power")
	state.power={"generation":generation,"demand":demand,"ratio":minf(1,generation/demand) if demand>0 else 1.0}

func trade() -> Dictionary:
	if not state.factory.has("trade"): state.factory.trade={"active":null,"completed":0,"rewardEarned":0,"cooldownS":0.0,"repeat":false,"lastOfferId":null}
	return state.factory.trade

func quotes(r,bonus = -1.0,historical=false) -> Array:
	if not data.resources.has(r): return []
	if bonus<0: bonus=effects().shipment
	var resources=legacy_data.resources if historical else data.resources
	var base=maxi(1,int(floor(32.0/resources[r].legacyPrice+0.5)))
	var quantities=[]
	var result=[]
	for n in [base,int(ceil(base*1.5)),int(ceil(base*2.25))]:
		if n not in quantities: quantities.append(n)
	for i in range(quantities.size()):
		var n=quantities[i]
		result.append({"id":"%s:%d"%[r,n],"resource":r,"quantity":n,"reward":ceil(resources[r].price*n*[1.3,1.4,1.5][i]*bonus),"bonus":bonus})
	return result

func offers() -> Array:
	var result=[]
	var depot=shipping_depot()
	if depot.is_empty(): return result
	for r in data.resources:
		if produced(r)>0 and ((depot.get("inventory",{}).get(r,0)>0 if world_mode() else state.bag.get(r,0)>0) or state.totals.sold.get(r,0)>0): result.append_array(quotes(r))
	return result

func shipping_depot() -> Dictionary:
	var original=state.entities.get("e3",{})
	if not state.factory.has("startMode") and original.get("kind","")=="warehouse":return original
	var first={}
	for e in state.entities.values():
		if e.kind=="warehouse" and (first.is_empty() or int(e.id.substr(1))<int(first.id.substr(1))):first=e
	return first

func start_shipment(id) -> bool:
	var t=trade()
	if t.active!=null or t.cooldownS>0: return false
	for offer in offers():
		if offer.id==id:
			t.lastOfferId=id
			t.active=offer.duplicate(true)
			t.active.merge({"reserved":0,"loaded":0,"departureS":5.0,"loadingCredit":0.0})
			return true
	return false

func trade_step(available):
	var t=trade()
	if t.active==null:
		t.cooldownS=maxf(0,t.cooldownS-DT)
		if t.repeat and t.cooldownS==0: start_shipment(t.lastOfferId)
	if t.active==null: return
	var a=t.active
	if a.loaded<a.quantity:
		if not available: return
		var surplus=maxf(0,state.bag.get(a.resource,0)-maxf(0,state.factory.reserves[a.resource]))
		var n=minf(a.quantity-a.loaded-a.reserved,surplus)
		add(state.bag,a.resource,-n)
		a.reserved+=n
		a.loadingCredit=minf(effects().loading,a.loadingCredit+DT*effects().loading)
		var loaded=minf(a.reserved,floor(a.loadingCredit+0.000000001))
		a.reserved-=loaded
		a.loaded+=loaded
		a.loadingCredit=maxf(0,a.loadingCredit-loaded)
		return
	a.departureS=maxf(0,a.departureS-DT)
	if a.departureS>0: return
	var income=credit(a.reward)
	add(state.totals.sold,a.resource,a.quantity)
	t.rewardEarned=mini(MAX_MONEY,int(t.rewardEarned)+income)
	t.completed+=1
	t.active=null
	t.cooldownS=effects().cooldown
	event("first_shipment")
	sale(income,"shipment")

func project_step(available):
	for e in state.entities.values():
		if not is_project(e.kind) or e.paused or e.project.complete: continue
		var p=e.project
		var definition=data.projects[e.kind]
		if available:
			for r in definition.materials:
				var n=minf(definition.materials[r]-p.materials.get(r,0),maxf(0,state.bag.get(r,0)-maxf(0,state.factory.reserves[r])))
				add(state.bag,r,-n)
				add(p.materials,r,n)
		if has_stock(p.materials,definition.materials):
			p.remainingS=maxf(0,p.remainingS-DT)
			if p.remainingS==0: p.complete=true; event("complete_"+e.kind)

func warehouse_step():
	if world_mode():WorldRules.warehouse_step(self);return
	var warehouses=[]
	for e in state.entities.values():
		if e.kind=="warehouse" and not e.paused: warehouses.append(e)
	if warehouses.is_empty(): project_step(false); trade_step(false); return
	for e in warehouses:
		for r in e.inputs: add(state.bag,r,e.inputs[r])
		e.inputs={}
	if state.rocket.launched==0:
		for e in state.entities.values():
			if e.kind=="launchpad" and not e.paused:
				for r in data.rocket:
					var n=minf(state.bag.get(r,0),data.rocket[r]-state.rocket.delivered.get(r,0))
					add(state.bag,r,-n)
					add(state.rocket.delivered,r,n)
				break
	project_step(true)
	var dispatchers=warehouses.filter(func(e): return e.get("dispatchResource")!=null)
	dispatchers.sort_custom(func(a,b):
		if a.dispatchResource!=b.dispatchResource: return a.dispatchResource<b.dispatchResource
		var cursor=state.factory.dispatchCursors.get(a.dispatchResource,0)
		var ai=int(a.id.substr(1))
		var bi=int(b.id.substr(1))
		return int(ai<=cursor)<int(bi<=cursor) if (ai<=cursor)!=(bi<=cursor) else ai<bi)
	for e in dispatchers:
		var r=e.dispatchResource
		var buffer=maxi(1,int(ceil(1.5*speed(e)*DT)))
		if state.bag.get(r,0)<=0 or e.outputs.get(r,0)>=buffer or (state.factory.reserves[r]>=0 and state.bag[r]<=state.factory.reserves[r]): continue
		var dir=DIRS[int(e.direction)]
		var target=at(e.x+dir.x,e.y+dir.y)
		if target.is_empty() or target.paused or target.kind=="warehouse": continue
		var out=DIRS[int(target.direction)]
		var backwards=target.x+out.x==e.x and target.y+out.y==e.y
		if transport(target):
			if backwards or target.queue.size()>=(4 if target.level==1 else 8): continue
		elif target.kind=="market":
			if not target.saleFilters[r] or target.inputs.get(r,0)>=capacity(target): continue
		elif target.kind=="launchpad":
			if state.rocket.delivered.get(r,0)>=data.rocket.get(r,0): continue
		elif not data.facilities[target.kind].input.has(r) or target.inputs.get(r,0)>=capacity(target) or backwards: continue
		var amount=minf(buffer-e.outputs.get(r,0),state.bag[r]-maxf(0,state.factory.reserves[r]))
		add(state.bag,r,-amount)
		add(e.outputs,r,amount)
		state.factory.dispatchCursors[r]=int(e.id.substr(1))
	trade_step(true)
	var ids=data.resources.keys()
	var policy=state.factory
	policy.saleCredit=minf(2,policy.saleCredit+DT*2)
	var income=0
	while policy.saleCredit>=1:
		var index=-1
		for offset in range(ids.size()):
			var i=(int(policy.saleCursor)+offset)%ids.size()
			var r=ids[i]
			if policy.reserves[r]>=0 and state.bag.get(r,0)>policy.reserves[r]: index=i; break
		if index<0: break
		var r=ids[index]
		income+=credit(price(r))
		add(state.bag,r,-1)
		add(state.totals.sold,r,1)
		policy.saleCredit-=1
		policy.saleCursor=(index+1)%ids.size()
		if r=="plank": event("first_auto_sale")
	if income>0: sale(income,"market")

func sale(amount,mode,entity_id=""):
	var entry={"atS":state.clock.elapsedS,"cash":amount,"mode":mode}
	if not entity_id.is_empty():entry.entityId=entity_id;feedback_sale(amount,entity_id)
	state.recentSales.append(entry)
func feedback_sale(amount,entity_id):sales.append({"atS":state.clock.elapsedS,"cash":amount,"entityId":entity_id})

func logistics():
	var all=state.entities.values()
	var index={}
	var snapshots={}
	var reserved={}
	var sources=[]
	var budgets={}
	var ids=data.resources.keys()
	var income=0
	for e in all:
		index[key(e.x,e.y)]=e
		if e.kind=="market" and not e.paused:
			var sold_here=0
			e.flowCredit=minf(2*speed(e),e.flowCredit+DT*2*speed(e))
			var budget=int(floor(e.flowCredit+0.000000001))
			while budget>0:
				var selected=-1
				for offset in range(ids.size()):
					var i=(int(e.get("saleCursor",0))+offset)%ids.size()
					if e.saleFilters[ids[i]] and e.inputs.get(ids[i],0)>0: selected=i; break
				if selected<0: break
				var r=ids[selected]
				var paid=credit(sale_price(e,r));income+=paid;sold_here+=paid
				add(e.inputs,r,-1)
				add(state.totals.sold,r,1)
				e.flowCredit=maxf(0,e.flowCredit-1)
				budget-=1
				e.saleCursor=(selected+1)%ids.size()
				if r=="plank": event("first_auto_sale")
			if world_mode() and sold_here>0:feedback_sale(sold_here,e.id)
		if not e.paused and e.kind not in ["market","launchpad","generator"]: sources.append(e)
		if not e.has("intakeCursors"): e.intakeCursors={}
		snapshots[e.id]={"queue":e.queue.duplicate(),"outputs":e.outputs.duplicate(),"inputs":e.inputs.duplicate()}
	if income>0: sale(income,"market")
	for e in sources:
		var rate=1.5*speed(e) if e.kind=="warehouse" else (1.5 if e.level==1 else 3.0) if transport(e) else 8.0
		e.flowCredit=minf(maxf(1,rate),e.flowCredit+DT*rate)
		budgets[e.id]=int(floor(e.flowCredit+0.000000001))
	while true:
		var groups={}
		for e in sources:
			if budgets[e.id]==0: continue
			var snap=snapshots[e.id]
			var r=""
			if transport(e):
				if not snap.queue.is_empty(): r=snap.queue[0]
			else:
				for resource in snap.outputs:
					if snap.outputs[resource]>0: r=resource; break
			if r.is_empty(): continue
			var dirs=e.splitDirections if e.kind=="splitter" else [e.direction]
			for offset in range(dirs.size()):
				var port=(offset+int(e.splitCursor))%dirs.size()
				var dir=DIRS[int(dirs[port])]
				var target=index.get(key(e.x+dir.x,e.y+dir.y),{})
				if target.is_empty() or transport_space(target,r,e,snapshots,reserved)<=0: continue
				var resource_key="*" if transport(target) else r
				var group_key=target.id+":"+resource_key
				if not groups.has(group_key): groups[group_key]=[]
				groups[group_key].append({"e":e,"target":target,"r":r,"port":port,"resourceKey":resource_key})
				break
		var moved=0
		for proposals in groups.values():
			var target=proposals[0].target
			var rk=proposals[0].resourceKey
			var cursor=target.intakeCursors.get(rk,0)
			proposals.sort_custom(func(a,b):
				var ai=int(a.e.id.substr(1))
				var bi=int(b.e.id.substr(1))
				return int(ai<=cursor)<int(bi<=cursor) if (ai<=cursor)!=(bi<=cursor) else ai<bi)
			for p in proposals:
				var e=p.e
				var r=p.r
				if transport_space(target,r,e,snapshots,reserved)<=0: continue
				var g=target.id+":"+p.resourceKey
				reserved[g]=reserved.get(g,0)+1
				if transport(e): e.queue.pop_front(); snapshots[e.id].queue.pop_front()
				else: add(e.outputs,r,-1); add(snapshots[e.id].outputs,r,-1)
				if target.kind=="launchpad": add(state.rocket.delivered,r,1)
				elif transport(target): target.queue.append(r)
				else: add(target.inputs,r,1)
				target.intakeCursors[p.resourceKey]=int(e.id.substr(1))
				if e.kind=="splitter": e.splitCursor=(p.port+1)%e.splitDirections.size()
				e.flowCredit=maxf(0,e.flowCredit-1)
				budgets[e.id]-=1
				moved+=1
				transfers.append({"sourceId":e.id,"targetId":target.id,"resource":r})
		if moved==0: break

func transport_space(target,r,source,snapshots,reserved) -> float:
	if target.paused or not owned(target.x,target.y): return 0
	var own=snapshots[target.id]
	var rk="*" if transport(target) else r
	var used=reserved.get(target.id+":"+rk,0)
	var dir=DIRS[int(target.direction)]
	var backwards=source.x==target.x+dir.x and source.y==target.y+dir.y
	if target.kind=="launchpad": return maxf(0,data.rocket.get(r,0)-state.rocket.delivered.get(r,0))
	if transport(target): return 0 if backwards else maxf(0,(4 if target.level==1 else 8)-own.queue.size()-used)
	if target.kind=="warehouse":
		if world_mode():return 0 if backwards and target.get("dispatchResource")!=null else maxf(0,minf(capacity(target)-own.inputs.get(r,0)-used,storage_capacity(target)-target.inventory.get(r,0)-own.inputs.get(r,0)-used))
		return 0 if backwards else maxf(0,capacity(target)-own.inputs.get(r,0)-used)
	if world_mode() and is_project(target.kind):return maxf(0,minf(capacity(target)-own.inputs.get(r,0)-used,data.projects[target.kind].materials.get(r,0)-target.project.materials.get(r,0)-own.inputs.get(r,0)-used))
	if target.kind=="market": return maxf(0,capacity(target)-own.inputs.get(r,0)-used) if target.saleFilters[r] else 0
	var f=data.facilities[target.kind]
	if not f.input.has(r) or (not f.output.is_empty() and backwards): return 0
	return maxf(0,capacity(target)-own.inputs.get(r,0)-used)

func tick():
	clear_effects()
	transfers.clear()
	sales.clear()
	warehouse_step()
	logistics()
	power_step()
	production()
	progression()
	state.clock.tickIndex+=1
	state.clock.elapsedS+=DT
	state.recentSales=state.recentSales.filter(func(e): return e.atS>state.clock.elapsedS-(80 if world_mode() else 60))

func advance(seconds):
	var total=seconds+state.clock.carryS
	var count=int(floor(total/DT+0.000000001))
	state.clock.carryS=maxf(0,total-count*DT)
	for i in range(count): tick()

func status(e) -> String:
	if e.paused: return "잠시 쉬는 중"
	if is_project(e.kind): return "운영 중" if e.project.complete else "공사 중"
	if e.kind=="warehouse": return "자동 입출고"
	if e.kind=="market": return "자동 판매"
	if e.kind=="launchpad": return "로켓 조립"
	if transport(e): return "운송 중" if not e.queue.is_empty() else "운송 대기"
	if e.kind=="generator": return "발전 중" if e.burnRemainingS>0 or e.inputs.get("coal",0)>0 else "석탄 부족"
	var f=recipe(e)
	if not output_fits(e,f.output): return "출력 가득"
	if e.job==null and not has_stock(e.inputs,f.input): return "재료 부족"
	if f.power>0 and state.power.ratio<1: return "전력 부족"
	return "가동 중"

static func money(value) -> String:
	var n=maxf(0,value)
	for pair in [[1e12,"T"],[1e9,"B"],[1e6,"M"],[1e4,"K"]]:
		if n>=pair[0]:
			var divisor=1000.0 if pair[1]=="K" else pair[0]
			return ("%.2f" % (floor(n/divisor*100)/100)).trim_suffix("0").trim_suffix("0").trim_suffix(".")+pair[1]
	return str(int(n))

func demolition_refund(e) -> int:
	var refund=int(floor(e.investedCash*0.5))
	if world_mode() and e.kind=="forest":
		var others=state.entities.values().filter(func(other):return other.kind=="forest" and other.id!=e.id)
		if others.is_empty():
			# Original populated saves received this camp for free. Recover its
			# construction value once; every replacement is paid normally.
			var basis=int(data.facilities.forest.cost) if e.get("starter",false) and e.investedCash==0 else int(e.investedCash)
			refund=mini(basis,maxi(refund,int(data.facilities.forest.cost)))
	return refund
