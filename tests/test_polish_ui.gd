extends SceneTree
var checks=0
var failures=0
func check(v,m):
	checks+=1
	if not v:failures+=1;printerr("FAIL: "+m)
func buttons(node):
	var result=[]
	for child in node.get_children():
		if child is Button:result.append(child)
		result.append_array(buttons(child))
	return result
func tap(ui,text):
	for button in buttons(ui.body):
		if button.text==text:
			button.pressed.emit();await process_frame;await process_frame;return
	check(false,"missing button "+text)
func _initialize():call_deferred("run")
func run():
	var ui=load("res://scenes/Main.tscn").instantiate();ui.allow_save=false;ui.busy=true;root.add_child(ui);await process_frame
	ui.set_process(false);ui.busy=false;ui.game.fresh(0,true,42);ui.size=Vector2(390,844)
	ui._build_at("forest",Vector2i(62,64));await process_frame;await process_frame
	check(not ui.dialog.visible and ui.game.state.entities.size()==1,"construction executes without modal")
	var camp=ui.game.at(62,64)
	var early=buttons(ui.body).filter(func(b):return "→" in b.text and "₩" in b.text)
	check(early.size()==2,"two early investment buttons are directly visible")
	for b in early:check(b.disabled,"unaffordable investments visibly disabled")
	for screen in [Vector2(390,844),Vector2(320,568),Vector2(844,320)]:
		ui.size=screen;ui._rebuild();ui._layout();await process_frame;await process_frame;await process_frame
		check(ui.body.get_combined_minimum_size().y<=ui.scroll.size.y+2,"early control card fits "+str(screen))
		check(ui.body.get_combined_minimum_size().x<=ui.scroll.size.x+2,"early control card width "+str(screen))
	ui.size=Vector2(390,844);ui._layout()
	var old=int(camp.direction);await tap(ui,"회전 →")
	check(camp.direction==(old+1)%4 and not ui.dialog.visible,"primary rotation is one tap")
	await tap(ui,"철거")
	check(ui.game.state.entities.is_empty() and ui.selected=="" and not ui.dialog.visible,"primary demolition is one tap and clears inspector")
	check(ui.game.state.cash==2250,"first camp recovery funds visible state")
	ui._build_at("forest",Vector2i(62,64));ui.game.state.cash=2000
	ui._build_linked({"kind":"sawmill","sourceId":ui.game.at(62,64).id,"x":64,"y":64})
	check(ui.game.at(64,64).get("kind","")=="sawmill" and not ui.dialog.visible,"connected construction requires one tap")
	var depot=ui.game.create_entity("warehouse",66,64,{"autoSell":true});ui.game.event("first_auto_sale")
	ui.selected=depot.id;ui.inspect_details=true;ui.inspector_page="improve";ui._rebuild();await process_frame
	var labels=[]
	collect_text(ui.body,labels)
	var text=" ".join(labels)
	check("200 → 400개" in text and "2.00 → 2.24개/s" in text,"warehouse upgrade shows storage and throughput")
	check("판매 2.00 → 2.16개/s" in text and not "판자 3" in text,"manager shows concrete effect and no material fee")
	print("POLISH_UI: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
func collect_text(node,result):
	for child in node.get_children():
		if child is Label or child is Button:result.append(child.text)
		collect_text(child,result)
