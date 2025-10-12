@tool
extends Control


const License := preload("../core/license.gd")

const LicensedAssetDatabase := preload("../core/licensed_asset_database.gd")


@export var database: LicensedAssetDatabase : set = _set_database


var is_plugin_instance := false


var _selected_license: License : set = _set_selected_license


@onready var _undo_redo := EditorInterface.get_editor_undo_redo()

@onready var _license_list := %license_list as ItemList


func _ready() -> void:
	if Engine.is_editor_hint() and not is_plugin_instance:
		return

	_database_changed()
	_update_selected_license_details()

	_setup_button(%add_license_button, _on_add_license_button_pressed, &"Add")
	_setup_button(%remove_license_button, _on_remove_license_button_pressed, &"Remove")

	_license_list.item_selected.connect(_on_license_list_item_selected)

	%attribution_toggle.toggled.connect(_set_license_bool_property.bind(&"requires_attribution"))
	%modification_toggle.toggled.connect(_set_license_bool_property.bind(&"allows_modifications"))
	%commercial_use_toggle.toggled.connect(_set_license_bool_property.bind(&"allows_commercial_use"))
	%redistribution_toggle.toggled.connect(_set_license_bool_property.bind(&"allows_redistribution"))

	%short_name_edit.text_changed.connect(_set_license_string_property.bind(&"short_name"))
	%full_name_edit.text_changed.connect(_set_license_string_property.bind(&"full_name"))
	%file_edit.text_changed.connect(_set_license_string_property.bind(&"file"))
	%url_edit.text_changed.connect(_set_license_string_property.bind(&"url"))
	%text_edit.text_changed.connect(
		func() -> void: _set_license_string_property(%text_edit.text, &"text", false)
	)


func _set_database(value: LicensedAssetDatabase) -> void:
	if database == value:
		return
	if Engine.is_editor_hint() and not is_plugin_instance:
		database = value
		return

	if database != null:
		database.license_added.disconnect(_on_database_license_added)
		database.license_removed.disconnect(_on_database_license_removed)

	database = value

	if database != null:
		database.license_added.connect(_on_database_license_added)
		database.license_removed.connect(_on_database_license_removed)

	_database_changed()


func _database_changed() -> void:
	if not is_node_ready():
		return

	_license_list.clear()

	%add_license_button.disabled = database == null
	%remove_license_button.disabled = database == null

	if database != null:
		for license in database.licenses:
			_add_license_to_list(license)


func _on_database_license_added(license: License, index: int) -> void:
	_add_license_to_list(license, index)


func _on_database_license_removed(license: License, index: int) -> void:
	_remove_license_from_list(license, index)
	if license == _selected_license:
		_selected_license = null


func _on_add_license_button_pressed() -> void:
	var license := License.new()
	license.full_name = "New License"
	_add_license_to_database(license)


func _on_remove_license_button_pressed() -> void:
	var selected_licenses := _get_selected_licenses()
	if not selected_licenses.is_empty():
		_remove_licenses_from_database(selected_licenses)


func _add_license_to_database(license: License) -> void:
	_undo_redo.create_action("Add license(s)", UndoRedo.MERGE_DISABLE, database)
	var index := database.licenses.size()
	_undo_redo.add_do_method(database, &"add_license", license, index)
	_undo_redo.add_undo_method(database, &"remove_license", license, index)
	_undo_redo.commit_action()


func _remove_licenses_from_database(licenses: Array[License]) -> void:
	_undo_redo.create_action("Remove license(s)", UndoRedo.MERGE_DISABLE, database, true)
	for license in licenses:
		var index := database.licenses.find(license)
		# NOTE: remove immediately so indices of following items are correct
		database.remove_license(license, index)
		_undo_redo.add_do_method(database, &"remove_license", license, index)
		_undo_redo.add_undo_method(database, &"add_license", license, index)
	_undo_redo.commit_action(false)


func _on_license_list_item_selected(index: int) -> void:
	_selected_license = _get_item_license(index)


func _set_selected_license(value: License) -> void:
	if _selected_license != null:
		_selected_license.property_value_changed.disconnect(_on_selected_license_property_value_changed)
	_selected_license = value
	if _selected_license != null:
		_selected_license.property_value_changed.connect(_on_selected_license_property_value_changed)
	_update_selected_license_details()


