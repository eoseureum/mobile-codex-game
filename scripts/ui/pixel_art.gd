class_name RustPixelArt
extends RefCounted
## Original 32px art, generated once from integer rectangles. No filtered vectors.
const INK="443d3c"
const WOOD="98704c"
const CREAM="f4deb0"
const ROOF="a85f50"
const GREEN="54794d"
static var cache={}

static func texture(kind:String,frame=0) -> ImageTexture:
	var key=kind+str(posmod(frame,4))
	if not cache.has(key):cache[key]=ImageTexture.create_from_image(image(kind,posmod(frame,4)))
	return cache[key]
static func rect(im:Image,x:int,y:int,w:int,h:int,color:String):
	im.fill_rect(Rect2i(x,y,w,h),Color(color))
static func panel(im:Image,x:int,y:int,w:int,h:int,color:String):
	rect(im,x+1,y,w-2,h,INK);rect(im,x,y+1,w,h-2,INK)
	rect(im,x+1,y+1,w-2,h-2,color)
static func shadow(im:Image):
	rect(im,5,27,24,3,"50634750");rect(im,8,30,18,1,"50634740")
static func roof(im:Image,x=2,y=6,w=28,color=ROOF):
	for row in range(9):
		var inset=maxi(0,7-row)
		rect(im,x+inset,y+row,w-inset*2,1,INK)
		if row>0:rect(im,x+inset+1,y+row,w-inset*2-2,1,color)
		if row in [3,6]:rect(im,x+inset+2,y+row,w-inset*2-4,1,"c87f61")
	rect(im,x,y+8,w,2,INK)
static func window(im:Image,x:int,y:int,light="b5dac2"):
	panel(im,x,y,5,6,light);rect(im,x+2,y+1,1,4,"f8e4b3")
static func log_pile(im:Image,x:int,y:int):
	panel(im,x,y,11,4,"a8794e");rect(im,x+1,y+1,2,2,"efd5a0");rect(im,x+4,y+1,6,1,"c69964")
static func tree(im:Image,x:int,y:int):
	rect(im,x+7,y+16,4,10,INK);rect(im,x+8,y+16,2,9,"ad7b4f")
	rect(im,x+6,y,6,2,INK);rect(im,x+3,y+2,12,3,INK)
	rect(im,x+1,y+5,16,9,INK);rect(im,x+3,y+14,12,4,INK);rect(im,x+6,y+18,6,1,INK)
	rect(im,x+6,y+1,6,2,"7fa357");rect(im,x+3,y+3,12,4,"7fa357")
	rect(im,x+2,y+6,14,7,GREEN);rect(im,x+4,y+13,10,4,GREEN)
	rect(im,x+4,y+5,7,3,"a2bd6b");rect(im,x+3,y+8,4,3,"7fa357")
	rect(im,x+11,y+9,4,5,"3e6246");rect(im,x+7,y+15,6,2,"3e6246")
static func cat(im:Image,frame:int):
	var y=1 if frame in [1,2] else 0
	rect(im,11,12+y,10,10,INK);rect(im,12,13+y,8,8,"f5dfac")
	rect(im,10,7+y,12,9,INK);rect(im,10,4+y,4,6,INK);rect(im,18,4+y,4,6,INK)
	rect(im,11,6+y,2,4,"efc58f");rect(im,19,6+y,2,4,"efc58f")
	rect(im,11,9+y,10,6,"fff0c8");rect(im,13,10+y,1,2,INK);rect(im,18,10+y,1,2,INK)
	rect(im,15,13+y,2,1,"c88a73");rect(im,11,16+y,10,2,"bd6651")
	rect(im,11,22+y,3,2,INK);rect(im,18,22+y,3,2,INK)
	rect(im,21,19+y,3,2,"f5dfac");rect(im,23,16+y,2,4,"f5dfac")
static func smoke(im:Image,x:int,frame:int):
	var y=posmod(frame,3)
	rect(im,x,4-y,3,3,"e9e5c5bc");rect(im,x+2,1-y,4,2,"f9edce90")
