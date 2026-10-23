extends RefCounted
const Panels=preload("res://scripts/ui/paged_panels.gd")
static func show(ui,e):
	if e.get("salesHub",false):
		load("res://scripts/ui/production_card.gd").hub(ui,e);return
	var game=ui.game;var f=game.recipe(e)
	if game.is_project(e.kind) or e.kind=="launchpad":
		project(ui,e);return
	if game.central_sales() and not game.recipe(e).output.is_empty() and not game.transport(e):load("res://scripts/ui/production_card.gd").collection(ui,e)
	Panels.tabs(ui,[["summary","요약"],["improve","개선"],["flow","물류"],["stock","재고"]],ui.inspector_page,func(id):ui.inspector_page=id;ui.inspect_details=id!="summary";ui._rebuild())
	match ui.inspector_page:
		"flow":
			var row=ui._row()
			for i in range(4):
				var direction=i;var b=ui._button(row,["↑","→","↓","←"][i],func():ui._command({"type":"rotate","entityId":e.id,"direction":direction}));b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			ui._button(row,"철거",func():ui._demolish(e))
			var actions=ui._row();ui._button(actions,"재개" if e.paused else "일시 정지",func():ui._command({"type":"pause","entityId":e.id}));ui._spacer(actions)
			if e.kind=="warehouse":
				var selling=CheckButton.new();selling.text="자동 판매";selling.button_pressed=e.autoSell;selling.custom_minimum_size.y=48*ui.scale_ui;actions.add_child(selling)
				selling.toggled.connect(func(value):ui._command({"type":"setWarehouseSales","entityId":e.id,"enabled":value}))
				var resources=[""]+game.data.resources.keys();var option=OptionButton.new();option.custom_minimum_size.y=48*ui.scale_ui;ui.body.add_child(option)
				for r in resources:
					option.add_item("출고 안 함" if r=="" else ui._resource_name(r));option.set_item_disabled(option.item_count-1,r!="" and not game.known_resource(r))
				option.select(maxi(0,resources.find(e.get("dispatchResource",""))))
				option.item_selected.connect(func(i):ui._command({"type":"configureWarehouse","entityId":e.id,"resource":null if resources[i]=="" else resources[i]}))
		"stock":
			var resources=game.data.resources.keys().filter(func(r):return game.known_resource(r)) if e.kind in ["warehouse","market","belt","splitter"] else f.input.keys()+f.output.keys()
			var limit=2 if game.central_sales() else 4
			var shown=Panels.items(ui,"facility_stock",resources,limit);var g=Panels.grid(ui)
			for value in shown:
				var r=value;var row=HBoxContainer.new();row.custom_minimum_size.y=40*ui.scale_ui;g.add_child(row);Panels.picture(ui,row,"item_"+r)
				if e.kind=="market":
					var filter=CheckButton.new();filter.button_pressed=e.saleFilters[r];filter.custom_minimum_size.y=48*ui.scale_ui;row.add_child(filter);filter.toggled.connect(func(value):ui._command({"type":"setFilters","entityId":e.id,"filters":{r:value}}))
				ui._bind_label(row,func():return str(int(e.inputs.get(r,0)+e.outputs.get(r,0)+e.queue.count(r)+e.get("inventory",{}).get(r,0))))
			Panels.pager(ui,"facility_stock",resources.size(),limit)
		_:
			var level=int(e.level)
			upgrade(ui,func():return production_title(game,e),"₩ "+game.money(f.upgradeCosts[mini(level-1,f.upgradeCosts.size()-1)]),{"type":"upgrade","entityId":e.id},level>=f.maxLevel or (game.transport(e) and game.stage_index()<4))
			if game.income_facility(e):
				var income=int(e.get("incomeLevel",0));upgrade(ui,"판매 단가\n+%d%% → +%d%%"%[income*12,(income+1)*12],"₩ "+game.money(f.incomeCosts[mini(income,9)]),{"type":"upgradeIncome","entityId":e.id},income>=10)
			if e.kind not in ["belt","splitter"]:
				var manager=int(e.get("managerLevel",0))
				upgrade(ui,func():return manager_title(game,e),"₩ "+game.money(f.managerCosts[mini(manager,2)]),{"type":"upgradeManager","entityId":e.id},manager>=3 or not game.recorded("first_auto_sale"))
