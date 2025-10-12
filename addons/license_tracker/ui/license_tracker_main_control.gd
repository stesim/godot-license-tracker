@tool
extends Control


const LicensedAssetDatabase := preload("../core/licensed_asset_database.gd")

const LicenseTrackerSettings := preload("../core/license_tracker_settings.gd")


const DEBUG_SETTING := &"license_tracker/debug"


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
		%database_selection.is_plugin_instance = is_plugin_instance


var _settings := LicenseTrackerSettings.new()


func _enter_tree() -> void:
	if Engine.is_editor_hint() and not is_plugin_instance:
		return

	_database_changed()
	_set_up_reload_button()


func _ready() -> void:
	%database_selection.database_selected.connect(
		func(selection: LicensedAssetDatabase) -> void:
			database = selection
			_settings.database_file = database.resource_path
	)


func _database_changed() -> void:
	if not is_inside_tree():
		return
	if Engine.is_editor_hint() and not is_plugin_instance:
		return

	%Assets.database = database
	%Licenses.database = database

	$tabs.visible = database != null
	$database_selection_container.visible = database == null


func _set_up_reload_button() -> void:
	if _settings.debug:
		$restart_button.show()
		$restart_button.pressed.connect(
			func() -> void:
				EditorInterface.set_plugin_enabled.call_deferred("license_tracker", true)
				EditorInterface.set_main_screen_editor.call_deferred("Licenses")
				EditorInterface.set_plugin_enabled("license_tracker", false)
		)
