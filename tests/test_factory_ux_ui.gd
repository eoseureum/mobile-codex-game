extends SceneTree
var checks=0
var failures=0
var ui
func check(ok,message):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func nodes(node) -> Array:
	var result=[node]
	for child in node.get_children():result.append_array(nodes(child))
	return result
func text(node) -> String:
	var parts=[]
	for n in nodes(node):
		if n is Label or n is Button:parts.append(n.text)
	return " ".join(parts)
func button(node,prefix):
	for n in nodes(node):
		if n is Button and n.text.begins_with(prefix):return n
	return null
func settle():
	await process_frame;await process_frame;await process_frame;await process_frame
func _initialize():call_deferred("run")
func run():
	root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(390,844)
	ui=load("res://scenes/Main.tscn").instantiate();ui.allow_save=false;root.add_child(ui);ui.set_process(false);await settle()
	ui.game.fresh(0,true,42);ui.game.state.cash=1000000000;ui._enter_game();ui.set_process(false)
	ui.show_tab("settings")
	check(not ui.panel_ready and is_zero_approx(ui.scroll.modulate.a),"moving sheet content cannot receive a tap before its layout settles")
	await settle();check(ui.scroll.visible and ui.scroll.modulate.a==1,"settled sheet content becomes available without confirmation")
	var e=ui.game.at(62,64);ui._tile(Vector2i(62,64));await settle()
	var rotate=button(ui.body,"회전")
	if rotate!=null:
		var before=e.direction;rotate.pressed.emit();await settle()
		check(e.direction==before,"opening direction picker does not rotate or emit cargo")
		var picker=ui.find_child("DirectionPicker",true,false)
		check(picker!=null,"facility exposes direct direction selection")
		if picker!=null:
			var up=button(picker,"↑")
			if up!=null:up.pressed.emit();await settle()
			check(e.direction==0,"choosing north performs exactly one atomic direction command")
	else:check(false,"rotation control exists")
	ui.game.state.totals.produced.wire=10;ui.game.state.stage=ui.game.data.stages[2];ui.game.state.unlocks.smelting=true;ui.show_tab("industry");await settle()
	check("전선" in text(ui.body) and "발전기" in text(ui.body),"industry exposes the next power-era conditions")
	ui.game.state.stage=ui.game.data.stages[1];ui.game.state.unlocks.smelting=false;ui._rebuild();await settle()
	check("누적" in text(ui.body) and "구리" in text(ui.body),"research names its resource and cumulative production condition")
	ui.show_tab("build");await settle();var first=button(ui.body,"시설").get_global_rect()
	ui.pages.build=1;ui._rebuild();await settle()
	check(button(ui.body,"시설").get_global_rect()==first,"construction category stays fixed on short final page")
	ui._recipe_info("cabin");await settle()
	check("판매 단가" in text(ui.dialog) and not "0.0초" in text(ui.dialog),"city information shows its effect instead of a zero-second recipe")
	ui.dialog.hide();ui._recipe_info("sawmill");await settle()
	check("판매액" in text(ui.dialog) and "300" in text(ui.dialog),"processing preview explains its total sale value")
	ui.dialog.hide()
	var pad=ui.game.create_entity("launchpad",80,80)
	ui.game.state.stage=ui.game.data.stages[6];ui.game.state.unlocks.offline=true
	for screen in [Vector2i(390,844),Vector2i(320,568),Vector2i(844,320)]:
		root.size=screen;ui.size=screen;ui.selected=pad.id;ui.tab="map";ui.sheet_fraction=.5;ui._rebuild();ui._layout();await settle()
		var content=text(ui.body)
		for r in ui.game.data.rocket:check(ui.game.data.resources[r].name in content,"all named rocket resources visible at "+str(screen))
		check(button(ui.body,"조립 중")!=null,"incomplete rocket has no active launch button")
		check(ui.body.get_combined_minimum_size().y<=ui.scroll.size.y+2,"rocket fits without vertical scrolling at "+str(screen))
	ui.game.state.rocket.delivered=ui.game.data.rocket.duplicate();ui._rebuild();await settle()
	check(button(ui.body,"로켓 발사")!=null and not button(ui.body,"로켓 발사").disabled,"completed rocket enables launch")
	ui.game.command({"type":"launch"});ui._rebuild();await settle()
	check(button(ui.body,"발사 완료")!=null,"reopened completed rocket stays complete")
	ui.map.zoom=.55;ui.map.zoom_by(-10)
	check(ui.map.zoom<=.03,"strategic zoom can show the full 128-tile world")
	var extent=Vector2.ONE*128*ui.map.tile_size*ui.map.zoom
	check(ui.map.camera.x>=0 and ui.map.camera.x+extent.x<=ui.map.size.x+1,"small full-world map stays centered inside the viewport")
	ui.build_kind="sawmill";ui.tab="build";var count=ui.game.state.entities.size()
	ui._tile(Vector2i(90,90))
	check(ui.game.state.entities.size()==count and ui.map.zoom>=.4,"strategic tap zooms in without accidental construction")
	ui.game.state.rocket.launched=0;ui.game.state.rocket.delivered=ui.game.data.rocket.duplicate()
	ui.map.zoom=.1;ui.map.view_filter="stopped"
	ui.game.state.world.nodes.erase("30,30")
	var mill=ui.game.create_entity("sawmill",30,30);ui.game.clear_effects();ui.map.queue_redraw();await settle()
	check(ui.map.strategic_texture.get_image().get_pixel(30,30)==Color("c77955"),"strategic raster marks an actually stopped mill")
	mill.inputs.log=10;ui.game.advance(1.25);ui.map.queue_redraw();await settle()
	check(ui.map.strategic_texture.get_image().get_pixel(30,30)==Color("f4dfad"),"strategic stopped coloring clears after production recovers")
	if ui.has_method("_launch"):
		var path="/tmp/rust-ux-launch-%d"%Time.get_ticks_usec()
		ui.library=load("res://scripts/core/world_library.gd").new(path,path+"-legacy.json")
		var id=ui.library.create(ui.game);check(not id.is_empty(),"prepare persisted pre-launch city")
		ui.active_world_id="world_99999";ui.allow_save=true
		var before=JSON.stringify(ui.game.state)
		ui._launch(pad);await settle()
		check(JSON.stringify(ui.game.state)==before and ui.find_child("LaunchSequence",true,false)==null,"failed launch save leaves a retryable city without a false ending")
		check(ui.library.load_world(id).state.rocket.launched==0,"failed launch cannot overwrite the last usable city")
		ui.active_world_id=id
		ui._launch(pad);await settle()
		check(ui.game.state.rocket.launched==1 and ui.find_child("LaunchSequence",true,false)!=null,"launch commits completion and opens its transient ending")
		check(ui.library.load_world(id).state.rocket.launched==1,"successful launch is durable before the ending opens")
		var sequence=ui.find_child("LaunchSequence",true,false);sequence.set_process(false)
		var elapsed_before=sequence.elapsed
		await create_timer(.25).timeout;sequence._process(0)
		check(sequence.elapsed-elapsed_before>=.2,"ending duration follows elapsed time when rendering pauses")
	else:check(false,"launch has a dedicated ending action")
	ui.queue_free();await settle()
	print("FACTORY_UX_UI: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
