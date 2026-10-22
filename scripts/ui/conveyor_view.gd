extends RefCounted
## Geometry and sprite identities use actual connections and queued cargo only.
static func inputs(game,e) -> Array:
	var ports=[]
	for direction in range(4):
		if direction==int(e.direction):continue
		var d=game.DIRS[direction];var source=game.at(e.x+d.x,e.y+d.y)
		if source.is_empty():continue
		if not game.transport(source) and game.recipe(source).output.is_empty() and not (source.kind=="warehouse" and source.get("dispatchResource")!=null):continue
		var out=source.splitDirections if source.kind=="splitter" else [int(source.direction)]
		if (direction+2)%4 in out:ports.append(direction)
	return ports
static func cargo(e) -> Array:
	var items=[]
	var direction=Vector2([Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0)][int(e.direction)])
	for i in range(mini(3,e.queue.size())):
		var along=0.3-i*0.3 if e.queue.size()>1 else 0.0
		items.append({"resource":e.queue[i],"offset":direction*along,"size":0.36})
	return items
static func duration(game,e) -> float:
	var rate=(1.5 if e.level==1 else 3.0) if game.transport(e) else 1.5*game.speed(e) if e.kind=="warehouse" else 8.0
	return clampf(1.0/rate,0.12,0.65)
