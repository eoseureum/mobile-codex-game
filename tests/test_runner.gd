extends SceneTree
const Factory = preload("res://scripts/core/factory.gd")
var failures=0
var checks=0
func check(ok,message):
	checks+=1
	if not ok: failures+=1; printerr("FAIL: "+message)
func _initialize():
	var started=Time.get_ticks_msec()
	var game=Factory.new()
	game.fresh(0,false)
	check(game.state.cash==500,"starts with 500 won")
	check(game.command({"type":"build","kind":"sawmill","x":1,"y":1})=="INSUFFICIENT_CASH","cannot buy another sawmill at the start")
	game.advance(36)
	check(game.affordable(1500,{"plank":6}),"sawmill becomes affordable after actual production")
	game.fresh(0,false)
	game.advance(120)
	check(game.produced("plank")>60 and game.state.bag.plank>=20,"automatic production protects reserves")
	check(game.command({"type":"feed","entityId":"e2","resource":"log"})=="INVALID","manual feeding unavailable")
	check(game.command({"type":"demolish","entityId":"e1"})=="PROTECTED","starter cannot be demolished")
	var trace=JSON.parse_string(FileAccess.get_file_as_string("res://tests/reference_campaign.json"))
	game.fresh(0,false)
	for c in trace.commands:
		while game.state.clock.elapsedS<c.atS: game.tick()
		var result=game.command(c)
		check(result=="OK","paid campaign %s at %s: %s" % [c.type,c.atS,result])
		if result!="OK": break
	check(game.state.rocket.launched==1,"full paid native factory reaches rocket")
	check(game.state.cash==trace.expected.cash,"rocket cash equals original factory")
	check(JSON.parse_string(JSON.stringify(game.state.totals.produced))==trace.expected.totals.produced,"all produced materials equal original factory")
	check(JSON.parse_string(JSON.stringify(game.state.totals.sold))==trace.expected.totals.sold,"all sold materials equal original factory")
	check(game.state.records==trace.expected.records,"industry milestones equal original factory")
	check(JSON.parse_string(JSON.stringify(game.state.rocket))==trace.expected.rocket,"rocket deliveries equal original factory")
	var Store=load("res://scripts/core/save_store.gd")
	var store=Store.new()
	var encoded=store.export_text(game)
	var imported=store.parse(encoded)
	check(not imported.is_empty(),"native factory save validates: "+store.last_error)
	if not imported.is_empty():check(imported.state.cash==game.state.cash,"backup keeps exact billion balance")
	check(store.parse("{}").is_empty(),"invalid backup rejected")
	var altered=JSON.parse_string(encoded)
	altered.state.cash=-1
	check(not store.validate(altered).is_empty(),"negative money rejected")
	altered=JSON.parse_string(encoded)
	altered.state.factory.trade.active={"resource":"plank","id":"plank:8","quantity":8,"reward":999999999,"bonus":1.0,"loaded":0,"reserved":0,"departureS":5,"loadingCredit":0}
	check(not store.validate(altered).is_empty(),"spoofed order rejected")
	for field in ["missing_job","elapsed_string","missing_active","missing_offer"]:
		altered=JSON.parse_string(encoded)
		match field:
			"missing_job":altered.state.entities.e1.erase("job")
			"elapsed_string":altered.state.clock.elapsedS="bad"
			"missing_active":altered.state.factory.trade.erase("active")
			"missing_offer":altered.state.factory.trade.erase("lastOfferId")
		check(store.parse(JSON.stringify(altered)).is_empty(),"malformed import rejected: "+field)
	var clone=Factory.new()
	clone.state=imported.state
	game.advance(120);clone.advance(120)
	check(JSON.parse_string(JSON.stringify(game.state))==JSON.parse_string(JSON.stringify(clone.state)),"save reload preserves next 120 seconds exactly")
	for item in [[10000,"10K"],[1000000,"1M"],[7500000000,"7.5B"]]:check(Factory.money(item[0])==item[1],"currency formatting "+item[1])
	game.fresh(0,false)
	game.advance(180)
	var offer=game.offers()[0]
	check(game.command({"type":"takeOrder","offerId":offer.id})=="OK","order accepts earned stock")
	game.command({"type":"setReserve","resource":offer.resource,"quantity":0})
	game.advance(2)
	var cargo=game.trade().active.loaded+game.trade().active.reserved
	check(cargo>0,"cancellation test actually has cargo")
	var before=game.state.bag.get(offer.resource,0)
	check(game.command({"type":"cancelOrder"})=="OK" and game.state.bag.get(offer.resource,0)==before+cargo,"cancelling returns exact cargo")
	print("%d checks, %d failures, %d ms"%[checks,failures,Time.get_ticks_msec()-started])
	quit(1 if failures else 0)
