extends Control
const Factory=preload("res://scripts/core/factory.gd")
const SaveStore=preload("res://scripts/core/save_store.gd")
const CityMap=preload("res://scripts/ui/city_map.gd")
const World=preload("res://scripts/core/world_map.gd")
const WorldTools=preload("res://scripts/ui/world_tools.gd")
const Overview=preload("res://scripts/ui/world_overview.gd")
const Art=preload("res://scripts/ui/pixel_art.gd")
var game=Factory.new()
var store=SaveStore.new()
var map
var world_tools
var overview
var header: Control
var wallet: Panel
var cash_label: Label
var income_label: Label
var stage_label: Label
var sheet: Panel
var handle: Button
var scroll: ScrollContainer
var body: VBoxContainer
var nav: HBoxContainer
var map_buttons: VBoxContainer
var toast_label: Label
var scale_ui=1.0
var sheet_fraction=0.0
var tab="map"
var selected="e1"
var selected_tile=Vector2i.ZERO
var build_kind=""
var bindings=[]
var layout_signature=""
var busy=false
var visible_game=true
var allow_save=true
var last_save=0
var toast_until=0
var paused_at=0.0
var drag_sheet=false
var drag_start=0.0
var drag_initial=0.0
var drag_moved=false
var import_callback
var dialog: ConfirmationDialog
var pending_action: Callable
var auto_checks=false

func _ready():
	auto_checks="--ui-check" in OS.get_cmdline_user_args()
	var skin=Theme.new()
	skin.default_font=load("res://assets/fonts/RustCity.otf")
	theme=skin
	map=CityMap.new();map.game=game;add_child(map);map.tile_pressed.connect(_tile)
	world_tools=WorldTools.new(self)
	overview=Overview.new();overview.game=game;overview.city=map;add_child(overview);overview.point_selected.connect(func(p):map.focus_point(p))
	header=Control.new();header.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(header)
	wallet=Panel.new();wallet.mouse_filter=Control.MOUSE_FILTER_IGNORE;header.add_child(wallet)
	cash_label=Label.new();cash_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;wallet.add_child(cash_label)
	income_label=Label.new();income_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;wallet.add_child(income_label)
	stage_label=Label.new();stage_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;wallet.add_child(stage_label)
	var warehouse=_floating_button(header,"창고","inventory",func():show_tab("inventory"));warehouse.name="WarehouseButton"
	sheet=Panel.new();add_child(sheet)
	handle=_button(sheet,"",func():
		if not drag_moved:sheet_fraction=0.48 if sheet_fraction==0 else 0.0;_layout())
	handle.gui_input.connect(_sheet_input)
	scroll=ScrollContainer.new();sheet.add_child(scroll);scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	body=VBoxContainer.new();body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(body)
	nav=HBoxContainer.new();nav.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(nav)
	for item in [["settings","관리"],["records","기록"],["industry","산업"],["build","건설"],["map","지도"]]:
		var id=item[0]
		var button=_floating_button(nav,item[1],id,func():show_tab(id));button.set_meta("tab",id);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	map_buttons=VBoxContainer.new();map_buttons.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(map_buttons)
	_icon_button(map_buttons,"plus",func():map.zoom_by(0.15))
	_icon_button(map_buttons,"minus",func():map.zoom_by(-0.15))
	_icon_button(map_buttons,"home",func():map.focus_district())
	toast_label=Label.new();toast_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;add_child(toast_label)
	dialog=ConfirmationDialog.new();dialog.title="Rust City";add_child(dialog);dialog.confirmed.connect(func():if pending_action.is_valid():pending_action.call())
	resized.connect(_resize_layout)
	_layout();_focus_city();_rebuild()
	if not auto_checks:
		var saved=store.load_city()
		if not saved.is_empty():
			game.state=saved.state
			await _catch_up(maxf(0,Time.get_unix_time_from_system()-saved.savedAtMs/1000.0))
		elif not store.last_error.is_empty():allow_save=false;message(store.last_error)
		_focus_city();_rebuild();_layout();_save()
	else:
		await get_tree().process_frame
		await _ui_test()

func _focus_city():
	var e=game.state.entities.get(selected,game.state.entities.e1)
	selected_tile=Vector2i(int(e.x),int(e.y));map.selection=selected_tile
	game.invalidate_index();game.clear_effects();world_tools.reset();map.focus_district()

