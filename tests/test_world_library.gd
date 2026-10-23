extends SceneTree
const Factory=preload("res://scripts/core/factory.gd")
const Store=preload("res://scripts/core/save_store.gd")
const Fixture=preload("res://tests/world_fixture.gd")
var checks=0
var failures=0
var root_path="/tmp/rust-world-library-"+str(Time.get_ticks_usec())
func check(value,message):
	checks+=1
	if not value:failures+=1;printerr("FAIL: "+message)
func put(path:String,value:String):
	var file=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(value);file.close()
func remove_tree(path:String):
	for file in DirAccess.get_files_at(path):DirAccess.remove_absolute(path.path_join(file))
	for folder in DirAccess.get_directories_at(path):remove_tree(path.path_join(folder))
	DirAccess.remove_absolute(path)
func _initialize():
	var store=Store.new()
	check(store.has_method("write_snapshot"),"save store accepts a validated snapshot without replacing its timestamp")
	check(FileAccess.file_exists("res://scripts/core/world_library.gd"),"independent world library is available")
	if failures:finish();return
	var Library=load("res://scripts/core/world_library.gd")
	var library=Library.new(root_path,root_path+"-legacy.json")
	check(library.worlds().is_empty() and not DirAccess.dir_exists_absolute(root_path),"listing an unused library does not create or migrate saves")
	var first=Factory.new();Fixture.empty(first,11)
	var first_id=library.create(first)
	check(first_id=="world_1","first save receives an independent ID")
	if first_id.is_empty():finish();return
	var saved=library.load_world(first_id)
	check(saved.state.entities.is_empty() and saved.state.cash==first.data.facilities.forest.cost,"new empty city persists without producing starter buildings or cash")
	var second=Factory.new();Fixture.empty(second,22)
	var second_id=library.create(second)
	first.state.cash=777;first.advance(0.5)
	check(library.save_world(first_id,first),"active city can save into its selected slot")
	check(library.load_world(first_id).state.cash==777 and library.load_world(second_id).state.cash==second.data.facilities.forest.cost,"saving one city leaves another city untouched")
	var rows=library.worlds()
	var by_id={}
	for row in rows:by_id[row.id]=row
	check(by_id[first_id].name=="도시 1" and by_id[second_id].name=="도시 2","worlds receive automatic display names")
	check(by_id[first_id].cash==777 and by_id[first_id].elapsedS==0.5 and by_id[first_id].seed==11 and by_id[first_id].buildings==0 and by_id[first_id].valid and by_id[first_id].error.is_empty(),"rows expose saved city summaries")
	for bad_id in ["../world_1","world_0","world_01","world_1.json","world_1/other","world_1\n","legacy/../world_1",""]:
		check(library.load_world(bad_id).is_empty() and not library.last_error.is_empty(),"unsafe ID cannot load: "+bad_id)
		check(not library.save_world(bad_id,first),"unsafe ID cannot save: "+bad_id)
	check(not library.save_world("world_999",first),"saving cannot silently create an unselected slot")
	var snapshot=store.snapshot(second);snapshot.savedAtMs=987654
	var custom_script=load("res://scripts/core/save_store.gd")
	var custom=custom_script.new(root_path.path_join("custom.json"))
	check(custom.write_snapshot(snapshot) and custom.load_city().savedAtMs==987654,"snapshot writer preserves original save timestamp at an injected path")
	var imported=library.import_snapshot(snapshot)
	check(imported=="world_3" and library.load_world(imported).savedAtMs==987654,"import makes a separate world and preserves timestamp")
	var existing=FileAccess.get_file_as_string(root_path.path_join("world_1.json"))
	var invalid=snapshot.duplicate(true);invalid.state.cash=-1
	var count_before=DirAccess.get_files_at(root_path).size()
	check(library.import_snapshot(invalid).is_empty() and not library.last_error.is_empty(),"invalid import is rejected")
	check(DirAccess.get_files_at(root_path).size()==count_before and FileAccess.get_file_as_string(root_path.path_join("world_1.json"))==existing,"invalid import creates no slot and changes no existing files")
	put(root_path.path_join("world_4.json"),"damaged")
	put(root_path.path_join("world_5.json.tmp"),"interrupted")
	put(root_path.path_join("world_6.json.bak"),"damaged backup")
	check(library.create(second)=="world_7","new IDs never overwrite corrupt, temporary, or backup slot names")
	var fresh=Factory.new();fresh.fresh(789,true,33)
	var fresh_id=library.create(fresh)
	var fresh_saved=library.load_world(fresh_id)
	check(fresh_saved.state.cash==0 and fresh_saved.state.bag.is_empty(),"fresh game preserves its zero-resource opening")
	check(fresh_saved.state.entities.size()==2 and JSON.stringify(fresh_saved.state.entities)==JSON.stringify(JSON.parse_string(JSON.stringify(fresh.state.entities))),"fresh game preserves its central hub and paid logging camp without production")
	by_id={}
	for row in library.worlds():by_id[row.id]=row
	check(by_id.has("world_4") and not by_id.world_4.valid and not by_id.world_4.error.is_empty(),"damaged save remains visible with an error")
	check(by_id.has("world_5") and not by_id.world_5.valid and by_id.has("world_6") and not by_id.world_6.valid,"incomplete slots remain visible")
	check(not library.load_world(first_id).is_empty() and library.last_error.is_empty(),"a broken slot does not block or contaminate a healthy load")
	check(library.save_world(first_id,first),"second save retains an automatic backup")
	put(root_path.path_join(first_id+".json"),"corrupt primary")
	check(library.load_world(first_id).state.cash==777 and not library.last_error.is_empty(),"valid backup recovers a corrupt primary with a notice")
	DirAccess.remove_absolute(root_path.path_join(first_id+".json"))
	check(library.load_world(first_id).state.cash==777,"valid backup also recovers a missing primary")
	var legacy_path=root_path+"-legacy.json"
	put(legacy_path,JSON.stringify(snapshot))
	by_id={}
	for row in library.worlds():by_id[row.id]=row
	check(not by_id.has("legacy") and not FileAccess.file_exists(root_path.path_join("legacy.json")),"listing never implicitly migrates a legacy save")
	check(library.migrate_existing(),"legacy save copies into a separate world")
	var migrated=library.load_world("legacy")
	check(migrated.savedAtMs==987654 and JSON.stringify(migrated)==JSON.stringify(JSON.parse_string(JSON.stringify(snapshot))),"migration preserves timestamp and complete snapshot contents")
	check(FileAccess.file_exists(legacy_path),"migration retains the original single-world save")
	second.state.cash=888
	check(library.save_world("legacy",second) and library.migrate_existing() and library.load_world("legacy").state.cash==888,"repeated migration never overwrites a changed migrated city")
	by_id={};rows=library.worlds()
	for row in rows:by_id[row.id]=row
	check(by_id.legacy.name=="기존 도시","migrated city has its own automatic name")
	for i in range(1,rows.size()):check(rows[i-1].savedAtMs>=rows[i].savedAtMs,"worlds sort by most recent save first")
	var damaged_root=root_path+"-damaged"
	DirAccess.make_dir_recursive_absolute(damaged_root)
	put(damaged_root.path_join("legacy.json"),"keep damaged destination")
	var damaged_library=Library.new(damaged_root,legacy_path)
	check(not damaged_library.migrate_existing() and FileAccess.get_file_as_string(damaged_root.path_join("legacy.json"))=="keep damaged destination","migration refuses to overwrite a damaged destination")
	var empty_library=Library.new(root_path+"-unused",root_path+"-missing.json")
	check(empty_library.import_snapshot(invalid).is_empty() and not DirAccess.dir_exists_absolute(root_path+"-unused"),"invalid import into a new library leaves no directory or partial slot")
	check(empty_library.migrate_existing() and empty_library.worlds().is_empty(),"absent legacy saves require no migration")
	var interrupted_root=root_path+"-interrupted"
	DirAccess.make_dir_recursive_absolute(interrupted_root)
	put(interrupted_root.path_join("legacy.json.tmp"),"keep interrupted destination")
	var interrupted_library=Library.new(interrupted_root,legacy_path)
	check(not interrupted_library.migrate_existing() and FileAccess.get_file_as_string(interrupted_root.path_join("legacy.json.tmp"))=="keep interrupted destination" and not FileAccess.file_exists(interrupted_root.path_join("legacy.json")),"migration does not overwrite an interrupted destination")
	remove_tree(interrupted_root)
	var backup_root=root_path+"-backup"
	var backup_path=root_path+"-backup.json"
	put(backup_path+".bak",JSON.stringify(snapshot))
	var backup_library=Library.new(backup_root,backup_path)
	check(backup_library.migrate_existing() and backup_library.load_world("legacy").savedAtMs==987654 and FileAccess.file_exists(backup_path+".bak"),"migration can recover a lone legacy backup without removing it")
	remove_tree(backup_root);DirAccess.remove_absolute(backup_path+".bak")
	var older=snapshot.duplicate(true);older.state.world.erase("scatterVersion")
	var older_path=root_path+"-older.json"
	put(older_path,JSON.stringify(older))
	var older_root=root_path+"-older"
	var older_library=Library.new(older_root,older_path)
	check(older_library.migrate_existing(),"older supported world format migrates")
	var copied=JSON.parse_string(FileAccess.get_file_as_string(older_root.path_join("legacy.json")))
	check(JSON.stringify(copied)==JSON.stringify(JSON.parse_string(JSON.stringify(older))),"migration copies the complete original snapshot before normal load upgrades")
	remove_tree(older_root);DirAccess.remove_absolute(older_path)
	remove_tree(damaged_root);remove_tree(root_path);DirAccess.remove_absolute(legacy_path)
	finish()
func finish():
	print("WORLD_LIBRARY: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
