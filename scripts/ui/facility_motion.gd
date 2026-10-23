extends RefCounted
## Presentation only: one production animation loop per actual recipe cycle.
static func phase(game,e) -> float:
	if e.paused:return -1.0
	var time=game.state.clock.elapsedS+game.state.clock.carryS
	if e.get("salesHub",false):return fposmod(time*0.7,1.0)
	var f=game.recipe(e)
	if f.cycle>0 and not f.output.is_empty():
		var rate=game.speed(e)*(game.state.power.ratio if f.power>0 else 1.0)
		if rate<=0:return -1.0
		if e.job==null:
			if not game.has_stock(e.inputs,f.input) or not game.output_fits(e,f.output):return -1.0
			return minf(0.999999,game.state.clock.carryS*rate/f.cycle)
		if e.job.remaining<=0.00000001:return -1.0
		return clampf(1.0-e.job.remaining/f.cycle+game.state.clock.carryS*rate/f.cycle,0.0,0.999999)
	if game.transport(e):
		if e.queue.is_empty() or not can_send(game,e,e.queue[0]):return -1.0
		return fposmod(time*(1.5 if e.level==1 else 3.0),1.0)
	if e.kind=="generator":return fposmod(time*game.speed(e),1.0) if e.burnRemainingS>0 else -1.0
	var order=game.state.factory.get("trade",{}).get("active")
	if e.kind=="warehouse":
		if e==game.shipping_depot() and order!=null:return fposmod(time*game.effects().loading,1.0)
		if not e.inputs.is_empty() or not e.outputs.is_empty():return fposmod(time*1.5*game.speed(e),1.0)
		for r in e.get("inventory",{}):
			var surplus=e.inventory[r]-maxf(0,game.state.factory.reserves[r])
			if surplus>0 and ((e.autoSell and game.state.factory.reserves[r]>=0) or (e.get("dispatchResource")==r and can_send(game,e,r))):return fposmod(time*1.5*game.speed(e),1.0)
		return -1.0
	if e.kind=="market":
		for r in e.inputs:
			if e.saleFilters[r] and e.inputs[r]>0:return fposmod(time*2*game.speed(e),1.0)
	if game.is_project(e.kind) and not e.project.complete:
		var definition=game.data.projects[e.kind]
		if game.central_sales() or game.has_stock(e.project.materials,definition.materials):return fposmod((definition.seconds-e.project.remainingS+game.state.clock.carryS)*2,1.0)
	if e.kind=="launchpad":
		for transfer in game.transfers:
			if transfer.targetId==e.id:return fposmod(time,1.0)
	return -1.0
static func can_send(game,e,r) -> bool:
	var directions=e.splitDirections if e.kind=="splitter" else [e.direction]
	for direction in directions:
		var d=game.DIRS[int(direction)];var target=game.at(e.x+d.x,e.y+d.y)
		if target.is_empty():continue
		var snapshot={target.id:{"queue":target.queue,"inputs":target.inputs,"outputs":target.outputs}}
		if game.transport_space(target,r,e,snapshot,{})>0:return true
	return false
static func frame(progress:float) -> int:return 0 if progress<0 else 1+mini(7,int(floor(progress*8)))
