extends Control
signal point_selected(point:Vector2i)
const World=preload("res://scripts/core/world_map.gd")
var game
var city
var raster:ImageTexture
var signature=""
func _ready():
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
func _process(_delta):
	if visible:queue_redraw()
func _draw():
	if game==null or not game.world_mode():return
	var current=str(game.state.world.seed)+":"+str(game.state.world.revision)+":"+game.state.stage+":"+str(game.state.entities.size())+city.view_filter+(str(int(game.state.clock.elapsedS)) if city.view_filter=="stopped" else "")
	if current!=signature or raster==null:
		signature=current
		var im=terrain_image(game,city.view_filter)
		raster=ImageTexture.create_from_image(im)
	var box=StyleBoxFlat.new();box.bg_color=Color("fff2cf");box.border_color=Color("8c9470");box.set_border_width_all(2);box.set_corner_radius_all(6);box.shadow_size=3;box.shadow_offset=Vector2(0,4);box.shadow_color=Color("344a3b32")
	draw_style_box(box,Rect2(Vector2.ZERO,size))
	var inner=Rect2(Vector2.ONE*5,size-Vector2.ONE*10)
	draw_texture_rect(raster,inner,false)
	var unit=city.tile_size*city.zoom
	var pos=(-city.camera/unit/World.SIZE)*inner.size+inner.position
	var extent=(city.size/unit/World.SIZE)*inner.size
	draw_rect(Rect2(pos,extent).intersection(inner),Color("fff5c9"),false,2)
static func terrain_image(factory,filter="all") -> Image:
	var im=Image.create(World.SIZE,World.SIZE,false,Image.FORMAT_RGBA8);im.fill(Color("a7ba7c"))
	var colors={"log":"51704b","stone":"8f9891","coal":"555a56","copper":"bd845c","iron":"a8b8b2"}
	for key in factory.state.world.nodes:
		var r=factory.state.world.nodes[key]
		if filter not in ["all","stopped"] and (r!=filter or not factory.known_resource(r)):continue
		if filter=="stopped":continue
		var p=World.parse_key(key);im.set_pixel(p.x,p.y,Color(colors[r]) if factory.known_resource(r) else Color("8f9891"))
	for e in factory.state.entities.values():
		var footprint=factory.entity_rect(e)
		for y in range(footprint.position.y,footprint.end.y):
			for x in range(footprint.position.x,footprint.end.x):im.set_pixel(x,y,Color("c77955") if filter=="stopped" and factory.Insight.issue(factory,e).kind in ["missing","blocked","incompatible","power"] else Color("f4dfad"))
	return im
func _gui_input(event):
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		var uv=(event.position-Vector2.ONE*5)/(size-Vector2.ONE*10)
		point_selected.emit(Vector2i(clampi(int(uv.x*World.SIZE),0,World.SIZE-1),clampi(int(uv.y*World.SIZE),0,World.SIZE-1)))
		accept_event()
