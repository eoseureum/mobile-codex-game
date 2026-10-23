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
	var key=kind+":"+str(clampi(frame,0,8))
	if not cache.has(key):cache[key]=ImageTexture.create_from_image(image(kind,clampi(frame,0,8)))
	return cache[key]
static func conveyor_texture(mask:int,outputs:Array,frame:int=0) -> Texture2D:
	var output_mask=0
	for direction in outputs:output_mask|=1<<posmod(int(direction),4)
	var key="conveyor:%d:%d:%d"%[mask&15,output_mask,clampi(frame,0,8)]
	if not cache.has(key):cache[key]=ImageTexture.create_from_image(conveyor_image(mask,outputs,frame))
	return cache[key]
static func conveyor_contains(mask:int,x:int,y:int) -> bool:
	# Pixel centres and the tile centre use half coordinates, so all four
	# orientations are exact rotations, including the two sides of each rail.
	var p=Vector2(x+0.5,y+0.5)
	# Extend open ports off-tile for boundary sampling: rails must not cap them.
	if y<0:return bool(mask&1) and x>=9 and x<=22
	if x>31:return bool(mask&2) and y>=9 and y<=22
	if y>31:return bool(mask&4) and x>=9 and x<=22
	if x<0:return bool(mask&8) and y>=9 and y<=22
	if mask in [3,6,12,9]:
		var centre={3:Vector2(32,0),6:Vector2(32,32),12:Vector2(0,32),9:Vector2(0,0)}[mask]
		var radius=p.distance_to(centre)
		return radius>=9.0 and radius<=23.0
	if x>=9 and x<=22 and y>=9 and y<=22:return true
	return (bool(mask&1) and x>=9 and x<=22 and y<16) or (bool(mask&2) and y>=9 and y<=22 and x>=16) or (bool(mask&4) and x>=9 and x<=22 and y>=16) or (bool(mask&8) and y>=9 and y<=22 and x<16)
static func conveyor_image(mask:int,outputs:Array,frame:int=0) -> Image:
	mask&=15
	var im=Image.create(32,32,false,Image.FORMAT_RGBA8)
	im.fill(Color.TRANSPARENT)
	var phase=maxi(0,clampi(frame,0,8)-1)
	for y in range(32):
		for x in range(32):
			if not conveyor_contains(mask,x,y):continue
			var edge=false;var rail=false
			for d in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
				if not conveyor_contains(mask,x+d.x,y+d.y):edge=true
				if not conveyor_contains(mask,x+2*d.x,y+2*d.y):rail=true
			var color="344b49" if edge else "bacbc6" if rail else "6f8d80"
			if not edge and not rail:
				# Rollers meet in one bed; no overlapping half-belt sprites.
				var p=Vector2(x-15.5,y-15.5)
				var distance=maxf(absf(p.x),absf(p.y))
				if mask in [1,4,5]:distance=absf(p.y)
				elif mask in [2,8,10]:distance=absf(p.x)
				elif mask in [3,6,12,9]:
					# Crossbars on a bend are radial spokes of the same curve.
					var curve={3:Vector2(31.5-x,y+0.5),6:Vector2(31.5-y,31.5-x),12:Vector2(x+0.5,31.5-y),9:Vector2(y+0.5,x+0.5)}[mask]
					distance=atan2(curve.y,curve.x)*16.0
				if mask!=0 and posmod(int(floor(distance))-phase,7)<2:color="4e6a60"
			im.set_pixel(x,y,Color(color))
	# One arrow for each real output. Coordinate rotation also rotates the
	# arrow itself, so splitters do not inherit a phantom straight-through port.
	for direction in outputs:
		var d=posmod(int(direction),4)
		if not mask&(1<<d):continue
		for at in [Vector2i(15,4),Vector2i(16,4),Vector2i(14,5),Vector2i(17,5),Vector2i(13,6),Vector2i(18,6),Vector2i(15,5),Vector2i(16,5),Vector2i(15,6),Vector2i(16,6),Vector2i(15,7),Vector2i(16,7),Vector2i(15,8),Vector2i(16,8)]:
			var p=at
			for turn in range(d):p=Vector2i(31-p.y,p.x)
			if conveyor_contains(mask,p.x,p.y):im.set_pixelv(p,Color("e2eee4"))
	return im
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
static func line(im:Image,a:Vector2i,b:Vector2i,color:String):
	var steps=maxi(abs(b.x-a.x),abs(b.y-a.y))
	for i in range(steps+1):
		var p=Vector2(a).lerp(Vector2(b),float(i)/maxi(1,steps)).round()
		rect(im,int(p.x),int(p.y),1,1,color)
