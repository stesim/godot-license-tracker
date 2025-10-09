@tool
extends Control


const LicensedAssetDatabase := preload("../core/licensed_asset_database.gd")


var _just_changed_extensions := false


@export var is_plugin_instance := false

@export var database: LicensedAssetDatabase : set = _set_database


@onready var _undo_redo := EditorInterface.get_editor_undo_redo()


func _ready() -> void:
	if Engine.is_editor_hint() and not is_plugin_instance:
		return

	_database_changed()

	%extensions_edit.text_changed.connect(_on_tracked_extensions_edit_text_changed)


func _set_database(value: LicensedAssetDatabase) -> void:
	if database == value:
		return
	if Engine.is_editor_hint() and not is_plugin_instance:
		database = value
		return

	if database != null:
		database.property_value_changed.disconnect(_on_database_property_value_changed)

	database = value

	if database != null:
		database.property_value_changed.connect(_on_database_property_value_changed)

	_database_changed()


func _database_changed() -> void:
	if not is_node_ready():
		return

	if database != null:
		var extensions_string := ",".join(database.tracked_extensions)
		_update_editable(%extensions_edit, true, extensions_string)
	else:
		_update_editable(%extensions_edit, false)


func _on_tracked_extensions_edit_text_changed(text: String) -> void:
	var extensions := text.split(",", false)
	for i in extensions.size():
		extensions[i] = extensions[i].strip_edges()
	_undo_redo.create_action("Set tracked extensions", UndoRedo.MERGE_ENDS, database)
	_undo_redo.add_do_property(database, &"tracked_extensions", extensions)
	_undo_redo.add_undo_property(database, &"tracked_extensions", database.tracked_extensions)
	_just_changed_extensions = true
	_undo_redo.commit_action()
	_just_changed_extensions = false


func _on_database_property_value_changed(property: StringName, value: Variant) -> void:
	match property:
		&"tracked_extensions":
			if not _just_changed_extensions:
				var extensions_string := ",".join(database.tracked_extensions)
				_update_text_value(%extensions_edit, extensions_string)


func _update_editable(control: Control, editable: bool, text := "") -> void:
	control.text = text
	control.editable = editable


func _update_text_value(control: Control, value: String, check_trimmed := true) -> void:
	if control.text == value or (check_trimmed and control.text.strip_edges() == value):
		return

	control.text = value
