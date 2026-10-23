extends Control
## Full-screen entry point. No game state or storage writes happen here.
signal new_world_requested
signal resume_world_requested(id:String)
signal import_requested
const Backdrop=preload("res://scripts/ui/start_backdrop.gd")
const Art=preload("res://scripts/ui/pixel_art.gd")
const Factory=preload("res://scripts/core/factory.gd")
var ui
var home_page:Control
var worlds_page:Control
var new_button:Button
var continue_button:Button
var back_button:Button
var import_button:Button
var empty_new_button:Button
var previous_button:Button
var next_button:Button
var title_label:Label
var subtitle:Label
var device_label:Label
var worlds_title:Label
var status_label:Label
var count_label:Label
var page_label:Label
var backdrop:Control
var rows:Array=[]
var worlds:Array=[]
var page=0
var page_size=4
var loading=false
var message=""
var mode="home"
var last_import_request_ms=-1000

func setup(owner_ui):
	ui=owner_ui
	if home_page!=null:return
	name="StartScreen"
	mouse_filter=Control.MOUSE_FILTER_STOP
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	home_page=Control.new();home_page.name="HomePage";add_child(home_page)
	backdrop=Backdrop.new();backdrop.name="PixelDiorama";home_page.add_child(backdrop)
	title_label=_label(home_page,"RUST CITY",44)
	title_label.add_theme_color_override("font_color",Color("536348"))
	subtitle=_label(home_page,"작은 숲에서 시작하는 도시",13)
	new_button=_button(home_page,"새로 하기",_request_new);new_button.name="NewWorldButton"
	continue_button=_button(home_page,"이어하기",show_worlds);continue_button.name="ContinueWorldButton"
	device_label=_label(home_page,"이 기기에 저장",11)
	worlds_page=Control.new();worlds_page.name="WorldsPage";add_child(worlds_page)
	worlds_title=_label(worlds_page,"나의 도시",26)
	count_label=_label(worlds_page,"",12)
	back_button=_button(worlds_page,"뒤로",show_home)
	status_label=_label(worlds_page,"",15)
	status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	status_label.max_lines_visible=2
	status_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	previous_button=_button(worlds_page,"‹",func():_change_page(-1));previous_button.name="PreviousWorldsPage"
	next_button=_button(worlds_page,"›",func():_change_page(1));next_button.name="NextWorldsPage"
	page_label=_label(worlds_page,"",13)
	import_button=_button(worlds_page,"백업 불러오기",_request_import)
	empty_new_button=_button(worlds_page,"새로 하기",_request_new)
	resized.connect(layout_screen)
	show_home()
	layout_screen()

func _label(parent,text_value,font_size)->Label:
	var label=Label.new();label.text=text_value
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("536348"))
	parent.add_child(label)
	return label

func _button(parent,text_value,action:Callable)->Button:
	var button=Button.new();button.text=text_value
	button.pressed.connect(func():
		if not loading:action.call())
	parent.add_child(button)
	return button

func _skin(button:Button,primary=false):
	var u=_unit()
	for state in ["normal","hover","pressed","disabled","focus"]:
		var box=StyleBoxFlat.new()
		box.bg_color=Color("698252" if primary else "fff4d7")
		if state=="pressed":box.bg_color=Color("506b42" if primary else "e8e5bc")
		if state=="hover":box.bg_color=Color("79935f" if primary else "fff9e9")
		if state=="disabled":box.bg_color=Color("b0b69a" if primary else "e7e7ce")
		box.border_color=Color("526748" if primary else "bac09a")
		box.set_border_width_all(maxi(1,int(u)))
		box.set_corner_radius_all(int(14*u))
		box.content_margin_left=8*u;box.content_margin_right=8*u
		if state=="focus":box.bg_color=Color.TRANSPARENT;box.border_color=Color("d49a50");box.set_border_width_all(maxi(2,int(3*u)))
		button.add_theme_stylebox_override(state,box)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:button.add_theme_color_override(state,Color("fff7dc" if primary else "4d6044"))
	button.add_theme_color_override("font_disabled_color",Color("7a846c"))
	button.add_theme_font_size_override("font_size",int(16*u))
	button.custom_minimum_size=Vector2(48,48)*u

func _unit()->float:
	return maxf(0.1,float(ui.scale_ui)) if ui!=null else 1.0

func refresh(saved_worlds:Array,error_message=""):
	worlds=saved_worlds.duplicate(true)
	message=str(error_message)
	page=clampi(page,0,maxi(0,int(ceil(float(worlds.size())/page_size))-1))
	if home_page!=null:layout_screen()

