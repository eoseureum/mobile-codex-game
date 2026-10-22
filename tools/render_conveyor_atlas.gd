extends SceneTree
## Run headless to inspect every connection mask, direction and animation frame.
const Art=preload("res://scripts/ui/pixel_art.gd")
const DIGITS={"0":["111","101","101","101","111"],"1":["010","110","010","010","111"],"2":["111","001","111","100","111"],"3":["111","001","111","001","111"],"4":["101","101","111","001","001"],"5":["111","100","111","001","111"],"6":["111","100","111","101","111"],"7":["111","001","010","010","010"],"8":["111","101","111","101","111"],"9":["111","101","111","001","111"]}
func label(im:Image,value:int,origin:Vector2i):
	var col=0
	for digit in str(value):
		for y in range(5):
			for x in range(3):
				if DIGITS[digit][y][x]=="1":im.set_pixelv(origin+Vector2i(col+x,y),Color("e2eee4"))
		col+=4
func _initialize():
	var atlas=Image.create(384,240,false,Image.FORMAT_RGBA8)
	atlas.fill(Color("344b49"))
	for section in range(2):
		for mask in range(16):
			var outputs=[]
			for d in range(4):
				if mask&(1<<d):outputs.append(d)
			if section==1 and outputs.size()>1:outputs=outputs.slice(0,1)
			var origin=Vector2i(mask%8*48,section*96+(mask/8)*48)
			label(atlas,mask,origin+Vector2i(5,1))
			atlas.blit_rect(Art.image("grass",mask%4),Rect2i(0,0,32,32),origin+Vector2i(5,8))
			atlas.blend_rect(Art.conveyor_image(mask,outputs,section*5),Rect2i(0,0,32,32),origin+Vector2i(5,8))
	# Two flush-connected path segments with bends and split output arrows.
	var masks=[2,10,9,6,14,10,11,8]
	var ports=[[1],[1],[0],[1],[1,2],[1],[0,1],[3]]
	for i in range(8):
		var origin=Vector2i(64+i*32,200)
		atlas.blit_rect(Art.image("grass",i%4),Rect2i(0,0,32,32),origin)
		atlas.blend_rect(Art.conveyor_image(masks[i],ports[i],3),Rect2i(0,0,32,32),origin)
	atlas.resize(1536,960,Image.INTERPOLATE_NEAREST)
	var result=atlas.save_png("/tmp/conveyor-atlas.png")
	print("CONVEYOR_ATLAS /tmp/conveyor-atlas.png ",error_string(result))
	quit(0 if result==OK else 1)
