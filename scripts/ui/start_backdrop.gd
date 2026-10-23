extends Control
## A tiny original title-screen island, composed from Rust City's pixel art.
const Art=preload("res://scripts/ui/pixel_art.gd")
var island:Texture2D
var frame=0
var age=0.0

func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	_make_island()

func _make_island():
	var image=Image.create(256,160,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	# Stepped earth edges retain the same hand-built pixel rhythm as the sprites.
	for band in [Rect2i(38,46,180,91),Rect2i(22,58,212,66),Rect2i(10,76,236,32)]:
		Art.rect(image,band.position.x,band.position.y+8,band.size.x,band.size.y,"797a50")
		Art.rect(image,band.position.x,band.position.y+4,band.size.x,band.size.y,"a58a5c")
		Art.rect(image,band.position.x,band.position.y,band.size.x,band.size.y,"a7ba7c")
	for i in range(90):
		var x=30+posmod(i*37,195);var y=61+posmod(i*23,58)
		Art.rect(image,x,y,2,1,"c1cf91" if i%3==0 else "90a66c")
	Art.rect(image,45,98,162,12,"c5bc8b")
	Art.rect(image,142,67,13,58,"c5bc8b")
	for p in [Vector2i(26,56),Vector2i(40,38),Vector2i(61,32),Vector2i(80,47),Vector2i(198,40),Vector2i(216,58),Vector2i(203,88),Vector2i(48,103)]:
		image.blend_rect(Art.image("tree"),Rect2i(0,0,32,32),p)
	image.blend_rect(Art.image("forest",3),Rect2i(0,0,32,32),Vector2i(73,66))
	for x in [91,111]:image.blend_rect(Art.image("belt",3),Rect2i(0,0,32,32),Vector2i(x,82))
	image.blend_rect(Art.image("sawmill",3),Rect2i(0,0,32,32),Vector2i(77,99))
	image.blend_rect(Art.image("sales_hub",3),Rect2i(0,0,96,96),Vector2i(119,40))
	image.blend_rect(Art.image("generator",3),Rect2i(0,0,32,32),Vector2i(179,97))
	image.blend_rect(Art.image("item_log"),Rect2i(0,0,32,32),Vector2i(49,80))
	island=ImageTexture.create_from_image(image)
	queue_redraw()

func _process(delta):
	age+=delta
	var next=int(age*2.0)%4
	if next!=frame:frame=next;queue_redraw()

func _draw():
	if island==null:return
	var scale_factor=minf(size.x/256.0,size.y/160.0)
	var extent=Vector2(256,160)*scale_factor
	var origin=(size-extent)*0.5
	draw_texture_rect(island,Rect2(origin,extent),false)
	# A quiet four-step puff above the camp's chimney.
	for i in range(3):
		var p=Vector2(202+i*2,98-i*6-frame)
		draw_rect(Rect2(origin+p*scale_factor,Vector2(4+i,3)*scale_factor),Color(Color("e6ebd0"),0.7-float(i)*0.15))
