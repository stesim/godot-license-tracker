@tool
extends EditorPlugin


const License := preload("./core/license.gd")

const LicensedAssetDatabase := preload("./core/licensed_asset_database.gd")


const PLUGIN_ICON := preload("./icon.svg")

const DATABASE_FILE := "res://licenses.tres"

const MAIN_CONTROL_SCENE := preload("./ui/license_tracker_main_control.tscn")

const DEFAULT_EXTENSIONS_RESOURCE_TYPES: PackedStringArray = [
	"Texture",
	"AudioStream",
	"PackedScene",
	"Font",
]

const DEFAULT_EXTENSIONS_IGNORED: PackedStringArray = [
	"tres",
	"res",
	"tscn",
	"scn",
]


var _main_control: Control = null


func _enter_tree() -> void:
	assert(_main_control == null)

	_main_control = MAIN_CONTROL_SCENE.instantiate()
	_main_control.is_plugin_instance = true
	_main_control.database = _load_or_create_database()
	EditorInterface.get_editor_main_screen().add_child(_main_control)
	_make_visible(false)


func _exit_tree() -> void:
	if _main_control != null:
		_main_control.queue_free()


func _has_main_screen() -> bool:
	return true


func _make_visible(visible: bool) -> void:
	if _main_control != null:
		_main_control.visible = visible


func _get_plugin_name() -> String:
	return "Licenses"


func _get_plugin_icon() -> Texture2D:
	return PLUGIN_ICON


func _load_or_create_database() -> LicensedAssetDatabase:
	var db: LicensedAssetDatabase

	if ResourceLoader.exists(DATABASE_FILE):
		db = ResourceLoader.load(DATABASE_FILE) as LicensedAssetDatabase
		if db == null:
			EditorInterface.get_editor_toaster().push_toast(
				"Failed to load license tracker database",
				EditorToaster.SEVERITY_ERROR,
				"File is not a valid license tracker database: %s" % DATABASE_FILE,
			)
			return null
	else:
		db = _create_default_database()
		ResourceSaver.save(db, DATABASE_FILE)
		db.take_over_path(DATABASE_FILE)

	return db


func _create_default_database() -> LicensedAssetDatabase:
	var db := LicensedAssetDatabase.new()
	db.tracked_extensions = _collect_default_extensions()
	db.licenses = _load_default_licenses()
	return db


func _load_default_licenses() -> Array[License]:
	var licenses: Array[License] = []
	var plugin_dir := (get_script() as Script).resource_path.get_base_dir()
	var licenses_dir := plugin_dir.path_join("licenses")
	for file in ResourceLoader.list_directory(licenses_dir):
		var license := ResourceLoader.load(licenses_dir.path_join(file)) as License
		if license:
			licenses.push_back(license)
	return licenses


func _collect_default_extensions() -> PackedStringArray:
	var extensions: Dictionary[String, bool] = {}
	for type in DEFAULT_EXTENSIONS_RESOURCE_TYPES:
		for extension in ResourceLoader.get_recognized_extensions_for_type(type):
			extensions[extension] = true
	for extension in DEFAULT_EXTENSIONS_IGNORED:
		extensions.erase(extension)
	return PackedStringArray(extensions.keys())
