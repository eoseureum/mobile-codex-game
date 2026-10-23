extends SceneTree
const Start=preload("res://scripts/ui/start_screen.gd")
class Owner:
	extends Control
	var scale_ui=1.0
	var game={"data":{"stages":["forest"],"stageNames":["숲의 마을"]}}
var checks=0
var failures=0
var new_requests=0
var resume_requests:Array=[]
var import_requests=0
func check(value:bool,description:String):
	checks+=1
	if not value:failures+=1;printerr("FAIL: "+description)
func _initialize():call_deferred("run")
func run():
	var owner_ui=Owner.new();owner_ui.theme=Theme.new();owner_ui.theme.default_font=load("res://assets/fonts/RustCity.otf")
	var screen=Start.new();screen.setup(owner_ui);owner_ui.add_child(screen);root.add_child(owner_ui)
	screen.new_world_requested.connect(func():new_requests+=1)
	screen.resume_world_requested.connect(func(id):resume_requests.append(id))
	screen.import_requested.connect(func():import_requests+=1)
	await process_frame
	check(screen.home_page.visible and not screen.worlds_page.visible,"home is the first page")
	check(screen._world_detail({"stage":"forest"},true).begins_with("숲의 마을"),"stage names use catalog array indexes")
	check(screen._saved_date({"savedAtMs":Time.get_unix_time_from_system()*1000}).contains("방금"),"saved time is timezone-independent relative text")
	var worlds:Array=[]
	for i in range(11):worlds.append({"id":"world-%d"%i,"name":"도시 %d"%(i+1),"cash":123456,"stage":"forest","buildings":7,"savedAtMs":1700000000000,"valid":i!=1})
	for extent in [Vector2(390,844),Vector2(320,568),Vector2(844,320),Vector2(960,540)]:
		for density in [1.0,960.0/390.0]:
			owner_ui.scale_ui=density;screen.size=extent*density;screen.layout_screen();screen.set_loading(false);screen.show_home()
			await process_frame
			verify_controls(screen.home_page,screen,density,str(extent)+" home")
			screen.refresh(worlds);screen.show_worlds();await process_frame
			check(screen.rows.size()==screen.page_size,"world rows are paged: "+str(extent))
			verify_controls(screen.worlds_page,screen,density,str(extent)+" worlds")
			var invalid=screen.rows[1].get_node("ResumeButton")
			check(invalid.disabled,"invalid world cannot resume")
			var first=screen.rows[0].get_node("ResumeButton")
			check(first.position.x>screen.rows[0].size.x*0.5,"continue is on the right")
			screen.next_button.pressed.emit();await process_frame
			check(screen.page==1,"next page opens")
			verify_controls(screen.worlds_page,screen,density,str(extent)+" next page")
			screen.page=0
	screen.set_loading(false);screen.show_home();screen.new_button.pressed.emit();screen.new_button.pressed.emit()
	check(new_requests==1 and screen.loading,"new callback is protected against duplicate taps")
	screen.set_loading(false);screen.show_worlds();screen.refresh(worlds)
	screen._request_resume("world-1");check(resume_requests.is_empty(),"invalid resume rejected at action boundary")
	screen.rows[0].get_node("ResumeButton").pressed.emit();screen._request_resume("world-0")
	check(resume_requests==["world-0"],"resume emits the selected ID once")
	screen.set_loading(false);screen.refresh([]);screen.show_worlds();await process_frame
	check(screen.status_label.visible and screen.status_label.text.contains("아직"),"empty chooser explains its state")
	check(screen.import_button.visible and screen.empty_new_button.visible,"empty chooser permits import and new world")
	screen.import_button.pressed.emit();screen.import_button.pressed.emit();check(import_requests==1,"import guarded against repeated taps")
	check(not screen.loading and not screen.empty_new_button.disabled,"picker cancellation cannot lock the chooser")
	screen.set_loading(false);screen.refresh([],"저장 파일을 읽을 수 없어요")
	check(screen.status_label.text=="저장 파일을 읽을 수 없어요","storage error remains visible")
	screen.set_loading(true);check(screen.new_button.disabled and screen.import_button.disabled,"loading disables actions")
	owner_ui.scale_ui=1;screen.size=Vector2(390,844);screen.set_loading(false);screen.show_home();screen.layout_screen()
	print("START_TAP_CENTER: ",screen.new_button.get_global_rect().get_center())
	print("START_SCREEN: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
func verify_controls(parent:Node,screen:Control,density:float,description:String):
	for child in parent.get_children():
		if child is Control and child.is_visible_in_tree():
			var rect=child.get_global_rect();var bounds=screen.get_global_rect().grow(1)
			check(bounds.encloses(rect),description+" fits "+child.name)
			if child is Button:check(child.size.x/density>=47.9 and child.size.y/density>=47.9,description+" touch size "+child.name)
			verify_controls(child,screen,density,description)