func _resize_layout():
	_layout();_rebuild()
	# Theme and container minimum sizes settle on the next frame after rotation.
	await get_tree().process_frame
	_layout();map.focus_district()
	await get_tree().process_frame
	for b in nav.get_children():_size_floating_button(b,scale_ui)

func _box(color:Color,radius=10) -> StyleBoxFlat:
	var box=StyleBoxFlat.new();box.bg_color=color;box.border_color=Color("8c9470")
	box.set_border_width_all(maxi(1,int(2*scale_ui)));box.set_corner_radius_all(int(radius*scale_ui))
	box.content_margin_left=12*scale_ui;box.content_margin_right=12*scale_ui
	box.shadow_color=Color("344a3b32");box.shadow_size=int(3*scale_ui);box.shadow_offset=Vector2(0,4)*scale_ui
	return box
func _button(parent,text,action:Callable) -> Button:
	var b=Button.new();b.text=text;b.custom_minimum_size=Vector2(48,48)*scale_ui;b.pressed.connect(func():action.call_deferred());parent.add_child(b);return b
func _icon_button(parent,icon,action:Callable) -> Button:
	var b=_button(parent,"",action);b.set_meta("icon",icon)
	var picture=TextureRect.new();picture.texture=Art.texture("icon_"+icon);picture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
	b.add_child(picture);picture.name="PixelIcon"
	b.resized.connect(func():_size_floating_button(b,scale_ui,b.has_node("Caption")))
	b.tooltip_text={"plus":"확대","minus":"축소","home":"산림으로"}.get(icon,"")
	return b
func _floating_button(parent,text,icon,action:Callable) -> Button:
	var b=_icon_button(parent,icon,action)
	var label=Label.new();label.name="Caption";label.text=text;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.mouse_filter=Control.MOUSE_FILTER_IGNORE;b.add_child(label)
	b.tooltip_text=text
	return b
func _size_floating_button(b:Button,u:float,caption=true):
	var icon=b.get_node("PixelIcon")
	icon.position=Vector2(0,5 if caption else 0)*u
	icon.size=Vector2(b.size.x,32*u if caption else b.size.y)
	if caption:
		var label=b.get_node("Caption");label.position=Vector2(0,36)*u;label.size=Vector2(b.size.x,22*u);label.add_theme_font_size_override("font_size",int(12*u))
func _label(parent,text="",large=false) -> Label:
	var l=Label.new();l.text=text;l.add_theme_font_size_override("font_size",int((20 if large else 14)*scale_ui));parent.add_child(l);return l
func _bind_label(parent,get_text:Callable,large=false) -> Label:
	var label=_label(parent,str(get_text.call()),large);bindings.append(func():if is_instance_valid(label):label.text=str(get_text.call()));return label
func _row() -> HBoxContainer:
	var row=HBoxContainer.new();row.add_theme_constant_override("separation",int(10*scale_ui));body.add_child(row);return row
func _section(text):
	var l=_label(body,text);l.add_theme_color_override("font_color",Color("84906f"));l.custom_minimum_size.y=36*scale_ui;l.vertical_alignment=VERTICAL_ALIGNMENT_BOTTOM
func _cost(f) -> String:
	var text="₩ "+Factory.money(f.cost)
	for r in f.materials:text+=" · "+_resource_name(r)+" %d"%f.materials[r]
	return text
func _resource_name(r) -> String: return game.data.resources[r].name if game.known_resource(r) else "?"
func _spacer(row):
	var spacer=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(spacer)
func _action(text,c:Dictionary,disabled=false):
	var row=_row();_spacer(row);var b=_button(row,text,func():_command(c));b.disabled=disabled;return b
func _error(code) -> String:
	return {"LOCKED":"아직 잠겨 있어요.","INSUFFICIENT_CASH":"돈이 부족해요.","INSUFFICIENT_RESOURCE":"도시 자재가 부족해요.","OCCUPIED":"이미 시설이 있어요.","PROTECTED":"시작 생산라인은 보존해요.","BLOCKED":"나무나 광맥이 길을 막고 있어요.","RESOURCE_REQUIRED":"시설에 맞는 숲이나 광맥을 선택해 주세요.","TOO_LARGE":"작업 범위를 256칸 이내로 줄여 주세요.","EMPTY":"정리하거나 연결할 대상이 없어요.","WRONG_PORT":"도착 시설의 출구 쪽이에요. 방향을 바꿔 주세요."}.get(code,"위치와 연결을 다시 확인해 주세요.")