static func gear(im:Image,x:int,y:int,n:int,color="e3dfcb"):
	rect(im,x-3,y-4,7,9,INK);rect(im,x-4,y-3,9,7,INK)
	rect(im,x-3,y-3,7,7,color)
	var tips=[Vector2i(0,-3),Vector2i(2,-2),Vector2i(3,0),Vector2i(2,2),Vector2i(0,3),Vector2i(-2,2),Vector2i(-3,0),Vector2i(-2,-2)]
	var tip=tips[posmod(n,8)]
	line(im,Vector2i(x,y),Vector2i(x,y)+tip,"687f78");rect(im,x-1,y-1,2,2,INK)
	rect(im,x+tip.x,y+tip.y,1,1,"f1c66a")
static func smoke(im:Image,x:int,frame:int):
	var n=posmod(frame-1,8);var y=n%4
	rect(im,x+n/4,4-y,3,3,"d2ddcfaa");rect(im,x+2-n/4,1-y/2,3,2,"e4eade77")
static func factory(im:Image,kind:String,frame:int):
	var n=maxi(0,frame-1);var active=frame>0
	var stroke=[0,1,2,3,4,3,2,1][n]
	var colors={"copperSmelter":"b77350","ironSmelter":"8d9d9a","wireFactory":"c39b56","partsFactory":"7b9b9b","structureFactory":"9aaf8c","electronicsFactory":"7ba0b1","precisionFactory":"998fab","refinery":"b4a275"}
	var c=colors.get(kind,"91a088")
	panel(im,3,15,26,14,"c7ba91");rect(im,4,25,24,3,"9d9b7f")
	panel(im,22,5,5,11,"877d6b");rect(im,21,5,7,2,INK)
	if active:smoke(im,23,frame)
	if kind in ["copperSmelter","ironSmelter"]:
		panel(im,7,9,15,19,c);rect(im,8,13,13,2,"efd4a4")
		panel(im,11,19,8,8,"463f3b")
		if active:
			rect(im,12,23-stroke/2,6,3+stroke/2,"d78945")
			rect(im,12+n%4,22-stroke/2,2,4,"f4ce68")
			rect(im,6,17,2+stroke/2,5,"ab8564")
		rect(im,7,28,19,2,INK)
	elif kind=="refinery":
		panel(im,4,8,9,21,c);panel(im,16,12,11,17,"c0c5a7")
		rect(im,5,14,7,2,CREAM);rect(im,5,23,7,2,CREAM);rect(im,13,18,5,3,"7d887d")
		rect(im,21,9,3,4,INK);rect(im,26,22,4,3,"be8a59")
		panel(im,7,10,3,13,"4b645b")
		if active:rect(im,8,12+n,1,3,"e4c875");gear(im,21,22,n,"c3c9ad")
	else:
		panel(im,5,10,21,6,c);rect(im,7,9,6,2,INK);rect(im,16,7,6,4,c)
		window(im,6,18);window(im,21,18)
		panel(im,13,19,6,10,"5c766e");rect(im,14,20,4,2,"edd397")
		if kind=="wireFactory":
			gear(im,17,12,n,"d69955")
			if active:rect(im,10+n,16,5,1,"efc47d")
		elif kind=="partsFactory":
			rect(im,11,5,2,12,INK);rect(im,23,5,2,12,INK);rect(im,11,5,14,2,"6f8c87")
			panel(im,13,7+stroke,10,4,"dcc699");rect(im,17,11+stroke,3,2,"6f8c87")
			if active:rect(im,12+n,17,3,1,"e3dfcb")
		elif kind=="electronicsFactory":
			panel(im,11,7,12,9,"355b52")
			for x in [13,16,19]:rect(im,x,9,1,5,"9dba73")
			if active:rect(im,12+n,8,2,7,"edce7a");rect(im,13+(n*3)%8,12,1,1,"e9f0bd")
		elif kind=="precisionFactory":
			panel(im,11,7,13,9,"cac9c0");gear(im,17,11,n,"9fa5b1")
			if active:rect(im,11+stroke,15,3,2,"dcb57b")
		else:
			rect(im,6,5,2,13,INK);rect(im,6,5,19,2,"d1b97f")
			var hook=10+n if active else 10
			rect(im,hook,7,1,7,"7c8b78");rect(im,hook-2,14,5,2,"e6d8b1")
			if active:rect(im,9+n,17,5,2,"a0b4a8")

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
	if kind=="sales_hub":return hub_image(frame)
	var im=Image.create(32,32,false,Image.FORMAT_RGBA8)
	im.fill(Color.TRANSPARENT)
	if kind.begins_with("icon_"):icon(im,kind.trim_prefix("icon_"));return im
	if kind.begins_with("item_"):
		var r=kind.trim_prefix("item_")
		if r=="log":log_pile(im,4,10);log_pile(im,12,17)
		elif r=="plank":
			for y in [8,15,22]:panel(im,4,y,24,5,"d9b67b");rect(im,9,y+2,12,1,"ad8054")
		else:
			var colors={"stone":"a8b1a2","coal":"56615b","copper":"d89b65","iron":"b9cac4","wire":"d9ad64","copperIngot":"c88652","ironIngot":"b8c5bd","machinePart":"859e98","structure":"9bae8d","electronics":"86b5b3","precision":"afa1c1","fuel":"e0c17b"}
			var c=colors.get(r,"a8b1a2")
			if r in ["stone","coal","copper","iron"]:
				panel(im,5,16,12,11,c);panel(im,12,7,13,14,c);panel(im,20,19,8,9,c)
				rect(im,14,9,7,2,"dbe0bd" if r!="coal" else "89938a");rect(im,7,18,5,2,"dbe0bd" if r!="coal" else "89938a")
			elif r in ["copperIngot","ironIngot"]:
				panel(im,4,14,24,11,c);panel(im,9,8,15,9,c);line(im,Vector2i(5,14),Vector2i(10,8),INK);rect(im,11,10,10,2,"e8d5ad");rect(im,7,21,18,2,"78665a")
			elif r=="wire":
				panel(im,5,6,23,23,c);panel(im,9,10,15,15,"b58143");panel(im,13,14,7,7,"00000000");rect(im,24,24,4,6,c)
			elif r=="machinePart":gear(im,16,16,2,"9caeaa");rect(im,7,24,18,3,INK)
			elif r=="structure":
				panel(im,4,5,24,6,c);panel(im,12,10,8,13,c);panel(im,4,22,24,6,c);rect(im,14,12,2,9,"d3dfc3")
			elif r=="electronics":
				panel(im,4,5,24,23,"6e9f88");panel(im,10,11,12,11,"465c5a")
				for at in [7,13,20,25]:rect(im,at,3,2,4,"dfbd73");rect(im,at,27,2,3,"dfbd73")
				rect(im,6,8,10,1,"c8d3a0");rect(im,24,13,1,10,"c8d3a0")
			elif r=="precision":gear(im,16,17,1,"c4bdd8");panel(im,14,4,5,13,"dce0d0");rect(im,15,24,3,5,INK)
			elif r=="fuel":
				panel(im,8,4,17,26,"756956");rect(im,9,8,15,5,c);rect(im,9,22,15,4,c);rect(im,11,5,3,22,"e4cb87")
			else:panel(im,7,9,19,17,c)
		return im
	if kind=="tree":tree(im,7,2);return im
	if kind.begins_with("ore_"):
		var color={"ore_stone":"bec1ac","ore_coal":"535c55","ore_copper":"d59866","ore_iron":"c9d5cd"}.get(kind,"9aa89a")
		shadow(im);rect(im,10,9,12,3,INK);rect(im,6,12,21,5,INK);rect(im,4,17,25,10,INK)
		rect(im,11,10,10,3,"adb6a2");rect(im,7,13,19,6,"adb6a2");rect(im,5,19,23,7,"859b8a")
		for at in [Vector2i(10,14),Vector2i(19,17),Vector2i(8,22),Vector2i(23,23)]:rect(im,at.x,at.y,3,2,color)
		return im
	if kind in ["grass","yard","wild","rock","water"]:
		var base="96ad73" if kind=="wild" else "a7ba7c"
		if kind=="rock":base="9da995"
		if kind=="water":base="7eaeaa"
		im.fill(Color(base))
		for i in range(17):
			var x=posmod(i*13+frame*7,31);var y=posmod(i*19+frame*11,31)
			rect(im,x,y,2,1,"b9c88b" if i%3==0 else "90a66c")
			if kind=="rock":rect(im,x,y,3,2,"b7bea8" if i%2==0 else "859584")
			if kind=="water":rect(im,x,y,4,1,"a4cec0" if i%2==0 else "719c9b")
		return im
	shadow(im)
	var n=maxi(0,frame-1);var active=frame>0
	var stroke=[0,1,2,3,4,3,2,1][n]
	match kind:
		"forest":
			tree(im,0,2);tree(im,14,0);log_pile(im,9,25)
			panel(im,12,19,14,5,"6f8674")
			if active:
				rect(im,13+stroke,20,9,2,"d3dec6")
				for x in range(14+stroke,23+stroke,2):rect(im,x,22,1,1,INK)
				rect(im,24+n%3,23-n%3,1,1,"dec592")
		"sawmill":
			panel(im,3,14,26,15,"ccb28a");roof(im,1,5,30)
			rect(im,4,22,24,3,"748d7a");log_pile(im,4,24)
			panel(im,16,16,10,10,"d8dfcb");rect(im,19,18,4,6,"84988b")
			gear(im,21,21,n,"d8dfcb");window(im,5,16)
			if active:
				rect(im,4+n,24,6,3,"b88a55");rect(im,5+n,24,2,2,"efd5a0")
				if n>=4:rect(im,25+n%3,27-n%2,1,1,"e3c98d")
		"warehouse","market":
			panel(im,3,13,26,16,"d6bc8e");roof(im,1,4,30,"a86752")
			panel(im,12,18,10,11,"765f49");rect(im,14,19,6,9,"b49465");rect(im,17,19,1,9,"e7c48b")
			window(im,5,18);panel(im,24,23,7,6,"b78e55")
			if kind=="market":
				rect(im,2,15,28,3,"ebcf85");rect(im,7,15,4,3,ROOF);rect(im,19,15,4,3,ROOF)
				if active:panel(im,5+n*2,24-stroke/2,4,4,"d8ad59")
			elif active:
				rect(im,14,19,6,8,"475a4d");rect(im,14,19,6,maxi(1,7-stroke),"b49465")
				panel(im,13+n/2,24,5,4,"b78e55")
		"belt","splitter":
			panel(im,0,11,32,13,"637b72");rect(im,0,14,32,7,"8b9f83")
			for x in range(-8,33,8):rect(im,x+(n if active else 0),14,2,7,"526a61")
			rect(im,0,12,32,2,"c0bc91");rect(im,0,22,32,1,"4f6258")
			if kind=="splitter":
				panel(im,10,6,12,20,"d2b774");gear(im,16,16,n,"d2b774")
		"mine":
			rect(im,9,4,13,3,INK);rect(im,5,7,22,5,INK);rect(im,2,12,28,16,INK)
			rect(im,10,5,11,3,"abb5a6");rect(im,6,8,20,6,"abb5a6");rect(im,3,14,26,13,"8a9a91")
			rect(im,19,9,4,3,"cbb38b");rect(im,5,18,4,3,"b5bda7")
			panel(im,10,15,15,14,"3e4d47");rect(im,9,14,17,3,"bb955f");rect(im,10,17,3,12,"d4b078");rect(im,23,17,2,12,"bb955f")
			rect(im,12,28,14,1,"c5b38c");rect(im,12,30,14,1,"786a55")
			var cart=13+stroke if active else 13
			panel(im,cart,23,8,5,"697d76");rect(im,cart+1,22,5,2,"c99b6c")
			rect(im,cart+1,28,2,2,INK);rect(im,cart+5,28,2,2,INK)
			if active:rect(im,14+n,20,1,1,"d2c5a1")
		"generator":
			panel(im,4,14,24,15,"c4b77d");panel(im,22,7,5,10,"867c68")
			if active:smoke(im,23,frame)
			panel(im,7,9,15,19,"7a9587");rect(im,8,13,13,2,"b7c6a2")
			gear(im,15,22,n,"a3b7a3")
			if active:rect(im,7+n,16,2,1,"f1d485")
			for x in [6,24]:rect(im,x,27,3,3,INK)
		"cabin","cityWorkshop","dispatchOffice":
			panel(im,4,14,24,15,"dec99a");roof(im,2,5,28,"7b9270" if kind=="cityWorkshop" else ROOF)
			window(im,7,18,"f5dc92");window(im,21,18,"f5dc92");panel(im,14,19,5,10,"947553")
			rect(im,2,28,28,2,"b29265");rect(im,3,30,27,1,INK)
			if kind=="cabin":rect(im,5,25,6,2,"7f9b6b");rect(im,6,24,4,1,"dbbb70")
			if kind=="cityWorkshop":panel(im,11,11,10,5,"b9bf9b");rect(im,15,11,2,5,INK)
			if kind=="dispatchOffice":rect(im,26,7,1,15,INK);rect(im,27,7,5,4,"e3b65e")
			if active:
				if kind=="cityWorkshop":gear(im,16,13,n,"b9bf9b")
				elif kind=="dispatchOffice":rect(im,27,7+n%3,5,3,"f2d591");rect(im,5+n*2,26,3,2,"ddc07e")
				else:rect(im,8+n,11+stroke,5,2,"cfb07c");rect(im,10+n,13+stroke,1,3,INK)
		"launchpad":
			panel(im,2,26,28,5,"95a291");rect(im,4,7,2,20,INK);rect(im,4,8,8,2,"a88c65")
			rect(im,15,2,4,2,INK);rect(im,13,4,8,3,INK);panel(im,12,7,10,19,"ecdfb9")
			rect(im,13,9,8,3,"b86f59");panel(im,14,14,6,6,"79a6a4");rect(im,15,15,2,2,"d5edce")
			rect(im,10,22,3,6,ROOF);rect(im,21,22,3,6,ROOF);rect(im,15,26,4,3,"ddab5d")
			if active:
				rect(im,6,10+n,6,1,"b4c7b4");rect(im,24,27-n,2,2,"e8d587")
		_:
			factory(im,kind,frame)
	return im