func show_home():
	if loading:return
	mode="home"
	if home_page!=null:home_page.show();worlds_page.hide();layout_screen()

func show_worlds():
	if loading:return
	mode="worlds"
	if home_page!=null:home_page.hide();worlds_page.show();layout_screen()

func set_loading(flag:bool):
	loading=flag
	if home_page!=null:
		for b in [new_button,continue_button,back_button,import_button,empty_new_button,previous_button,next_button]:b.disabled=loading
		layout_screen()

func _request_new():
	if loading:return
	set_loading(true)
	new_world_requested.emit()

func _request_resume(id:String):
	if loading:return
	for world in worlds:
		if str(world.get("id",""))==id and bool(world.get("valid",true)):
			set_loading(true);resume_world_requested.emit(id);return

func _request_import():
	if loading:return
	# Native pickers may never report cancellation. Only debounce the opening tap;
	# Main owns the loading state after an actual backup has been selected.
	var now=Time.get_ticks_msec()
	if now-last_import_request_ms<400:return
	last_import_request_ms=now
	import_requested.emit()

func _change_page(step:int):
	page=clampi(page+step,0,maxi(0,int(ceil(float(worlds.size())/page_size))-1))
	layout_screen()

func _place(control:Control,rect:Rect2):
	control.position=rect.position*_unit();control.size=rect.size*_unit()

func layout_screen():
	if home_page==null or size.x<1 or size.y<1:return
	var u=_unit();var extent=size/u;var w=extent.x;var h=extent.y
	for container in [home_page,worlds_page]:container.position=Vector2.ZERO;container.size=size
	for b in [new_button,continue_button,back_button,import_button,empty_new_button,previous_button,next_button]:_skin(b,b in [new_button,empty_new_button])
	for label in [title_label,subtitle,device_label,worlds_title,status_label,count_label,page_label]:label.add_theme_font_size_override("font_size",int(({title_label:44,subtitle:13,device_label:11,worlds_title:26,status_label:15,count_label:12,page_label:13}[label])*u))
	var landscape=w>h*1.3
	if landscape:
		var left=w*0.49;var panel_w=minf(300,w-left-32);var x=left+(w-left-panel_w)*0.5
		_place(backdrop,Rect2(12,h*0.06,left-20,h*0.88))
		_place(title_label,Rect2(x, h*0.13,panel_w,56))
		_place(subtitle,Rect2(x,h*0.13+56,panel_w,24))
		var top=maxf(h*0.48,h*0.13+88)
		_place(new_button,Rect2(x,top,panel_w,52))
		_place(continue_button,Rect2(x,top+62,panel_w,52))
		_place(device_label,Rect2(x,minf(h-22,top+119),panel_w,20))
	else:
		var bw=minf(310,w-40);var bx=(w-bw)*0.5
		var top=minf(h*0.63,h-170)
		_place(title_label,Rect2(16,h*0.105,w-32,62))
		_place(subtitle,Rect2(16,h*0.105+62,w-32,24))
		var art_top=h*0.105+94
		_place(backdrop,Rect2(10,art_top,w-20,maxf(90,top-art_top-24)))
		_place(new_button,Rect2(bx,top,bw,56))
		_place(continue_button,Rect2(bx,top+68,bw,56))
		_place(device_label,Rect2(bx,top+137,bw,20))
	new_button.text="준비 중…" if loading else "새로 하기"
	device_label.text=message if not message.is_empty() else "이 기기에 저장"
	device_label.tooltip_text=message
	device_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	device_label.add_theme_color_override("font_color",Color("9c5548") if not message.is_empty() else Color("7c856b"))
	_layout_worlds(extent)
	queue_redraw()

