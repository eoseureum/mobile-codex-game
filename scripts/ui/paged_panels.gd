extends RefCounted
const Opening=preload("res://scripts/ui/opening_ux.gd")
const Art=preload("res://scripts/ui/pixel_art.gd")
static func picture(ui,parent,kind):
	var p=TextureRect.new();p.texture=Art.texture(kind);p.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;p.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;p.custom_minimum_size=Vector2(32,32)*ui.scale_ui;parent.add_child(p)
static func items(ui,key,values,limit=4) -> Array:
	var last=maxi(0,int(ceil(float(values.size())/limit))-1)
	ui.pages[key]=clampi(int(ui.pages.get(key,0)),0,last)
	return values.slice(ui.pages[key]*limit,mini(values.size(),(ui.pages[key]+1)*limit))
static func pager(ui,key,count,limit=4,extra="",action=Callable()):
	var last=maxi(0,int(ceil(float(count)/limit))-1);var page=int(ui.pages.get(key,0))
	var row=ui._row()
	ui._button(row,"‹",func():ui.pages[key]=maxi(0,page-1);ui._rebuild()).disabled=page==0
	var label=ui._label(row,"%d / %d"%[page+1,last+1]);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	if not extra.is_empty():ui._button(row,extra,action)
	ui._button(row,"›",func():ui.pages[key]=mini(last,page+1);ui._rebuild()).disabled=page==last
static func tabs(ui,labels,current,action):
	var row=ui._row()
	for entry in labels:
		var id=entry[0];var b=ui._button(row,entry[1],func():action.call(id));b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		if id==current:b.add_theme_stylebox_override("normal",ui._box(Color("e2b86b")))
static func grid(ui) -> GridContainer:
	var g=GridContainer.new();g.columns=2;g.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	g.add_theme_constant_override("h_separation",int(6*ui.scale_ui));g.add_theme_constant_override("v_separation",int(6*ui.scale_ui));ui.body.add_child(g);return g
static func tile(ui,parent,title,subtitle,art,action,disabled=false):
	var b=ui._button(parent,"",action);b.disabled=disabled;b.custom_minimum_size=Vector2(0,60)*ui.scale_ui;b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.tooltip_text=title+" · "+subtitle
	var column=VBoxContainer.new();column.mouse_filter=Control.MOUSE_FILTER_IGNORE;b.add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);column.offset_left=4*ui.scale_ui;column.offset_right=-4*ui.scale_ui
	column.add_theme_constant_override("separation",0)
	var icon=TextureRect.new();icon.texture=Art.texture(art);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.custom_minimum_size.y=24*ui.scale_ui;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;column.add_child(icon)
	for text in [title,subtitle]:
		var l=Label.new();l.text=text;l.clip_text=true;l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;l.mouse_filter=Control.MOUSE_FILTER_IGNORE;l.add_theme_font_size_override("font_size",int(12*ui.scale_ui));column.add_child(l)
	return b
static func build(ui):
	if ui.game.recorded("first_sawmill"):
		tabs(ui,[["facilities","시설"],["logistics","물류"]],ui.build_page,func(id):ui.build_page=id;ui._rebuild())
	if ui.build_page=="logistics" and ui.game.recorded("first_sawmill"):
		var row=ui._row();ui._button(row,"컨베이어 연결",func():ui.world_tools.begin("route"));ui._button(row,"부지 정리",func():ui.world_tools.begin("clear"))
	var values=Opening.catalog(ui.game,ui.catalog_all and not ui.game.state.entities.is_empty())
	if ui.build_page=="logistics":values=values.filter(func(k):return k in ["belt","splitter","warehouse","market"])
	var limit=2 if ui.build_page=="logistics" else 4
	var shown=items(ui,"build",values,limit);var g=grid(ui)
	for kind in shown:
		var k=kind;var f=ui.game.data.facilities[k];var known=ui.game.unlocked(k)
		tile(ui,g,f.name if known else "?",ui._cost(k) if known else "",k if known else "icon_unknown",func():ui.build_kind=k;ui.map.building=k;ui.sheet_fraction=0;ui._layout(),not known)
	if ui.game.state.entities.is_empty():return
	pager(ui,"build",values.size(),limit,"주요" if ui.catalog_all else "전체",func():ui.catalog_all=not ui.catalog_all;ui.pages.build=0;ui._rebuild())
static func inventory(ui):
	tabs(ui,[[false,"재고"],[true,"판매 설정"]],ui.inventory_details,func(value):ui.inventory_details=value;ui._rebuild())
	var resources=ui.game.data.resources.keys().filter(func(r):return ui.game.known_resource(r))
	var limit=2 if ui.inventory_details else 4
	var shown=items(ui,"inventory",resources,limit)
	if ui.inventory_details:
		for value in shown:
			var r=value;var row=ui._row();picture(ui,row,"item_"+r);ui._spacer(row)
			var selector=OptionButton.new();selector.custom_minimum_size=Vector2(140,48)*ui.scale_ui;row.add_child(selector)
			var choices=[0,20,50,100,200,500,1000,-1]
			if ui.game.state.factory.reserves[r] not in choices:choices.append(ui.game.state.factory.reserves[r])
			for n in choices:selector.add_item("판매 안 함" if n==-1 else "%d개 보관"%n)
			selector.select(choices.find(ui.game.state.factory.reserves[r]));selector.item_selected.connect(func(i):ui._command({"type":"setReserve","resource":r,"quantity":choices[i]}))
	else:
		var g=grid(ui)
		for value in shown:
			var r=value;var cell=HBoxContainer.new();cell.custom_minimum_size.y=40*ui.scale_ui;cell.size_flags_horizontal=Control.SIZE_EXPAND_FILL;g.add_child(cell)
			picture(ui,cell,"item_"+r);ui._spacer(cell);ui._bind_label(cell,func():return ui.game.money(ui.game.stock(r)))
	pager(ui,"inventory",resources.size(),limit,"주문" if Opening.feature(ui.game,"trade") else "",func():ui.show_tab("trade"))
