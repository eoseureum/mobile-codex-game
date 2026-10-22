extends SceneTree

var checks := 0
var failures := 0
var korean_characters := {}

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func _initialize() -> void:
	var font := load("res://assets/fonts/RustCity.otf") as FontFile
	check(font != null, "shipped font loads as a FontFile")
	if font == null:
		quit(1)
		return
	# A developer's installed Korean fonts must never hide a missing web glyph.
	font.allow_system_fallback = false
	font.fallbacks = []
	for directory in ["res://scripts", "res://data", "res://scenes"]:
		collect_sources(directory)
	check(not korean_characters.is_empty(), "catalog, script and scene Korean text was discovered")
	var codepoints := korean_characters.keys()
	codepoints.sort()
	for code in codepoints:
		check(font.has_char(code), "shipped font covers U+%04X %s (%s)" % [code, String.chr(code), korean_characters[code]])
	# Keep these reported regressions visible even if their catalog entries move.
	for text in ["나무꾼 휴게소", "구리괴"]:
		for index in text.length():
			check(font.has_char(text.unicode_at(index)), "reported label renders: " + text + " / " + text[index])
	print("FONT_GLYPHS: %d checks, %d failures / %d Korean characters" % [checks, failures, korean_characters.size()])
	quit(1 if failures else 0)

func collect_sources(directory: String) -> void:
	var files := DirAccess.get_files_at(directory)
	files.sort()
	for filename in files:
		if filename.get_extension() not in ["gd", "json", "tscn", "tres"]:
			continue
		var path := directory.path_join(filename)
		var content := FileAccess.get_file_as_string(path)
		if filename.get_extension() == "json":
			var json := JSON.new()
			check(json.parse(content) == OK, "catalog parses: " + path)
			collect_json(json.data, path)
		else:
			collect_text(content, path)
	var directories := DirAccess.get_directories_at(directory)
	directories.sort()
	for child in directories:
		collect_sources(directory.path_join(child))

func collect_json(value: Variant, path: String) -> void:
	if value is String:
		collect_text(value, path)
	elif value is Dictionary:
		for key in value:
			collect_text(str(key), path)
			collect_json(value[key], path)
	elif value is Array:
		for child in value:
			collect_json(child, path)

func collect_text(text: String, path: String) -> void:
	for index in text.length():
		var code := text.unicode_at(index)
		if (code >= 0xAC00 and code <= 0xD7A3) or (code >= 0x1100 and code <= 0x11FF) or (code >= 0x3130 and code <= 0x318F) or (code >= 0xA960 and code <= 0xA97F) or (code >= 0xD7B0 and code <= 0xD7FF):
			korean_characters[code] = path
