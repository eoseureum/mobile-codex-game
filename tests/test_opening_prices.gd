extends SceneTree
const Factory=preload("res://scripts/core/factory.gd")
const Store=preload("res://scripts/core/save_store.gd")
const World=preload("res://scripts/core/world_map.gd")
var checks=0
var failures=0
func check(v,m):
	checks+=1
	if not v:failures+=1;printerr("FAIL: "+m)
func _initialize():
	var g=Factory.new();g.fresh(0,true,42)
	var f=g.data.facilities
	check(f.sawmill.cost>=500 and f.sawmill.cost<=800,"sawmill sits in requested500–800 price band")
	check(g.command({"type":"build","kind":"forest","x":62,"y":64})=="OK" and g.state.cash==0,"initial cash still funds only first logging camp")
	g.advance(150)
	var quote=World.linked_quote(g,"e1","sawmill",{"x":64,"y":64})
	check(quote.ok and g.affordable(quote.cash,quote.materials),"actual log sales can fund connected sawmill within150seconds")
	if not g.affordable(quote.cash,quote.materials):finish();return
	var spent=int(quote.cash)
	check(g.command({"type":"buildLinked","sourceId":"e1","kind":"sawmill","x":64,"y":64})=="OK","first mill uses real paid construction")
	quote=World.linked_quote(g,g.at(64,64).id,"warehouse",{"x":66,"y":64})
	while g.state.clock.elapsedS<330 and not g.affordable(quote.cash,quote.materials):g.tick()
	check(g.affordable(quote.cash,quote.materials),"partial line funds its shipping warehouse before330seconds")
	if not g.affordable(quote.cash,quote.materials):finish();return
	spent+=int(quote.cash)
	g.command({"type":"buildLinked","sourceId":g.at(64,64).id,"kind":"warehouse","x":66,"y":64})
	while g.state.clock.elapsedS<360 and not g.recorded("first_auto_sale"):g.tick()
	check(g.recorded("first_auto_sale"),"unassisted factory reaches actual plank sales within sixminutes")
	check(g.state.cash==g.state.totals.earned-spent,"opening discount never injects extra money")
	check(Store.new().validate(Store.new().snapshot(g)).is_empty(),"paid discounted opening remains save-compatible")
	print("OPENING_PRICE_TIMING: %.2f seconds / spent%d / earned%d"%[g.state.clock.elapsedS,spent,g.state.totals.earned])
	finish()
func finish():
	print("OPENING_PRICES: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
