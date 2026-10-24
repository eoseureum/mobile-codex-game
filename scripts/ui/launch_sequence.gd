extends Control
## Transient celebration. The authoritative launch is saved before this opens.
signal finished
var elapsed=0.0
var started_at=0
var scale_ui=1.0
var launch_at=Vector2.ZERO
var heading:Label
var detail:Label
var action:Button
var summary=""
func _ready():
	started_at=Time.get_ticks_msec()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	heading=Label.new();heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;heading.add_theme_font_size_override("font_size",int(26*scale_ui));heading.add_theme_color_override("font_color",Color("fff2cf"));add_child(heading)
	detail=Label.new();detail.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;detail.add_theme_font_size_override("font_size",int(14*scale_ui));detail.add_theme_color_override("font_color",Color("fff2cf"));add_child(detail)
	action=Button.new();action.text="건너뛰기";add_child(action);action.pressed.connect(func():finished.emit();queue_free())
	resized.connect(layout);layout()
func layout():
	if heading==null:return
	heading.position=Vector2(12*scale_ui,size.y*.12);heading.size=Vector2(size.x-24*scale_ui,44*scale_ui)
	detail.position=Vector2(12*scale_ui,size.y*.12+48*scale_ui);detail.size=Vector2(size.x-24*scale_ui,60*scale_ui)
	action.position=Vector2(size.x*.5-80*scale_ui,size.y-80*scale_ui);action.size=Vector2(160,52)*scale_ui
func _process(_delta):
	elapsed=maxf(0,(Time.get_ticks_msec()-started_at)/1000.0)
	heading.text="점화" if elapsed<1.5 else "이륙" if elapsed<4.5 else "첫 로켓 발사"
	detail.text=summary if elapsed>=4.5 else ""
	action.text="도시로" if elapsed>=4.5 else "건너뛰기"
	queue_redraw()
func _draw():
	draw_rect(Rect2(Vector2.ZERO,size),Color(.09,.17,.16,.83))
	var p=maxf(2,minf(size.x/70,size.y/100))
	var lift=maxf(0,elapsed-1.5)
	var origin=(launch_at if launch_at!=Vector2.ZERO else Vector2(size.x*.5,size.y*.65))-Vector2(0,8*p+lift*lift*size.y*.08)
	if elapsed<4.5:
		draw_rect(Rect2(origin+Vector2(-4,-13)*p,Vector2(8,21)*p),Color("ecdfb9"))
		draw_colored_polygon(PackedVector2Array([origin+Vector2(-4,-13)*p,origin+Vector2(0,-19)*p,origin+Vector2(4,-13)*p]),Color("b86f59"))
		draw_rect(Rect2(origin+Vector2(-2,-9)*p,Vector2(4,5)*p),Color("79a6a4"))
		for sign_x in [-1,1]:draw_rect(Rect2(origin+Vector2(sign_x*5-1,3)*p,Vector2(2,7)*p),Color("b86f59"))
		var flame=5+int(elapsed*18)%4
		draw_colored_polygon(PackedVector2Array([origin+Vector2(-3,8)*p,origin+Vector2(0,8+flame)*p,origin+Vector2(3,8)*p]),Color("eeb25b"))
	else:
		var at=Vector2(size.x*.5,size.y*.55)
		for n in range(12):
			var angle=n*TAU/12
			draw_rect(Rect2(at+Vector2(cos(angle),sin(angle))*60-Vector2.ONE*3,Vector2.ONE*6),Color("e8cf7d"))