func _command(c):
	if busy:return
	var result=game.command(c)
	if result!="OK":message(_error(result));return
	if c.get("type")=="build":selected=game.at(c.x,c.y).get("id","")
	_save();_rebuild()
func message(text):
	toast_label.text=text;toast_until=Time.get_ticks_msec()+3500;_layout()
func confirm(text,action:Callable):
	pending_action=action;dialog.dialog_text=text;dialog.get_ok_button().text="확인";dialog.get_cancel_button().text="취소";dialog.popup_centered(Vector2i(int(330*scale_ui),int(170*scale_ui)))

func _layout():
	if not is_node_ready() or header==null:return
	var physical=DisplayServer.window_get_size()
	if OS.has_feature("web"):
		physical=Vector2i(int(JavaScriptBridge.eval("window.innerWidth")),int(JavaScriptBridge.eval("window.innerHeight")))
	if physical.x<2 or physical.y<2:physical=Vector2i(size)
	scale_ui=size.x/maxf(1,physical.x)
	var u=scale_ui
	theme.default_font_size=int(14*u)
	for type in ["Button","OptionButton"]:
		theme.set_stylebox("normal",type,_box(Color("fff2cf")))
		theme.set_stylebox("hover",type,_box(Color("fff8e1")))
		theme.set_stylebox("pressed",type,_box(Color("dbe8b5")))
		theme.set_stylebox("disabled",type,_box(Color("e5e5c3")))
		for state in ["font_color","font_hover_color","font_pressed_color"]:theme.set_color(state,type,Color("414b38"))
		theme.set_color("font_disabled_color",type,Color("969b80"))
		var focus=_box(Color.TRANSPARENT);focus.border_color=Color("b58d4f");focus.shadow_size=0;theme.set_stylebox("focus",type,focus)
	theme.set_color("font_color","Label",Color("414b38"))
	map.position=Vector2.ZERO;map.size=size;map.tile_size=96*u
	overview.visible=game.world_mode();overview.position=Vector2(16,114)*u;overview.size=Vector2(94,94)*u
	header.position=Vector2.ZERO;header.size=size
	wallet.position=Vector2(16,16)*u;wallet.size=Vector2(214,86)*u;wallet.add_theme_stylebox_override("panel",_box(Color("fff2cf"),12))
	cash_label.position=Vector2(14,24)*u;cash_label.add_theme_font_size_override("font_size",int(28*u))
	income_label.position=Vector2(14,62)*u;income_label.add_theme_font_size_override("font_size",int(10*u))
	stage_label.position=Vector2(14,8)*u;stage_label.add_theme_font_size_override("font_size",int(10*u))
	var warehouse=header.get_node("WarehouseButton");warehouse.custom_minimum_size=Vector2(64,64)*u
	warehouse.position=Vector2(size.x-80*u,16*u);warehouse.size=Vector2(64,64)*u;_size_floating_button(warehouse,u)
	var dock_width=minf(384*u,size.x-32*u)
	nav.add_theme_constant_override("separation",int(8*u))
	for child in nav.get_children():child.custom_minimum_size=Vector2(48,64)*u
	nav.position=Vector2((size.x-dock_width)/2,size.y-84*u);nav.size=Vector2(dock_width,64*u)
	for child in nav.get_children():_size_floating_button(child,u)
	var width=minf(430*u,size.x-32*u) if sheet_fraction>0 else minf(234*u,size.x-32*u)
	var available=maxf(56*u,size.y-216*u)
	var height=56*u if sheet_fraction==0 else clampf(available*sheet_fraction,minf(180*u,available),available)
	sheet.position=Vector2(size.x-width-16*u,nav.position.y-height-16*u);sheet.size=Vector2(width,height)
	sheet.add_theme_stylebox_override("panel",_box(Color("fff5d9"),12))
	handle.custom_minimum_size=Vector2(48,48)*u;handle.position=Vector2.ZERO;handle.size=Vector2(width,56*u)
	for state in ["normal","hover","pressed","focus"]:handle.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	scroll.position=Vector2(14,60)*u;scroll.size=Vector2(width-28*u,maxf(0,height-74*u));scroll.visible=sheet_fraction>0
	body.add_theme_constant_override("separation",int(10*u))
	map_buttons.add_theme_constant_override("separation",int(8*u))
	for b in map_buttons.get_children():b.custom_minimum_size=Vector2(48,48)*u
	map_buttons.position=Vector2(size.x-64*u,sheet.position.y-176*u);map_buttons.size=Vector2(48,160)*u;map_buttons.visible=sheet_fraction==0
	for b in map_buttons.get_children():_size_floating_button(b,u,false)
	toast_label.position=Vector2(16,116)*u;toast_label.size=Vector2(size.x-32*u,44*u);toast_label.add_theme_font_size_override("font_size",int(13*u))
	_layout_title()
