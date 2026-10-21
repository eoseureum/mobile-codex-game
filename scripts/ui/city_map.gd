extends Control
signal tile_pressed(tile: Vector2i)
const World=preload("res://scripts/core/world_map.gd")
const Art=preload("res://scripts/ui/pixel_art.gd")
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
var particles=[]
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
	camera=(size*Vector2(0.5,0.47)-Vector2(d.x+n/2,d.y+n/2)*tile_size*zoom).round()
	queue_redraw()
func focus_point(tile:Vector2i):
	camera=(size*Vector2(0.5,0.47)-(Vector2(tile)+Vector2.ONE*0.5)*tile_size*zoom).round()
	clamp_camera();queue_redraw()
func clamp_camera():
	if not game.world_mode():return
	var pad=tile_size*0.5
	camera.x=clampf(camera.x,size.x-World.SIZE*tile_size*zoom-pad,pad)
	camera.y=clampf(camera.y,size.y-World.SIZE*tile_size*zoom-pad,pad)
func zoom_by(delta):
	var old=zoom
	zoom=clampf(zoom+delta,0.45,1.7)
	camera=(size/2-(size/2-camera)*zoom/old).round()
	clamp_camera()
	queue_redraw()
func _gui_input(e):
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
	for t in game.transfers:
		if particles.size()>=50:break
		particles.append({"a":Vector2(game.state.entities[t.sourceId].x+0.5,game.state.entities[t.sourceId].y+0.5),"b":Vector2(game.state.entities[t.targetId].x+0.5,game.state.entities[t.targetId].y+0.5),"r":t.resource,"age":0.0})
func _process(delta):
	for p in particles:p.age+=delta
	particles=particles.filter(func(p):return p.age<0.65)
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
				if occupied.has(Vector2i(x,y)):_sprite("yard",r,variant)
				elif owned:
					var resource=World.resource_at(game.state.world,x,y)
					if resource=="log":_sprite("tree",r)
					elif not resource.is_empty():_sprite("ore_"+(resource if known[resource] else "unknown"),r)
					elif game.state.world.cleared.has(game.key(x,y)):_sprite("yard",r,variant)
			else:
				if owned:
					if occupied.has(Vector2i(x,y)):_sprite("yard",r,variant)
				else:
					if id=="mines":_sprite("rock",r,variant)
					if posmod(x*17+y*31,9)==0:_sprite("tree",r.grow(-unit*0.12))

	var frame=int(floor(game.state.clock.elapsedS*5))%4
	for e in game.state.entities.values():
		var r=tile_rect(int(e.x),int(e.y))
		if not r.intersects(Rect2(Vector2.ZERO,size)):continue
		var active=game.status(e) in ["가동 중","발전 중","운송 중","자동 입출고","자동 판매","운영 중","공사 중"]
		var anim=frame if active else 0
		if game.transport(e):
			draw_set_transform(r.get_center(),(int(e.direction)-1)*PI/2,Vector2.ONE*r.size.x/32)
			_sprite(e.kind,Rect2(-Vector2.ONE*16,Vector2.ONE*32),anim)
			for i in range(e.queue.size()):
				var cargo=Vector2(-13+i*3,-1)
				draw_rect(Rect2(cargo-Vector2.ONE,Vector2.ONE*4),INK)
				draw_rect(Rect2(cargo,Vector2.ONE*2),Color(game.data.resources[e.queue[i]].color))
			draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
		else:_sprite(e.kind,r,anim)
		if not game.transport(e):
			_sprite("cat",Rect2(r.position+r.size*Vector2(0.58,0.48),r.size*0.50),anim)
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
	if selected_id.is_empty():_corners(tile_rect(selection.x,selection.y).grow(-unit*0.03),Color("f4d487"))
	for p in particles:
		var t=clampf(p.age/0.65,0,1)
		var at=(camera+p.a.lerp(p.b,t)*unit).round()
		var px=maxf(1,round(unit/32))
		draw_rect(Rect2(at-Vector2.ONE*3*px,Vector2.ONE*6*px),INK)
		draw_rect(Rect2(at-Vector2.ONE*2*px,Vector2.ONE*4*px),Color(game.data.resources[p.r].color))

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
