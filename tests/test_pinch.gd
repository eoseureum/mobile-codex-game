extends SceneTree
const City=preload("res://scripts/ui/city_map.gd")
const Factory=preload("res://scripts/core/factory.gd")
var checks=0
var failures=0
var selections=[]
var city
func check(v,s):checks+=1;if not v:failures+=1;printerr("FAIL: "+s)
func _initialize():call_deferred("run")
func finger(id,p,down,canceled=false):
	var e=InputEventScreenTouch.new();e.index=id;e.position=p;e.pressed=down;e.canceled=canceled;Input.parse_input_event(e);await process_frame
func move(id,p):
	var e=InputEventScreenDrag.new();e.index=id;e.position=p;Input.parse_input_event(e);await process_frame
func world_at(p):return (p-city.camera)/(city.tile_size*city.zoom)
func run():
	root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(800,600)
	city=City.new();city.game=Factory.new();root.add_child(city);city.size=Vector2(800,600);city.focus_point(Vector2i(64,64));city.tile_pressed.connect(func(p):selections.append(p));await process_frame
	var anchor=world_at(Vector2(350,250))
	await finger(0,Vector2(250,250),true);await finger(1,Vector2(450,250),true);await move(1,Vector2(550,250))
	check(is_equal_approx(city.zoom,1.5),"spreading two fingers increases map scale by their distance ratio")
	check(world_at(Vector2(400,250)).distance_to(anchor)<0.02,"the midpoint's world location remains under the moving fingers")
	await move(1,Vector2(350,250));check(is_equal_approx(city.zoom,0.5),"bringing fingers together zooms out continuously")
	await finger(1,Vector2(350,250),false)
	var camera=city.camera;await move(0,Vector2(270,280))
	check(city.camera.distance_to(camera+Vector2(20,30))<1,"remaining finger continues panning without a jump")
	await finger(0,Vector2(270,280),false);check(selections.is_empty(),"releasing a pinch never selects a tile")
	await finger(0,Vector2(300,300),true);await finger(0,Vector2(300,300),false)
	check(selections.size()==1,"one touch still selects exactly once with mouse emulation enabled")
	camera=city.camera;await finger(0,Vector2(300,300),true);await move(0,Vector2(340,330));await finger(0,Vector2(340,330),false)
	check(city.camera.distance_to(camera+Vector2(40,30))<1 and selections.size()==1,"one finger pans without selecting on release")
	camera=city.camera;await finger(0,Vector2(300,300),true);await move(0,Vector2(304,300))
	check(city.camera==camera,"small finger tremor does not pan the map")
	await move(0,Vector2(312,300));await finger(0,Vector2(312,300),false)
	check(city.camera.distance_to(camera+Vector2(12,0))<1,"crossing the drag threshold preserves the full finger displacement")
	await finger(0,Vector2(300,300),true);await finger(0,Vector2(300,300),false,true)
	check(selections.size()==1,"canceled touch cannot issue a tile action")
	await finger(0,Vector2(300,200),true);await finger(1,Vector2(320,200),true);await move(1,Vector2(700,200))
	check(is_equal_approx(city.zoom,1.7),"pinching respects maximum zoom")
	await move(1,Vector2(300.2,200));check(is_equal_approx(city.zoom,0.025),"pinching respects minimum zoom and nearly coincident fingers")
	await finger(1,Vector2(300.2,200),false);await finger(0,Vector2(300,200),false)
	var overlay=Button.new();overlay.position=Vector2(500,350);overlay.size=Vector2(200,150);root.add_child(overlay);await process_frame
	await finger(0,Vector2(250,250),true);await finger(1,Vector2(450,250),true);await move(1,Vector2(550,400));await finger(1,Vector2(550,400),false);await finger(0,Vector2(250,250),false)
	await finger(0,Vector2(300,300),true);await finger(0,Vector2(300,300),false)
	check(selections.size()==2,"lifting over a floating card ends the gesture and does not leave touch state stuck")
	var old=city.zoom;await finger(0,Vector2(250,250),true);await finger(1,Vector2(550,400),true);await move(1,Vector2(600,400));await finger(1,Vector2(600,400),false);await finger(0,Vector2(250,250),false)
	check(city.zoom==old and selections.size()==2,"a second finger starting on a card neither zooms the map nor causes an accidental tile action")
	city.zoom=1;city.clamp_camera();anchor=world_at(Vector2(250,250))
	var hover=InputEventMouseMotion.new();hover.position=Vector2(250,250);Input.parse_input_event(hover);await process_frame
	var magnify=InputEventMagnifyGesture.new();magnify.position=Vector2(250,250);magnify.factor=1.2;city._gui_input(magnify);await process_frame
	check(is_equal_approx(city.zoom,1.2) and world_at(Vector2(250,250)).distance_to(anchor)<0.02,"native magnify gesture uses its own cursor position")
	var count=selections.size();await finger(0,Vector2(250,250),true);await finger(1,Vector2(450,250),true)
	city._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await finger(1,Vector2(450,250),false);await finger(0,Vector2(250,250),false)
	check(selections.size()==count,"losing focus cancels a gesture without a pending tile action")
	await finger(0,Vector2(300,300),true);await finger(0,Vector2(300,300),false)
	check(selections.size()==count+1,"touch selection recovers after focus loss")
	print("PINCH: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
