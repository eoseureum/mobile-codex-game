extends SceneTree
var checks=0
var failures=0
var ui
func check(ok,message):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func reset_city():
	ui.game.fresh(0,true,42);ui._enter_game();ui.set_process(false)
func _initialize():call_deferred("run")
func run():
	ui=load("res://scenes/Main.tscn").instantiate();ui.allow_save=false;root.add_child(ui);ui.set_process(false)
	await process_frame;reset_city()
	ui._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);ui.paused_at-=18
	await ui._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(ui.game.state.clock.elapsedS>=18 and ui.game.state.clock.elapsedS<18.5,"stage-zero tab absence advances actual production by elapsed time")
	check(ui.game.at(62,64).outputs.get("log",0)==3 and ui.game.state.cash==0 and ui.game.state.bag.is_empty(),"absent starting camp produces three retained logs, without automatic collection or invented cash")
	var ticks=ui.game.state.clock.tickIndex
	await ui._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(ui.game.state.clock.tickIndex==ticks,"duplicate resume never credits the same absence twice")
	reset_city();ui._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);ui.paused_at-=18
	ui._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await ui._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(ui.game.state.clock.elapsedS>=18,"duplicate pause keeps the original absence timestamp")
	reset_city();ui._notification(Node.NOTIFICATION_APPLICATION_PAUSED);ui.paused_at-=18
	await ui._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(ui.game.at(62,64).outputs.get("log",0)==3,"application suspend/resume works before offline progression unlock")
	reset_city();await ui._catch_up(240)
	check(ui.game.state.clock.elapsedS==240 and ui.game.at(62,64).outputs.get("log",0)==20,"storage reaches its real twenty-log limit during absence")
	check(ui.game.state.cash==0,"full storage cannot produce phantom sales")
	reset_city();ui.game.state.cash=150
	check(ui.game.command({"type":"buildRoute","from":{"x":62,"y":64},"to":{"x":65,"y":64}})=="OK","prepare real first factory conveyor route")
	await ui._catch_up(60)
	check(ui.game.state.totals.sold.get("log",0)>=9 and ui.game.state.cash>=315,"real conveyors deliver and sell while absent at the starting stage")
	check(ui.game.state.bag.is_empty(),"automatic background sales do not create inventory")
	reset_city();await ui._catch_up(8000)
	check(ui.game.state.clock.elapsedS==7200,"an absence is capped at two hours")
	if "last_frame_at" in ui:
		reset_city();ui.last_frame_at-=18
		await ui._process(0.01)
		check(ui.game.at(62,64).outputs.get("log",0)==3,"a browser freeze without focus events recovers elapsed time instead of clipping its delta")
		ticks=ui.game.state.clock.tickIndex
		await ui._process(0)
		check(ui.game.state.clock.tickIndex==ticks,"the first normal frame after recovery cannot double-count the gap")
	else:check(false,"Main tracks active-world frame time to recover missed lifecycle events")
	var Library=load("res://scripts/core/world_library.gd")
	var path="/tmp/rust-background-%d"%Time.get_ticks_usec();var library=Library.new(path,path+"-old.json")
	reset_city();var snapshot=ui.store.snapshot(ui.game);snapshot.savedAtMs-=18000
	var id=library.import_snapshot(snapshot)
	ui.library=library;ui.game_started=false
	# A real title control supplies the same loading surface as normal launch.
	ui.start_screen=load("res://scripts/ui/start_screen.gd").new();ui.start_screen.setup(ui);ui.add_child(ui.start_screen)
	await ui._resume_world(id)
	check(ui.game.at(62,64).outputs.get("log",0)==3,"selected saved starting city catches up even after Safari discards its old tab")
	check(ui.game.state.clock.elapsedS>=18 and ui.game.state.clock.elapsedS<24,"world selection applies the saved interval once")
	reset_city();ui.allow_save=true;ui.active_world_id=library.create(ui.game)
	ui.last_frame_at-=18;ui._pause_production()
	check(library.load_world(ui.active_world_id).savedAtMs<=int(Time.get_unix_time_from_system()*1000)-17000,"pause persists the accounted state timestamp before Safari can discard a frozen page")
	id=ui.active_world_id;ui.game_started=false;await ui._resume_world(id)
	check(ui.game.at(62,64).outputs.get("log",0)==3,"reload after a frozen-frame pause preserves pending production")
	reset_city();ui.active_world_id=library.create(ui.game);ui.last_frame_at-=1000;ui._pause_production()
	ui._resume_production()
	check(ui.busy,"long background recovery yields without allowing world switches")
	ui._pause_production()
	check(library.load_world(ui.active_world_id).state.clock.elapsedS==0,"pause during catch-up preserves the last complete checkpoint rather than stamping a partial replay as current")
	while ui.busy:await process_frame
	await ui._resume_production()
	ui.queue_free();await process_frame
	print("BACKGROUND_PRODUCTION: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