func _sheet_input(e):
	if e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT:
		if e.pressed:drag_sheet=true;drag_moved=false;drag_start=get_global_mouse_position().y;drag_initial=sheet.size.y
		else:drag_sheet=false
	if e is InputEventMouseMotion and drag_sheet:
		var dy=drag_start-get_global_mouse_position().y
		if abs(dy)>6*scale_ui:
			drag_moved=true
			sheet_fraction=clampf((drag_initial+dy)/maxf(1,size.y-216*scale_ui),0.0,0.8)
			if sheet_fraction<0.2:sheet_fraction=0
			_layout()
func _layout_title():
	var labels={"inventory":"도시 창고","trade":"주문 출하","industry":"산업과 확장","build":"시설 건설","records":"도시 기록","settings":"도시 관리"}
	var e=game.state.entities.get(selected,{})
	handle.text=(game.data.facilities[e.kind].name if not e.is_empty() else "빈 건설 부지") if tab=="map" else labels.get(tab,"")
	if tab=="build" and not build_kind.is_empty():handle.text=game.data.facilities[build_kind].name+" 배치"
	if world_tools!=null and not world_tools.mode.is_empty():handle.text=world_tools.title()
	handle.text+="   ↑" if sheet_fraction==0 else "   ↓"
	for b in nav.get_children():
		var active=b.get_meta("tab")==tab
		b.add_theme_stylebox_override("normal",_box(Color("e2b86b") if active else Color("fff2cf")))
func show_tab(value):
	world_tools.reset();build_kind="";tab=value;sheet_fraction=0 if tab=="map" else 0.48;_rebuild();_layout()
func _build_at(kind,tile):
	confirm(game.data.facilities[kind].name+" 건설\n"+_cost(game.data.facilities[kind]),func():
		var result=game.command({"type":"build","kind":kind,"x":tile.x,"y":tile.y})
		if result=="OK":
			selected=game.at(tile.x,tile.y).id;tab="map";build_kind="";sheet_fraction=0.56;_save();_rebuild();_layout()
		else:message(_error(result)))
func _tile(tile):
	if game.world_mode() and not game.owned(tile.x,tile.y):return
	if not game.world_mode() and (tile.x<0 or tile.y<0 or tile.x>=18 or tile.y>=12):return
	selected_tile=tile;map.selection=tile
	if game.world_mode() and world_tools.handle_tile(tile):return
	var e=game.at(tile.x,tile.y)
	if tab=="build" and not build_kind.is_empty() and e.is_empty() and game.owned(tile.x,tile.y):_build_at(build_kind,tile);return
	selected=e.get("id","");tab="map";sheet_fraction=0.56;_rebuild();_layout()

func _signature() -> String:
	var value=game.state.stage+str(game.recorded("first_auto_sale"))
	for kind in game.data.facilities:value+=str(game.unlocked(kind))
	for r in game.data.resources:value+=str(game.known_resource(r))
	if not game.world_mode():
		for id in game.data.districts:value+=str(game.district_known(id))
	value+=str(game.produced("copper")>=20)
	if tab=="trade":value+=str(game.trade().active!=null)+str(game.trade().completed)+str(game.trade().cooldownS<=0)
	return value
func _rebuild():
	if body==null:return
	var previous=scroll.scroll_vertical
	bindings=[]
	for child in body.get_children():body.remove_child(child);child.queue_free()
	layout_signature=_signature()
	match tab:
		"map":_facility()
		"build":_build_list()
		"inventory":_inventory()
		"trade":_trade_panel()
		"industry":_industry()
		"records":_records()
		"settings":_settings()
		"work":world_tools.panel()
	scroll.set_deferred("scroll_vertical",previous)
	_layout_title();_refresh()
