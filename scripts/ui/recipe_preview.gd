extends RefCounted
const Art=preload("res://scripts/ui/pixel_art.gd")
static func first(game,kind) -> bool:
	return game.central_sales() and not game.data.facilities[kind].input.is_empty() and not game.recorded("first_"+kind)
static func clear(ui):
	var content=ui.dialog.get_node_or_null("RecipeContent")
	if content!=null:content.hide();ui.dialog.remove_child(content);content.queue_free()
	ui.dialog.title="Rust City"
	if ui.dialog.has_meta("recipeKind"):ui.dialog.remove_meta("recipeKind")
	for child in ui.dialog.get_ok_button().get_parent().get_children():
		if not child is Button:child.show()
static func chip(ui,parent,resource,count):
	var row=HBoxContainer.new();parent.add_child(row)
	var picture=TextureRect.new();picture.texture=Art.texture("item_"+resource);picture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;picture.custom_minimum_size=Vector2(28,28)*ui.scale_ui;row.add_child(picture)
	ui._label(row,ui.game.data.resources[resource].name+" × "+str(int(count)))
static func align_actions(ui):
	if not ui.dialog.visible or not ui.dialog.has_meta("recipeKind"):return
	var actions=ui.dialog.get_ok_button().get_parent()
	if actions is BoxContainer:
		actions.alignment=BoxContainer.ALIGNMENT_END
		for child in actions.get_children():
			if not child is Button:child.hide()
static func show(ui,kind,install=Callable()):
	clear(ui)
	var game=ui.game;var f=game.data.facilities[kind];var u=ui.scale_ui
	ui.pending_action=install;ui.dialog.dialog_text="";ui.dialog.title=f.name+" · 생산식"
	ui.dialog.set_meta("recipeKind",kind)
	ui.dialog.get_ok_button().text="설치" if install.is_valid() else "확인"
	ui.dialog.get_cancel_button().text="취소";ui.dialog.get_cancel_button().visible=install.is_valid()
	ui.dialog.add_theme_constant_override("buttons_min_height",int(48*u));ui.dialog.add_theme_constant_override("buttons_min_width",int(72*u))
	var actions=ui.dialog.get_ok_button().get_parent()
	if actions is BoxContainer:
		actions.alignment=BoxContainer.ALIGNMENT_END
		for child in actions.get_children():
			if not child is Button:child.hide()
	var column=VBoxContainer.new();column.name="RecipeContent";column.add_theme_constant_override("separation",int(8*u));ui.dialog.add_child(column)
	var row=HBoxContainer.new();row.alignment=BoxContainer.ALIGNMENT_CENTER;row.add_theme_constant_override("separation",int(12*u));column.add_child(row)
	var inputs=VBoxContainer.new();row.add_child(inputs)
	for r in f.input:chip(ui,inputs,r,f.input[r])
	if f.input.is_empty():ui._label(inputs,"광맥" if kind=="mine" else "숲" if kind=="forest" else "원료 없음")
	ui._label(row,"→")
	var outputs=VBoxContainer.new();row.add_child(outputs)
	if kind=="generator":ui._label(outputs,"전력 +12")
	elif kind=="mine":ui._label(outputs,"해당 광물 × 1")
	else:
		for r in f.output:chip(ui,outputs,r,f.output[r])
	var timing=ui._label(column,"%.1f초 / 회"%(10.0 if kind=="generator" else f.cycle)+(" · 전력 %d"%f.power if f.power>0 else ""));timing.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var width=minf(330,ui.size.x/u-24)
	column.custom_minimum_size=Vector2(minf(286,width-24),0)*u
	ui.dialog.reset_size();ui.dialog.popup_centered(Vector2i(int(width*u),0))
	# AcceptDialog may restore its native centering spacers during popup layout.
	align_actions.call_deferred(ui)
