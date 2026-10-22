extends SceneTree
const World=preload("res://scripts/core/world_map.gd")
const Factory=preload("res://scripts/core/factory.gd")
const Store=preload("res://scripts/core/save_store.gd")
var failures=0
var checks=0
func check(v,s):checks+=1;if not v:failures+=1;printerr("FAIL: "+s)
func _initialize():
	for seed in [1,42,98]:
		var w=World.generate(seed);var touching=0;var counts={}
		for pos in w.nodes:
			var p=World.parse_key(pos);counts[w.nodes[pos]]=counts.get(w.nodes[pos],0)+1
			for dy in range(-1,2):
				for dx in range(-1,2):
					if (dx!=0 or dy!=0) and w.nodes.has(World.key(p.x+dx,p.y+dy)):touching+=1
		check(touching==0,"natural resources have an empty tile between them, including diagonals")
		check(w.nodes.size()>=900 and w.nodes.size()<=1400,"scattering retains enough individual production sites")
		for r in World.NODE_TYPES:check(counts.get(r,0)>=60,"all industries have distributed sources: "+r)
		check(w.nodes==World.generate(seed).nodes,"scatter remains deterministic")
	if failures:quit(1);return
	var g=Factory.new();g.fresh(0,true,42);g.command({"type":"build","kind":"forest","x":62,"y":64});g.advance(160)
	g.command({"type":"buildLinked","kind":"sawmill","sourceId":"e1","x":64,"y":64})
	g.command({"type":"clearArea","from":{"x":59,"y":69},"to":{"x":59,"y":69}})
	g.state.world.erase("scatterVersion")
	for y in range(90,93):
		for x in range(90,93):g.state.world.nodes[World.key(x,y)]="log"
	var prior=JSON.parse_string(JSON.stringify(g.state));var store=Store.new();var restored=store.parse(store.export_text(g))
	check(not restored.is_empty(),"existing city loads after safe terrain redistribution")
	if restored.is_empty():quit(1);return
	var s=restored.state
	check(s.world.get("scatterVersion")==2,"old clustered save adopts scattered natural resources")
	for field in ["cash","entities","totals","rocket","bag","records","factory"]:check(s[field]==prior[field],"redistribution preserves "+field)
	check(not s.world.nodes.has("59,69") and s.world.cleared.has("59,69"),"cleared land never regrows")
	check(s.world.nodes.get("62,64")=="log" and not s.world.nodes.has("64,64"),"production sources and occupied construction ground are preserved")
	check(store.validate(restored).is_empty(),"redistributed save validates")
	print("SCATTER: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
