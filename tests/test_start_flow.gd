extends SceneTree
var checks=0
var failures=0
func check(ok,message):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func settle():
	await process_frame;await process_frame;await process_frame
func _initialize():call_deferred("run")
func run():
	var ui=load("res://scenes/Main.tscn").instantiate()
	for method in ["_show_start","_new_world","_resume_world"]:check(ui.has_method(method),"main provides explicit menu lifecycle "+method)
	if failures:ui.free();print("START_FLOW: %d checks, %d failures"%[checks,failures]);quit(1);return
	var Library=load("res://scripts/core/world_library.gd")
	var directory="/tmp/rust-start-flow-%d"%Time.get_ticks_usec()
	ui.library=Library.new(directory,directory+"/old.json");root.add_child(ui);await settle()
	check(ui.start_screen.visible and not ui.game_started and ui.active_world_id.is_empty(),"normal launch shows start menu without selecting or saving a draft world")
	var before=JSON.stringify(ui.game.state)
	await create_timer(0.4).timeout
	check(JSON.stringify(ui.game.state)==before and ui.library.worlds().is_empty(),"waiting at title never produces logs or creates a saved world")
	check(not ui.map.is_processing_input(),"title screen disables hidden map gestures")
	ui.set_process(false);await ui._new_world();await settle()
	var first=ui.active_world_id;var camp=ui.game.at(62,64)
	check(ui.game_started and not ui.start_screen.visible and ui.map.is_processing_input(),"new game enters playable map and restores gestures")
	check(not first.is_empty() and ui.game.state.cash==0 and ui.game.state.bag.is_empty() and camp.outputs.is_empty(),"new game starts with zero cash, bag and completed wood")
	check(ui.game.state.entities.size()==2 and ui.game.sales_hub().size()>0 and camp.kind=="forest" and ui.game.state.clock.elapsedS==0,"new world contains exactly hub and logging camp at time zero")
	ui.game.advance(18);ui.game.state.cash=777;ui._show_start();await settle()
	check(not ui.game_started and ui.start_screen.visible and ui.library.load_world(first).state.cash==777,"return to title saves the active city")
	ui.start_screen.show_worlds();await settle()
	check(ui.start_screen.rows.size()==1 and ui.start_screen.rows[0].find_child("WorldName",true,false).text=="도시 1","continue displays the actual saved world using real catalog data")
	await ui._new_world();await settle();var second=ui.active_world_id
	check(second!=first and ui.library.worlds().size()==2,"new game creates a separate slot")
	check(ui.game.state.cash==0 and ui.game.state.bag.is_empty() and ui.game.at(62,64).outputs.is_empty() and ui.game.state.clock.elapsedS==0,"new game cannot inherit previous money, logs or play time")
	ui.game.state.cash=45;ui._show_start();await ui._resume_world(first);await settle()
	check(ui.active_world_id==first and ui.game.state.cash==777 and ui.game.at(62,64).outputs.get("log",0)==3,"continue restores the chosen world's exact progress")
	check(ui.library.load_world(second).state.cash==45,"resuming one world does not alter another")
	ui._show_start();before=JSON.stringify(ui.game.state);await ui._resume_world("../invalid");await settle()
	check(not ui.game_started and ui.start_screen.visible and JSON.stringify(ui.game.state)==before,"invalid selection leaves menu and existing world untouched")
	await ui._resume_world(first);var count=ui.library.worlds().size()
	ui._prepare_import(ui.store.export_text(ui.game));await settle();await settle()
	check(ui.library.worlds().size()==count+1 and ui.active_world_id not in [first,second] and not ui.dialog.visible,"backup import creates another world without destructive replacement dialog")
	check(ui.library.load_world(first).state.cash==777 and ui.library.load_world(second).state.cash==45,"backup import preserves all existing cities")
	var active=ui.active_world_id;ui._show_start();await settle()
	ui._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);ui._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN);await settle()
	check(not ui.game_started and ui.start_screen.visible and ui.active_world_id==active,"focus notifications cannot silently reopen a city from the title")
	await ui._resume_world(first)
	ui.game.state.unlocks.offline=true
	ui._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);ui.paused_at-=1000
	ui._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(ui.busy,"offline catch-up owns busy state while yielding")
	ui._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	ui._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	ui._show_start();ui._new_world()
	check(ui.busy and ui.game_started and ui.active_world_id==first and not ui.start_screen.visible,"nested focus cannot release catch-up ownership or switch worlds")
	while ui.busy:await process_frame
	check(ui.game.state.clock.elapsedS>=1018,"original city receives all offline production before switching")
	ui._show_start();await ui._new_world();await settle()
	check(ui.game.state.clock.elapsedS==0 and ui.game.at(62,64).outputs.is_empty(),"completed old catch-up cannot advance a newly created world")
	print("START_FLOW: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