static func factory(im:Image,kind:String,frame:int):
	var colors={"copperSmelter":"b77350","ironSmelter":"8d9d9a","wireFactory":"c39b56","partsFactory":"7b9b9b","structureFactory":"9aaf8c","electronicsFactory":"7ba0b1","precisionFactory":"998fab","refinery":"b4a275"}
	var c=colors.get(kind,"91a088")
	panel(im,3,15,26,14,"c7ba91");rect(im,4,25,24,3,"9d9b7f")
	panel(im,22,5,5,11,"877d6b");rect(im,21,5,7,2,INK)
	if frame>0:smoke(im,23,frame)
	if kind in ["copperSmelter","ironSmelter"]:
		panel(im,7,9,15,19,c);rect(im,8,13,13,2,"efd4a4")
		panel(im,11,19,8,8,"704a40");rect(im,12,22,6,4,"d78945")
		rect(im,13+frame%2,20,3,5,"f4ce68");rect(im,7,28,19,2,INK)
	elif kind=="refinery":
		panel(im,4,8,9,21,c);panel(im,16,12,11,17,"c0c5a7")
		rect(im,5,14,7,2,CREAM);rect(im,5,23,7,2,CREAM);rect(im,13,18,5,3,"7d887d")
		rect(im,21,9,3,4,INK);rect(im,26,22,4,3,"be8a59")
	else:
		panel(im,5,10,21,6,c);rect(im,7,9,6,2,INK);rect(im,16,7,6,4,c)
		window(im,6,18);window(im,21,18)
		panel(im,13,19,6,10,"5c766e");rect(im,14,20,4,2,"edd397")
		if kind=="wireFactory":
			panel(im,13,12,8,7,"d69955");rect(im,15,13,4,5,"8f6749");rect(im,16,14,2,3,"e6c28a")
		elif kind=="partsFactory":
			rect(im,11,9,10,2,INK);rect(im,14,6,4,8,INK);rect(im,12,8,8,4,"dcc699");rect(im,15,8,2,4,"6f8c87")
		elif kind=="electronicsFactory":
			panel(im,12,7,9,8,"355b52");rect(im,14,9,5,4,"9dba73");rect(im,14,6,1,2,"d5bd7b")
		elif kind=="precisionFactory":
			panel(im,11,7,12,8,"cac9c0");rect(im,14,9,6,4,"77778f");rect(im,16,10,2,2,"dbe9d2")
		else:rect(im,10,11,15,2,"e6d8b1");rect(im,10,14,15,1,"7c8b78")

static func icon(im:Image,kind:String):
	match kind:
		"build":
			rect(im,9,17,13,3,INK);rect(im,17,8,3,15,INK);panel(im,6,7,14,7,"ce9a62");rect(im,7,8,12,2,"f0cc87")
		"inventory":
			panel(im,6,10,20,16,"be955e");rect(im,7,15,18,2,"efd4a4");rect(im,9,11,2,14,"e2bb77");rect(im,21,11,2,14,"e2bb77");rect(im,7,8,18,3,"f1d49a")
		"industry":
			panel(im,5,15,22,12,"89a18a");rect(im,8,6,5,10,INK);rect(im,9,7,3,9,"c9bc97");rect(im,15,11,6,5,"789083");window(im,9,19);window(im,19,19)
		"records":
			panel(im,8,5,17,23,"ead2a1");rect(im,7,7,3,18,"a9825c")
			for y in [10,15,20]:rect(im,13,y,8,2,"9c9d77")
		"settings":
			rect(im,13,4,6,24,INK);rect(im,4,13,24,6,INK);panel(im,7,7,18,18,"a2b2a1");panel(im,12,12,8,8,"ead6a4")
		"map","home":
			panel(im,6,14,20,14,"d1bb8c");roof(im,4,5,24,"a86650");panel(im,14,20,5,8,"6c7762")
		"plus","minus":
			rect(im,7,14,18,4,INK)
			if kind=="plus":rect(im,14,7,4,18,INK)
		"coin":
			panel(im,6,6,20,20,"d4a850");panel(im,9,9,14,14,"f4d37b");rect(im,15,11,2,10,"ba8b48");rect(im,12,14,8,2,"ba8b48")
		_:
			panel(im,7,7,18,18,"c9cfac");rect(im,13,11,6,2,INK);rect(im,17,13,2,3,INK);rect(im,15,16,3,2,INK);rect(im,15,20,2,2,INK)

