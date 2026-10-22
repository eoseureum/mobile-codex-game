extends SceneTree
var failures=0
var checks=0
func check(v,s):checks+=1;if not v:failures+=1;printerr("FAIL: "+s)
func _initialize():call_deferred("run")
func run():
	var ui=load("res://scenes/Main.tscn").instantiate();ui.allow_save=false;ui.busy=true;root.add_child(ui);await process_frame
	ui.game.fresh(0,true,42);ui.game.command({"type":"build","kind":"forest","x":62,"y":64})
	ui.game.event("first_sawmill");ui.game.event("first_auto_sale")
	ui.game.state.stage="space";ui.game.state.unlocks.offline=true;ui.catalog_all=true
	ui.size=Vector2(390,844);ui.show_tab("build");await process_frame;await process_frame;await process_frame
	check(ui.body.get_combined_minimum_size().y<=ui.scroll.size.y+2,"full construction catalogue fits a card without vertical scrolling")
	if failures:quit(1);return
	var depot=ui.game.create_entity("warehouse",66,64)
	for r in ui.game.data.resources:depot.inventory[r]=50;depot.intakeCursors[r]=1;ui.game.state.totals.produced[r]=100
	var machine=ui.game.create_entity("structureFactory",80,80)
	var market=ui.game.create_entity("market",82,80)
	var rocket=ui.game.create_entity("launchpad",84,80)
	var project=ui.game.create_entity("cabin",86,80,{"project":{"materials":{},"remainingS":ui.game.data.projects.cabin.seconds,"complete":false}})
	var belt=ui.game.create_entity("belt",88,80)
	for screen in [Vector2(390,844),Vector2(320,568),Vector2(960,540),Vector2(844,320)]:
		ui.size=screen;ui._layout()
		for tab in ["build","inventory","industry","records","settings","trade","logistics","policies","projects"]:
			ui.build_page="logistics" if tab=="logistics" else "facilities";ui.inventory_details=tab=="policies";ui.industry_page="city" if tab=="projects" else "research"
			tab={"logistics":"build","policies":"inventory","projects":"industry"}.get(tab,tab)
			ui.show_tab(tab)
			await process_frame;await process_frame;await process_frame
			check(ui.body.get_combined_minimum_size().y<=ui.scroll.size.y+2,"page fits vertically: "+tab+" "+str(screen))
			check(ui.body.get_combined_minimum_size().x<=ui.scroll.size.x+2,"page fits horizontally: "+tab)
		for id in ["e1",depot.id,machine.id,market.id,rocket.id,project.id,belt.id]:
			for page in ["summary","improve","flow","stock"]:
				ui.selected=id;ui.tab="map";ui.inspect_details=page!="summary";ui.inspector_page=page;ui.sheet_fraction=0.42;ui._rebuild();ui._layout()
				await process_frame;await process_frame;await process_frame
				check(ui.body.get_combined_minimum_size().y<=ui.scroll.size.y+2,"facility page fits without scrolling: "+page+" "+str(screen))
				check(ui.body.get_combined_minimum_size().x<=ui.scroll.size.x+2,"facility page fits horizontally: "+page)
	ui.selected=belt.id;ui.inspect_details=false;ui.tab="map";ui._rebuild()
	var connect_ready=false
	for row in ui.body.get_children():
		for node in row.get_children():
			if node is Button and node.text=="연결":connect_ready=not node.disabled
	check(connect_ready,"selected conveyor can start another connection directly")
	print("COMPACT_CARDS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
