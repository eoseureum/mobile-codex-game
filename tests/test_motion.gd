extends SceneTree
const Factory=preload("res://scripts/core/factory.gd")
const Art=preload("res://scripts/ui/pixel_art.gd")
const Fixture=preload("res://tests/world_fixture.gd")
var checks=0
var failures=0
func check(value,message):
	checks+=1
	if not value:failures+=1;printerr("FAIL: "+message)
func _initialize():
	check(ResourceLoader.exists("res://scripts/ui/facility_motion.gd"),"facility motion follows actual production progress")
	if failures:quit(1);return
	var Motion=load("res://scripts/ui/facility_motion.gd")
	var g=Factory.new();Fixture.connected(g);g.advance(0.5)
	var normal=Motion.phase(g,g.state.entities.e1)
	check(is_equal_approx(normal,0.125),"four second logging advances one eighth of its animation in half a second")
	Fixture.connected(g);g.state.entities.e1.level=5;g.advance(0.5)
	check(is_equal_approx(Motion.phase(g,g.state.entities.e1),normal*g.speed(g.state.entities.e1)),"production upgrade speeds animation by the same ratio as crafting")
	var prior=Motion.phase(g,g.state.entities.e1);g.advance(0.125)
	check(is_equal_approx(Motion.phase(g,g.state.entities.e1)-prior,0.125*g.speed(g.state.entities.e1)/4.0),"animation interpolates smoothly between simulation ticks")
	g.state.entities.e1.paused=true
	check(Motion.phase(g,g.state.entities.e1)<0,"paused facility has no running animation")
	Fixture.connected(g)
	check(Motion.phase(g,g.state.entities.e2)<0,"sawmill without input stays idle")
	g.state.entities.e1.outputs.log=g.capacity(g.state.entities.e1)
	check(Motion.phase(g,g.state.entities.e1)<0,"full output prevents a new animation cycle")
	var machine=g.create_entity("partsFactory",68,64)
	var cycle=g.recipe(machine).cycle
	machine.job={"remaining":cycle,"output":{"machinePart":1},"reserved":{}}
	g.state.clock.carryS=0.125;g.state.power.ratio=1
	var full_power=Motion.phase(g,machine);g.state.power.ratio=0.5
	check(is_equal_approx(Motion.phase(g,machine),full_power*0.5),"power shortage slows animation with production")
	g.state.power.ratio=0
	check(Motion.phase(g,machine)<0,"no power stops powered machinery")
	check(Motion.phase(g,g.state.entities.e4)<0,"empty conveyor has no working animation")
	g.state.entities.e4.queue=["log"]
	check(Motion.phase(g,g.state.entities.e4)>=0,"loaded conveyor feeding a facility runs")
	g.state.entities.e2.paused=true
	check(Motion.phase(g,g.state.entities.e4)<0,"blocked conveyor stops")
	Fixture.connected(g);g.advance(180)
	g.command({"type":"takeOrder","offerId":g.offers()[0].id});g.advance(0.25)
	g.state.entities.e3.inventory={};g.state.entities.e3.inputs={};g.state.entities.e3.outputs={}
	check(Motion.phase(g,g.state.entities.e3)>=0,"shipping depot animates while loading a real order")
	for kind in g.data.facilities:
		var frames={}
		for frame in range(1,9):frames[Art.image(kind,frame).get_data().hex_encode()]=true
		check(frames.size()>=4,"distinct working motion frames: "+kind)
		check(Art.image(kind,0).get_pixel(0,0).a==0,"facility sprite has transparent terrain corners: "+kind)
	check(Art.image("yard").get_pixel(0,0)==Art.image("grass").get_pixel(0,0),"facility ground matches grass instead of beige tiles")
	check(Art.texture("sawmill",0)!=Art.texture("sawmill",8),"idle and final working frame do not collide in texture cache")
	print("MOTION: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
