extends Control
signal tile_pressed(tile: Vector2i)
const World=preload("res://scripts/core/world_map.gd")
const Art=preload("res://scripts/ui/pixel_art.gd")
const Conveyor=preload("res://scripts/ui/conveyor_view.gd")
const Motion=preload("res://scripts/ui/facility_motion.gd")
var game
var zoom=1.0
var tile_size=96.0
var camera=Vector2.ZERO
var selection=Vector2i(0,0)
var building=""
var preview_path=[]
var preview_clear=[]
var preview_area=Rect2i()
var work_origin=Vector2i(-1,-1)
var pressed=false
var dragging=false
var press_at=Vector2.ZERO
var last_at=Vector2.ZERO
var touch_points={}
var active_fingers={}
var touch_origin=Vector2.ZERO
var touch_moved=false
var suppress_touch_tap=false
var particles=[]
var opportunity={}
var sale_bubbles=[]
var sale_state={}
var last_sale_time=-1.0
var font: Font
const INK=Color("443d3c")

func _ready():
	mouse_default_cursor_shape=Control.CURSOR_DRAG
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents=true
	font=load("res://assets/fonts/RustCity.otf")
func focus_district(id="forest"):
	if game==null:return
	if game.world_mode():
		zoom=clampf(size.x/(tile_size*6),0.5,1.0)
		focus_point(Vector2i(int(game.state.world.spawn.x),int(game.state.world.spawn.y)));return
	var d=game.data.districts[id]
	var n=maxf(3,game.state.districts[id].size)
	camera=(size*Vector2(0.25 if size.x>size.y*1.3 else 0.5,0.47)-Vector2(d.x+n/2,d.y+n/2)*tile_size*zoom).round()
	queue_redraw()
func focus_point(tile:Vector2i):
	camera=(size*Vector2(0.25 if size.x>size.y*1.3 else 0.5,0.47)-(Vector2(tile)+Vector2.ONE*0.5)*tile_size*zoom).round()
	clamp_camera();queue_redraw()
func clamp_camera():
	if not game.world_mode():return
	var pad=tile_size*0.5
	camera.x=clampf(camera.x,size.x-World.SIZE*tile_size*zoom-pad,pad)
	camera.y=clampf(camera.y,size.y-World.SIZE*tile_size*zoom-pad,pad)
func zoom_by(delta):
	_zoom_between(size/2,size/2,zoom+delta)
func _zoom_between(before:Vector2,after:Vector2,value:float):
	if not is_finite(value):return
	var next=clampf(value,0.45,1.7)
	camera=after-(before-camera)*next/zoom
	zoom=next;clamp_camera();queue_redraw()
func _input(e):
	# Continue map gestures over floating controls, but start them only on the map.
	if e is InputEventScreenTouch:
		if e.pressed:
			active_fingers[e.index]=true
			if active_fingers.size()>1 and not touch_points.is_empty():suppress_touch_tap=true
		else:
			active_fingers.erase(e.index)
			if touch_points.has(e.index):
				_end_touch(e.index,get_global_transform_with_canvas().affine_inverse()*e.position,e.canceled)
				get_viewport().set_input_as_handled()
	elif e is InputEventScreenDrag and touch_points.has(e.index):
		_move_touch(e.index,get_global_transform_with_canvas().affine_inverse()*e.position)
		get_viewport().set_input_as_handled()
func _begin_touch(index,point):
	if touch_points.is_empty():
		touch_origin=point;touch_moved=false;suppress_touch_tap=active_fingers.size()>1
		pressed=false;dragging=false
	else:suppress_touch_tap=true
	touch_points[index]=point
func _move_touch(index,point):
	if touch_points.size()>=2:
		var pair=touch_points.keys();var a=touch_points[pair[0]];var b=touch_points[pair[1]]
		var before=(a+b)*0.5;var distance=a.distance_to(b)
		touch_points[index]=point;a=touch_points[pair[0]];b=touch_points[pair[1]]
		var next=zoom*a.distance_to(b)/distance if distance>1 else zoom
		_zoom_between(before,(a+b)*0.5,next)
	else:
		var movement=point-touch_points[index]
		if not touch_moved and point.distance_to(touch_origin)>8*tile_size/96.0:
			touch_moved=true;movement=point-touch_origin
		if touch_moved:camera+=movement;clamp_camera();queue_redraw()
		touch_points[index]=point
