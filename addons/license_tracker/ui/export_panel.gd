@tool
extends Control


const License := preload("../core/license.gd")

const LicensedAsset := preload("../core/licensed_asset.gd")

const LicensedAssetDatabase := preload("../core/licensed_asset_database.gd")

const JsonExport := preload("../core/json_export.gd")


@export var database: LicensedAssetDatabase : set = _set_database


var is_plugin_instance := false


var _export_dialog: EditorFileDialog

var _export_attributions_dialog: EditorFileDialog


@onready var _assets_tree := %assets_tree as Tree

@onready var _licenses_tree := %licenses_tree as Tree


func _ready() -> void:
	if Engine.is_editor_hint() and not is_plugin_instance:
		return

	_export_dialog = _create_export_dialog()
	_export_attributions_dialog = _create_export_attributions_dialog()

	_set_up_button(%select_all_assets_button, _tree_set_checked.bind(_assets_tree, true), &"GuiCheckedDisabled")
	_set_up_button(%deselect_all_assets_button, _tree_set_checked.bind(_assets_tree, false), &"GuiUncheckedDisabled")
	_set_up_button(%select_all_licenses_button, _tree_set_checked.bind(_licenses_tree, true), &"GuiCheckedDisabled")
	_set_up_button(%deselect_all_licenses_button, _tree_set_checked.bind(_licenses_tree, false), &"GuiUncheckedDisabled")

	_set_up_button(%export_button, _export_dialog.popup_file_dialog)
	_set_up_button(%export_attributions_button, _export_attributions_dialog.popup_file_dialog)

	_database_changed(null)


func _set_database(value: LicensedAssetDatabase) -> void:
	if database == value:
		return
	if Engine.is_editor_hint() and not is_plugin_instance:
		database = value
		return

	if database != null:
		database.asset_added.disconnect(_add_asset_to_tree)
		database.asset_removed.disconnect(_remove_asset_from_tree)
		database.license_added.disconnect(_add_license_to_tree)
		database.license_removed.disconnect(_remove_license_from_tree)

	var previous_value := database
	database = value

	if database != null:
		database.asset_added.connect(_add_asset_to_tree)
		database.asset_removed.connect(_remove_asset_from_tree)
		database.license_added.connect(_add_license_to_tree)
		database.license_removed.connect(_remove_license_from_tree)

	_database_changed(previous_value)


func _database_changed(previous_database: LicensedAssetDatabase) -> void:
	if not is_node_ready():
		return

	if previous_database != null:
		for asset in previous_database.assets:
			asset.property_value_changed.disconnect(_on_asset_property_value_changed.bind(asset))
		for license in previous_database.licenses:
			license.display_name_changed.disconnect(_on_license_display_name_changed.bind(license))

	_assets_tree.clear()
	_assets_tree.create_item()
	_licenses_tree.clear()
	_licenses_tree.create_item()

	var disabled := database == null
	%select_all_assets_button.disabled = disabled
	%deselect_all_assets_button.disabled = disabled
	%select_all_licenses_button.disabled = disabled
	%deselect_all_licenses_button.disabled = disabled
	%export_button.disabled = disabled

	if database != null:
		for asset in database.assets:
			_add_asset_to_tree(asset)
		for license in database.licenses:
			_add_license_to_tree(license)


func _add_asset_to_tree(asset: LicensedAsset, index := -1) -> void:
	var item := _assets_tree.create_item(null, index)
	item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
	item.set_editable(0, true)
	item.set_checked(0, true)
	item.set_text(0, asset.original_name)
	item.set_metadata(0, asset)

	asset.property_value_changed.connect(_on_asset_property_value_changed.bind(asset))


func _remove_asset_from_tree(asset: LicensedAsset, index := -1) -> void:
	asset.property_value_changed.disconnect(_on_asset_property_value_changed.bind(asset))

	if index >= 0:
		var item := _assets_tree.get_root().get_child(index)
		assert(item.get_metadata(0) == asset)
		_assets_tree.get_root().remove_child(item)
	else:
		var item := _get_asset_item(asset)
		if item:
			_assets_tree.get_root().remove_child(item)


