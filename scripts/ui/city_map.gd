extends Control
signal tile_pressed(tile: Vector2i)
var game
var zoom=1.0
var tile_size=88.0
var camera=Vector2.ZERO
var selection=Vector2i(0,0)
var building=""
var pressed=false
var dragging=false
var press_at=Vector2.ZERO
var last_at=Vector2.ZERO
var particles=[]
var font: Font
const GREEN=Color("9dbd7d")
const INK=Color("5c7150")
func _ready():
	mouse_default_cursor_shape=Control.CURSOR_DRAG
	clip_contents=true
	font=load("res://assets/fonts/RustCity.otf")
func focus_district(id="forest"):
	if game==null:return
	var d=game.data.districts[id]
	var n=maxf(3,game.state.districts[id].size)
	camera=size/2-Vector2(d.x+n/2,d.y+n/2)*tile_size*zoom
	queue_redraw()
func zoom_by(delta):
	var old=zoom
	zoom=clampf(zoom+delta,0.45,1.7)
	camera=size/2-(size/2-camera)*zoom/old
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
		if e.position.distance_to(press_at)>8:dragging=true
		if dragging:camera+=e.position-last_at;queue_redraw()
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
func box(rect:Rect2,color:Color,radius=10.0):
	var style=StyleBoxFlat.new()
	style.bg_color=color
	style.set_corner_radius_all(int(radius))
	style.border_color=color.darkened(0.18)
	style.set_border_width_all(1)
	draw_style_box(style,rect)
func tree(at:Vector2,scale=1.0):
	draw_line(at+Vector2(0,5)*scale,at+Vector2(0,20)*scale,Color("ac8b61"),5*scale)
	draw_circle(at+Vector2(0,-4)*scale,14*scale,Color("68965d"))
	draw_circle(at+Vector2(-6,-9)*scale,10*scale,Color("82ad6b"))
func worker(at:Vector2,active=false):
	var bob=sin(Time.get_ticks_msec()/140.0)*1.2 if active else 0.0
	at+=Vector2(0,bob)
	draw_circle(at,8,Color("fff1d4"))
	draw_colored_polygon(PackedVector2Array([at+Vector2(-7,-3),at+Vector2(-8,-12),at+Vector2(-1,-7)]),Color("fff1d4"))
	draw_colored_polygon(PackedVector2Array([at+Vector2(7,-3),at+Vector2(8,-12),at+Vector2(1,-7)]),Color("fff1d4"))
	draw_circle(at+Vector2(-3,-1),1,INK);draw_circle(at+Vector2(3,-1),1,INK)
	box(Rect2(at+Vector2(-6,6),Vector2(12,12)),Color("c89570"),4)
func label(text,at:Vector2,font_size=12,color=INK):
	if font:draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
