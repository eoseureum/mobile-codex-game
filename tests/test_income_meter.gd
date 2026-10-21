extends SceneTree
const Factory=preload("res://scripts/core/factory.gd")
var failures=0
var checks=0
func check(v,s):checks+=1;if not v:failures+=1;printerr("FAIL: "+s)
func _initialize():
	check(ResourceLoader.exists("res://scripts/ui/income_meter.gd"),"income uses completed reporting windows")
	if failures:quit(1);return
	var meter=load("res://scripts/ui/income_meter.gd").new();var g=Factory.new();g.fresh(0,true,42)
	check(meter.rate(g)<0,"fresh city shows gathering data instead of a false extrapolated rate")
	g.command({"type":"build","kind":"forest","x":62,"y":64});g.advance(20)
	check(meter.rate(g)==750,"twenty seconds of real logging income reports 750 per minute")
	var stable=true
	for i in range(79):g.advance(0.25);stable=stable and meter.rate(g)==750
	check(stable,"rate stays fixed between completed reporting windows despite individual sales")
	g.advance(0.25);check(meter.rate(g)==750,"next completed window preserves steady production income")
	g.command({"type":"pause","entityId":"e1"});g.advance(20)
	check(meter.rate(g)==500,"recent average reflects a genuine production stoppage")
	g.advance(40);check(meter.rate(g)==0,"stopped production eventually reports zero")
	g.fresh(0,true,42);check(meter.rate(g)<0,"new city does not inherit the old city's income estimate")
	print("INCOME: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
