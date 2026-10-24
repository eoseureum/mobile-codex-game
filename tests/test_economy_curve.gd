extends SceneTree
const F=preload("res://scripts/core/factory.gd")
var checks=0
var failures=0
func check(ok,message):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+message)
func _initialize():
	var g=F.new()
	check(g.price("log")==35 and g.data.facilities.sawmill.cost==700,"preserve deliberate opening scarcity and first sawmill investment")
	check(g.price("iron")/float(g.price("copper"))<=20,"raw iron no longer makes a hundredfold sale jump")
	check(g.data.facilities.launchpad.cost>=1000000000,"rocket construction retains billion-scale money")
	check(g.data.facilities.launchpad.cost/float(g.price("precision"))>=60,"twenty precision sales cannot pay for the entire launchpad")
	for kind in ["copperSmelter","ironSmelter","wireFactory","partsFactory","structureFactory","electronicsFactory","precisionFactory","refinery"]:
		var f=g.data.facilities[kind];var input_value=0;var output_value=0
		for r in f.input:input_value+=g.price(r)*f.input[r]
		for r in f.output:output_value+=g.price(r)*f.output[r]
		check(output_value>input_value,kind+" retains positive processing margin")
	for pair in [["machinePart","structure"],["structure","electronics"],["electronics","precision"]]:
		check(g.price(pair[1])/float(g.price(pair[0]))<=12,"new advanced product step stays within twelvefold: "+pair[1])
	var resources=["machinePart","structure","electronics","precision","fuel"]
	for r in resources:print(r," unit ",g.money(g.price(r)))
	print("ECONOMY_CURVE: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
