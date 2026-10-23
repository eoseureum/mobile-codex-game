extends SceneTree
const Factory=preload("res://scripts/core/factory.gd")
const Motion=preload("res://scripts/ui/facility_motion.gd")
var checks=0
var failures=0
func check(ok,message):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func texts(node) -> String:
	var parts=[]
	if node is Label or node is Button:parts.append(node.text)
	for child in node.get_children():parts.append(texts(child))
	return " ".join(parts)
func purchase(ui,fragment):
	for row in ui.body.get_children():
		if fragment not in texts(row):continue
		for child in row.get_children():
			if child is Button and child.text.begins_with("₩"):return child
	return null
func _initialize():call_deferred("run")
func settle():
	await process_frame;await process_frame;await process_frame
func bare(game):
	game.fresh(0,true,42)
	game.state.entities.erase(game.state.factory.pioneerForestId);game.invalidate_index()
	game.state.cash=1000000000000000;game.state.stage="space";game.state.unlocks.offline=true
func run():
	# Measure real output at every level and manager rank, with uninterrupted supply.
	var game=Factory.new()
	for kind in game.data.facilities:
		if kind=="generator" or game.data.facilities[kind].output.is_empty() and kind!="mine":continue
		for level in range(1,21):
			for manager in range(4):
				bare(game)
				var e=game.create_entity(kind,80,80,{"level":level,"managerLevel":manager});var f=game.recipe(e)
				for r in f.input:e.inputs[r]=100
				if f.power>0:game.create_entity("generator",90,90,{"level":20,"inputs":{"coal":100}})
				var output=f.output.keys()[0];var elapsed=0.0
				while game.produced(output)<2*f.output[output] and elapsed<60:
					game.tick();elapsed+=Factory.DT
				var expected=2*f.cycle/(1+0.12*(level-1)+0.08*manager)
				check(elapsed>=expected-0.00001 and elapsed<expected+Factory.DT+0.00001,"measured cycle "+kind+" Lv%d manager%d"%[level,manager])
	for level in [1,2]:
		bare(game);var belt=game.create_entity("belt",64,64,{"level":level,"direction":1})
		for i in range(80):
			while belt.queue.size()<4:belt.queue.append("log")
			game.tick()
		check(game.state.totals.sold.get("log",0)==(30 if level==1 else 60),"measured conveyor deliveries over twenty seconds Lv%d"%level)
	for level in [1,2,10,20]:
		bare(game);var gen=game.create_entity("generator",80,80,{"level":level,"inputs":{"coal":2}})
		game.advance(5)
		check(is_equal_approx(gen.burnRemainingS,5) and gen.inputs.coal==1,"generator burns one coal for ten seconds regardless of level")
		check(is_equal_approx(game.state.power.generation,12*(1+0.12*(level-1))),"generator upgrade raises real output")
		check(is_equal_approx(Motion.phase(game,gen),0.5),"generator animation follows fuel-cycle progress instead of fictitious faster recipes")
	var ui=load("res://scenes/Main.tscn").instantiate();ui.allow_save=false;ui.busy=true;root.add_child(ui);await settle()
	ui.set_process(false)
	bare(ui.game);ui.game.event("first_auto_sale")
	var gen=ui.game.create_entity("generator",90,90,{"inputs":{"coal":100}});ui.game.power_step()
	ui.selected=gen.id;ui.inspect_details=true;ui.inspector_page="improve";ui._rebuild();await settle()
	check("전력 12.00 → 13.44" in texts(ui.body),"generator upgrade describes power output instead of shortening its catalog cycle")
	check("전력 12.00 → 12.96" in texts(ui.body),"generator manager describes actual extra power")
	ui.inspect_details=false;ui._rebuild();await settle()
	check("전력 12.00" in texts(ui.body) and "10.0초" in texts(ui.body),"generator summary shows power and fixed coal duration")
	var belt=ui.game.create_entity("belt",80,80)
	ui.selected=belt.id;ui.inspect_details=true;ui._rebuild();await settle()
	check("1.50 → 3.00개/s" in texts(ui.body),"conveyor upgrade previews its actual doubled throughput")
	ui.game.state.stage=ui.game.data.stages[3];ui._rebuild();await settle()
	var button=purchase(ui,"운송")
	check(button!=null and button.disabled,"conveyor upgrade button respects its automation-stage requirement")
	ui.game.state.stage=ui.game.data.stages[4];ui._rebuild();await settle();button=purchase(ui,"운송")
	if button!=null:ui.busy=false;button.pressed.emit();await settle();ui.busy=true
	check(belt.level==2 and purchase(ui,"운송").disabled,"touch purchase applies doubled throughput once and disables its maximum level")
	var machine=ui.game.create_entity("partsFactory",82,80,{"inputs":{"ironIngot":100,"plank":100}})
	for i in range(7):ui.game.create_entity("partsFactory",80+i,82)
	ui.game.power_step();ui.selected=machine.id;ui._rebuild();await settle()
	check("13.2 → 12.0초" in texts(ui.body),"production upgrade preview includes both brownout and added power demand")
	check("13.2 → 12.3초" in texts(ui.body),"manager preview includes brownout and added power demand")
	machine.paused=true;ui.game.power_step();ui._refresh();await settle()
	check("13.2 → 12.0초" in texts(ui.body),"paused factory preview includes its own load when it resumes")
	machine.paused=false;ui.game.power_step()
	# The displayed prediction must match the actual upgraded cycle, not merely a formula.
	button=purchase(ui,"생산 ·")
	if button!=null:ui.busy=false;button.pressed.emit();await settle();ui.busy=true
	check(machine.level==2,"touch purchase applies the displayed production upgrade")
	ui.game.power_step()
	var elapsed=0.0
	while ui.game.produced("machinePart")==0 and elapsed<30:ui.game.tick();elapsed+=Factory.DT
	check(elapsed>=11.9625-0.00001 and elapsed<11.9625+Factory.DT,"brownout upgrade actually completes in the displayed twelve seconds")
	machine.level=1;gen.level=20;gen.managerLevel=0;ui.game.power_step();ui._refresh();await settle()
	check("6.6 → 5.9초" in texts(ui.body),"open upgrade card refreshes after grid capacity changes")
	gen.paused=true;ui.game.power_step();ui._refresh();await settle()
	check("전력 대기" in texts(ui.body) and not "inf" in texts(ui.body),"zero-power previews never promise impossible cycle times")
	print("UPGRADE_ACCURACY: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
