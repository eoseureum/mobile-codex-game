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
static func ports_mask(game,e) -> int:
	var mask=0
	for direction in inputs(game,e):mask|=1<<int(direction)
	var outputs=e.splitDirections if e.kind=="splitter" else [int(e.direction)]
	for direction in outputs:mask|=1<<int(direction)
	return mask
static func cargo(e,incoming:Dictionary={}) -> Array:
	# Transfers already exist in the destination queue. Hide their stationary
	# copies until the flight lands, then group every remaining unit by resource.
	var pending=incoming.duplicate();var counts={};var order=[]
	for resource in e.queue:
		if int(pending.get(resource,0))>0:
			pending[resource]=int(pending[resource])-1
			continue
		if not counts.has(resource):order.append(resource);counts[resource]=0
		counts[resource]+=1
	var items=[]
	var columns=mini(3,int(ceil(sqrt(order.size()))))
	if columns==0:return items
	var rows=int(ceil(float(order.size())/columns))
	var gap=0.3 if order.size()<=4 else 0.26
	for i in range(order.size()):
		var row=i/columns;var row_count=mini(columns,order.size()-row*columns)
		var offset=Vector2((i%columns-(row_count-1)*0.5)*gap,(row-(rows-1)*0.5)*gap)
		items.append({"resource":order[i],"offset":offset,"size":0.36 if order.size()<=4 else 0.25,"count":counts[order[i]]})
	return items
static func duration(game,e) -> float:
	var rate=(1.5 if e.level==1 else 3.0) if game.transport(e) else 1.5*game.speed(e) if e.kind=="warehouse" else 8.0
	# A flight must land before the next fixed simulation tick can forward it.
	return minf(clampf(1.0/rate,0.12,0.65),game.DT*0.88)
