extends SceneTree
const Fixture=preload("res://tests/world_fixture.gd")
var failures=0
var checks=0
func check(value,description):
	checks+=1
	if not value:failures+=1;printerr("FAIL: "+description)
func _initialize():call_deferred("run")
func run():
	var main=load("res://scenes/Main.tscn").instantiate()
	main.allow_save=false
	main.busy=true
	root.add_child(main)
	await process_frame
	main.game.fresh(0,true,42);main._focus_city();main._rebuild()
	check(main.game.state.entities.is_empty() and main.selected.is_empty(),"empty city focuses safely without an e1 building")
	check(main.handle.text.begins_with("벌목장 건설"),"first construction is visible in the floating handle")
	check(not main._cost("forest").contains("판자"),"first logging camp price has no impossible plank requirement")
	var confirmation_panel=main.dialog.get_theme_stylebox("panel","AcceptDialog")
	check(confirmation_panel is StyleBoxFlat and confirmation_panel.bg_color.r>0.8,"first construction confirmation has a light background behind dark labels")
	check(main.dialog.get_ok_button().get_theme_color("font_focus_color").r<0.5,"focused construction confirmation keeps dark readable text")
	for viewport_size in [Vector2(390,844),Vector2(960,540),Vector2(320,568),Vector2(844,320)]:
		main.size=viewport_size
		await process_frame
		main._layout()
		await process_frame
		check(main.map.position==Vector2.ZERO and main.map.size==main.size,"map fills the screen behind floating controls")
		check(main.header.mouse_filter==Control.MOUSE_FILTER_IGNORE,"empty HUD space passes gestures to the map")
		check(main.nav.mouse_filter==Control.MOUSE_FILTER_IGNORE,"gaps between floating menu buttons pass gestures to the map")
		var u=main.scale_ui
		check(main.nav.position.x>=12*u and main.nav.position.y+main.nav.size.y<=main.size.y-12*u,"menu floats inside screen edges")
		for button in main.nav.get_children():
			check(button.size.x>=48*u and button.size.y>=48*u,"floating menu retains a 48px touch target")
		main.show_tab("settings")
		await process_frame
		check(main.sheet.position.x>=12*u and main.sheet.position.x+main.sheet.size.x<=main.size.x-12*u,"expanded panel floats with side margins")
		check(not main.sheet.get_rect().intersects(main.nav.get_rect()),"expanded panel clears navigation touch targets")
		check(not main.sheet.get_rect().intersects(main.header.get_node("WarehouseButton").get_rect()),"floating panel does not cover the warehouse button on short screens")
		main.show_tab("map")
		await process_frame
		var rects=[]
		for button in main.nav.get_children():rects.append(button.get_global_rect())
		for i in range(96):main.game.tick();main._refresh()
		await process_frame
		for i in range(rects.size()):check(rects[i]==main.nav.get_child(i).get_global_rect(),"production never shifts floating controls")
	var city=main.map
	var camera_before=city.camera
	var press=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=Vector2(200,200)
	city._gui_input(press)
	var move=InputEventMouseMotion.new();move.position=Vector2(260,240)
	city._gui_input(move)
	check(city.camera==camera_before+Vector2(60,40),"dragging uncovered map pans the city")
	press.pressed=false;press.position=move.position;city._gui_input(press)
	Fixture.connected(main.game);main.game.invalidate_index();main._focus_city();main.size=Vector2(390,844);main._layout()
	main.world_tools.begin("route")
	main._tile(Vector2i(64,66));main._tile(Vector2i(68,66))
	check(main.tab=="work" and main.map.preview_path.size()==5,"two tile taps preview the complete route")
	check(main.map.tile_rect(64,66).end.y<main.sheet.position.y,"route preview remains visible above its floating inspector")
	var before=JSON.stringify(main.game.state)
	main.show_tab("map")
	check(main.world_tools.mode.is_empty() and main.map.preview_path.is_empty() and JSON.stringify(main.game.state)==before,"cancelling preview never spends or changes terrain")
	main.world_tools.begin("route");main._tile(Vector2i(64,66));main._tile(Vector2i(68,66));main.world_tools.commit()
	check(main.game.state.cash==500-5*main.game.data.facilities.belt.cost and main.game.at(68,66).kind=="belt" and main.world_tools.mode.is_empty(),"confirmed route is committed and preview closes")
	Fixture.connected(main.game);main.game.invalidate_index();main._focus_city()
	main._tile(Vector2i(59,69));main.world_tools.clear_one(Vector2i(59,69))
	check(main.map.preview_clear==["59,69"] and main.map.preview_area.size==Vector2i.ONE,"single tree clearing highlights the affected tile")
	main.world_tools.commit()
	check(main.game.stock("log")==2 and not main.game.state.world.nodes.has("59,69"),"touch clearing recovers resources and permanently removes the tree")
	var previous_camera=main.map.camera
	main.overview.point_selected.emit(Vector2i(100,100))
	check(main.map.camera!=previous_camera,"minimap selection moves the camera")
	main.game.fresh(0,false);main._focus_city();main.show_tab("settings")
	var migration=false
	for child in main.body.get_children():
		if child is Button and child.text=="큰 월드로 이전":migration=true
	check(migration,"legacy settings offer explicit world migration")
	main.game.command({"type":"migrateWorld","seed":42});main._focus_city();main.show_tab("map")
	check(main.game.world_mode() and main.overview.visible,"migrated city displays the open world and minimap")
	print("UI_LAYOUT: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