func facility(e):
	var origin=Vector2(e.x,e.y)*88
	draw_set_transform(camera+origin*zoom,0,Vector2.ONE*zoom)
	var kind=e.kind
	var active=game.status(e)=="가동 중"
	draw_circle(Vector2(44,65),32,Color("566a4916"))
	box(Rect2(8,15,72,57),Color("e9e5ca"),13)
	if kind=="forest":
		box(Rect2(12,19,64,48),Color("a9c489"),10)
		tree(Vector2(28,40),0.8);tree(Vector2(58,33),0.75);tree(Vector2(47,51),0.65)
	elif game.transport(e):
		box(Rect2(1,31,86,26),Color("718c79"),12)
		for x in range(7,85,13):draw_line(Vector2(x,35),Vector2(x,53),Color("afc7ac"),2)
		for i in range(e.queue.size()):box(Rect2(10+i*8,38,9,12),Color(game.data.resources[e.queue[i]].color),3)
	elif kind=="mine":
		draw_circle(Vector2(30,36),20,Color("a4b0a2"));draw_circle(Vector2(56,35),21,Color("8da59a"))
		box(Rect2(29,31,30,32),Color("576e5a"),10)
		draw_line(Vector2(22,28),Vector2(66,28),Color("ba9468"),6)
	elif kind=="sawmill":
		box(Rect2(14,31,60,27),Color("90b3a1"),8)
		box(Rect2(12,28,58,9),Color("c9996d"),4)
		draw_circle(Vector2(39,43),14,Color("eff1d8"));draw_circle(Vector2(39,43),5,Color("849e84"))
		var angle=Time.get_ticks_msec()/140.0 if active else 0.0
		draw_line(Vector2(39,43),Vector2(39,43)+Vector2.from_angle(angle)*13,INK,2)
	elif kind=="generator":
		box(Rect2(21,20,47,48),Color("e1bd70"),10)
		label("ϟ",Vector2(32,57),34,Color("fff6d6"))
	elif kind=="launchpad":
		box(Rect2(12,62,65,10),Color("acb8a1"),4)
		draw_line(Vector2(22,64),Vector2(22,13),Color("b29574"),5)
		box(Rect2(35,16,23,48),Color("f8efd7"),11)
		draw_circle(Vector2(47,34),5,Color("88b3a7"))
		if game.state.rocket.launched:label("★",Vector2(38,14),21,Color("e9bc64"))
	else:
		var house=game.is_project(kind)
		box(Rect2(16,32,56,34),Color("f0d9a4") if house else Color("a9c2a3"),8)
		draw_colored_polygon(PackedVector2Array([Vector2(10,33),Vector2(44,11),Vector2(78,33)]),Color("d39c7a") if kind in ["warehouse","market","cabin"] else Color("99b19a"))
		box(Rect2(24,40,14,15),Color("e4edd2"),4);box(Rect2(49,40,14,15),Color("e4edd2"),4)
		if house and not e.project.complete:
			draw_line(Vector2(17,65),Vector2(17,25),Color("b28d66"),4);draw_line(Vector2(68,65),Vector2(68,25),Color("b28d66"),4)
	if not game.transport(e):worker(Vector2(72,58),active)
	if e.job!=null:
		var percent=clampf(1-e.job.remaining/game.recipe(e).cycle,0,1)
		box(Rect2(23,76,42,4),Color("c0cba8"),2);box(Rect2(23,76,42*percent,4),Color("78a26e"),2)
	if not game.is_project(kind):
		var d=RustFactory.DIRS[int(e.direction)]
		var p=Vector2(44,44)+Vector2(d)*37
		draw_circle(p,7,Color("fff9df"));draw_line(p-Vector2(d)*4,p+Vector2(d)*4,INK,2)
		var side=Vector2(-d.y,d.x)
		draw_line(p+Vector2(d)*4,p-Vector2(d)*1+side*3,INK,2);draw_line(p+Vector2(d)*4,p-Vector2(d)*1-side*3,INK,2)
	if e.level>1:label("Lv.%d"%e.level,Vector2(11,12),10)
	if e.paused:label("Ⅱ",Vector2(66,16),15)
func _draw():
	if game==null:return
	draw_rect(Rect2(Vector2.ZERO,size),Color("e4ebcc"))
	var scale=tile_size/88.0
	# Facility art uses the same 88-unit grid at every zoom level.
	var original_zoom=zoom
	zoom*=scale
	for y in range(12):
		for x in range(18):
			var rect=Rect2(camera+Vector2(x,y)*88*zoom,Vector2.ONE*88*zoom)
			if not rect.intersects(Rect2(Vector2.ZERO,size)):continue
			var id=game.district_at(x,y)
			var colors={"forest":"c9dca5","mines":"ccd5bb","industrial":"e4d8b8","logistics":"ceddc0","advanced":"d3dfc6","launch":"e6dfc3"}
			var c=Color(colors.get(id,"dbe4c6"))
			draw_rect(rect.grow(-1),c if game.owned(x,y) else c.darkened(0.09))
			if not game.owned(x,y):draw_circle(rect.get_center(),2*zoom,Color("a6b38f"))
	for e in game.state.entities.values():facility(e)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	var selected=Rect2(camera+Vector2(selection)*88*zoom,Vector2.ONE*88*zoom)
	draw_rect(selected.grow(-2),Color("e7b45a"),false,3)
	for p in particles:
		var t=clampf(p.age/0.65,0,1)
		var pos=camera+p.a.lerp(p.b,t)*88*zoom
		draw_circle(pos,6*zoom,Color("fff5d5"));draw_circle(pos,3*zoom,Color(game.data.resources[p.r].color))
	zoom=original_zoom