static func image(kind:String,frame=0) -> Image:
	var im=Image.create(32,32,false,Image.FORMAT_RGBA8)
	im.fill(Color.TRANSPARENT)
	if kind.begins_with("icon_"):icon(im,kind.trim_prefix("icon_"));return im
	if kind=="cat":cat(im,frame);return im
	if kind=="tree":tree(im,7,2);return im
	if kind.begins_with("ore_"):
		var color={"ore_stone":"bec1ac","ore_coal":"535c55","ore_copper":"d59866","ore_iron":"c9d5cd"}.get(kind,"9aa89a")
		shadow(im);rect(im,10,9,12,3,INK);rect(im,6,12,21,5,INK);rect(im,4,17,25,10,INK)
		rect(im,11,10,10,3,"adb6a2");rect(im,7,13,19,6,"adb6a2");rect(im,5,19,23,7,"859b8a")
		for at in [Vector2i(10,14),Vector2i(19,17),Vector2i(8,22),Vector2i(23,23)]:rect(im,at.x,at.y,3,2,color)
		return im
	if kind in ["grass","yard","wild","rock","water"]:
		var base="96ad73" if kind=="wild" else "a7ba7c"
		if kind=="yard":base="c8bb8b"
		if kind=="rock":base="9da995"
		if kind=="water":base="7eaeaa"
		im.fill(Color(base))
		for i in range(17):
			var x=posmod(i*13+frame*7,31);var y=posmod(i*19+frame*11,31)
			rect(im,x,y,2,1,"b9c88b" if i%3==0 else "90a66c")
			if kind=="yard":rect(im,x,y,2,1,"b3aa7d" if i%2==0 else "ded09a")
			if kind=="rock":rect(im,x,y,3,2,"b7bea8" if i%2==0 else "859584")
			if kind=="water":rect(im,x,y,4,1,"a4cec0" if i%2==0 else "719c9b")
		return im
	shadow(im)
	match kind:
		"forest":
			tree(im,0,2);tree(im,14,0);log_pile(im,9,25)
		"sawmill":
			panel(im,3,14,26,15,"ccb28a");roof(im,1,5,30)
			rect(im,4,22,24,3,"748d7a");log_pile(im,4,24)
			panel(im,16,16,10,10,"d8dfcb");rect(im,19,18,4,6,"84988b")
			if frame%2==0:rect(im,16,20,10,2,"f2e9c8")
			else:rect(im,20,16,2,10,"f2e9c8")
			rect(im,20,20,2,2,INK);window(im,5,16)
		"warehouse","market":
			panel(im,3,13,26,16,"d6bc8e");roof(im,1,4,30,"a86752")
			panel(im,12,18,10,11,"765f49");rect(im,14,19,6,9,"b49465");rect(im,17,19,1,9,"e7c48b")
			window(im,5,18);panel(im,24,23,7,6,"b78e55")
			if kind=="market":rect(im,2,15,28,3,"ebcf85");rect(im,7,15,4,3,ROOF);rect(im,19,15,4,3,ROOF)
		"belt","splitter":
			panel(im,0,11,32,13,"637b72");rect(im,0,14,32,7,"8b9f83")
			for x in range(-4,33,6):rect(im,x+frame,14,2,7,"526a61")
			rect(im,0,12,32,2,"c0bc91");rect(im,0,22,32,1,"4f6258")
			if kind=="splitter":panel(im,10,6,12,20,"d2b774");rect(im,15,8,2,15,INK);rect(im,15,12,6,2,INK)
		"mine":
			rect(im,9,4,13,3,INK);rect(im,5,7,22,5,INK);rect(im,2,12,28,16,INK)
			rect(im,10,5,11,3,"abb5a6");rect(im,6,8,20,6,"abb5a6");rect(im,3,14,26,13,"8a9a91")
			rect(im,19,9,4,3,"cbb38b");rect(im,5,18,4,3,"b5bda7")
			panel(im,10,15,15,14,"3e4d47");rect(im,9,14,17,3,"bb955f");rect(im,10,17,3,12,"d4b078");rect(im,23,17,2,12,"bb955f")
			rect(im,14,26,8,2,"c5b38c");rect(im,15,22,1,8,"786a55");rect(im,21,22,1,8,"786a55")
		"generator":
			panel(im,4,14,24,15,"c4b77d");panel(im,22,7,5,10,"867c68");smoke(im,23,frame)
			panel(im,7,9,15,19,"7a9587");rect(im,8,13,13,2,"b7c6a2")
			panel(im,10,19,9,8,"4e6259");rect(im,12,21,5,4,"dca85b");rect(im,14,19,2,4,"f1d485")
			for x in [6,24]:rect(im,x,27,3,3,INK)
		"cabin","cityWorkshop","dispatchOffice":
			panel(im,4,14,24,15,"dec99a");roof(im,2,5,28,"7b9270" if kind=="cityWorkshop" else ROOF)
			window(im,7,18,"f5dc92");window(im,21,18,"f5dc92");panel(im,14,19,5,10,"947553")
			rect(im,2,28,28,2,"b29265");rect(im,3,30,27,1,INK)
			if kind=="cabin":rect(im,5,25,6,2,"7f9b6b");rect(im,6,24,4,1,"dbbb70")
			if kind=="cityWorkshop":panel(im,11,11,10,5,"b9bf9b");rect(im,15,11,2,5,INK)
			if kind=="dispatchOffice":rect(im,26,7,1,15,INK);rect(im,27,7,5,4,"e3b65e")
		"launchpad":
			panel(im,2,26,28,5,"95a291");rect(im,4,7,2,20,INK);rect(im,4,8,8,2,"a88c65")
			rect(im,15,2,4,2,INK);rect(im,13,4,8,3,INK);panel(im,12,7,10,19,"ecdfb9")
			rect(im,13,9,8,3,"b86f59");panel(im,14,14,6,6,"79a6a4");rect(im,15,15,2,2,"d5edce")
			rect(im,10,22,3,6,ROOF);rect(im,21,22,3,6,ROOF);rect(im,15,26,4,3,"ddab5d")
		_:
			factory(im,kind,frame)
	return im
