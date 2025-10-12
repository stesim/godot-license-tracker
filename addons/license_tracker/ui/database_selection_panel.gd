@tool
extends Control


const License := preload("../core/license.gd")

const LicensedAssetDatabase := preload("../core/licensed_asset_database.gd")


signal database_selected(database: LicensedAssetDatabase)


const DEFAULT_DATABASE_FILE := "res://licenses.tres"


var is_plugin_instance := false


var _save_dialog: EditorFileDialog

var _load_dialog: EditorFileDialog


func _ready() -> void:
	if Engine.is_editor_hint() and not is_plugin_instance:
		return

	_save_dialog = _create_save_dialog()
	_load_dialog = _create_load_dialog()

	_set_up_button(%create_default_button, _create_database_at_default_path, &"Add")
	_set_up_button(%create_custom_button, _save_dialog.popup_file_dialog, &"Add")
	_set_up_button(%load_button, _load_dialog.popup_file_dialog, &"Load")


func _create_database_at_default_path() -> void:
	if FileAccess.file_exists(DEFAULT_DATABASE_FILE):
		push_error("Unable to create database. File already exists: ", DEFAULT_DATABASE_FILE)
		return

	_create_database(DEFAULT_DATABASE_FILE)


func _create_database(path: String) -> void:
	var db := LicensedAssetDatabase.new()
	db.licenses = _load_default_licenses()

	ResourceSaver.save(db, path)
	db.take_over_path(path)

	database_selected.emit(db)


func _load_database(path: String) -> void:
	var db := ResourceLoader.load(path)
	if db is not LicensedAssetDatabase:
		push_error("File is not licensing database: ", path)
		return
	
	database_selected.emit(db)


func _create_save_dialog() -> EditorFileDialog:
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	dialog.filters = ["*.tres, *.res"]
	dialog.file_selected.connect(_create_database)
	add_child(dialog)
	return dialog


func _create_load_dialog() -> EditorFileDialog:
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = ["*.tres, *.res"]
	dialog.file_selected.connect(_load_database)
	add_child(dialog)
	return dialog


func _load_default_licenses() -> Array[License]:
	var licenses: Array[License] = []
	var plugin_dir := (get_script() as Script).resource_path.get_base_dir()
	var licenses_dir := plugin_dir.path_join("../licenses")
	for file in ResourceLoader.list_directory(licenses_dir):
		var license := ResourceLoader.load(licenses_dir.path_join(file)) as License
		if license:
			licenses.push_back(license)
	return licenses


func _set_up_button(button: Button, on_pressed: Callable, icon_name := &"") -> void:
	if icon_name and Engine.is_editor_hint():
		button.icon = _get_editor_icon(icon_name)
	button.pressed.connect(on_pressed)


func _get_editor_icon(icon_name: StringName) -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon(icon_name, &"EditorIcons")
