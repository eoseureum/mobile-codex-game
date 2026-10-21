extends RefCounted
const Art=preload("res://scripts/ui/pixel_art.gd")
const Opening=preload("res://scripts/ui/opening_ux.gd")
static func picture(ui,parent,kind):
	var p=TextureRect.new();p.texture=Art.texture(kind);p.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	p.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;p.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	p.custom_minimum_size=Vector2(32,32)*ui.scale_ui;p.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(p)
static func resource(ui,parent,r,n):
	var chip=HBoxContainer.new();parent.add_child(chip)
	picture(ui,chip,"item_"+r);ui._label(chip,str(int(n)))
static func recipe_row(ui,e):
	var game=ui.game;var f=game.recipe(e)
	var row
	if f.input.size()>1:
		row=HFlowContainer.new();row.size_flags_horizontal=Control.SIZE_EXPAND_FILL;ui.body.add_child(row)
	else:row=ui._row()
	if e.kind=="warehouse":
		picture(ui,row,"warehouse");ui._label(row,"→");picture(ui,row,"icon_coin")
		ui._spacer(row);ui._bind_label(row,func():return "초과분 판매" if e.autoSell else "보관 중")
		return
	if f.output.is_empty():ui._bind_label(row,func():return game.status(e));return
	for r in f.input:resource(ui,row,r,f.input[r])
	if f.input.is_empty():picture(ui,row,"tree" if e.kind=="forest" else "ore_"+e.mineResourceId)
	ui._label(row,"→")
	for r in f.output:resource(ui,row,r,f.output[r])
	if e.id==game.state.factory.get("pioneerForestId","") and not game.recorded("first_auto_sale"):
		ui._label(row,"→");picture(ui,row,"icon_coin");ui._label(row,game.money(game.price("log")))
	if row is HBoxContainer:ui._spacer(row)
	ui._bind_label(row,func():
		var rate=game.speed(e)*(game.state.power.ratio if f.power>0 else 1.0)
		return "Ⅱ" if e.paused or rate<=0 else "%.1fs"%(f.cycle/rate))
	if not f.output.is_empty() and e.kind!="forest":
		var worth=ui._row();ui._spacer(worth);picture(ui,worth,"icon_coin")
		ui._bind_label(worth,func():
			var value=0;var depot=game.shipping_depot()
			for r in f.output:value+=f.output[r]*(game.price(r) if depot.is_empty() else game.sale_price(depot,r))
			return "판매가 "+game.money(value))
static func show(ui,e):
	var game=ui.game;var f=game.recipe(e)
	recipe_row(ui,e)
	if f.cycle>0 and e.kind!="generator":
		var progress=ProgressBar.new();progress.show_percentage=false;progress.custom_minimum_size.y=6*ui.scale_ui;ui.body.add_child(progress)
		ui.bindings.append(func():if is_instance_valid(progress):progress.value=clampf(1-e.job.remaining/f.cycle,0,1)*100 if e.job!=null else 0)
	if e.kind=="warehouse":
		for resource_id in Opening.handled_resources(game,e):
			var r=resource_id;var row=ui._row();picture(ui,row,"item_"+r)
			ui._bind_label(row,func():return "보관 %d / %d"%[e.inventory.get(r,0),int(game.state.factory.reserves[r])] if e.autoSell and game.state.factory.reserves[r]>0 else "재고 %d"%e.inventory.get(r,0));ui._spacer(row)
			picture(ui,row,"icon_coin");ui._bind_label(row,func():return game.money(game.sale_price(e,r)) if e.autoSell and game.state.factory.reserves[r]>=0 else "—")
		var row=ui._row();ui._spacer(row);ui._button(row,"설정",func():ui.inspect_details=true;ui._rebuild())
		return
	var suggestion=Opening.suggestion(game,e)
	ui.map.opportunity=suggestion
	if suggestion.get("kind","")=="sawmill":
		var future=ui._row();picture(ui,future,"sawmill");ui._label(future,"→")
		resource(ui,future,"plank",3);ui._label(future,"→");picture(ui,future,"icon_coin");ui._label(future,game.money(3*game.price("plank")))
	var row=ui._row()
	ui._button(row,"설정",func():ui.inspect_details=true;ui._rebuild())
	ui._spacer(row)
	if not suggestion.is_empty():
		var label=game.data.facilities[suggestion.kind].name+" + 연결\n₩ "+game.money(suggestion.cash)
		var button=ui._button(row,label,func():ui._build_linked(suggestion))
		ui.bindings.append(func():
			if not is_instance_valid(button):return
			var ready=game.affordable(suggestion.cash,suggestion.materials);button.disabled=not ready
			if not button.has_meta("ready") or button.get_meta("ready")!=ready:
				button.set_meta("ready",ready);button.add_theme_stylebox_override("normal",ui._box(Color("e2b86b") if ready else Color("e5e5c3"))))
		var savings=ProgressBar.new();savings.show_percentage=false;savings.custom_minimum_size.y=6*ui.scale_ui;ui.body.add_child(savings)
		ui.bindings.append(func():if is_instance_valid(savings):savings.value=100.0*game.state.cash/maxf(1,suggestion.cash))
	else:
		var connect=ui._button(row,"연결",func():ui.world_tools.begin("route");ui.world_tools.origin={"x":int(e.x),"y":int(e.y)};ui.map.work_origin=Vector2i(int(e.x),int(e.y));ui._layout_title())
		connect.disabled=not game.world_mode() or game.recipe(e).output.is_empty()
		ui._bind_label(ui.body,func():return game.status(e))
