extends RefCounted
const INTERVAL=20.0
var source={}
var from_s=0.0
var bucket=-1.0
var value=-1.0
func rate(game) -> float:
	var elapsed=float(game.state.clock.elapsedS)
	if not is_same(source,game.state):
		source=game.state;from_s=ceil(maxf(0,elapsed-60)/INTERVAL)*INTERVAL;bucket=-1;value=-1
	var end=floor(elapsed/INTERVAL)*INTERVAL
	if end==bucket:return value
	bucket=end
	var start=maxf(from_s,end-(60 if game.world_mode() else 40))
	if end<=start:value=-1;return value
	var earned=0
	for sale in game.state.recentSales:
		if sale.atS>=start and sale.atS<end and sale.mode!="shipment":earned+=sale.cash
	value=earned*60.0/(end-start)
	return value
