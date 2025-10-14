@tool
extends ItemList


const License := preload("../core/license.gd")

const LicensedAsset := preload("../core/licensed_asset.gd")

const LicensedAssetDatabase := preload("../core/licensed_asset_database.gd")

const LicenseFileWatcher := preload("../core/license_file_watcher.gd")

const Utils := preload("../core/utils.gd")


signal updated()


@export var database: LicensedAssetDatabase : set = _set_database

@export var active := false :
	set(value):
		if active != value:
			active = value
			if active and Engine.is_editor_hint() and is_plugin_instance:
				_queue_update()


var is_plugin_instance := false


func get_selected_file() -> String:
	var selected_items := get_selected_items()
	if selected_items.size() != 1:
		return ""

	return get_item_text(selected_items[0])


func _ready() -> void:
	if not Engine.is_editor_hint() or not is_plugin_instance:
		return

	var fs := EditorInterface.get_resource_filesystem()
	fs.filesystem_changed.connect(_queue_update)
	_queue_update()

	item_activated.connect(_on_item_activated)


func _set_database(value: LicensedAssetDatabase) -> void:
	if database == value:
		return
	if not Engine.is_editor_hint() or not is_plugin_instance:
		database = value
		return

	if database != null:
		database.license_added.disconnect(_on_database_license_added)
		database.license_removed.disconnect(_on_database_license_removed)
		for license in database.licenses:
			license.property_value_changed.disconnect(_on_license_property_value_changed)
		database.asset_added.disconnect(_on_database_asset_added)
		database.asset_removed.disconnect(_on_database_asset_removed)
		for asset in database.assets:
			asset.property_value_changed.disconnect(_on_asset_property_value_changed)

	database = value

	if database != null:
		database.license_added.connect(_on_database_license_added)
		database.license_removed.connect(_on_database_license_removed)
		for license in database.licenses:
			license.property_value_changed.connect(_on_license_property_value_changed)
		database.asset_added.connect(_on_database_asset_added)
		database.asset_removed.connect(_on_database_asset_removed)
		for asset in database.assets:
			asset.property_value_changed.connect(_on_asset_property_value_changed)

	_queue_update()


func _update() -> void:
	if database == null:
		clear()
		return

	var checked_paths: Dictionary[String, bool] = {}
	for index in range(item_count - 1, -1, -1):
		var path := get_item_text(index)
		var is_tracked := _is_license_file_tracked(path)
		if is_tracked or not FileAccess.file_exists(path):
			remove_item(index)
		checked_paths[path] = true

	var license_files := LicenseFileWatcher.scan_for_license_files()
	for path in license_files:
		if path in checked_paths:
			continue
		var is_tracked := _is_license_file_tracked(path)
		if not is_tracked and _get_item_by_path(path) < 0:
			add_item(path)

	sort_items_by_text()
	updated.emit()


func _is_license_file_tracked(path: String) -> bool:
	return (
		database.get_license_by_file(path) != null
		or database.get_asset_by_license_file(path) != null
	)


func _queue_update() -> void:
	if active:
		Utils.queue(_update)


func _on_database_license_added(license: License, _index: int) -> void:
	license.property_value_changed.connect(_on_license_property_value_changed)
	if license.file:
		_queue_update()


func _on_database_license_removed(license: License, _index: int) -> void:
	license.property_value_changed.disconnect(_on_license_property_value_changed)
	if license.file:
		_queue_update()


func _on_license_property_value_changed(property: StringName, _value: Variant) -> void:
	if property == &"file":
		_queue_update()


func _on_database_asset_added(asset: LicensedAsset, _index: int) -> void:
	asset.property_value_changed.connect(_on_asset_property_value_changed)
	if asset.license_file:
		_queue_update()


func _on_database_asset_removed(asset: LicensedAsset, _index: int) -> void:
	asset.property_value_changed.disconnect(_on_asset_property_value_changed)
	if asset.license_file:
		_queue_update()


func _on_asset_property_value_changed(property: StringName, _value: Variant) -> void:
	if property == &"license_file":
		_queue_update()


func _on_item_activated(index: int) -> void:
	if index < 0:
		return
	
	var path := get_item_text(index)
	Utils.navigate_to(path)


func _get_item_by_path(path: String) -> int:
	return Utils.find_item_list_item_by_text(self, path)
