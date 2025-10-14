@tool
extends Control


const LicensedAssetDatabase := preload("../core/licensed_asset_database.gd")

const LicenseTrackerSettings := preload("../core/license_tracker_settings.gd")

const DatabaseFilesWatcher := preload("../core/database_files_watcher.gd")


@export var database: LicensedAssetDatabase :
	set(value):
		if database != value:
			database = value
			_database_changed()


var is_plugin_instance := false :
	set(value):
		is_plugin_instance = value
		%Assets.is_plugin_instance = is_plugin_instance
		%Licenses.is_plugin_instance = is_plugin_instance
		%Export.is_plugin_instance = is_plugin_instance
		%Import.is_plugin_instance = is_plugin_instance
		%database_selection.is_plugin_instance = is_plugin_instance


var _settings := LicenseTrackerSettings.new()

var _watcher: DatabaseFilesWatcher


func _enter_tree() -> void:
	if Engine.is_editor_hint() and not is_plugin_instance:
		return

	_watcher = DatabaseFilesWatcher.new()

	_database_changed()
	_set_up_reload_button()

	%database_selection.database_selected.connect(_on_database_selection_database_selected)


func _on_database_selection_database_selected(selected: LicensedAssetDatabase) -> void:
	database = selected
	_settings.database_file = database.resource_path


func _database_changed() -> void:
	if not is_inside_tree():
		return
	if Engine.is_editor_hint() and not is_plugin_instance:
		return

	if _watcher:
		_watcher.database = database

	%Assets.database = database
	%Licenses.database = database
	%Export.database = database
	%Import.database = database

	$tabs.visible = database != null
	$database_selection_container.visible = database == null


func _set_up_reload_button() -> void:
	if _settings.debug:
		$restart_button.show()
		$restart_button.pressed.connect(_on_start_button_pressed)


func _on_start_button_pressed() -> void:
	EditorInterface.set_plugin_enabled.call_deferred("license_tracker", true)
	EditorInterface.set_main_screen_editor.call_deferred("Licenses")
	EditorInterface.set_plugin_enabled("license_tracker", false)