func _facility():
	var e=game.state.entities.get(selected,{})
	if e.is_empty():
		if game.world_mode():world_tools.tile_panel();return
		var id=game.district_at(selected_tile.x,selected_tile.y)
		if not id.is_empty():_district(id)
		_button(body,"시설 건설",func():show_tab("build"))
		return
	_bind_label(body,func():return game.status(e))
	var f=game.recipe(e)
	if f.cycle>0 and e.kind!="generator":
		_label(body,_stock_text(f.input)+"  →  "+_stock_text(f.output))
		var progress=ProgressBar.new();progress.custom_minimum_size.y=8*scale_ui;progress.show_percentage=false;body.add_child(progress)
		bindings.append(func():if is_instance_valid(progress):progress.value=clampf(1-e.job.remaining/f.cycle,0,1)*100 if e.job!=null else 0)
	_action("생산 재개" if e.paused else "잠시 쉬기",{"type":"pause","entityId":e.id})
	if not game.is_project(e.kind):
		var row=_row();_spacer(row)
		for i in range(4):
			var direction=i
			_button(row,["↑","→","↓","←"][i],func():_command({"type":"rotate","entityId":e.id,"direction":direction}))
		_section("내부 재고")
		var resources=game.data.resources.keys().filter(func(r):return game.known_resource(r)) if e.kind in ["warehouse","market","belt","splitter"] else (f.input.keys()+f.output.keys())
		for r in resources:
			var resource=r
			var row_stock=_row();_label(row_stock,_resource_name(resource));_spacer(row_stock)
			_bind_label(row_stock,func():return str(int(e.inputs.get(resource,0)+e.outputs.get(resource,0)+e.queue.count(resource)+e.get("inventory",{}).get(resource,0))))
	if e.kind=="mine" and not game.world_mode():_choice("채굴할 광물",["stone","coal","copper","iron"],e.mineResourceId,func(r):_command({"type":"setMineResource","entityId":e.id,"resource":r}))
	if e.kind=="warehouse":
		if game.world_mode():
			var selling=CheckButton.new();selling.text="자동 판매";selling.button_pressed=e.autoSell;selling.custom_minimum_size.y=48*scale_ui;body.add_child(selling)
			selling.toggled.connect(func(value):_command({"type":"setWarehouseSales","entityId":e.id,"enabled":value}))
		_choice("컨베이어로 출고",[""]+game.data.resources.keys(),e.get("dispatchResource",""),func(r):_command({"type":"configureWarehouse","entityId":e.id,"resource":null if r=="" else r}))
		_button(body,"도시 재고 / 주문",func():show_tab("inventory"))
	if e.kind=="market":
		for r in game.data.resources:
			var resource=r
			var check=CheckButton.new();check.text=_resource_name(r);check.button_pressed=e.saleFilters[r];check.disabled=not game.known_resource(r);check.custom_minimum_size.y=48*scale_ui;body.add_child(check)
			check.toggled.connect(func(value):_command({"type":"setFilters","entityId":e.id,"filters":{resource:value}}))
	if game.is_project(e.kind):
		var definition=game.data.projects[e.kind]
		_label(body,_project_effect(e.kind))
		for r in definition.materials:
			var resource=r
			_bind_label(body,func():return "%s %d / %d"%[_resource_name(resource),e.project.materials.get(resource,0),definition.materials[resource]])
		_bind_label(body,func():return "완공" if e.project.complete else ("운송 대기 · 공사 %d초" if game.world_mode() else "자동 조달 · 공사 %d초")%ceil(e.project.remainingS))
	elif e.kind=="launchpad":
		for r in game.data.rocket:
			var resource=r
			_bind_label(body,func():return "%s %d / %d"%[_resource_name(resource),game.state.rocket.delivered.get(resource,0),game.data.rocket[resource]])
		_action("로켓 발사",{"type":"launch"},bool(game.state.rocket.launched))
	else:
		if game.income_facility(e):
			_section(("판매 단가" if game.world_mode() else "운영 수익")+" · %d / 10"%e.get("incomeLevel",0))
			if game.world_mode():_label(body,"+%d%%"%round(e.get("incomeLevel",0)*12))
			else:_label(body,"₩ %s / 생산 완료"%Factory.money(game.income_per_batch(e)))
			var level=int(e.get("incomeLevel",0))
			_action("수익 개선 · ₩ "+Factory.money(f.incomeCosts[mini(level,9)]),{"type":"upgradeIncome","entityId":e.id},level>=10)
		if e.kind not in ["belt","splitter","launchpad"]:
			_section("매니저" if game.recorded("first_auto_sale") else "?")
			var level=int(e.get("managerLevel",0))
			_action(("교육" if level>0 else "배치")+" · ₩ "+Factory.money(f.managerCosts[mini(level,2)])+" · 판자 3",{"type":"upgradeManager","entityId":e.id},level>=3 or not game.recorded("first_auto_sale"))
		_section("생산 개선 · Lv.%d"%e.level)
		if f.cycle>0:_label(body,"%.2f초 → %.2f초"%[f.cycle/game.speed(e),f.cycle/(game.speed(e)+0.12)])
		_action("생산 개선 · ₩ "+Factory.money(f.upgradeCosts[int(e.level)-1]),{"type":"upgrade","entityId":e.id},e.level>=f.maxLevel)
	var row=_row();_spacer(row)
	var demolish=_button(row,"철거",func():confirm("시설을 철거하고 내부 재고와 투자금의 50%를 돌려받아요.",func():_command({"type":"demolish","entityId":e.id})))
	demolish.disabled=e.id in ["e1","e2","e3"] or e.get("starter",false)
