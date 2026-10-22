extends SceneTree
const Factory=preload("res://scripts/core/factory.gd")
const World=preload("res://scripts/core/world_map.gd")
const Store=preload("res://scripts/core/save_store.gd")
var checks=0
var failures=0
func check(value,message):
	checks+=1
	if not value:failures+=1;printerr("FAIL: "+message)
func _initialize():call_deferred("run")
func run():
	check(ResourceLoader.exists("res://scripts/ui/opening_ux.gd"),"opening exposes only relevant choices and connected expansion previews")
	if failures:quit(1);return
	var UX=load("res://scripts/ui/opening_ux.gd")
	var g=Factory.new();g.fresh(0,true,42)
	check(UX.catalog(g)==["forest"],"empty land presents a single meaningful building choice")
	check(not UX.feature(g,"inventory") and not UX.feature(g,"industry") and not UX.feature(g,"overview"),"empty land hides warehouse policies and future industry navigation")
	g.command({"type":"build","kind":"forest","x":62,"y":64})
	var camp=g.at(62,64);var before=JSON.stringify(g.state)
	var mill_cost=g.data.facilities.sawmill.cost+g.data.facilities.belt.cost
	var depot_cost=g.data.facilities.warehouse.cost+g.data.facilities.belt.cost
	var suggestion=UX.suggestion(g,camp)
	check(suggestion.get("ok",false) and suggestion.kind=="sawmill" and suggestion.cash==mill_cost,"first expansion quotes a real sawmill and its connecting belt")
	check(JSON.stringify(g.state)==before,"preview never changes resources, buildings, IDs or money")
	check(g.command({"type":"buildLinked","sourceId":camp.id,"kind":"sawmill","x":64,"y":64})=="INSUFFICIENT_CASH" and JSON.stringify(g.state)==before,"unaffordable linked expansion changes nothing")
	while g.state.cash<mill_cost:g.advance(0.25)
	var paid_cash=g.state.cash
	check(paid_cash<mill_cost+g.price("log"),"gradual log economy funds expansion without injected cash")
	check(g.command({"type":"buildLinked","sourceId":camp.id,"kind":"sawmill","x":64,"y":64})=="OK","one paid action builds a sawmill and physical connecting conveyor")
	check(g.at(64,64).kind=="sawmill" and g.at(63,64).kind=="belt" and g.state.cash==paid_cash-mill_cost,"linked build charges exact total without free materials or belts")
	var mill=g.at(64,64)
	check(UX.suggestion(g,mill).cash==depot_cost,"next visible expansion is a connected shipping warehouse")
	while g.state.cash<depot_cost:g.advance(0.25)
	check(g.command({"type":"buildLinked","sourceId":mill.id,"kind":"warehouse","x":66,"y":64})=="OK","second paid expansion completes the physical sales line")
	var depot=g.at(66,64)
	check(UX.feature(g,"inventory"),"warehouse controls appear only once a warehouse exists")
	var last_delta=0
	for i in range(480):
		if g.recorded("first_auto_sale"):break
		var previous_cash=g.state.cash
		g.advance(0.25)
		last_delta=g.state.cash-previous_cash
	check(g.recorded("first_auto_sale"),"actual plank sales follow the built line")
	var attributed=false
	for s in g.sales:
		if s.get("entityId")==depot.id:attributed=true
	check(attributed,"sale events identify the actual shipping building for visual income feedback")
	var shown_income=0
	for s in g.sales:shown_income+=s.cash
	check(shown_income==last_delta,"visual sale feedback equals actual credited money and never creates extra income")
	for i in range(600):
		if g.stage_index()>=1:break
		g.advance(0.25)
	check(UX.feature(g,"industry"),"industry opens as the automated line reaches mining scale")
	check(Store.new().validate(Store.new().snapshot(g)).is_empty(),"connected expansion and attributed sales roundtrip through existing saves")
	for command in [
		{"type":"buildLinked","sourceId":"missing","kind":"sawmill","x":68,"y":64},
		{"type":"buildLinked","sourceId":camp.id,"kind":"warehouse","x":62,"y":64},
		{"type":"buildLinked","sourceId":camp.id,"kind":"forest","x":59,"y":69},
		{"type":"buildLinked","sourceId":camp.id,"kind":"sawmill","x":128,"y":64}]:
		before=JSON.stringify(g.state)
		check(g.command(command)!="OK" and JSON.stringify(g.state)==before,"invalid linked construction is atomic")
	var main=load("res://scenes/Main.tscn").instantiate();main.allow_save=false;main.busy=true;root.add_child(main)
	await process_frame
	main.game.fresh(0,true,42);main._focus_city();main._rebuild();main._layout()
	var hidden_buttons=0
	for b in main.nav.get_children():
		if b.get_meta("tab") in ["industry","records"] and b.disabled and b.mouse_filter==Control.MOUSE_FILTER_IGNORE:hidden_buttons+=1
	check(hidden_buttons==2,"future menus keep their slots but do not intercept early map gestures")
	check(not main.header.get_node("WarehouseButton").visible,"warehouse button is absent before warehouse construction")
	main.game.command({"type":"build","kind":"forest","x":62,"y":64});main.selected=main.game.at(62,64).id;main.tab="map";main._rebuild()
	var texts=[]
	collect_text(main.body,texts)
	check(not "내부 재고" in texts and not "매니저" in texts and not "잠시 쉬기" in texts,"basic producer view does not expose advanced maintenance controls")
	check(main.map.get("opportunity").get("kind","")=="sawmill","next connected facility is shown on the map without a quest card")
	var controls=main.body.get_children().duplicate();main.game.advance(4);main._refresh()
	check(main.body.get_children()==controls,"a sale updates feedback without rebuilding or moving controls")
	# Presentation fixtures verify narrow-screen recipes without changing campaign economics.
	main.game.state=g.state.duplicate(true);main.game.state.stage="space";main.game.state.unlocks.offline=true
	var complex=main.game.create_entity("structureFactory",80,80)
	for screen in [Vector2(320,568),Vector2(390,844),Vector2(844,320)]:
		main.size=screen;main._layout()
		for id in ["e1",depot.id,complex.id]:
			main.selected=id;main.inspect_details=false;main.sheet_fraction=0.42;main._rebuild();main._layout()
			await process_frame
			await process_frame
			check(main.body.get_combined_minimum_size().x<=main.scroll.size.x+2,"basic recipes and warehouse information fit the available width")
			if id==depot.id:check(main.body.get_child_count()<=4,"warehouse shows its handled goods instead of every unlocked industrial resource")
	print("OPENING_UX: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
func collect_text(node,result):
	if node is Label or node is Button:result.append(node.text)
	for child in node.get_children():collect_text(child,result)
