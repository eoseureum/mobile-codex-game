class_name RustWorldLibrary
extends RefCounted
const SaveStore=preload("res://scripts/core/save_store.gd")
const ROOT="user://rust-city-worlds"
var last_error=""
var root_path:String
var legacy_path:String

func _init(path:String=ROOT,old_path:String=SaveStore.PATH):
	root_path=path
	legacy_path=old_path

func _valid_id(id:String) -> bool:
	if id=="legacy":return true
	var matched=RegEx.create_from_string("^world_[1-9][0-9]*$").search(id)
	return matched!=null and matched.get_string()==id

func _path(id:String) -> String:
	return root_path.path_join(id+".json")

func _slot_exists(id:String) -> bool:
	for suffix in ["",".tmp",".bak"]:
		if FileAccess.file_exists(_path(id)+suffix) or DirAccess.dir_exists_absolute(_path(id)+suffix):return true
	return false

func _ids() -> Array:
	var ids={}
	for file in DirAccess.get_files_at(root_path):
		for suffix in [".json",".json.tmp",".json.bak"]:
			if file.ends_with(suffix):
				var id=file.trim_suffix(suffix)
				if _valid_id(id):ids[id]=true
	for folder in DirAccess.get_directories_at(root_path):
		for suffix in [".json",".json.tmp",".json.bak"]:
			if folder.ends_with(suffix):
				var id=folder.trim_suffix(suffix)
				if _valid_id(id):ids[id]=true
	return ids.keys()

func _prepare_root() -> bool:
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root_path))!=OK:
		last_error="도시 저장 폴더를 만들 수 없어요.";return false
	return true

func worlds() -> Array:
	last_error=""
	var rows:Array=[]
	if not DirAccess.dir_exists_absolute(root_path):return rows
	for id in _ids():
		var value=load_world(id)
		var row={"id":id,"name":"기존 도시" if id=="legacy" else "도시 "+id.trim_prefix("world_"),"savedAtMs":0,"cash":0,"stage":"","elapsedS":0,"seed":0,"buildings":0,"valid":not value.is_empty(),"error":last_error}
		if not value.is_empty():
			var state:Dictionary=value.state
			row.savedAtMs=value.savedAtMs;row.cash=state.cash;row.stage=state.stage
			row.elapsedS=state.clock.elapsedS;row.seed=state.get("world",{}).get("seed",0);row.buildings=state.entities.size()
		rows.append(row)
	rows.sort_custom(func(a,b):return a.savedAtMs>b.savedAtMs if a.savedAtMs!=b.savedAtMs else a.id.naturalnocasecmp_to(b.id)<0)
	last_error=""
	return rows

func create(game) -> String:
	return import_snapshot(SaveStore.new().snapshot(game))

func import_snapshot(snapshot:Dictionary) -> String:
	last_error=SaveStore.new().validate(snapshot)
	if not last_error.is_empty() or not _prepare_root():return ""
	var number=1
	while true:
		var id="world_"+str(number)
		number+=1
		if _slot_exists(id):continue
		var store=SaveStore.new(_path(id))
		var saved=store.write_snapshot(snapshot)
		last_error=store.last_error
		return id if saved else ""
	return ""

func load_world(id:String) -> Dictionary:
	last_error=""
	if not _valid_id(id):last_error="도시 식별자가 올바르지 않아요.";return {}
	var store=SaveStore.new(_path(id))
	var value=store.load_city()
	last_error=store.last_error
	if value.is_empty() and last_error.is_empty():last_error="도시 저장 파일이 없거나 저장이 완료되지 않았어요."
	return value

func save_world(id:String,game,saved_at_ms:int=-1) -> bool:
	last_error=""
	if not _valid_id(id):last_error="도시 식별자가 올바르지 않아요.";return false
	if not _slot_exists(id):last_error="저장할 도시를 먼저 선택해 주세요.";return false
	var store=SaveStore.new(_path(id))
	var snapshot=store.snapshot(game)
	if saved_at_ms>=0:snapshot.savedAtMs=saved_at_ms
	var saved=store.write_snapshot(snapshot)
	last_error=store.last_error
	return saved

func _legacy_snapshot() -> Dictionary:
	var source=SaveStore.new(legacy_path)
	for suffix in ["",".bak"]:
		if not FileAccess.file_exists(legacy_path+suffix):continue
		var text=FileAccess.get_file_as_string(legacy_path+suffix)
		if source.parse(text).is_empty():last_error=source.last_error;continue
		# Parsing proves the snapshot is usable; copy the original before load upgrades.
		return JSON.parse_string(text)
	return {}

func migrate_existing() -> bool:
	last_error=""
	if _slot_exists("legacy"):
		var existing=load_world("legacy")
		return not existing.is_empty()
	if not FileAccess.file_exists(legacy_path) and not FileAccess.file_exists(legacy_path+".bak"):return true
	var snapshot=_legacy_snapshot()
	if snapshot.is_empty():return false
	if not _prepare_root():return false
	# The destination itself records migration; no separate marker can claim success early.
	var target=SaveStore.new(_path("legacy"))
	var saved=target.write_snapshot(snapshot)
	last_error=target.last_error
	return saved
