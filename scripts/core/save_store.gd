class_name RustSaveStore
extends RefCounted
const Factory=preload("res://scripts/core/factory.gd")
const PATH="user://rust-city-godot-v1.json"
var last_error=""

func whole(n,lo=0,hi=RustFactory.MAX_MONEY) -> bool:
	return (n is int or n is float) and is_finite(float(n)) and n>=lo and n<=hi and floor(n)==n
func resources(v,limit=RustFactory.MAX_MONEY) -> bool:
	if not v is Dictionary: return false
	var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	for r in v:
		if not catalog.resources.has(r) or not whole(v[r],0,limit): return false
	return true

func same_resources(a:Dictionary,b:Dictionary) -> bool:
	if a.size()!=b.size():return false
	for r in a:
		if not b.has(r) or a[r]!=b[r]:return false
	return true

func validate(snapshot) -> String:
	if not snapshot is Dictionary or snapshot.get("version")!=1 or not whole(snapshot.get("savedAtMs")): return "저장 형식을 확인해 주세요."
	var s=snapshot.get("state")
	if not s is Dictionary or s.get("version")!=1 or not s.get("factory") is Dictionary or s.factory.get("currencyVersion")!=2 or s.has("harvest"): return "현재 공장 도시의 백업만 불러올 수 있어요."
	for key in ["entities","districts","unlocks","totals","clock","power","rocket","bag"]:
		if not s.get(key) is Dictionary: return "저장된 도시 정보가 부족해요."
	for key in ["records","recentSales","corridors"]:
		if not s.get(key) is Array: return "저장된 도시 기록이 올바르지 않아요."
	if not whole(s.get("cash")) or not whole(s.get("createdAtMs")) or not whole(s.get("nextId"),2) or not resources(s.bag): return "저장된 금액이나 재고가 올바르지 않아요."
	if not resources(s.totals.get("produced")) or not resources(s.totals.get("sold")) or not whole(s.totals.get("earned")) or not whole(s.totals.get("operatingEarned",0),0,s.totals.earned): return "생산 기록이 올바르지 않아요."
	var game=Factory.new()
	game.state=s
	var tier=game.data.stages.find(s.get("stage",""))
	if tier<0 or s.unlocks.get("offline")!=(tier>=4): return "산업 단계가 올바르지 않아요."
	for id in game.data.districts:
		if not s.districts.get(id) is Dictionary or int(s.districts[id].get("size",-1)) not in ([1,2,3,6] if id=="forest" else [0,3,6]): return "토지 정보가 올바르지 않아요."
	if s.entities.size()>216 or s.records.size()>100 or s.recentSales.size()>20000 or s.corridors.size()>216: return "저장 데이터가 너무 커요."
	if not (s.clock.get("elapsedS") is int or s.clock.get("elapsedS") is float): return "도시 시각이 올바르지 않아요."
	if not whole(s.clock.get("tickIndex")) or not whole(s.clock.get("elapsedS",-1)*4) or abs(s.clock.elapsedS-s.clock.tickIndex*0.25)>0.000001: return "도시 시각이 올바르지 않아요."
	if not s.clock.get("carryS") is float and not s.clock.get("carryS") is int: return "도시 시각이 올바르지 않아요."
	if s.clock.carryS<0 or s.clock.carryS>=0.25: return "도시 시각이 올바르지 않아요."
	if not s.factory.get("reserves") is Dictionary or not s.factory.get("dispatchCursors") is Dictionary or not whole(s.factory.get("saleCursor"),0,game.data.resources.size()-1): return "창고 정책이 올바르지 않아요."
	if not (s.factory.get("saleCredit") is float or s.factory.get("saleCredit") is int) or s.factory.saleCredit<0 or s.factory.saleCredit>2: return "판매 속도가 올바르지 않아요."
	for r in game.data.resources:
		if not whole(s.factory.reserves.get(r),-1,10000): return "창고 보관량이 올바르지 않아요."
	var positions={}
	var projects={}
	var ids=RegEx.create_from_string("^e[1-9][0-9]*$")
	for id in s.entities:
		var e=s.entities[id]
		if not e is Dictionary or ids.search(id)==null or e.get("id")!=id or not game.data.facilities.has(e.get("kind","")): return "시설 정보가 올바르지 않아요."
		for field in ["x","y","level","direction","investedCash","flowCredit","splitCursor","burnRemainingS"]:
			if not (e.get(field) is int or e.get(field) is float) or not is_finite(float(e[field])) or e[field]<0: return "시설 수치가 올바르지 않아요."
		if not whole(e.x,0,17) or not whole(e.y,0,11) or not whole(e.level,1,game.data.facilities[e.kind].maxLevel) or not whole(e.direction,0,3) or not whole(e.investedCash) or game.data.facilities[e.kind].tier>tier or not game.owned(e.x,e.y): return "시설 위치나 단계가 올바르지 않아요."
		if not e.get("paused") is bool or e.get("factory")!=true or e.get("automatic")!=true: return "자동 공장 정보가 올바르지 않아요."
		var point=game.key(e.x,e.y)
		if positions.has(point) or int(id.substr(1))>=s.nextId: return "시설이 겹치거나 식별자가 올바르지 않아요."
		positions[point]=true
		if not resources(e.get("inputs"),game.capacity(e)) or not resources(e.get("outputs"),game.capacity(e)) or not e.get("queue") is Array or not e.get("saleFilters") is Dictionary or not e.get("intakeCursors",{}) is Dictionary: return "시설 재고가 올바르지 않아요."
		if e.queue.size()>(4 if e.level==1 else 8) or (not game.transport(e) and not e.queue.is_empty()): return "컨베이어 재고가 올바르지 않아요."
		for r in e.queue:
			if not game.data.resources.has(r): return "운송 재료가 올바르지 않아요."
		for r in game.data.resources:
			if not e.saleFilters.get(r) is bool: return "판매 설정이 올바르지 않아요."
		if not e.get("splitDirections") is Array or e.splitDirections.size()!=2 or not whole(e.splitDirections[0],0,3) or not whole(e.splitDirections[1],0,3) or e.splitDirections[0]==e.splitDirections[1]: return "분배기 방향이 올바르지 않아요."
		if e.get("mineResourceId","") not in ["stone","coal","copper","iron"]: return "광물 정보가 올바르지 않아요."
		if e.kind=="warehouse" and e.get("dispatchResource")!=null and not game.data.resources.has(e.dispatchResource): return "출고 재료가 올바르지 않아요."
		var f=game.recipe(e)
		if not e.has("job"): return "진행 중 작업이 올바르지 않아요."
		if e.get("job")!=null:
			var job=e.job
			if not job is Dictionary or f.cycle<=0 or e.kind=="generator" or not job.get("reserved") is Dictionary or not job.get("output") is Dictionary: return "진행 중 작업이 올바르지 않아요."
			if not (job.get("remaining") is int or job.get("remaining") is float) or not is_finite(float(job.remaining)) or job.remaining<0 or job.remaining>f.cycle or not same_resources(job.reserved,f.input) or not same_resources(job.output,f.output): return "작업 재료가 올바르지 않아요."
		if not whole(e.get("managerLevel",0),0,3) or not whole(e.get("incomeLevel",0),0,10): return "개선 단계가 올바르지 않아요."
		if e.has("incomeCredit") and (not (e.incomeCredit is int or e.incomeCredit is float) or e.incomeCredit<0 or e.incomeCredit>=1 or not is_finite(float(e.incomeCredit))): return "운영 수입이 올바르지 않아요."
		if game.is_project(e.kind):
			if projects.has(e.kind) or not e.get("project") is Dictionary: return "도시 건설 정보가 올바르지 않아요."
			projects[e.kind]=true
			var p=e.project
			if not resources(p.get("materials")) or not p.get("complete") is bool or not (p.get("remainingS") is int or p.get("remainingS") is float): return "공사 재료가 올바르지 않아요."
			if p.remainingS<0 or p.remainingS>game.data.projects[e.kind].seconds or e.investedCash!=f.cost: return "공사 진행이 올바르지 않아요."
			for r in p.materials:
				if p.materials[r]>game.data.projects[e.kind].materials.get(r,0): return "공사 재료가 너무 많아요."
			if p.complete and (p.remainingS!=0 or not game.has_stock(p.materials,game.data.projects[e.kind].materials)): return "미완성 공사예요."
	for id in ["e1","e2","e3"]:
		if not s.entities.has(id): return "시작 생산라인이 없어요."
	if s.entities.e1.kind!="forest" or s.entities.e2.kind!="sawmill" or s.entities.e3.kind!="warehouse": return "시작 생산라인이 올바르지 않아요."
	for event in s.records:
		if not event is Dictionary or not event.get("type") is String or not (event.get("atS") is int or event.get("atS") is float) or event.atS<0 or event.atS>s.clock.elapsedS: return "도시 기록이 올바르지 않아요."
	for sale in s.recentSales:
		if not sale is Dictionary or not whole(sale.get("cash")) or sale.get("mode","") not in ["operating","market","shipment"] or not (sale.get("atS") is int or sale.get("atS") is float): return "수입 기록이 올바르지 않아요."
	if not resources(s.rocket.get("delivered")) or not whole(s.rocket.get("launched"),0,1): return "로켓 정보가 올바르지 않아요."
	for r in s.rocket.delivered:
		if s.rocket.delivered[r]>game.data.rocket.get(r,0): return "로켓 납품이 올바르지 않아요."
	if s.rocket.launched and not game.has_stock(s.rocket.delivered,game.data.rocket): return "로켓이 미완성이에요."
	if s.factory.has("trade"):
		var t=s.factory.trade
		if not t is Dictionary or not whole(t.get("completed")) or not whole(t.get("rewardEarned")) or not t.get("repeat") is bool or not (t.get("cooldownS") is int or t.get("cooldownS") is float): return "주문 기록이 올바르지 않아요."
		if t.cooldownS<0 or t.cooldownS>20: return "주문 대기 시간이 올바르지 않아요."
		if not t.has("active") or not t.has("lastOfferId") or (t.lastOfferId!=null and not t.lastOfferId is String): return "주문 기록이 올바르지 않아요."
		if t.get("active")!=null:
			var a=t.active
			if not a is Dictionary or not game.data.resources.has(a.get("resource","")) or a.get("bonus",0) not in [1.0,1.1]: return "출하 주문이 올바르지 않아요."
			var quote={}
			for q in game.quotes(a.resource,a.bonus):
				if q.id==a.get("id"): quote=q
			if quote.is_empty() or quote.reward!=a.get("reward") or quote.quantity!=a.get("quantity") or a.id!=t.get("lastOfferId"): return "출하 금액이 올바르지 않아요."
			if not whole(a.get("loaded"),0,a.quantity) or not whole(a.get("reserved"),0,a.quantity) or a.loaded+a.reserved>a.quantity: return "출하 수량이 올바르지 않아요."
			if not (a.get("departureS") is int or a.get("departureS") is float) or not (a.get("loadingCredit") is int or a.get("loadingCredit") is float) or a.departureS<=0 or a.departureS>5 or a.loadingCredit<0 or a.loadingCredit>1.8: return "상차 정보가 올바르지 않아요."
	return ""