func _end_touch(index,point,canceled):
	var tap=touch_points.size()==1 and not suppress_touch_tap and not touch_moved and not canceled and point.distance_to(touch_origin)<=8*tile_size/96.0
	touch_points.erase(index)
	if tap:
		var world=(point-camera)/(tile_size*zoom)
		tile_pressed.emit(Vector2i(floori(world.x),floori(world.y)))
	if touch_points.is_empty():suppress_touch_tap=false;touch_moved=false
	elif touch_points.size()==1:touch_origin=touch_points.values()[0];touch_moved=true
func _notification(what):
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		touch_points.clear();active_fingers.clear();pressed=false;dragging=false;suppress_touch_tap=true
func _gui_input(e):
	if e is InputEventScreenTouch and e.pressed:
		_begin_touch(e.index,e.position);accept_event();return
	if e is InputEventMagnifyGesture:
		if touch_points.is_empty():_zoom_between(e.position,e.position,zoom*e.factor)
		pressed=false;accept_event();return
	if e is InputEventMouse and (e.device==InputEvent.DEVICE_ID_EMULATION or not touch_points.is_empty()):
		accept_event();return
	if e is InputEventMouseButton:
		if e.button_index==MOUSE_BUTTON_WHEEL_UP and e.pressed:zoom_by(0.1);accept_event()
		if e.button_index==MOUSE_BUTTON_WHEEL_DOWN and e.pressed:zoom_by(-0.1);accept_event()
		if e.button_index==MOUSE_BUTTON_LEFT:
			if e.pressed:pressed=true;dragging=false;press_at=e.position;last_at=e.position
			elif pressed:
				pressed=false
				if not dragging:
					var world=(e.position-camera)/(tile_size*zoom)
					tile_pressed.emit(Vector2i(floori(world.x),floori(world.y)))
			accept_event()
	if e is InputEventMouseMotion and pressed:
		if e.position.distance_to(press_at)>8*tile_size/96.0:dragging=true
		if dragging:camera+=e.position-last_at;clamp_camera();queue_redraw()
		last_at=e.position
		accept_event()
func record_transfers():
	if not is_same(sale_state,game.state):sale_state=game.state;last_sale_time=game.state.clock.elapsedS-game.DT-0.000001;sale_bubbles=[];particles=[]
	for sale in game.sales:
		if sale.atS<=last_sale_time or not game.state.entities.has(sale.get("entityId","")):continue
		var e=game.state.entities[sale.entityId]
		if sale_bubbles.size()<16:sale_bubbles.append({"at":Vector2(e.x+0.5,e.y+0.1),"cash":sale.cash,"age":0.0})
	last_sale_time=game.state.clock.elapsedS-game.DT
	for t in game.transfers:
		if particles.size()>=50:break
		if not game.state.entities.has(t.sourceId) or not game.state.entities.has(t.targetId):continue
		particles.append({"sourceId":t.sourceId,"targetId":t.targetId,"a":Vector2(game.state.entities[t.sourceId].x+0.5,game.state.entities[t.sourceId].y+0.5),"b":Vector2(game.state.entities[t.targetId].x+0.5,game.state.entities[t.targetId].y+0.5),"r":t.resource,"duration":Conveyor.duration(game,game.state.entities[t.sourceId]),"age":0.0})
func _process(delta):
	for p in particles:p.age+=delta
	particles=particles.filter(func(p):return p.age<p.duration)
	for p in sale_bubbles:p.age+=delta
	sale_bubbles=sale_bubbles.filter(func(p):return p.age<1.4)
	queue_redraw()
func tile_rect(x:int,y:int) -> Rect2:
	var a=(camera+Vector2(x,y)*tile_size*zoom).round()
	var b=(camera+Vector2(x+1,y+1)*tile_size*zoom).round()
	return Rect2(a,b-a)
