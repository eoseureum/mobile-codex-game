extends RefCounted
const World=preload("res://scripts/core/world_map.gd")
static func feature(game,name) -> bool:
	if game.central_sales():
		match name:
			"inventory":return true
			"logistics":return game.SalesHub.started(game)
			"industry","overview","records":return game.recorded("first_sale") and game.produced("log")>0
			"trade":return false
		return true
	if not game.world_mode() or not game.state.factory.has("startMode"):return true
	match name:
		"inventory":return not game.shipping_depot().is_empty()
		"industry","overview","records":return game.stage_index()>=1 and game.recorded("first_auto_sale")
		"trade":return game.recorded("first_auto_sale")
	return true
static func catalog(game,all=false) -> Array:
	if game.central_sales():
		if not game.SalesHub.started(game):return ["forest"]
		var values=[]
		for kind in game.data.facilities:
			if kind in ["warehouse","market"]:continue
			if not all and not game.unlocked(kind):continue
			if not all and game.data.facilities[kind].tier>0 and not feature(game,"industry"):continue
			values.append(kind)
		if "sawmill" in values and not game.has_facility("sawmill"):values.erase("sawmill");values.push_front("sawmill")
		return values
	if all:return game.data.facilities.keys()
	if game.world_mode() and game.state.entities.is_empty():return ["forest"]
	var result=[]
	var kinds=["forest","sawmill","warehouse","belt","mine","copperSmelter","wireFactory","generator","ironSmelter","partsFactory","structureFactory","electronicsFactory","precisionFactory","refinery","launchpad"]
	for kind in kinds:
		if not game.unlocked(kind):continue
		if kind in ["warehouse","belt"] and not game.recorded("first_sawmill"):continue
		if game.state.factory.has("startMode") and game.data.facilities[kind].tier>0 and not game.recorded("first_auto_sale"):continue
		result.append(kind)
	if game.stage_index()>=4:result.append("splitter")
	var preferred="sawmill" if not game.has_facility("sawmill") else "warehouse" if not game.has_facility("warehouse") else "mine" if game.stage_index()>=1 and not game.recorded("first_mine") else ""
	if preferred in result:result.erase(preferred);result.push_front(preferred)
	return result
static func suggestion(game,e) -> Dictionary:
	if game.central_sales():return central_suggestion(game,e)
	if not game.world_mode() or e.is_empty():return {}
	var kind="sawmill" if e.kind=="forest" and not game.has_facility("sawmill") else "warehouse" if e.kind=="sawmill" and not game.has_facility("warehouse") else ""
	if kind.is_empty():return {}
	for offset in [Vector2i(2,0),Vector2i(0,2),Vector2i(0,-2),Vector2i(-2,0),Vector2i(3,0),Vector2i(0,3),Vector2i(0,-3),Vector2i(-3,0)]:
		var q=World.linked_quote(game,e.id,kind,{"x":int(e.x)+offset.x,"y":int(e.y)+offset.y})
		if q.ok:return q
	return {}
static func handled_resources(game,e) -> Array:
	var found={}
	for store in [e.inputs,e.outputs,e.get("inventory",{}),e.intakeCursors]:
		for r in store:
			if game.data.resources.has(r):found[r]=true
	var frontier=[e];var visited={}
	# The short opening line is visible before its first item reaches the depot.
	for depth in range(2):
		var next=[]
		for target in frontier:
			for d in game.DIRS:
				var source=game.at(target.x+d.x,target.y+d.y)
				if source.is_empty() or visited.has(source.id):continue
				var feeds=false
				for direction in (source.splitDirections if source.kind=="splitter" else [source.direction]):
					var out=game.DIRS[int(direction)]
					if source.x+out.x==target.x and source.y+out.y==target.y:feeds=true
				if not feeds:continue
				visited[source.id]=true
				if game.transport(source):next.append(source)
				else:
					for r in game.recipe(source).output:found[r]=true
					if source.kind=="warehouse" and source.get("dispatchResource")!=null:found[source.dispatchResource]=true
		frontier=next
	var result=[]
	for r in game.data.resources:
		if found.has(r):result.append(r)
	return result

static func leads_to_hub(game,e) -> bool:
	var frontier=[e];var seen={}
	while not frontier.is_empty():
		var source=frontier.pop_back()
		if seen.has(source.id):continue
		seen[source.id]=true
		if source.get("salesHub",false):return true
		for direction in (source.splitDirections if source.kind=="splitter" else [source.direction]):
			var d=game.DIRS[int(direction)];var target=game.at(source.x+d.x,source.y+d.y)
			if not target.is_empty():frontier.append(target)
	return false
static func central_suggestion(game,e) -> Dictionary:
	if e.is_empty() or e.kind!="forest":return {}
	if not leads_to_hub(game,e):
		var hub=game.sales_hub();var footprint=game.entity_rect(hub);var best={}
		for y in range(footprint.position.y,footprint.end.y):
			for x in range(footprint.position.x,footprint.end.x):
				if x!=footprint.position.x and x!=footprint.end.x-1 and y!=footprint.position.y and y!=footprint.end.y-1:continue
				var q=World.route_quote(game,{"x":e.x,"y":e.y},{"x":x,"y":y})
				if q.ok and (best.is_empty() or q.cash<best.cash):
					best=q;best.action="connectMarket";best.sourceId=e.id;best.kind="market";best.x=x;best.y=y;best.materials={}
		return best
	if game.has_facility("sawmill"):return {}
	var source=e;var visited={};var path=[Vector2i(int(e.x),int(e.y))]
	while not source.is_empty() and not visited.has(source.id):
		visited[source.id]=true
		var d=game.DIRS[int(source.direction)];var next=game.at(source.x+d.x,source.y+d.y)
		if source.kind=="belt" and next.get("salesHub",false):
			return {"action":"insertSawmill","entityId":source.id,"sourceId":e.id,"kind":"sawmill","x":int(source.x),"y":int(source.y),"cash":game.data.facilities.sawmill.cost,"materials":{},"path":path}
		if next.is_empty() or not game.transport(next):break
		source=next;path.append(Vector2i(int(source.x),int(source.y)))
	for offset in [Vector2i(2,0),Vector2i(0,2),Vector2i(0,-2),Vector2i(-2,0),Vector2i(3,0),Vector2i(0,3),Vector2i(0,-3),Vector2i(-3,0)]:
		var q=World.linked_quote(game,e.id,"sawmill",{"x":int(e.x)+offset.x,"y":int(e.y)+offset.y})
		if q.ok:return q
	return {}
