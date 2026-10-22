extends RefCounted
const World=preload("res://scripts/core/world_map.gd")
static func feature(game,name) -> bool:
	if not game.world_mode() or not game.state.factory.has("startMode"):return true
	match name:
		"inventory":return not game.shipping_depot().is_empty()
		"industry","overview","records":return game.stage_index()>=1 and game.recorded("first_auto_sale")
		"trade":return game.recorded("first_auto_sale")
	return true
static func catalog(game,all=false) -> Array:
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
