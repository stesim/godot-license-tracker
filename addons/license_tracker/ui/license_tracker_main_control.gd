@tool
extends Control


const LicensedAssetDatabase := preload("../core/licensed_asset_database.gd")


const DEBUG_ENABLED := false


@export var is_plugin_instance := false :
	set(value):
		is_plugin_instance = value
		%Assets.is_plugin_instance = is_plugin_instance
		%Licenses.is_plugin_instance = is_plugin_instance
		%Settings.is_plugin_instance = is_plugin_instance

@export var database: LicensedAssetDatabase


func _enter_tree() -> void:
	if Engine.is_editor_hint() and not is_plugin_instance:
		return

	%Assets.database = database
	%Licenses.database = database
	%Settings.database = database

	if DEBUG_ENABLED:
		$restart_button.show()
		$restart_button.pressed.connect(
			func() -> void:
				EditorInterface.set_plugin_enabled.call_deferred("license_tracker", true)
				EditorInterface.set_main_screen_editor.call_deferred("Licenses")
				EditorInterface.set_plugin_enabled("license_tracker", false)
		)
