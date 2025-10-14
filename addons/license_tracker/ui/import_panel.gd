@tool
extends Control


const License := preload("../core/license.gd")

const LicensedAsset := preload("../core/licensed_asset.gd")

const LicensedAssetDatabase := preload("../core/licensed_asset_database.gd")

const JsonImport := preload("../core/json_import.gd")


@export var database: LicensedAssetDatabase : set = _set_database


var is_plugin_instance := false


var _import_dialog: EditorFileDialog

var _imported_database: LicensedAssetDatabase = null :
	set(value):
		if _imported_database != value:
			_imported_database = value
			_imported_database_changed()


@onready var _undo_redo := EditorInterface.get_editor_undo_redo()

@onready var _assets_tree := %assets_tree as Tree

@onready var _licenses_tree := %licenses_tree as Tree


func _ready() -> void:
	if Engine.is_editor_hint() and not is_plugin_instance:
		return

	_import_dialog = _create_import_dialog()

	_set_up_button(%select_all_assets_button, _tree_set_checked.bind(_assets_tree, true), &"GuiCheckedDisabled")
	_set_up_button(%deselect_all_assets_button, _tree_set_checked.bind(_assets_tree, false), &"GuiUncheckedDisabled")
	_set_up_button(%select_all_licenses_button, _tree_set_checked.bind(_licenses_tree, true), &"GuiCheckedDisabled")
	_set_up_button(%deselect_all_licenses_button, _tree_set_checked.bind(_licenses_tree, false), &"GuiUncheckedDisabled")

	_set_up_button(%import_button, _import_dialog.popup_file_dialog)
	_set_up_button(%confirm_button, _add_import_to_database)
	_set_up_button(%cancel_button, _cancel_import)

	_database_changed()


func _set_database(value: LicensedAssetDatabase) -> void:
	if database == value:
		return
	if Engine.is_editor_hint() and not is_plugin_instance:
		database = value
		return

	database = value

	_database_changed()


func _database_changed() -> void:
	if not is_node_ready():
		return

	_update_buttons()


func _imported_database_changed() -> void:
	if Engine.is_editor_hint() and not is_plugin_instance:
		return

	_assets_tree.clear()
	_assets_tree.create_item()
	_licenses_tree.clear()
	_licenses_tree.create_item()

	_update_buttons()

	if _imported_database != null:
		for asset in _imported_database.assets:
			_add_asset_to_tree(asset)
		for license in _imported_database.licenses:
			_add_license_to_tree(license)


func _update_buttons() -> void:
	var disabled := database == null or _imported_database == null
	%select_all_assets_button.disabled = disabled
	%deselect_all_assets_button.disabled = disabled
	%select_all_licenses_button.disabled = disabled
	%deselect_all_licenses_button.disabled = disabled

	var has_import := _imported_database != null
	%import_button.visible = not has_import
	%confirm_button.disabled = database == null
	%confirm_button.visible = has_import
	%cancel_button.visible = has_import


func _add_asset_to_tree(asset: LicensedAsset, index := -1) -> void:
	var item := _assets_tree.create_item(null, index)
	item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
	item.set_editable(0, true)
	item.set_checked(0, true)
	item.set_text(0, asset.asset_name)
	item.set_metadata(0, asset)


func _add_license_to_tree(license: License, index := -1) -> void:
	var item := _licenses_tree.create_item(null, index)
	item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
	item.set_editable(0, true)
	item.set_checked(0, not license.read_only)
	item.set_text(0, license.get_display_name())
	item.set_metadata(0, license)


func _import_database(path: String) -> void:
	var imported_db := LicensedAssetDatabase.new()
	if JsonImport.new().import_combined(path, imported_db, database):
		_imported_database = imported_db


func _add_import_to_database() -> void:
	if database == null or _import_database == null:
		return

	_undo_redo.create_action("Import licensing data", UndoRedo.MERGE_DISABLE, database, true)
	for license in _get_selected_licenses():
		_undo_redo.add_do_method(database, &"add_license", license)
		_undo_redo.add_undo_method(database, &"remove_license", license)
	for asset in _get_selected_assets():
		_undo_redo.add_do_method(database, &"add_asset", asset)
		_undo_redo.add_undo_method(database, &"remove_asset", asset)
	_undo_redo.commit_action()

	_imported_database = null


func _cancel_import() -> void:
	_imported_database = null


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


func _create_import_dialog() -> EditorFileDialog:
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = ["*.json"]
	dialog.file_selected.connect(_import_database)
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