func parse(text: String) -> Dictionary:
	if text.to_utf8_buffer().size()>2000000: last_error="백업 파일이 너무 커요."; return {}
	var parser=JSON.new()
	if parser.parse(text)!=OK: last_error="백업 JSON을 읽을 수 없어요."; return {}
	last_error=validate(parser.data)
	return parser.data if last_error.is_empty() else {}

func snapshot(game) -> Dictionary:
	return {"version":1,"savedAtMs":int(Time.get_unix_time_from_system()*1000),"state":game.state.duplicate(true)}
func export_text(game) -> String: return JSON.stringify(snapshot(game),"",false,true)

func save(game) -> bool:
	var value=snapshot(game)
	last_error=validate(value)
	if not last_error.is_empty(): return false
	var file=FileAccess.open(PATH+".tmp",FileAccess.WRITE)
	if file==null: last_error="저장할 수 없어요. 백업을 내보내 주세요."; return false
	file.store_string(JSON.stringify(value,"",false,true))
	file.flush()
	file.close()
	var absolute=ProjectSettings.globalize_path(PATH)
	if FileAccess.file_exists(PATH):
		var prior=FileAccess.get_file_as_string(PATH)
		if not parse(prior).is_empty():
			if DirAccess.copy_absolute(absolute,absolute+".bak")!=OK: last_error="이전 백업을 보관하지 못했어요."; return false
	if DirAccess.rename_absolute(absolute+".tmp",absolute)!=OK: last_error="저장 파일을 교체하지 못했어요."; return false
	last_error=""
	return true

func load_city() -> Dictionary:
	if not FileAccess.file_exists(PATH): return {}
	var value=parse(FileAccess.get_file_as_string(PATH))
	if value.is_empty() and FileAccess.file_exists(PATH+".bak"):
		value=parse(FileAccess.get_file_as_string(PATH+".bak"))
		if not value.is_empty(): last_error="이전 자동 백업에서 도시를 복원했어요."
	return value
