extends RefCounted
## Read-only player-facing diagnostics; all telemetry is transient, never saved.
static func issue(game,e) -> Dictionary:
	if e.is_empty():return {"kind":"idle","text":"","resource":""}
	if game._issues.has(e.id):return game._issues[e.id]
	var result=_issue(game,e);game._issues[e.id]=result;return result
static func state(kind,text,resource="") -> Dictionary:return {"kind":kind,"text":text,"resource":resource}
static func _issue(game,e) -> Dictionary:
	if e.paused:return state("paused","일시 정지")
	if e.get("salesHub",false):return state("active","도착 즉시 판매")
	if game.is_project(e.kind):return state("complete","완공") if e.project.complete else state("active","공사 중")
	if e.kind=="launchpad":return state("complete","발사 완료") if game.state.rocket.launched else state("active","발사 준비 완료" if rocket_ready(game) else "로켓 조립 중")
	if game.transport(e):
		if e.queue.is_empty():return state("idle","운송 대기")
		var r=e.queue[0];var dirs=e.splitDirections if e.kind=="splitter" else [e.direction]
		var reason=state("blocked","출구 연결 없음",r)
		for direction in dirs:
			var d=game.DIRS[int(direction)];var target=game.at(e.x+d.x,e.y+d.y)
			if target.is_empty():continue
			var snapshots={target.id:{"queue":target.queue,"inputs":target.inputs,"outputs":target.outputs}}
			if game.transport_space(target,r,e,snapshots,{})>0:return state("active","운송 중")
			if target.paused:reason=state("blocked","도착 시설 일시 정지",r)
			elif not game.transport(target) and target.kind not in ["market","launchpad","warehouse"] and not game.recipe(target).input.has(r):reason=state("incompatible",game.data.resources[r].name+" · 원료 불일치",r)
			elif game.transport(target) and Vector2i(int(target.x),int(target.y))+game.DIRS[int(target.direction)]==Vector2i(int(e.x),int(e.y)):reason=state("blocked","컨베이어 방향 충돌",r)
			else:reason=state("blocked","출구 정체",r)
		return reason
	if e.kind=="generator":return state("active","발전 중") if e.burnRemainingS>0 or e.inputs.get("coal",0)>0 else state("missing","석탄 부족","coal")
	var f=game.recipe(e)
	if f.cycle<=0:return state("idle",game.status_fallback(e))
	if not game.output_fits(e,f.output):return state("blocked","완성품 출구 정체")
	if e.job==null:
		for r in f.input:
			if e.inputs.get(r,0)<f.input[r]:return state("missing",game.data.resources[r].name+" 부족",r)
	if f.power>0 and game.state.power.ratio<1:return state("power","전력 부족")
	return state("active","가동 중")
static func rocket_ready(game) -> bool:
	return not game.state.rocket.launched and game.has_stock(game.state.rocket.delivered,game.data.rocket)
static func next_stage(game) -> Dictionary:
	var i=game.stage_index();var conditions=[]
	match i:
		0:conditions=[{"resource":"plank","need":30}]
		1:conditions=[{"resource":"copper","need":20}]
		2:conditions=[{"resource":"wire","need":10},{"facility":"generator"}]
		3:conditions=[{"resource":"machinePart","need":10},{"record":"first_power","name":"첫 전력 생산"}]
		4:conditions=[{"resource":"structure","need":10}]
		5:conditions=[{"resource":"electronics","need":10},{"resource":"precision","need":10}]
		_:return {"name":"로켓","conditions":[]}
	return {"name":game.data.stageNames[i+1],"conditions":conditions}
static func observe(game,e) -> Dictionary:
	var now=game.state.clock.elapsedS;var count=0
	var samples=game.production_samples.get(e.id,[])
	for sample in samples:
		if sample.at>now-60:count+=sample.count
	var elapsed=minf(60,now-game.observation_started)
	var f=game.recipe(e);var output=0
	for n in f.output.values():output+=int(n)
	return {"actual":count*60.0/elapsed if elapsed>=10 else -1.0,"nominal":output*60.0*game.speed(e)/f.cycle if f.cycle>0 else 0.0}
