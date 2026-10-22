extends SceneTree
var Art=load("res://scripts/ui/pixel_art.gd")
var View=load("res://scripts/ui/conveyor_view.gd")
const Factory=preload("res://scripts/core/factory.gd")
const Fixture=preload("res://tests/world_fixture.gd")
var checks=0
var failures=0
func check(value,message):
	checks+=1
	if not value:failures+=1;printerr("FAIL: "+message)
func rotated(mask:int)->int:return ((mask<<1)&15)|(mask>>3)
func same_rotated(a:Image,b:Image)->bool:
	for y in range(32):
		for x in range(32):
			if a.get_pixel(x,y)!=b.get_pixel(31-y,x):return false
	return true
func _initialize():
	if not Art.new().has_method("conveyor_image"):
		check(false,"connection-mask art API exists");quit(1);return
	for mask in range(16):
		var outputs=[]
		for d in range(4):
			if mask&(1<<d):outputs.append(d)
		for frame in [0,1,5,8]:
			var im=Art.conveyor_image(mask,outputs,frame)
			check(im.get_size()==Vector2i(32,32),"mask %d has native 32px art"%mask)
			var edges_ok=true
			for p in range(32):
				for d in range(4):
					var at=[Vector2i(p,0),Vector2i(31,p),Vector2i(p,31),Vector2i(0,p)][d]
					var visible=im.get_pixelv(at).a>0
					if visible != (bool(mask&(1<<d)) and p>=9 and p<=22):edges_ok=false
			check(edges_ok,"mask %d only opens declared edges at frame %d"%[mask,frame])
			var turned=[]
			for d in outputs:turned.append((d+1)%4)
			check(same_rotated(im,Art.conveyor_image(rotated(mask),turned,frame)),"mask %d rotates exactly at frame %d"%[mask,frame])
			check(im.get_pixel(0,0).a==0 and im.get_pixel(31,31).a==0,"terrain remains visible around mask %d"%mask)
		for d in outputs:
			check(same_rotated(Art.conveyor_image(mask,[d],3),Art.conveyor_image(rotated(mask),[(d+1)%4],3)),"directed mask %d rotates output %d"%[mask,d])
	var elbow=Art.conveyor_image(3,[1],0)
	check(elbow.get_pixel(9,22).a==0 and elbow.get_pixel(21,10).a>0,"elbow follows a curved bed without phantom branches")
	var junction=Art.conveyor_image(15,[1],0)
	var split=Art.conveyor_image(15,[0,1],0)
	check(junction.get_data()!=split.get_data(),"split output directions have distinct visible markers")
	var g=Factory.new();Fixture.connected(g)
	var e=g.create_entity("splitter",70,70,{"direction":1,"splitDirections":[0,2]})
	g.create_entity("belt",69,70,{"direction":1})
	g.create_entity("belt",70,69,{"direction":2})
	g.create_entity("belt",71,70,{"direction":1})
	check(View.ports_mask(g,e)==13,"splitter mask uses actual outputs and connected inputs, without phantom direction")
	check(View.inputs(g,e)==[0,3],"existing input discovery stays compatible")
	check(View.duration(g,e)<=g.DT*0.88,"incoming motion finishes before another simulation transfer")
	print("CONVEYOR SHAPES: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