func _update_selected_license_details() -> void:
	var license := _selected_license
	if license != null:
		var is_editable := not license.read_only

		_update_button(%remove_license_button, true)

		_update_editable(%short_name_edit, is_editable, license.short_name)
		_update_editable(%full_name_edit, is_editable, license.full_name)
		_update_editable(%url_edit, is_editable, license.url)
		_update_editable(%file_edit, is_editable, license.file)
		_update_editable(%text_edit, is_editable, license.text)

		_update_toggle(%attribution_toggle, is_editable, license.requires_attribution)
		_update_toggle(%modification_toggle, is_editable, license.allows_modifications)
		_update_toggle(%commercial_use_toggle, is_editable, license.allows_commercial_use)
		_update_toggle(%redistribution_toggle, is_editable, license.allows_redistribution)

		var selected_items := _license_list.get_selected_items()
		if selected_items.size() != 1 or _get_item_license(selected_items[0]) != license:
			var license_item := _get_license_item(license)
			_license_list.select(license_item)
	else:
		_update_button(%remove_license_button, false)

		_update_editable(%short_name_edit, false)
		_update_editable(%full_name_edit, false)
		_update_editable(%url_edit, false)
		_update_editable(%file_edit, false)
		_update_editable(%text_edit, false)

		_update_toggle(%attribution_toggle, false)
		_update_toggle(%modification_toggle, false)
		_update_toggle(%commercial_use_toggle, false)
		_update_toggle(%redistribution_toggle, false)

		if _license_list.is_anything_selected():
			_license_list.deselect_all()


func _on_selected_license_property_value_changed(property: StringName, value: Variant) -> void:
	match property:
		&"short_name": _update_text_value(%short_name_edit, value)
		&"full_name": _update_text_value(%full_name_edit, value)
		&"url": _update_text_value(%url_edit, value)
		&"file": _update_text_value(%file_edit, value)
		&"text_edit": _update_text_value(%text_edit, value, false)
		&"requires_attribution": _update_toggle_value(%attribution_toggle, value)
		&"allows_modifications": _update_toggle_value(%modification_toggle, value)
		&"allows_commercial_use": _update_toggle_value(%commercial_use_toggle, value)
		&"allows_redistribution": _update_toggle_value(%redistribution_toggle, value)


func _add_license_to_list(license: License, index := -1) -> void:
	var display_name := license.get_display_name()
	var initial_index := _license_list.add_item(display_name)
	_license_list.set_item_metadata(initial_index, license)
	if index >= 0:
		_license_list.move_item(initial_index, index)
	license.display_name_changed.connect(_on_license_display_name_changed.bind(license))


func _remove_license_from_list(license: License, index := -1) -> void:
	if index >= 0:
		assert(license == _get_item_license(index))
		_license_list.remove_item(index)
	else:
		index = _get_license_item(license)
		if index >= 0:
			_license_list.remove_item(index)
	license.display_name_changed.disconnect(_on_license_display_name_changed.bind(license))


func _on_license_display_name_changed(license: License) -> void:
	var item := _get_license_item(license)
	_license_list.set_item_text(item, license.get_display_name())


func _get_item_license(index: int) -> License:
	return _license_list.get_item_metadata(index) if index >= 0 else null


func _get_license_item(license: License) -> int:
	for item_index in _license_list.item_count:
		var item_license := _get_item_license(item_index)
		if item_license == license:
			return item_index
	return -1


func _get_selected_licenses() -> Array[License]:
	var selected_indices := _license_list.get_selected_items()
	var selected_licenses: Array[License] = []
	for index in selected_indices:
		var license := _get_item_license(index)
		selected_licenses.push_back(license)
	return selected_licenses


func _set_license_property(property: StringName, value: Variant) -> void:
	if _selected_license[property] == value:
		return

	var action_name: StringName = "Set " + property
	_undo_redo.create_action(action_name, UndoRedo.MERGE_ENDS, _selected_license)
	_undo_redo.add_do_property(_selected_license, property, value)
	_undo_redo.add_undo_property(_selected_license, property, _selected_license[property])
	_undo_redo.commit_action()


func _set_license_string_property(text: String, property: StringName, trim := true) -> void:
	if _selected_license != null:
		if trim:
			text = text.strip_edges()
		_set_license_property(property, text)


func _set_license_bool_property(value: bool, property: StringName) -> void:
	_set_license_property(property, value)


func _setup_button(button: Button, on_pressed: Callable, icon_name := &"") -> void:
	if icon_name and Engine.is_editor_hint():
		button.icon = EditorInterface.get_editor_theme().get_icon(icon_name, &"EditorIcons")
		button.text = ""
	button.pressed.connect(on_pressed)


func _update_editable(control: Control, editable: bool, text := "") -> void:
	control.text = text
	control.editable = editable


func _update_toggle(control: BaseButton, enabled: bool, value := false) -> void:
	control.set_pressed_no_signal(value)
	control.disabled = not enabled


func _update_button(control: BaseButton, enabled: bool) -> void:
	control.disabled = not enabled


func _update_text_value(control: Control, value: String, check_trimmed := true) -> void:
	if control.text == value or (check_trimmed and control.text.strip_edges() == value):
		return

	control.text = value


func _update_toggle_value(control: BaseButton, value: bool) -> void:
	if control.button_pressed != value:
		control.set_pressed_no_signal(value)
