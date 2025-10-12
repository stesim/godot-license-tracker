@tool
extends EditorPlugin


const License := preload("./core/license.gd")

const LicensedAssetDatabase := preload("./core/licensed_asset_database.gd")

const LicenseTrackerSettings := preload("./core/license_tracker_settings.gd")


const PLUGIN_ICON := preload("./icon.svg")

const DEFAULT_DATABASE_FILE := "res://licenses.tres"

const MAIN_CONTROL_SCENE := preload("./ui/license_tracker_main_control.tscn")


var _settings := LicenseTrackerSettings.new()

var _main_control: Control = null


func _enter_tree() -> void:
	assert(_main_control == null)

	LicenseTrackerSettings.initialize_project_settings()

	_main_control = MAIN_CONTROL_SCENE.instantiate()
	_main_control.is_plugin_instance = true
	_main_control.database = _load_database()
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


func _load_database() -> LicensedAssetDatabase:
	var database_file := _settings.database_file
	if database_file.is_empty():
		return null

	if not ResourceLoader.exists(database_file):
		EditorInterface.get_editor_toaster().push_toast(
			"Missing license tracker database",
			EditorToaster.SEVERITY_ERROR,
			"Cannot find license tracker database: %s" % database_file,
		)
		return null

	var db := ResourceLoader.load(database_file) as LicensedAssetDatabase
	if db == null:
		EditorInterface.get_editor_toaster().push_toast(
			"Invalid license tracker database",
			EditorToaster.SEVERITY_ERROR,
			"File is not a valid license tracker database: %s" % database_file,
		)

	return db