func _stock_text(values) -> String:
	var names=[]
	for r in values:names.append(_resource_name(r)+" %d"%values[r])
	return " · ".join(names) if not names.is_empty() else "원료"
func _choice(title,resources,current,action:Callable):
	_section(title)
	var option=OptionButton.new();option.custom_minimum_size.y=48*scale_ui;body.add_child(option)
	for i in range(resources.size()):
		var r=resources[i];option.add_item("출고 안 함" if r=="" else _resource_name(r));option.set_item_disabled(i,r!="" and not game.known_resource(r))
		if r==current or (current==null and r==""):option.select(i)
	option.item_selected.connect(func(index):action.call(resources[index]))
func _build_list():
	if game.world_mode():
		var row=_row();_spacer(row)
		_button(row,"컨베이어 연결",func():world_tools.begin("route"))
		_button(row,"부지 정리",func():world_tools.begin("clear"))
	for kind in game.data.facilities:
		var id=kind;var f=game.data.facilities[kind];var known=game.unlocked(kind)
		var text=f.name+"\n"+_cost(f) if known else "?"
		if known and game.is_project(kind):text+="\n"+_stock_text(game.data.projects[kind].materials)
		var button=_button(body,text,func():build_kind=id;map.building=id;sheet_fraction=0;_layout())
		button.disabled=not known;button.alignment=HORIZONTAL_ALIGNMENT_RIGHT
func _inventory():
	if game.world_mode():_section("도시 자재 · 창고 합계")
	_button(body,"주문 출하 →",func():show_tab("trade"))
	for r in game.data.resources:
		var resource=r;var row=_row();_label(row,_resource_name(r));_spacer(row);_bind_label(row,func():return str(int(game.stock(resource))) if game.known_resource(resource) else "?")
		var selector=OptionButton.new();selector.custom_minimum_size=Vector2(125,48)*scale_ui;row.add_child(selector)
		var choices=[0,20,50,100,200,500,1000,-1]
		if game.state.factory.reserves[r] not in choices:choices.append(game.state.factory.reserves[r])
		for i in range(choices.size()):selector.add_item("판매 안 함" if choices[i]==-1 else "%d개 보관"%choices[i]);selector.set_item_metadata(i,choices[i])
		for i in range(choices.size()):
			if choices[i]==game.state.factory.reserves[r]:selector.select(i)
		selector.disabled=not game.known_resource(r)
		selector.item_selected.connect(func(index):_command({"type":"setReserve","resource":resource,"quantity":selector.get_item_metadata(index)}))
func _trade_panel():
	var t=game.trade();var active=t.active
	_button(body,"← 창고",func():show_tab("inventory"))
	_bind_label(body,func():return "출하 %d회 · ₩ %s"%[t.completed,Factory.money(t.rewardEarned)])
	if t.lastOfferId!=null:
		var repeat=CheckButton.new();repeat.text="같은 주문 자동 반복";repeat.button_pressed=t.repeat;repeat.custom_minimum_size.y=48*scale_ui;body.add_child(repeat);repeat.toggled.connect(func(value):_command({"type":"setTradeRepeat","enabled":value}))
	if active!=null:
		_label(body,"%s %d개 · ₩ %s"%[_resource_name(active.resource),active.quantity,Factory.money(active.reward)],true)
		_bind_label(body,func():return "납품 %d초"%ceil(active.departureS) if active.loaded==active.quantity else "상차 %d / %d · 재고 대기 %d"%[active.loaded,active.quantity,active.quantity-active.loaded-active.reserved])
		_action("출하 취소 · 재고 반환",{"type":"cancelOrder"})
	else:_bind_label(body,func():return "다음 주문 %d초"%ceil(t.cooldownS) if t.cooldownS>0 else "초과 재고 자동 상차")
	for offer in game.offers():
		var quote=offer
		_action("%s %d개 · ₩ %s"%[_resource_name(quote.resource),quote.quantity,Factory.money(quote.reward)],{"type":"takeOrder","offerId":quote.id},active!=null or t.cooldownS>0)
