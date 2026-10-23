extends SceneTree
const Fixture=preload("res://tests/world_fixture.gd")
const Factory=preload("res://scripts/core/factory.gd")
var failures=0
var checks=0
func check(v,s):checks+=1;if not v:failures+=1;printerr("FAIL: "+s)
func _initialize():
	check(ResourceLoader.exists("res://scripts/ui/income_meter.gd"),"income uses completed reporting windows")
	if failures:quit(1);return
	var meter=load("res://scripts/ui/income_meter.gd").new();var g=Factory.new();Fixture.empty(g)
	check(meter.rate(g)<0,"fresh city shows gathering data instead of a false extrapolated rate")
	g.command({"type":"build","kind":"forest","x":62,"y":64});g.advance(20)
	var first_rate=meter.rate(g)
	check(first_rate==floor(20/g.data.facilities.forest.cycle)*g.price("log")*3,"income reflects actual completed production")
	var stable=true
	for i in range(79):g.advance(0.25);stable=stable and meter.rate(g)==first_rate
	check(stable,"rate stays fixed between completed reporting windows despite individual sales")
	g.advance(0.25);var expected=0
	for sale in g.state.recentSales:
		if sale.atS<40:expected+=sale.cash
	check(meter.rate(g)==expected*60.0/40,"next completed window measures real cash")
	g.command({"type":"pause","entityId":"e1"});g.advance(20)
	check(meter.rate(g)==expected,"recent average reflects a genuine production stoppage")
	g.advance(40);check(meter.rate(g)==0,"stopped production eventually reports zero")
	Fixture.empty(g);check(meter.rate(g)<0,"new city does not inherit the old city's income estimate")
	print("INCOME: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