func _sprite(kind:String,where:Rect2,frame=0):draw_texture_rect(Art.texture(kind,frame),where,false)
func _corners(r:Rect2,color:Color):
	var p=maxf(1,round(tile_size*zoom/32))
	var a=r.position;var b=r.end
	for corner in [Vector2(a.x,a.y),Vector2(b.x-7*p,a.y),Vector2(a.x,b.y-2*p),Vector2(b.x-7*p,b.y-2*p)]:draw_rect(Rect2(corner,Vector2(7*p,2*p)),color)
	for corner in [Vector2(a.x,a.y),Vector2(b.x-2*p,a.y),Vector2(a.x,b.y-7*p),Vector2(b.x-2*p,b.y-7*p)]:draw_rect(Rect2(corner,Vector2(2*p,7*p)),color)
func _item(resource,center,extent):
	var pixels=maxf(12,round(extent))
	var at=(center-Vector2.ONE*pixels*0.5).round()
	draw_texture_rect_region(Art.texture("item_"+resource),Rect2(at,Vector2.ONE*pixels),Rect2(2,3,28,28))
func _draw():
	if game==null:return
	draw_rect(Rect2(Vector2.ZERO,size),Color("a7ba7c"))
	var unit=tile_size*zoom
	var known={}
	if game.world_mode():
		for r in World.NODE_TYPES:known[r]=game.known_resource(r)
	var occupied={}
	for e in game.state.entities.values():occupied[Vector2i(int(e.x),int(e.y))]=true
	var selected_id=game.at(selection.x,selection.y).get("id","")
	var xmin=floori(-camera.x/unit)-1;var ymin=floori(-camera.y/unit)-1
	var xmax=ceili((size.x-camera.x)/unit)+1;var ymax=ceili((size.y-camera.y)/unit)+1
	for y in range(ymin,ymax):
		for x in range(xmin,xmax):
			var r=tile_rect(x,y)
			var owned=game.owned(x,y)
			var id=game.district_at(x,y) if x>=0 and y>=0 and x<18 and y<12 else ""
			var variant=posmod(x*13+y*7,4)
			_sprite("grass" if owned else "wild",r,variant)
			if game.world_mode():
				if owned and not occupied.has(Vector2i(x,y)):
					var resource=World.resource_at(game.state.world,x,y)
					if resource=="log":_sprite("tree",r)
					elif not resource.is_empty():_sprite("ore_"+(resource if known[resource] else "unknown"),r)
			else:
				if not owned:
					if id=="mines":_sprite("rock",r,variant)
					if posmod(x*17+y*31,9)==0:_sprite("tree",r.grow(-unit*0.12))

	for e in game.state.entities.values():
		var r=tile_rect(int(e.x),int(e.y))
		if not r.intersects(Rect2(Vector2.ZERO,size)):continue
		var anim=Motion.frame(Motion.phase(game,e))
		if game.transport(e):
			var outputs=e.splitDirections if e.kind=="splitter" else [int(e.direction)]
			draw_texture_rect(Art.conveyor_texture(Conveyor.ports_mask(game,e),outputs,anim),r,false)
			var incoming={}
			for flight in particles:
				if flight.targetId==e.id and flight.age<flight.duration:incoming[flight.r]=incoming.get(flight.r,0)+1
			for cargo in Conveyor.cargo(e,incoming):
				var at=r.get_center()+cargo.offset*unit
				_item(cargo.resource,at,unit*cargo.size)
				if cargo.count>1:
					draw_string_outline(font,at+Vector2(unit*0.08,unit*0.18),str(cargo.count),HORIZONTAL_ALIGNMENT_LEFT,-1,maxi(10,int(unit*.19)),3,INK)
					draw_string(font,at+Vector2(unit*0.08,unit*0.18),str(cargo.count),HORIZONTAL_ALIGNMENT_LEFT,-1,maxi(10,int(unit*.19)),Color("fff0ae"))
		else:_sprite(e.kind,r,anim)
		if e.job!=null:
			var percent=clampf(1-e.job.remaining/game.recipe(e).cycle,0,1)
			var p=r.size.x/32
			var bar=Rect2(r.position+Vector2(8,30)*p,Vector2(16,2)*p)
			draw_rect(bar,Color("655d48"));draw_rect(Rect2(bar.position,Vector2(floor(16*percent)*p,bar.size.y)),Color("e8cf7d"))
		if e.id==selected_id and not game.is_project(e.kind):
			var d=Vector2(RustFactory.DIRS[int(e.direction)])
			var p=r.size.x/32
			var at=(r.get_center()+d*unit*0.39).round()
			draw_rect(Rect2(at-Vector2.ONE*3*p,Vector2.ONE*6*p),Color("fff0ae"))
			for n in range(4):
				var side=Vector2(-d.y,d.x)
				var edge=at+d*(n-2)*p
				draw_rect(Rect2(edge,Vector2.ONE*p),INK)
				if n in [1,2]:
					var spread=3-n
					draw_rect(Rect2(edge+side*spread*p,Vector2.ONE*p),INK);draw_rect(Rect2(edge-side*spread*p,Vector2.ONE*p),INK)
		if e.paused:
			var p=r.size.x/32
			draw_rect(Rect2(r.position+Vector2(25,2)*p,Vector2(2,5)*p),INK);draw_rect(Rect2(r.position+Vector2(29,2)*p,Vector2(2,5)*p),INK)
		if game.is_project(e.kind) and not e.project.complete:_corners(r.grow(-unit*0.08),Color("c99c5c"))
		if e.id==selected_id:_corners(r.grow(-unit*0.02),Color("fff0ae"))
	if not opportunity.is_empty():
		var ghost=tile_rect(opportunity.x,opportunity.y)
		var ready=game.affordable(opportunity.cash,opportunity.materials)
		var tint=Color(1,1,1,0.35+0.15*(0.5+0.5*sin(Time.get_ticks_msec()*0.003)))
		draw_texture_rect(Art.texture(opportunity.kind),ghost,false,tint)
		_corners(ghost.grow(-unit*0.02),Color("c5e49d") if ready else Color("f4d487"))
		for i in range(1,opportunity.path.size()):
			var a=opportunity.path[i-1];var b=opportunity.path[i]
			var start=tile_rect(a.x,a.y).get_center();var finish=tile_rect(b.x,b.y).get_center()
			for n in range(1,4):draw_circle(start.lerp(finish,n/4.0),maxf(1,unit/48),Color("f4d487"))
	if selected_id.is_empty():_corners(tile_rect(selection.x,selection.y).grow(-unit*0.03),Color("f4d487"))
	for p in particles:
		if not game.state.entities.has(p.sourceId) or not game.state.entities.has(p.targetId):continue
		var t=clampf(p.age/p.duration,0,1)
		var at=(camera+p.a.lerp(p.b,t)*unit).round()
		_item(p.r,at,unit*0.46)
	for p in sale_bubbles:
		var at=camera+p.at*unit-Vector2(0,p.age*unit*0.35)
		var font_size=maxi(12,int(unit*0.24));var text="+₩ "+RustFactory.money(p.cash)
		at.x-=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x*0.5
		var fade=minf(1,(1.4-p.age)*3)
		draw_string_outline(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,3,Color(0.27,0.24,0.23,fade))
		draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(1,0.94,0.68,fade))

	if preview_area.has_area():
		var top=tile_rect(preview_area.position.x,preview_area.position.y).position
		var bottom=tile_rect(preview_area.end.x-1,preview_area.end.y-1).end
		draw_rect(Rect2(top,bottom-top),Color("e4b66a38"));draw_rect(Rect2(top,bottom-top),Color("ffe0a0"),false,2)
	for i in range(preview_path.size()):
		var p=preview_path[i];var rect=tile_rect(p.x,p.y)
		draw_rect(rect.grow(-unit*0.06),Color("fff0af75"))
		if i<preview_path.size()-1:
			var next=preview_path[i+1];var direction=Vector2(next-p)
			var center=rect.get_center();draw_line(center-direction*unit*0.18,center+direction*unit*0.18,INK,3)
			var tip=center+direction*unit*0.18;var side=Vector2(-direction.y,direction.x)
			draw_line(tip,tip-direction*unit*0.12+side*unit*0.1,INK,3);draw_line(tip,tip-direction*unit*0.12-side*unit*0.1,INK,3)
	for pos in preview_clear:
		var p=World.parse_key(pos);_corners(tile_rect(p.x,p.y).grow(-unit*0.05),Color("d78158"))
	if work_origin.x>=0:_corners(tile_rect(work_origin.x,work_origin.y),Color("fff0af"))