func _district(id):
	if not game.district_known(id):_label(body,"?");return
	var d=game.data.districts[id];var n=game.state.districts[id].size;var offer=game.expansion(id)
	_label(body,d.name+" %d×%d"%[n,n],true)
	if n<6:_action("확장 · ₩ "+Factory.money(offer.cash),{"type":"expand","districtId":id})
	_button(body,"지도에서 보기",func():map.focus_district(id);show_tab("map"))
func _project_effect(kind):
	return "판매 단가 +25%" if game.world_mode() and kind=="cabin" else game.data.projects[kind].effect
func _industry():
	if not game.state.unlocks.get("smelting",false):_action("제련 연구 · ₩ "+Factory.money(game.data.research.cash) if game.stage_index()>=1 else "?",{"type":"research","kind":"smelting"},game.produced("copper")<20)
	if game.world_mode():_label(body,"128 × 128")
	else:
		for id in game.data.districts:
			if game.district_known(id):_district(id)
			else:_label(body,"?")
	_section("도시 건설")
	for kind in game.data.projects:
		var id=kind;var enabled=game.unlocked(id)
		var button=_button(body,game.data.facilities[id].name+" · "+_project_effect(id) if enabled else "?",func():show_tab("build");build_kind=id;sheet_fraction=0;_layout())
		button.disabled=not enabled
	_label(body,"방치 생산 · 최대 2시간" if game.state.unlocks.offline else "?")
func _records():
	_label(body,"누적 수입 ₩ "+Factory.money(game.state.totals.earned),true)
	_label(body,"도시 가동 %d분"%floor(game.state.clock.elapsedS/60))
	var entries=game.state.records.duplicate();entries.reverse()
	for entry in entries:
		var text=entry.type
		if text.begins_with("first_"):text=game.data.facilities.get(text.trim_prefix("first_"),{}).get("name",{"first_automation":"첫 자동화","first_power":"첫 전력 생산","first_auto_sale":"첫 자동 판매","first_shipment":"첫 주문 출하","first_launch":"첫 로켓 발사","first_clearing":"첫 부지 정리","first_route":"첫 컨베이어 연결"}.get(text,text))
		if text.begins_with("complete_"):text=game.data.facilities.get(text.trim_prefix("complete_"),{}).get("name","도시 건물")+" 완공"
		if entry.type=="open_world":text="큰 월드 이전"
		if entry.type.begins_with("stage_"):text=game.data.stageNames[game.data.stages.find(entry.type.trim_prefix("stage_"))]
		_label(body,"%d분  %s"%[floor(entry.atS/60),text])
func _settings():
	if not game.world_mode():
		_button(body,"큰 월드로 이전",func():confirm("자금·시설·재고를 보존해 큰 월드로 이전해요. 공장 원료는 실제 운송망을 통해 공급해요.",func():_save();_command({"type":"migrateWorld"});_focus_city();show_tab("map")))
	_label(body,"이 브라우저 / 기기에 자동 저장")
	_button(body,"백업 내보내기",_export_backup)
	_button(body,"웹 도시 / Godot 백업 불러오기",_import_backup)
	_button(body,"새 도시 시작",func():confirm("현재 Godot 도시를 새로 시작해요. 백업을 먼저 보관해 주세요.",func():game.fresh();selected="e1";allow_save=true;_save();show_tab("map");_focus_city()))
func _refresh():
	cash_label.text="₩ "+Factory.money(game.state.cash)
	stage_label.text="RUST CITY · "+game.data.stageNames[game.stage_index()]
	var earned=0.0
	for sale in game.state.recentSales:earned+=sale.cash
	income_label.text="₩ %s / 분"%Factory.money(earned*60/maxf(1,minf(60,game.state.clock.elapsedS)))
	if game.stage_index()>=3:income_label.text+="   전력 %.0f / %.0f"%[game.state.power.generation,game.state.power.demand]
	for binding in bindings:binding.call()
	_layout_title()
