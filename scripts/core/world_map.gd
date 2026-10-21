class_name RustWorldMap
extends RefCounted
const SIZE=128
const NODE_TYPES=["log","stone","coal","copper","iron"]
const MAX_ENTITIES=1024
const MAX_WORK=256
static func key(x,y) -> String:return "%d,%d"%[x,y]
static func parse_key(value) -> Vector2i:
	if not value is String:return Vector2i(-1,-1)
	var parts=value.split(",")
	if parts.size()!=2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():return Vector2i(-1,-1)
	var p=Vector2i(int(parts[0]),int(parts[1]))
	return p if key(p.x,p.y)==value else Vector2i(-1,-1)
static func valid_point(p) -> bool:
	if not p is Dictionary:return false
	for name in ["x","y"]:
		var n=p.get(name)
		if not (n is int or n is float) or not is_finite(float(n)) or n!=floor(n) or n<0 or n>=SIZE:return false
	return true
static func resource_at(world:Dictionary,x,y) -> String:return world.nodes.get(key(x,y),"")
static func patch(nodes:Dictionary,x:int,y:int,radius:int,resource:String):
	for dy in range(-radius,radius+1):
		for dx in range(-radius,radius+1):
			if dx*dx+dy*dy>radius*radius or x+dx<0 or y+dy<0 or x+dx>=SIZE or y+dy>=SIZE:continue
			nodes[key(x+dx,y+dy)]=resource
static func generate(seed_value:int) -> Dictionary:
	var rng=RandomNumberGenerator.new();rng.seed=seed_value
	var nodes={}
	for cy in range(8):
		for cx in range(8):
			var x=cx*16+8+rng.randi_range(-3,3);var y=cy*16+8+rng.randi_range(-3,3)
			var r=["log","log","stone","coal","copper","iron"][rng.randi_range(0,5)]
			patch(nodes,x,y,3 if r=="log" else 2,r)
	# A fair opening replaces random spawn luck. Clustered resources still surround it.
	for pos in nodes.keys():
		var p=parse_key(pos)
		if abs(p.x-64)<=16 and abs(p.y-64)<=16:nodes.erase(pos)
	for p in [Vector2i(59,69),Vector2i(69,69),Vector2i(58,59),Vector2i(70,58)]:patch(nodes,p.x,p.y,2,"log")
	patch(nodes,75,66,2,"copper");patch(nodes,65,76,2,"stone")
	patch(nodes,75,55,2,"coal");patch(nodes,52,54,2,"iron")
	nodes[key(62,64)]="log"
	return {"version":1,"seed":seed_value,"width":SIZE,"height":SIZE,"spawn":{"x":64,"y":64},"nodes":nodes,"cleared":{},"revision":0}
static func valid_model(w) -> bool:
	if not w is Dictionary:return false
	for pair in [["version",1],["width",SIZE],["height",SIZE]]:
		var n=w.get(pair[0])
		if not (n is int or n is float) or n!=pair[1]:return false
	if not valid_point(w.get("spawn")):return false
	for field in ["seed","revision"]:
		var n=w.get(field)
		if not (n is int or n is float) or not is_finite(float(n)) or n!=floor(n) or n<0 or n>2147483647:return false
	if not w.get("nodes") is Dictionary or not w.get("cleared") is Dictionary or w.nodes.size()+w.cleared.size()>SIZE*SIZE:return false
	for pos in w.nodes:
		var p=parse_key(pos)
		if p.x<0 or p.y<0 or p.x>=SIZE or p.y>=SIZE or w.nodes[pos] not in NODE_TYPES or w.cleared.has(pos):return false
	for pos in w.cleared:
		var p=parse_key(pos)
		if p.x<0 or p.y<0 or p.x>=SIZE or p.y>=SIZE or not w.cleared[pos] is bool or not w.cleared[pos]:return false
	return true
static func failure(code:String) -> Dictionary:return {"ok":false,"code":code,"cells":[],"clear":[],"cash":0,"reward":{}}
static func clearance(game,points:Array) -> Dictionary:
	var result={"ok":true,"code":"OK","cells":[],"clear":[],"cash":0,"reward":{}}
	var prices={}
	for p in points:
		if not game.at(p.x,p.y).is_empty():return failure("OCCUPIED")
		var r=resource_at(game.state.world,p.x,p.y)
		if r.is_empty():continue
		if not game.known_resource(r):return failure("LOCKED")
		var count=2 if r=="log" else 1
		result.clear.append(key(p.x,p.y))
		if not prices.has(r):
			prices[r]=game.price(r)
			for e in game.state.entities.values():
				if e.kind in ["warehouse","market"]:prices[r]=maxi(prices[r],game.sale_price(e,r))
		result.cash+=int(ceil(prices[r]*count*1.2))
		result.reward[r]=result.reward.get(r,0)+count
	return result
static func clear_quote(game,from,to) -> Dictionary:
	if not game.world_mode() or not valid_point(from) or not valid_point(to):return failure("INVALID")
	var xmin=mini(int(from.x),int(to.x));var xmax=maxi(int(from.x),int(to.x))
	var ymin=mini(int(from.y),int(to.y));var ymax=maxi(int(from.y),int(to.y))
	if (xmax-xmin+1)*(ymax-ymin+1)>MAX_WORK:return failure("TOO_LARGE")
	var points=[]
	for y in range(ymin,ymax+1):
		for x in range(xmin,xmax+1):points.append(Vector2i(x,y))
	var result=clearance(game,points)
	if result.ok and result.clear.is_empty():return failure("EMPTY")
	return result
