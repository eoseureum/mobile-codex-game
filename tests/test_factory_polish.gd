extends SceneTree
const Factory=preload("res://scripts/core/factory.gd")
const Store=preload("res://scripts/core/save_store.gd")
var checks=0
var failures=0
func check(v,m):
	checks+=1
	if not v:failures+=1;printerr("FAIL: "+m)
func _initialize():
	var g=Factory.new();g.fresh(0,true,42)
	check(g.command({"type":"build","kind":"forest","x":62,"y":64})=="OK","paid first camp")
	var e=g.at(62,64);g.state.cash=10000;g.state.bag={}
	var before=g.state.cash
	check(g.command({"type":"upgrade","entityId":e.id})=="OK","production needs only cash")
	check(g.state.cash==before-g.data.facilities.forest.upgradeCosts[0] and g.stock("plank")==0,"exact upgrade cash debit")
	check(g.command({"type":"upgradeIncome","entityId":e.id})=="OK","pioneer can improve sales before sawmill")
	before=g.state.cash;g.advance(g.data.facilities.forest.cycle)
	check(g.state.cash-before==g.sale_price(e,"log"),"onsite sale uses improved price")
	g.event("first_auto_sale")
	check(g.command({"type":"upgradeManager","entityId":e.id})=="OK","manager needs only cash")
	check(g.command({"type":"demolish","entityId":e.id})=="OK","first camp removable")
	check(g.state.factory.pioneerForestId=="" and g.state.cash>=g.data.facilities.forest.cost,"last camp removal allows recovery")
	var store=Store.new();check(store.validate(store.snapshot(g)).is_empty(),"demolished city saves with history")
	check(g.command({"type":"build","kind":"forest","x":62,"y":64})=="OK","rebuild without inaccessible material")
	var belt=g.create_entity("belt",63,64,{"investedCash":100});belt.queue=["log","plank"]
	before=g.state.cash
	check(g.command({"type":"rotate","entityId":belt.id,"direction":2})=="OK" and belt.queue==["log","plank"] and g.state.cash==before,"loaded rotation preserves units and cash")
	var newgame=Factory.new();newgame.fresh(0,true,42);newgame.command({"type":"build","kind":"forest","x":62,"y":64})
	for i in range(3):
		newgame.command({"type":"demolish","entityId":newgame.at(62,64).id})
		check(newgame.state.cash==2250,"recovery refund never creates profit")
		newgame.command({"type":"build","kind":"forest","x":62,"y":64})
	var legacy=Factory.new();load("res://tests/world_fixture.gd").connected(legacy)
	var depot=legacy.state.entities.e3;depot.inventory={"log":50}
	legacy.state.totals.produced.log=50
	var old_quote=legacy.quotes("log")[0].duplicate(true)
	old_quote.reward=ceil(legacy.legacy_data.resources.log.price*old_quote.quantity*1.3)
	legacy.trade().active=old_quote;legacy.trade().lastOfferId=old_quote.id
	old_quote.merge({"loaded":2,"reserved":3,"departureS":5.0,"loadingCredit":0.0})
	check(store.validate(store.snapshot(legacy)).is_empty(),"pre-balance accepted order keeps its promised reward")
	var total=legacy.stock("log")+5
	check(legacy.command({"type":"demolish","entityId":depot.id})=="OK","active shipping warehouse removable")
	check(legacy.trade().active==null and not legacy.trade().repeat and legacy.stock("log")==total,"demolition returns loaded cargo exactly once")
	check(store.validate(store.snapshot(legacy)).is_empty(),"populated old world survives original warehouse demolition")
	check(legacy.command({"type":"demolish","entityId":"e2"})=="OK","original old sawmill removable")
	check(store.validate(store.snapshot(legacy)).is_empty(),"old original IDs no longer required after demolition")
	var old_camp=legacy.state.entities.e1
	check(legacy.command({"type":"demolish","entityId":old_camp.id})=="OK","original gifted camp can be moved")
	check(legacy.state.cash>=legacy.data.facilities.forest.cost,"gifted legacy camp also leaves a recoverable city")
	check(legacy.command({"type":"build","kind":"forest","x":62,"y":64})=="OK","legacy camp rebuild uses its recovered construction value")
	check(store.validate(store.snapshot(legacy)).is_empty(),"legacy city saves after all original buildings removed")
	var untouched=Factory.new();load("res://tests/world_fixture.gd").connected(untouched);untouched.state.cash=0
	check(untouched.command({"type":"demolish","entityId":"e1"})=="OK","legacy camp may be the first demolished building")
	check(untouched.state.cash==2250,"untouched legacy camp refunds recovery value before assigning new pioneer")
	check(untouched.command({"type":"buildRoute","from":{"x":64,"y":64},"to":{"x":64,"y":65}})=="OK","existing factory can be rerouted without a logging camp")
	check(untouched.command({"type":"clearArea","from":{"x":59,"y":69},"to":{"x":59,"y":69}})=="OK","remaining city can clear terrain without a logging camp")
	check(store.validate(store.snapshot(untouched)).is_empty(),"forest-free factory save remains valid")
	var restart=Factory.new();restart.fresh(0,true,42)
	restart.command({"type":"build","kind":"forest","x":62,"y":64});restart.advance(300)
	check(restart.command({"type":"buildLinked","sourceId":"e1","kind":"sawmill","x":64,"y":64})=="OK","recovery test pays for first processing line")
	restart.command({"type":"demolish","entityId":restart.at(64,64).id});restart.advance(600)
	check(restart.stock("plank")==0 and restart.recorded("first_sawmill"),"removed first mill has history but no planks")
	check(restart.construction_materials("sawmill").is_empty(),"replacement bootstrap does not require its own product")
	var suggestion=load("res://scripts/ui/opening_ux.gd").suggestion(restart,restart.at(62,64))
	check(suggestion.get("kind","")=="sawmill","missing mill visibly offers processing recovery")
	check(restart.command({"type":"build","kind":"sawmill","x":64,"y":64})=="OK","last sawmill can be rebuilt with money")
	check(not restart.construction_materials("sawmill").is_empty(),"additional mills still require construction materials")
	check(store.validate(store.snapshot(restart)).is_empty(),"restarted processing line saves")
	print("FACTORY_POLISH: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