func _process(delta):
	if game==null or header==null:return
	if not busy and visible_game and not auto_checks:
		var previous=game.state.clock.tickIndex
		game.advance(minf(1,delta))
		if previous!=game.state.clock.tickIndex:
			map.record_transfers();_refresh()
			var signature=_signature()
			if signature!=layout_signature:_rebuild()
		if Time.get_ticks_msec()-last_save>10000:_save()
	toast_label.visible=Time.get_ticks_msec()<toast_until
func _save():
	last_save=Time.get_ticks_msec()
	if allow_save and not auto_checks and not store.save(game):message(store.last_error)
func _catch_up(seconds):
	if not game.state.unlocks.offline:return
	busy=true
	var duration=minf(seconds,7200)
	var total=duration+game.state.clock.carryS
	var ticks=int(floor(total/0.25+0.000000001))
	game.state.clock.carryS=maxf(0,total-ticks*0.25)
	for i in range(ticks):
		game.tick()
		if i%400==399:await get_tree().process_frame
	busy=false
	if duration>=60:message("도시가 %d분 동안 가동됐어요."%floor(duration/60))
func _notification(what):
	if not is_node_ready() or auto_checks:return
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		visible_game=false;paused_at=Time.get_unix_time_from_system();_save()
	if what==NOTIFICATION_APPLICATION_FOCUS_IN and not visible_game:
		visible_game=true
		if paused_at>0:await _catch_up(maxf(0,Time.get_unix_time_from_system()-paused_at));_rebuild();_save()
	if what==NOTIFICATION_WM_CLOSE_REQUEST:_save()
func _export_backup():
	var text=store.export_text(game)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(()=>{const b=new Blob(["+JSON.stringify(text)+"],{type:'application/json'});const u=URL.createObjectURL(b);const a=document.createElement('a');a.href=u;a.download='rust-city-backup.json';a.click();setTimeout(()=>URL.revokeObjectURL(u),1000)})()")
		message("백업을 내보냈어요.")
	else:
		var path="user://rust-city-backup.json";var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(text);DisplayServer.clipboard_set(text);message("백업을 복사했어요. "+ProjectSettings.globalize_path(path))
func _import_backup():
	if OS.has_feature("web"):
		import_callback=JavaScriptBridge.create_callback(func(args):_prepare_import(str(args[0])))
		JavaScriptBridge.get_interface("window").rustCityImport=import_callback
		JavaScriptBridge.eval("(()=>{const i=document.createElement('input');i.type='file';i.accept='.json,application/json';i.onchange=()=>{const f=i.files[0];if(f&&f.size<=2000000)f.text().then(t=>window.rustCityImport(t));};i.click()})()")
	else:
		var chooser=FileDialog.new();chooser.file_mode=FileDialog.FILE_MODE_OPEN_FILE;chooser.access=FileDialog.ACCESS_FILESYSTEM;chooser.filters=PackedStringArray(["*.json ; Rust City backup"]);add_child(chooser);chooser.file_selected.connect(func(path):_prepare_import(FileAccess.get_file_as_string(path));chooser.queue_free());chooser.popup_centered_ratio(0.7)
func _prepare_import(text):
	var snapshot=store.parse(text)
	if snapshot.is_empty():message(store.last_error);return
	confirm("백업 도시로 교체할까요? 현재 Godot 도시를 먼저 내보내 보관할 수 있어요.",func():game.state=snapshot.state;selected="e1";allow_save=true;await _catch_up(maxf(0,Time.get_unix_time_from_system()-snapshot.savedAtMs/1000.0));_save();show_tab("map");_focus_city())
func _ui_test():
	var before={}
	for child in body.get_children():
		if child is HBoxContainer:
			for node in child.get_children():
				if node is Button:before[node]=node.get_rect()
	for i in range(96):game.tick();_refresh()
	await get_tree().process_frame
	var ok=true
	for node in before:
		if node.get_rect()!=before[node]:ok=false
	game.fresh(0);game.advance(180)
	var t=game.trade();t.lastOfferId=game.offers()[0].id;t.cooldownS=1.0
	show_tab("trade")
	var previous_signature=layout_signature
	game.advance(1)
	ok=ok and _signature()!=previous_signature
	_rebuild()
	for row in body.get_children():
		if row is HBoxContainer:
			for node in row.get_children():
				if node is Button:ok=ok and not node.disabled
	game.state.totals.produced.plank=0
	show_tab("build");previous_signature=layout_signature
	game.state.totals.produced.plank=20
	ok=ok and _signature()!=previous_signature
	print("UI_CHECK "+("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