static func records(ui):
	ui._label(ui.body,"누적 수입 ₩ "+ui.game.money(ui.game.state.totals.earned))
	var entries=ui.game.state.records.duplicate();entries.reverse()
	for entry in items(ui,"records",entries,4):
		var text=entry.type
		if text.begins_with("first_"):text=ui.game.data.facilities.get(text.trim_prefix("first_"),{}).get("name",{"first_automation":"첫 자동화","first_power":"첫 전력 생산","first_auto_sale":"첫 자동 판매","first_shipment":"첫 주문 출하","first_launch":"첫 로켓 발사","first_clearing":"첫 부지 정리","first_route":"첫 컨베이어 연결"}.get(text,text))
		if text.begins_with("complete_"):text=ui.game.data.facilities.get(text.trim_prefix("complete_"),{}).get("name","도시 건물")+" 완공"
		if text=="open_world":text="큰 월드 이전"
		if text.begins_with("stage_"):text=ui.game.data.stageNames[ui.game.data.stages.find(text.trim_prefix("stage_"))]
		var label=ui._label(ui.body,"%d분 · %s"%[floor(entry.atS/60),text]);label.clip_text=true;label.custom_minimum_size.y=28*ui.scale_ui
	pager(ui,"records",entries.size())
static func industry(ui):
	tabs(ui,[["research","연구"],["city","도시"]],ui.industry_page,func(value):ui.industry_page=value;ui._rebuild())
	if ui.industry_page=="research":
		if not ui.game.state.unlocks.get("smelting",false) and ui.game.stage_index()>=1:
			var row=ui._row()
			for value in ["copper","stone","coal"]:
				var r=value;var n=20 if r=="copper" else ui.game.data.research.materials[r]
				picture(ui,row,"item_"+r);ui._bind_label(row,func():return "%d/%d"%[mini(n,ui.game.produced(r) if r=="copper" else ui.game.stock(r)),n])
			ui._action("제련 · ₩ "+ui.game.money(ui.game.data.research.cash),{"type":"research","kind":"smelting"},ui.game.produced("copper")<20 or not ui.game.affordable(ui.game.data.research.cash,ui.game.data.research.materials))
		else:ui._label(ui.body,"방치 생산 · 최대 2시간" if ui.game.state.unlocks.offline else "?")
		return
	var values=ui.game.data.projects.keys().filter(func(k):return ui.game.unlocked(k));var shown=items(ui,"city",values);var g=grid(ui)
	for value in shown:
		var k=value;tile(ui,g,ui.game.data.facilities[k].name,ui._project_effect(k),k,func():ui.show_tab("build");ui.build_kind=k;ui.map.building=k;ui.sheet_fraction=0;ui._layout())
	pager(ui,"city",values.size())
static func trade(ui):
	var t=ui.game.trade()
	tabs(ui,[["offers","주문"],["active","진행"]],ui.trade_page,func(value):ui.trade_page=value;ui._rebuild())
	if ui.trade_page=="active":
		ui._label(ui.body,"출하 %d회 · ₩ %s"%[t.completed,ui.game.money(t.rewardEarned)])
		if t.active!=null:
			var a=t.active;ui._label(ui.body,"%s × %d"%[ui._resource_name(a.resource),a.quantity])
			ui._bind_label(ui.body,func():return "납품 %d초"%ceil(a.departureS) if a.loaded==a.quantity else "상차 %d / %d"%[a.loaded,a.quantity])
			ui._action("주문 취소",{"type":"cancelOrder"})
		if t.lastOfferId!=null:
			var repeat=CheckButton.new();repeat.text="자동 반복";repeat.button_pressed=t.repeat;repeat.custom_minimum_size.y=48*ui.scale_ui;ui.body.add_child(repeat);repeat.toggled.connect(func(value):ui._command({"type":"setTradeRepeat","enabled":value}))
		return
	var values=ui.game.offers();var shown=items(ui,"offers",values);var g=grid(ui)
	for offer in shown:
		var q=offer
		var b=tile(ui,g,ui._resource_name(q.resource)+" × %d"%q.quantity,"₩ "+ui.game.money(q.reward),"item_"+q.resource,func():ui.trade_page="active";ui._command({"type":"takeOrder","offerId":q.id}),t.active!=null or t.cooldownS>0)
		b.set_meta("offer",true)
	pager(ui,"offers",values.size())
