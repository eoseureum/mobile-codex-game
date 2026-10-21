extends SceneTree
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
		check(main.sheet.position.y+main.sheet.size.y<=main.nav.position.y-8*u,"expanded panel clears navigation touch targets")
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
	print("UI_LAYOUT: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