static func direction(a:Vector2i,b:Vector2i) -> int:
	var d=b-a
	return 1 if d.x>0 else 3 if d.x<0 else 2 if d.y>0 else 0
static func accepts_end(game,end:Vector2i,previous:Vector2i) -> bool:
	var e=game.at(end.x,end.y)
	if e.is_empty() or e.kind in ["market","launchpad"] or game.is_project(e.kind):return true
	if e.kind=="warehouse" and e.get("dispatchResource")==null:return true
	return Vector2i(int(e.x),int(e.y))+game.DIRS[int(e.direction)]!=previous
static func direct_path(a:Vector2i,b:Vector2i,horizontal:bool) -> Array:
	var path=[a];var p=a
	for axis in [0,1] if horizontal else [1,0]:
		while p[axis]!=b[axis]:p[axis]+=signi(b[axis]-p[axis]);path.append(p)
	return path
static func quote_path(game,path:Array,clear:bool) -> Dictionary:
	if path.size()<2 or path.size()>MAX_WORK:return failure("TOO_LARGE")
	if not accepts_end(game,path[-1],path[-2]):return failure("WRONG_PORT")
	var cells=[];var terrain=[]
	for i in range(path.size()):
		var p=path[i];var e=game.at(p.x,p.y)
		if not e.is_empty():
			if i>0 and i<path.size()-1:return failure("OCCUPIED")
			continue
		var r=resource_at(game.state.world,p.x,p.y)
		if not r.is_empty():
			if not clear:return failure("BLOCKED")
			terrain.append(p)
		cells.append({"x":p.x,"y":p.y,"direction":direction(p,path[i+1]) if i<path.size()-1 else direction(path[i-1],p)})
	if cells.is_empty():return failure("EMPTY")
	if cells.size()+game.state.entities.size()>MAX_ENTITIES:return failure("TOO_LARGE")
	var result=clearance(game,terrain)
	if not result.ok:return result
	result.cells=cells;result.path=path;result.cash+=cells.size()*int(game.data.facilities.belt.cost)
	result.sourceDirection=direction(path[0],path[1])
	return result
static func route_quote(game,from,to,clear=false) -> Dictionary:
	if not game.world_mode() or not valid_point(from) or not valid_point(to) or not clear is bool:return failure("INVALID")
	var a=Vector2i(int(from.x),int(from.y));var b=Vector2i(int(to.x),int(to.y))
	if a==b:return failure("INVALID")
	if clear:
		var first=quote_path(game,direct_path(a,b,true),true)
		var second=quote_path(game,direct_path(a,b,false),true)
		if not first.ok:return second if second.ok else first
		return second if second.ok and second.cash<first.cash else first
	var grid=AStarGrid2D.new();grid.region=Rect2i(0,0,SIZE,SIZE);grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.default_compute_heuristic=AStarGrid2D.HEURISTIC_MANHATTAN;grid.default_estimate_heuristic=AStarGrid2D.HEURISTIC_MANHATTAN;grid.update()
	for pos in game.state.world.nodes:grid.set_point_solid(parse_key(pos),true)
	for e in game.state.entities.values():grid.set_point_solid(Vector2i(int(e.x),int(e.y)),true)
	grid.set_point_solid(a,false);grid.set_point_solid(b,false)
	var end_entity=game.at(b.x,b.y)
	if not end_entity.is_empty() and end_entity.kind not in ["market","launchpad"] and not game.is_project(end_entity.kind) and not (end_entity.kind=="warehouse" and end_entity.get("dispatchResource")==null):
		var output=b+game.DIRS[int(end_entity.direction)]
		if output.x>=0 and output.y>=0 and output.x<SIZE and output.y<SIZE:
			if output==a:return failure("WRONG_PORT")
			grid.set_point_solid(output,true)
	var ids=grid.get_id_path(a,b)
	if ids.is_empty():return failure("BLOCKED")
	var path=[]
	for id in ids:path.append(id)
	return quote_path(game,path,false)

static func linked_quote(game,source_id,kind,to) -> Dictionary:
	if not game.world_mode() or not valid_point(to) or kind not in ["sawmill","warehouse"]:return failure("INVALID")
	var source=game.state.entities.get(source_id,{})
	if source.is_empty():return failure("INVALID")
	if not game.unlocked(kind):return failure("LOCKED")
	if not game.at(to.x,to.y).is_empty():return failure("OCCUPIED")
	if not resource_at(game.state.world,to.x,to.y).is_empty():return failure("BLOCKED")
	var output=game.recipe(source).output
	if output.is_empty() or (kind=="sawmill" and not output.has("log")):return failure("INVALID")
	var quote=route_quote(game,{"x":source.x,"y":source.y},to,false)
	if not quote.ok:return quote
	# The destination is a facility, so it replaces the last quoted belt.
	quote.cells.pop_back();quote.cash+=game.data.facilities[kind].cost-game.data.facilities.belt.cost
	quote.kind=kind;quote.x=int(to.x);quote.y=int(to.y);quote.sourceId=source_id
	quote.targetDirection=direction(quote.path[-2],quote.path[-1])
	quote.materials=game.construction_materials(kind).duplicate()
	return quote