static func hub_image(frame=0) -> Image:
	var im=Image.create(96,96,false,Image.FORMAT_RGBA8);im.fill(Color.TRANSPARENT)
	var phase=maxi(0,frame-1)
	# Open receiving apron: green steel lanes expose the grass between docks.
	for dock in [Rect2i(0,36,24,24),Rect2i(72,36,24,24),Rect2i(36,0,24,24),Rect2i(36,72,24,24)]:
		rect(im,dock.position.x,dock.position.y,dock.size.x,dock.size.y,"385b54")
		rect(im,dock.position.x+2,dock.position.y+2,dock.size.x-4,dock.size.y-4,"7e9b83")
	# Eight individual perimeter receivers stay readable across the 3×3 footprint.
	for at in [Vector2i(6,6),Vector2i(38,6),Vector2i(70,6),Vector2i(6,38),Vector2i(70,38),Vector2i(6,70),Vector2i(38,70),Vector2i(70,70)]:
		panel(im,at.x,at.y,20,20,"668779")
		rect(im,at.x+2,at.y+3,16,3,"b9cfb0")
		for n in range(3):rect(im,at.x+3,at.y+8+n*4,14,2,"3f6259")
		rect(im,at.x+3+(phase%4)*3,at.y+8,3,10,"e2c678")
	# A raised pavilion with a tall roof and compact service tower.
	rect(im,24,65,48,5,"344d4544")
	panel(im,24,30,48,36,"78928a")
	rect(im,26,53,44,11,"587369")
	for x in [28,57]:
		panel(im,x,41,11,18,"344f49");rect(im,x+2,43,7,5,"b7d5bd")
		for y in range(51,58,3):rect(im,x+2,y,7,1,"6b8d7d")
	panel(im,41,43,14,22,"344f49");rect(im,43,45,10,17,"9bb897")
	rect(im,46,46,4,14,"d8c781");rect(im,42,59,12,3,"6b8d7d")
	for row in range(20):
		var inset=maxi(0,18-row)
		rect(im,19+inset,15+row,58-inset*2,1,INK)
		if row>0:rect(im,20+inset,15+row,56-inset*2,1,"a85f50" if row%5<3 else "c27c60")
	rect(im,19,34,58,3,INK);rect(im,21,35,54,2,"dbac79")
	panel(im,35,29,26,10,"f2d48c");rect(im,38,32,20,3,"785b42")
	for x in range(39,58,5):rect(im,x,30,2,7,"f7e4ab")
	panel(im,61,18,8,14,"54776c");rect(im,62,19,6,2,"a7c9b0")
	rect(im,64,8,2,11,INK);rect(im,66,8,12,7,"d5ad5a");rect(im,66,9,9,4,"f2d48c")
	# Warm activity lights and a tiny trolley on the southern receiving lane.
	for x in [28,65]:rect(im,x,39,3,2,"f6d981" if phase%4<2 else "c7a162")
	if frame>0:
		var x=38+phase*2
		panel(im,x,76,8,7,"b78e55");rect(im,x+2,77,4,3,"f1d394")
		for wheel in [x+1,x+6]:rect(im,wheel,83,2,2,INK)
	return im