static func effect(game,e,bonus) -> String:
	if e.kind=="generator":return "전력 %.2f → %.2f"%[game.generator_output(e),game.generator_output(e,bonus)]
	if e.kind=="market":return "판매 %.2f → %.2f개/s"%[2*game.speed(e),2*(game.speed(e)+bonus)]
	if game.transport(e):return "%.2f → %.2f개/s"%[game.transport_rate(e),game.transport_rate(e,bonus>0)]
	var f=game.recipe(e)
	if f.cycle<=0:return ""
	var before=game.work_rate(e,0,true);var after=game.work_rate(e,bonus,true)
	if before<=0 or after<=0:return "전력 대기"
	return "%.1f → %.1f초"%[f.cycle/before,f.cycle/after]
static func production_title(game,e) -> String:
	var f=game.recipe(e);var level=int(e.level)
	if e.kind=="warehouse":return "창고 확장\n%d → %d개 · %.2f → %.2f개/s"%[game.storage_capacity(e),game.storage_capacity(e)+200,2*game.speed(e),2*(game.speed(e)+0.12)]
	var name="발전" if e.kind=="generator" else "운송" if game.transport(e) else "생산"
	return name+" · Lv.%d\n"%level+effect(game,e,0.12 if level<f.maxLevel else 0.0)
static func manager_title(game,e) -> String:
	if not game.recorded("first_auto_sale"):return "?"
	var manager=int(e.get("managerLevel",0));var title="매니저 · %d / 3"%manager
	if e.kind=="warehouse":return title+"\n판매 %.2f → %.2f개/s"%[2*game.speed(e),2*(game.speed(e)+0.08)]
	return title+"\n"+effect(game,e,0.08 if manager<3 else 0.0)
static func upgrade(ui,title,cost,command,disabled):
	var row=ui._row();var label=ui._bind_label(row,title) if title is Callable else ui._label(row,title);label.clip_text=true;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var b=ui._button(row,cost,func():ui._command(command));b.disabled=disabled
static func project(ui,e):
	var game=ui.game;var rocket=e.kind=="launchpad";var definition=game.data.rocket if rocket else game.data.projects[e.kind].materials
	if game.central_sales() and not rocket:
		ui._label(ui.body,ui._project_effect(e.kind))
		ui._bind_label(ui.body,func():return "완공" if e.project.complete else "공사 %d초"%ceil(e.project.remainingS))
		var row=ui._row();ui._spacer(row);ui._button(row,"철거",func():ui._demolish(e));return
	var received=game.state.rocket.delivered if rocket else e.project.materials
	var shown=Panels.items(ui,"project",definition.keys());var g=Panels.grid(ui)
	for value in shown:
		var r=value;var row=HBoxContainer.new();g.add_child(row);Panels.picture(ui,row,"item_"+r);ui._bind_label(row,func():return "%d / %d"%[received.get(r,0),definition[r]])
	Panels.pager(ui,"project",definition.size(),4,"철거",func():ui._demolish(e))
	if rocket:ui._action("로켓 발사",{"type":"launch"},bool(game.state.rocket.launched))
	else:ui._bind_label(ui.body,func():return "완공" if e.project.complete else ("창고 자동 조달 · 자재 대기" if not game.has_stock(e.project.materials,definition) else "공사 %d초"%ceil(e.project.remainingS)))

static func controls(ui,e):
	var row=ui._row();ui._spacer(row)
	ui._button(row,"관리",func():ui.inspect_details=true;ui.inspector_page="improve";ui._rebuild())
	if not ui.game.is_project(e.kind) and e.kind!="launchpad":
		ui._button(row,"회전 "+["↑","→","↓","←"][int(e.direction)],func():ui._command({"type":"rotate","entityId":e.id,"direction":(int(e.direction)+1)%4}))
	ui._button(row,"철거",func():ui._demolish(e))