func _layout_worlds(extent:Vector2):
	var w=extent.x;var h=extent.y;var u=_unit()
	var old_size=page_size
	page_size=4 if h>=740 else 3 if h>=500 else 2
	if old_size!=page_size:page=0
	var pages=maxi(1,int(ceil(float(worlds.size())/page_size)))
	page=clampi(page,0,pages-1)
	var width=minf(600,w-32);var x=(w-width)*0.5
	var top=88.0 if h>=500 else 68.0
	_place(worlds_title,Rect2(x,14,width-72,36));worlds_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	_place(count_label,Rect2(x,50,width-72,22));count_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	count_label.visible=h>=500
	count_label.text="%d개의 도시 · 이 기기에 저장"%worlds.size()
	_place(back_button,Rect2(x+width-64,16,64,48))
	var footer=h-64
	_place(import_button,Rect2(x,footer,minf(164,width*0.55),48))
	_place(empty_new_button,Rect2(x+width-112,footer,112,48))
	var pager_y=footer-58
	_place(next_button,Rect2(x+width-48,pager_y,48,48))
	_place(previous_button,Rect2(x+width-152,pager_y,48,48))
	_place(page_label,Rect2(x+width-104,pager_y,56,48))
	page_label.text="%d / %d"%[page+1,pages]
	for control in [previous_button,next_button,page_label]:control.visible=worlds.size()>page_size
	previous_button.disabled=loading or page==0;next_button.disabled=loading or page>=pages-1
	var bottom=pager_y-10 if worlds.size()>page_size else footer-16
	# A resume tap can rebuild this list while its button is emitting pressed.
	for row in rows:row.hide();row.queue_free()
	rows.clear()
	var row_h=minf(116,floor((bottom-top-8*(page_size-1))/page_size))
	for index in range(page*page_size,mini(worlds.size(),(page+1)*page_size)):
		var world:Dictionary=worlds[index]
		var row=Panel.new();row.name="World_"+str(index);worlds_page.add_child(row);rows.append(row)
		var box=StyleBoxFlat.new();box.bg_color=Color("fff6de");box.border_color=Color("c4c9a6");box.set_border_width_all(maxi(1,int(u)));box.set_corner_radius_all(int(12*u));row.add_theme_stylebox_override("panel",box)
		_place(row,Rect2(x,top+(index-page*page_size)*(row_h+8),width,row_h))
		var valid=bool(world.get("valid",true));var label_width=width-112
		var name_label=_label(row,str(world.get("name","도시 %d"%(index+1))),16)
		name_label.name="WorldName";name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT;name_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.add_theme_font_size_override("font_size",int(16*u))
		_place(name_label,Rect2(14,9,label_width,24))
		var meta=_label(row,_world_detail(world,valid),11);meta.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT;meta.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;meta.add_theme_font_size_override("font_size",int(11*u))
		_place(meta,Rect2(14,33,label_width,19))
		if row_h>=88:
			var saved_label=_label(row,_saved_date(world),11);saved_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT;saved_label.add_theme_font_size_override("font_size",int(11*u));_place(saved_label,Rect2(14,57,label_width,20))
		var id=str(world.get("id",""))
		var resume=_button(row,"계속" if valid else "확인 불가",func():_request_resume(id));resume.name="ResumeButton";_skin(resume);resume.add_theme_font_size_override("font_size",int((14 if valid else 11)*u));resume.disabled=loading or not valid
		_place(resume,Rect2(width-86,(row_h-48)*0.5,76,48))
	status_label.visible=loading or worlds.is_empty() or not message.is_empty()
	status_label.text="도시를 준비하고 있어요…" if loading else message if not message.is_empty() else "아직 저장된 도시가 없어요"
	if worlds.is_empty():_place(status_label,Rect2(x,top,width,maxf(48,bottom-top)))
	else:_place(status_label,Rect2(x,pager_y,width-164,48))

func _world_detail(world:Dictionary,valid:bool)->String:
	if not valid:return "백업을 불러와 복구해 주세요"
	var stage=str(world.get("stage",""))
	if ui!=null and ui.get("game")!=null:
		var stage_index=ui.game.data.stages.find(stage)
		if stage_index>=0 and stage_index<ui.game.data.stageNames.size():stage=str(ui.game.data.stageNames[stage_index])
	var cash=int(world.get("cash",0))
	var cash_text="₩ "+Factory.money(cash)
	return (stage+" · " if not stage.is_empty() else "")+cash_text+" · 시설 %d"%int(world.get("buildings",0))

func _saved_date(world:Dictionary)->String:
	var timestamp=float(world.get("savedAtMs",0))/1000.0
	if timestamp<=0:return "이 기기에 저장됨"
	var seconds=maxi(0,int(Time.get_unix_time_from_system()-timestamp))
	if seconds<60:return "방금 저장"
	if seconds<3600:return "%d분 전 저장"%int(seconds/60)
	if seconds<86400:return "%d시간 전 저장"%int(seconds/3600)
	return "%d일 전 저장"%int(seconds/86400)

func _draw():
	draw_rect(Rect2(Vector2.ZERO,size),Color("f3efd8"))
	if mode=="home":
		var u=_unit();var extent=size/u
		# Ground color ties the title island and controls together without showing gameplay.
		var ground=Rect2(Vector2(0,extent.y*0.88)*u,Vector2(extent.x,extent.y*0.12)*u)
		draw_rect(ground,Color("e7e9cb"))
