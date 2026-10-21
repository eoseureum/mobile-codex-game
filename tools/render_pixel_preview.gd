extends SceneTree
const Art=preload("res://scripts/ui/pixel_art.gd")
func _initialize():
	var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	var names=catalog.facilities.keys()
	var atlas=Image.create(320,256,false,Image.FORMAT_RGBA8)
	atlas.fill(Color("a7ba7c"))
	var i=0
	for kind in names:
		for frame in range(4):
			var tile=Art.image(kind,frame)
			atlas.blit_rect(tile,Rect2i(0,0,32,32),Vector2i(i%10*32,i/10*32))
			i+=1
	atlas.resize(960,768,Image.INTERPOLATE_NEAREST)
	var result=atlas.save_png("user://rust-pixel-gallery.png")
	print("PIXEL_GALLERY ",error_string(result))
	quit(0 if result==OK else 1)