func _on_asset_property_value_changed(property: StringName, value: Variant, asset: LicensedAsset) -> void:
	if property == &"original_name":
		var item := _get_asset_item(asset)
		item.set_text(0, value)


func _add_license_to_tree(license: License, index := -1) -> void:
	var item := _licenses_tree.create_item(null, index)
	item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
	item.set_editable(0, true)
	item.set_checked(0, not license.read_only)
	item.set_text(0, license.get_display_name())
	item.set_metadata(0, license)

	license.display_name_changed.connect(_on_license_display_name_changed.bind(license))


func _remove_license_from_tree(license: License, index := -1) -> void:
	license.display_name_changed.disconnect(_on_license_display_name_changed.bind(license))

	if index >= 0:
		var item := _licenses_tree.get_root().get_child(index)
		assert(item.get_metadata(0) == license)
		_licenses_tree.get_root().remove_child(item)
	else:
		var item := _get_license_item(license)
		if item:
			_licenses_tree.get_root().remove_child(item)


func _on_license_display_name_changed(license: License) -> void:
	var item := _get_license_item(license)
	item.set_text(0, license.get_display_name())


func _export_database(path: String) -> void:
	var assets := _get_selected_assets()
	var licenses := _get_selected_licenses()
	JsonExport.new().export_combined(path, assets, licenses)


func _export_attributions(path: String) -> void:
	var format := (
		LicensedAsset.AttributionFormat.MARKDOWN if path.get_extension() == "md"
		else LicensedAsset.AttributionFormat.PLAIN
	)

	var attributions := PackedStringArray()
	for asset in _get_selected_assets():
		var attribution := asset.generate_attribution(format)
		attributions.push_back(attribution)

	var string := "\n\n".join(attributions)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(string)


func _get_selected_assets() -> Array[LicensedAsset]:
	var assets: Array[LicensedAsset] = []
	for item in _assets_tree.get_root().get_children():
		if item.is_checked(0):
			var asset: LicensedAsset = item.get_metadata(0)
			assets.push_back(asset)
	return assets


func _get_selected_licenses() -> Array[License]:
	var licenses: Array[License] = []
	for item in _licenses_tree.get_root().get_children():
		if item.is_checked(0):
			var license: License = item.get_metadata(0)
			licenses.push_back(license)
	return licenses


func _get_asset_item(asset: LicensedAsset) -> TreeItem:
	for item in _assets_tree.get_root().get_children():
		var item_asset: LicensedAsset = item.get_metadata(0)
		if item_asset == asset:
			return item
	return null


func _get_license_item(license: License) -> TreeItem:
	for item in _licenses_tree.get_root().get_children():
		var item_license: License = item.get_metadata(0)
		if item_license == license:
			return item
	return null


func _tree_set_checked(tree: Tree, value: bool) -> void:
	tree.get_root().call_recursive(&"set_checked", 0, value)


func _create_export_dialog() -> EditorFileDialog:
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	dialog.filters = ["*.json"]
	dialog.file_selected.connect(_export_database)
	dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	add_child(dialog)
	return dialog


func _create_export_attributions_dialog() -> EditorFileDialog:
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	dialog.filters = ["*.txt; Plain text", "*.md; Markdown"]
	dialog.file_selected.connect(_export_attributions)
	dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	add_child(dialog)
	return dialog


func _set_up_button(button: Button, on_pressed: Callable, icon_name := &"") -> void:
	if icon_name and Engine.is_editor_hint():
		button.icon = _get_editor_icon(icon_name)
		button.text = ""
	button.pressed.connect(on_pressed)


func _get_editor_icon(icon_name: StringName) -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon(icon_name, &"EditorIcons")
