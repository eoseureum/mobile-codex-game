extends SceneTree
const Factory=preload("res://scripts/core/factory.gd")
const UX=preload("res://scripts/ui/opening_ux.gd")
const Art=preload("res://scripts/ui/pixel_art.gd")
var checks=0
var failures=0
func check(value,message):
	checks+=1
	if not value:failures+=1;printerr("FAIL: "+message)
func _initialize():call_deferred("run")
func buttons(node) -> Array:
	var result=[]
	if node is Button:result.append(node)
	for child in node.get_children():result.append_array(buttons(child))
	return result
func named(node,key):return node.find_child(key,true,false)
func texts(node) -> Array:
	var result=[]
	if node is Label or node is Button:result.append(node.text)
	for child in node.get_children():result.append_array(texts(child))
	return result
func settle():
	await process_frame;await process_frame;await process_frame
func run():
	var g=Factory.new();g.fresh(0,true,42)
	check(UX.feature(g,"inventory"),"bag is available before first construction")
	check(UX.catalog(g)==["forest"],"free public hub does not count as a started factory")
	g.command({"type":"build","kind":"forest","x":62,"y":64});var camp=g.at(62,64)
	var q=UX.suggestion(g,camp)
	check(q.get("action","")=="connectMarket" and q.get("cash",0)==150 and q.get("cells",[]).size()==2,"first expansion is a two-belt 150-cash hub connection")
	check(UX.feature(g,"logistics"),"logistics unlock after the first camp")
	check(not "warehouse" in UX.catalog(g,true) and not "market" in UX.catalog(g,true),"catalog never offers retired warehouses or duplicate hubs")
	var ui=load("res://scenes/Main.tscn").instantiate();ui.allow_save=false;ui.busy=true;root.add_child(ui);await settle()
	ui.game.fresh(0,true,42);ui._focus_city();ui._rebuild();ui._layout();await settle()
	check(ui.selected=="" and ui.selected_tile==Vector2i(62,64),"new city highlights the first tree without selecting hub")
	ui._tile(Vector2i(62,64));await settle()
	check(buttons(ui.body).filter(func(b):return "부지 정리" in b.text or "컨베이어" in b.text).is_empty(),"free hub does not expose logistics before first camp")
	check(ui.header.get_node("WarehouseButton").visible and ui.header.get_node("WarehouseButton/Caption").text=="가방","always-visible bag replaces warehouse caption")
	ui.game.command({"type":"build","kind":"forest","x":62,"y":64});camp=ui.game.at(62,64)
	ui.selected=camp.id;ui.sheet_fraction=0.42;ui._rebuild();ui._layout();await settle()
	var collect=named(ui.body,"CollectButton")
	check(collect!=null,"production card has a dedicated collection control")
	if collect!=null:
		check(collect.disabled,"empty producer collection stays present and disabled")
		var rect=collect.get_global_rect();ui.game.advance(30);ui._refresh();await settle()
		check(not collect.disabled and "수거" in collect.text,"finished output enables collection")
		check(collect.get_global_rect()==rect,"collection quantity never moves or resizes the control")
		ui.busy=false;collect.pressed.emit();await settle();ui.busy=true
		check(ui.game.stock("log")>0 and camp.outputs.is_empty(),"collection touch action moves finished output into bag")
	var route=UX.suggestion(ui.game,camp)
	if route.get("action","")=="connectMarket":
		ui.game.command({"type":"sellInventory","entityId":ui.game.sales_hub().id})
		ui.busy=false;ui._build_linked(route);ui.busy=true
		check(ui.game.at(63,64).get("kind","")=="belt" and ui.game.at(64,64).get("kind","")=="belt","opening shortcut constructs a real physical route")
		var mill=UX.suggestion(ui.game,camp)
		check(mill.get("kind","")=="sawmill","connected camp next suggests a sawmill instead of duplicate route")
		check(mill.get("action","")=="insertSawmill" and mill.get("cash",0)==700 and mill.get("x",0)==64,"automation expands by converting the last belt without severing hub sales")
	var hub=ui.game.sales_hub()
	for i in range(6):
		var r=ui.game.data.resources.keys()[i];ui.game.state.bag[r]=i+1;ui.game.state.totals.produced[r]=i+1
	for screen in [Vector2(390,844),Vector2(320,568),Vector2(960,540),Vector2(844,320)]:
		ui.size=screen;ui._layout();ui.map.focus_district();await settle()
		var camp_rect=ui.map.tile_rect(62,64);var far=ui.map.tile_rect(67,65)
		var view=Rect2(Vector2.ZERO,ui.map.size)
		check(view.encloses(camp_rect) and view.encloses(far),"initial view includes first camp and full hub: "+str(screen))
		ui.show_tab("inventory");await settle()
		check(named(ui.body,"FocusHubButton")!=null,"bag can focus the public sales hub")
		check(buttons(ui.body).filter(func(b):return "판매 설정" in b.text or "판매 안 함" in b.text or "모두 판매" in b.text).is_empty(),"bag has no policies or remote sale actions")
		ui._tile(Vector2i(67,65));await settle()
		check(ui.selected==hub.id,"every footprint tile selects the hub")
		check(named(ui.body,"SellAllButton")!=null,"hub offers sell all")
		check(buttons(ui.body).filter(func(b):return b.has_meta("sellResource")).size()<=4,"hub shows at most four sale stacks")
		check(buttons(ui.body).filter(func(b):return "철거" in b.text or "회전" in b.text or "일시 정지" in b.text).is_empty(),"protected hub has no invalid maintenance actions")
		check(ui.body.get_combined_minimum_size().y<=ui.scroll.size.y+2,"hub page fits without scrolling: "+str(screen))
		check(ui.body.get_combined_minimum_size().x<=ui.scroll.size.x+2,"hub page fits horizontally: "+str(screen))
		ui.inspect_details=true;ui.inspector_page="improve";ui._rebuild();await settle()
		check(buttons(ui.body).filter(func(b):return "₩" in b.text).size()>0,"cash upgrades remain accessible")
		check(ui.body.get_combined_minimum_size().y<=ui.scroll.size.y+2,"hub upgrades fit without scrolling: "+str(screen))
	var complex=ui.game.create_entity("structureFactory",80,80)
	for screen in [Vector2(320,568),Vector2(844,320)]:
		ui.size=screen;ui._layout()
		for entity in [camp,complex]:
			for page in ["summary","improve","flow","stock"]:
				ui.selected=entity.id;ui.tab="map";ui.inspect_details=page!="summary";ui.inspector_page=page;ui.sheet_fraction=0.42;ui._rebuild();ui._layout();await settle()
				check(named(ui.body,"CollectButton")!=null,"every production view preserves collection access: "+page)
				check(ui.body.get_combined_minimum_size().y<=ui.scroll.size.y+2,"production page fits without scrolling: "+page+" "+str(screen))
				check(ui.body.get_combined_minimum_size().x<=ui.scroll.size.x+2,"production page fits horizontally: "+page+" "+str(screen))
	var image=Art.image("sales_hub",1)
	check(image.get_width()==96 and image.get_height()==96,"public hub has a dedicated footprint-size pixel sprite")
	ui.inspect_details=false;ui._tile(Vector2i(65,64));await settle()
	var sell=named(ui.body,"SellAllButton");var cash=ui.game.state.cash
	if sell!=null:
		ui.busy=false;sell.pressed.emit();await settle();ui.busy=true
		check(ui.game.state.cash>cash and ui.game.stock("log")==0,"hub touch sale credits cash and removes bag stacks")
	ui.game.fresh(0,true,42);ui.game.command({"type":"build","kind":"forest","x":62,"y":64});ui.game.state.cash=10000
	ui.game.state.world.nodes.erase("80,80");ui.game.state.world.nodes.erase("80,81")
	ui.visible_game=false;ui.busy=false;var before=JSON.stringify(ui.game.state)
	ui._build_at("sawmill",Vector2i(80,80));await settle()
	check(ui.dialog.visible and JSON.stringify(ui.game.state)==before,"first processing placement previews its recipe before charging or placing")
	if ui.dialog.visible:
		ui.dialog.canceled.emit();ui.dialog.hide();await settle()
		check(JSON.stringify(ui.game.state)==before,"canceling first recipe preview is atomic")
		ui._build_at("sawmill",Vector2i(80,80));await settle();ui.dialog.confirmed.emit();ui.dialog.hide();await settle()
		check(ui.game.at(80,80).get("kind","")=="sawmill" and ui.game.state.cash==10000-ui.game.data.facilities.sawmill.cost,"accepting first recipe preview places exactly one paid machine")
		ui._build_at("sawmill",Vector2i(80,81));await settle()
		check(not ui.dialog.visible and ui.game.at(80,81).get("kind","")=="sawmill","later same-kind placements are immediate")
	check(ui.has_method("_recipe_info"),"recipe information remains accessible separately from installation")
	if ui.has_method("_recipe_info"):
		before=JSON.stringify(ui.game.state);ui._recipe_info("wireFactory");await settle()
		check(ui.dialog.visible and JSON.stringify(ui.game.state)==before,"opening production information never spends money or installs a machine")
		check(ui.dialog.get_ok_button().get_global_rect().end.x>=ui.dialog.get_node("RecipeContent").get_global_rect().end.x-1,"initial recipe actions align with content right edge")
		var copy=" ".join(texts(ui.dialog))
		check("구리괴 × 1" in copy and "전선 × 2" in copy and "4.4초 / 회" in copy,"recipe preview names input and output materials with exact quantities and cycle")
		ui._recipe_info("generator");copy=" ".join(texts(ui.dialog))
		check("석탄 × 1" in copy and "전력 +12" in copy and "10.0초 / 회" in copy,"generator preview matches actual coal burn and generation instead of unused catalog cycle")
		ui._recipe_info("structureFactory");copy=" ".join(texts(ui.dialog))
		check("전력 %d"%ui.game.data.facilities.structureFactory.power in copy,"powered recipe preview includes its electricity requirement")
		for screen in [Vector2i(320,568),Vector2i(844,320)]:
			root.size=screen;await settle();await settle()
			check(Rect2i(Vector2i.ZERO,Vector2i(root.get_visible_rect().size)).encloses(Rect2i(ui.dialog.position,ui.dialog.size)),"open recipe modal stays inside viewport after rotation: "+str(screen))
			check(ui.dialog.get_ok_button().get_combined_minimum_size().y>=48*ui.scale_ui,"recipe confirmation retains a 48-pixel touch target")
			check(ui.dialog.get_ok_button().get_rect().end.x>=ui.dialog.get_ok_button().get_parent().size.x-1,"recipe actions align to the right edge")
		ui.dialog.hide()
	ui.busy=true
	if "--web-fixture" in OS.get_cmdline_user_args():web_fixtures()
	print("SALES_HUB_UI: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)

func web_fixtures():
	var store=load("res://scripts/core/save_store.gd").new()
	DirAccess.make_dir_recursive_absolute("res://build/fixtures")
	var game=Factory.new();game.fresh(0,true,42);game.command({"type":"build","kind":"forest","x":62,"y":64});game.advance(30)
	FileAccess.open("res://build/fixtures/hub-ready.json",FileAccess.WRITE).store_string(store.export_text(game))
	game.command({"type":"collect","entityId":game.at(62,64).id})
	for i in range(6):
		var r=game.data.resources.keys()[i];game.state.bag[r]=i+1;game.state.totals.produced[r]=i+1
	game.state.stage=game.data.stages[-1];game.state.unlocks.offline=true;game.state.cash=10000;game.event("first_sale");game.event("first_auto_sale")
	FileAccess.open("res://build/fixtures/hub-stacks.json",FileAccess.WRITE).store_string(store.export_text(game))
	game.fresh(0,true,42);game.command({"type":"build","kind":"forest","x":62,"y":64});game.advance(30)
	game.command({"type":"collect","entityId":game.at(62,64).id});game.command({"type":"sellInventory","entityId":game.sales_hub().id})
	game.command({"type":"buildRoute","from":{"x":62,"y":64},"to":{"x":65,"y":64}});game.advance(138)
	FileAccess.open("res://build/fixtures/hub-inline.json",FileAccess.WRITE).store_string(store.export_text(game))
	load("res://tests/world_fixture.gd").connected(game)
	game.state.entities.e3.inventory={"log":17,"plank":3};game.state.bag={"log":2}
	FileAccess.open("res://build/fixtures/hub-legacy.json",FileAccess.WRITE).store_string(store.export_text(game))
	for filename in ["hub-ready.json","hub-stacks.json","hub-inline.json","hub-legacy.json"]:
		check(not store.parse(FileAccess.get_file_as_string("res://build/fixtures/"+filename)).is_empty(),"browser fixture validates: "+filename+" "+store.last_error)
