extends RefCounted
const World=preload("res://scripts/core/world_map.gd")
var ui
var mode=""
var origin={}
var destination={}
var clearing=false
func _init(main):ui=main
func point(tile):return {"x":tile.x,"y":tile.y}
func reset():
	mode="";origin={};destination={};clearing=false
	ui.map.preview_path=[];ui.map.preview_clear=[];ui.map.preview_area=Rect2i();ui.map.work_origin=Vector2i(-1,-1)
func begin(value):
	reset();mode=value;ui.build_kind="";ui.tab="map";ui.sheet_fraction=0;ui._rebuild();ui._layout()
func title() -> String:
	var name="컨베이어" if mode=="route" else "부지 정리"
	return name+" · "+("시작 선택" if origin.is_empty() else "끝 선택") if destination.is_empty() else name
func handle_tile(tile) -> bool:
	if mode.is_empty():return false
	if origin.is_empty():
		origin=point(tile);ui.map.work_origin=tile;ui._layout_title();return true
	destination=point(tile);ui.tab="work";ui.sheet_fraction=0.48;ui._rebuild();ui._layout();_reveal();return true
func _reveal():
	var middle=Vector2(float(origin.x+destination.x+1),float(origin.y+destination.y+1))*0.5
	var target=Vector2(ui.size.x*0.5,(208*ui.scale_ui+ui.sheet.position.y)*0.5)
	ui.map.camera=(target-middle*ui.map.tile_size*ui.map.zoom).round();ui.map.clamp_camera();ui.map.queue_redraw()
func clear_one(tile):
	begin("clear");origin=point(tile);destination=point(tile);ui.tab="work";ui.sheet_fraction=0.48;ui._rebuild();ui._layout();_reveal()
func _preview(quote):
	ui.map.preview_path=quote.get("path",[]) if quote.ok else []
	ui.map.preview_clear=quote.clear if quote.ok else []
	ui.map.queue_redraw()
func _button(text,action,disabled=false):
	var row=ui._row();ui._spacer(row);var b=ui._button(row,text,action);b.disabled=disabled;return b
func _recovery(quote):
	if quote.clear.is_empty():return
	var trees=0
	for pos in quote.clear:
		if World.resource_at(ui.game.state.world,World.parse_key(pos).x,World.parse_key(pos).y)=="log":trees+=1
	ui._label(ui.body,"나무 %d · 광맥 %d"%[trees,quote.clear.size()-trees])
	ui._label(ui.body,"회수 · "+ui._stock_text(quote.reward))
func panel():
	var game=ui.game
	if mode=="clear":
		var q=World.clear_quote(game,origin,destination);_preview(q)
		var x=mini(int(origin.x),int(destination.x));var y=mini(int(origin.y),int(destination.y))
		ui.map.preview_area=Rect2i(x,y,abs(int(origin.x-destination.x))+1,abs(int(origin.y-destination.y))+1)
		if q.ok:
			_recovery(q);var pay=_button("정리 · ₩ "+game.money(q.cash),commit)
			ui.bindings.append(func():if is_instance_valid(pay):pay.disabled=game.state.cash<q.cash)
		else:ui._label(ui.body,ui._error(q.code))
	else:
		var avoiding=World.route_quote(game,origin,destination,false)
		var direct=World.route_quote(game,origin,destination,true)
		if not avoiding.ok and direct.ok:clearing=true
		if direct.ok and not direct.clear.is_empty():
			var row=ui._row();ui._spacer(row)
			ui._button(row,"우회",func():clearing=false;ui._rebuild()).disabled=not avoiding.ok
			ui._button(row,"정리",func():clearing=true;ui._rebuild())
		var q=direct if clearing else avoiding;_preview(q)
		if q.ok:
			ui._label(ui.body,"컨베이어 %d칸"%q.cells.size());_recovery(q)
			var pay=_button(("정리하고 연결" if not q.clear.is_empty() else "연결")+" · ₩ "+game.money(q.cash),commit)
			ui.bindings.append(func():if is_instance_valid(pay):pay.disabled=game.state.cash<q.cash)
		else:ui._label(ui.body,ui._error(q.code))
	_button("다시 선택",func():begin(mode))
	_button("취소",func():ui.show_tab("map"))
func commit():
	var command={"type":"clearArea" if mode=="clear" else "buildRoute","from":origin,"to":destination,"clear":clearing}
	var end=Vector2i(int(destination.x),int(destination.y))
	var result=ui.game.command(command)
	if result!="OK":ui.message(ui._error(result));ui._rebuild();return
	reset();ui.selected_tile=end;ui.map.selection=end;ui.selected=ui.game.at(end.x,end.y).get("id","")
	ui.tab="map";ui.sheet_fraction=0;ui._save();ui._rebuild();ui._layout()
func tile_panel():
	var tile=ui.selected_tile;var game=ui.game;var r=World.resource_at(game.state.world,tile.x,tile.y)
	if not r.is_empty():
		ui._label(ui.body,ui._resource_name(r),true)
		var kind="forest" if r=="log" else "mine"
		if game.known_resource(r) and game.unlocked(kind):
			_button(game.data.facilities[kind].name+" · "+ui._cost(kind),func():ui._build_at(kind,tile))
		else:ui._label(ui.body,"?")
		if not game.state.entities.is_empty():_button("부지 정리",func():clear_one(tile),not game.known_resource(r))
	else:
		ui._label(ui.body,"빈 부지",true)
		_button("시설 건설",func():ui.show_tab("build"))
		_button("컨베이어 연결",func():begin("route");origin=point(tile);ui.map.work_origin=tile;ui._layout_title())
