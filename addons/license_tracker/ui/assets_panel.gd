@tool
extends Control


const License := preload("../core/license.gd")

const LicensedAsset := preload("../core/licensed_asset.gd")

const LicensedAssetDatabase := preload("../core/licensed_asset_database.gd")

const LicenseTrackerSettings := preload("../core/license_tracker_settings.gd")


@export var database: LicensedAssetDatabase : set = _set_database


var is_plugin_instance := false


var _settings := LicenseTrackerSettings.new()

var _selected_asset: LicensedAsset : set = _set_selected_asset

var _asset_load_dialog := _create_asset_load_dialog()

var _resource_tree_visibility_update_queued := false

var _resource_refresh_queued := true

var _tracked_extensions := _settings.tracked_extensions

var _credits_preview_dialog: AcceptDialog

var _external_link_confirmation_dialog: ConfirmationDialog


@onready var _undo_redo := EditorInterface.get_editor_undo_redo()

@onready var _asset_list := %asset_list as ItemList

@onready var _resource_tree := %resource_tree as Tree

@onready var _file_list := %file_list as ItemList


func _ready() -> void:
	if Engine.is_editor_hint() and not is_plugin_instance:
		return

	_credits_preview_dialog = _create_credits_preview_dialog()
	_external_link_confirmation_dialog = _create_external_link_confirmation_dialog()

	_database_changed()
	_update_selected_asset_details()

	_setup_button(%add_licensed_button, _on_add_licensed_button_pressed, &"Add")
	_setup_button(%remove_licensed_button, _on_remove_licensed_button_pressed, &"Remove")
	_setup_button(%open_source_button, _on_open_source_button_pressed, &"ExternalLink")
	_setup_button(%credits_preview_button, _on_credits_preview_button_pressed, &"NodeInfo")
	_setup_button(%retrieval_now_button, _on_retrieval_now_button_pressed, &"Time")
	_setup_button(%view_license_button, _on_view_license_button_pressed, &"ArrowRight")
	_setup_button(%add_files_button, _on_add_files_button_pressed, &"FileBrowse")
	_setup_button(%add_folder_button, _on_add_folder_button_pressed, &"FolderBrowse")
	_setup_button(%remove_file_button, _on_remove_file_button_pressed, &"Remove")

	visibility_changed.connect(_on_visibility_changed)

	_asset_list.item_selected.connect(_on_asset_list_item_selected)
	_resource_tree.item_activated.connect(_on_resource_tree_item_activated)
	_resource_tree.set_drag_forwarding(
		_resource_tree_get_drag_data,
		Callable(),
		Callable(),
	)
	_file_list.item_activated.connect(_on_file_list_item_activated)
	_file_list.set_drag_forwarding(
		Callable(),
		_file_list_can_drop_data,
		_file_list_drop_data,
	)

	%name_edit.text_changed.connect(_set_asset_string_property.bind(&"asset_name"))
	%author_edit.text_changed.connect(_set_asset_string_property.bind(&"author"))
	%description_edit.text_changed.connect(_set_asset_string_property.bind(&"description"))
	%source_edit.text_changed.connect(_set_asset_string_property.bind(&"source"))
	%retrieval_time_edit.text_changed.connect(_set_asset_string_property.bind(&"retrieved"))
	%attribution_edit.text_changed.connect(_set_asset_string_property.bind(&"custom_attribution"))
	%license_options.item_selected.connect(_on_license_options_item_selected)

	var fs := EditorInterface.get_resource_filesystem()
	fs.filesystem_changed.connect(_queue_resource_refresh)


func _on_visibility_changed() -> void:
	_check_for_resource_refresh()


func _set_database(value: LicensedAssetDatabase) -> void:
	if database == value:
		return
	if Engine.is_editor_hint() and not is_plugin_instance:
		database = value
		return

	if database != null:
		database.asset_added.disconnect(_on_database_asset_added)
		database.asset_removed.disconnect(_on_database_asset_removed)
		database.license_added.disconnect(_on_database_license_added)
		database.license_removed.disconnect(_on_database_license_removed)

	database = value

	if database != null:
		database.asset_added.connect(_on_database_asset_added)
		database.asset_removed.connect(_on_database_asset_removed)
		database.license_added.connect(_on_database_license_added)
		database.license_removed.connect(_on_database_license_removed)

	_database_changed()


func _database_changed() -> void:
	if not is_node_ready():
		return

	_asset_list.clear()

	_update_button(%add_licensed_button, database != null)

	if database == null:
		_update_button(%remove_licensed_button, false)

	if database != null:
		for asset in database.assets:
			_add_asset_to_list(asset)

	_update_license_options()
	_queue_resource_refresh()


func _on_database_asset_added(asset: LicensedAsset, index: int) -> void:
	_add_asset_to_list(asset, index)
	# TODO: check visibility only against asset's paths
	_queue_resource_tree_visibility_update()


func _on_database_asset_removed(asset: LicensedAsset, index: int) -> void:
	_remove_asset_from_list(asset, index)
	if asset == _selected_asset:
		_selected_asset = null
	# TODO: check visibility only against asset's paths
	_queue_resource_tree_visibility_update()


func _on_add_licensed_button_pressed() -> void:
	var asset := LicensedAsset.new()
	asset.asset_name = "Unnamed Asset"
	_add_asset_to_database(asset)


func _on_remove_licensed_button_pressed() -> void:
	var selected_assets := _get_selected_assets()
	if not selected_assets.is_empty():
		_remove_assets_from_database(selected_assets)


func _add_asset_to_database(asset: LicensedAsset) -> void:
	_undo_redo.create_action("Add licensed asset(s)", UndoRedo.MERGE_DISABLE, database)
	var index := database.assets.size()
	_undo_redo.add_do_method(database, &"add_asset", asset, index)
	_undo_redo.add_undo_method(database, &"remove_asset", asset, index)
	_undo_redo.commit_action()


func _remove_assets_from_database(assets: Array[LicensedAsset]) -> void:
	_undo_redo.create_action("Remove licensed asset(s)", UndoRedo.MERGE_DISABLE, database, true)
	for asset in assets:
		var index := database.assets.find(asset)
		# NOTE: remove immediately so indices of following items are correct
		database.remove_asset(asset, index)
		_undo_redo.add_do_method(database, &"remove_asset", asset, index)
		_undo_redo.add_undo_method(database, &"add_asset", asset, index)
	_undo_redo.commit_action(false)


func _add_asset_to_list(asset: LicensedAsset, index := -1) -> void:
	var initial_index := _asset_list.add_item(asset.asset_name)
	_asset_list.set_item_metadata(initial_index, asset)
	if index >= 0:
		_asset_list.move_item(initial_index, index)


func _remove_asset_from_list(asset: LicensedAsset, index := -1) -> void:
	if index >= 0:
		assert(asset == _get_licensed_item_asset(index))
		_asset_list.remove_item(index)
	else:
		index = _get_asset_item(asset)
		if index >= 0:
			_asset_list.remove_item(index)


func _on_asset_list_item_selected(index: int) -> void:
	_selected_asset = _get_licensed_item_asset(index)


func _set_selected_asset(value: LicensedAsset) -> void:
	if _selected_asset != null:
		_selected_asset.file_added.disconnect(_on_selected_asset_file_added)
		_selected_asset.file_removed.disconnect(_on_selected_asset_file_removed)
		_selected_asset.file_changed.disconnect(_on_selected_asset_file_changed)
		_selected_asset.property_value_changed.disconnect(_on_selected_asset_property_value_changed)
	_selected_asset = value
	if _selected_asset != null:
		_selected_asset.file_added.connect(_on_selected_asset_file_added)
		_selected_asset.file_removed.connect(_on_selected_asset_file_removed)
		_selected_asset.file_changed.connect(_on_selected_asset_file_changed)
		_selected_asset.property_value_changed.connect(_on_selected_asset_property_value_changed)
	_update_selected_asset_details()


func _update_selected_asset_details() -> void:
	var asset := _selected_asset
	if asset != null:
		_update_button(%remove_licensed_button, true)
		_update_button(%open_source_button, not asset.source.is_empty())
		_update_button(%credits_preview_button, true)
		_update_editable(%author_edit, true, asset.author)
		_update_editable(%name_edit, true, asset.asset_name)
		_update_editable(%description_edit, true, asset.description)
		_update_editable(%source_edit, true, asset.source)
		_update_editable(%retrieval_time_edit, true, asset.retrieved)
		_update_button(%retrieval_now_button, true)
		_update_editable(%attribution_edit, true, asset.custom_attribution)
		_license_option_select_license(asset.license)
		%license_options.disabled = false
		_update_button(%view_license_button, asset.license != null)
		_update_button(%add_files_button, true)
		_update_button(%add_folder_button, true)
		_update_button(%remove_file_button, true)
	else:
		_update_button(%remove_licensed_button, false)
		_update_button(%open_source_button, false)
		_update_button(%credits_preview_button, false)
		_update_editable(%author_edit, false)
		_update_editable(%name_edit, false)
		_update_editable(%description_edit, false)
		_update_editable(%source_edit, false)
		_update_editable(%retrieval_time_edit, false)
		_update_button(%retrieval_now_button, false)
		_update_editable(%attribution_edit, false)
		_license_option_select_license(null)
		%license_options.disabled = true
		_update_button(%view_license_button, false)
		_update_button(%add_files_button, false)
		_update_button(%add_folder_button, false)
		_update_button(%remove_file_button, false)

	_update_file_list()


func _on_retrieval_now_button_pressed() -> void:
	if _selected_asset != null:
		var time = Time.get_datetime_string_from_system(true, true)
		_set_asset_property(&"retrieved", time)


func _on_license_options_item_selected(index: int) -> void:
	if _selected_asset != null:
		var license: License = %license_options.get_item_metadata(index) if index >= 0 else null
		_set_asset_property(&"license", license)


func _on_view_license_button_pressed() -> void:
	# HACK
	var tab_container: TabContainer = get_parent()
	tab_container.get_node(^"Licenses")._selected_license = _selected_asset.license
	tab_container.current_tab = 1


func _on_selected_asset_property_value_changed(property: StringName, value: Variant) -> void:
	match property:
		&"files": _update_file_list()
		&"author": _update_text_value(%author_edit, value)
		&"asset_name":
			_update_text_value(%name_edit, value)
			var item_index := _get_asset_item(_selected_asset)
			_asset_list.set_item_text(item_index, value)
		&"license":
			_license_option_select_license(value)
			_update_button(%view_license_button, value != null)
		&"description": _update_text_value(%description_edit, value)
		&"source":
			_update_text_value(%source_edit, value)
			_update_button(%open_source_button, not value.is_empty())
		&"retrieved": _update_text_value(%retrieval_time_edit, value)
		&"custom_attribution": _update_text_value(%attribution_edit, value)
		&"is_modified": pass # TODO


func _license_option_select_license(license: License) -> void:
	var license_options := %license_options as OptionButton

	var selected := license_options.get_selected_id()
	if selected >= 0 and license_options.get_item_metadata(selected) == license:
		return

	for i in license_options.item_count:
		if license_options.get_item_metadata(i) == license:
			license_options.select(i)
			return

	license_options.select(-1)


func _update_license_options() -> void:
	var option_button := %license_options as OptionButton

	for item_index in range(1, option_button.item_count):
		var license: License = option_button.get_item_metadata(item_index)
		license.display_name_changed.disconnect(_on_license_display_name_changed.bind(license, item_index))

	option_button.clear()

	if database == null:
		return

	option_button.add_item("None")
	option_button.set_item_metadata(0, null)

	for index in database.licenses.size():
		var license := database.licenses[index]
		var item_index := index + 1
		var license_name := license.get_display_name()
		option_button.add_item(license_name)
		option_button.set_item_metadata(item_index, license)
		license.display_name_changed.connect(_on_license_display_name_changed.bind(license, item_index))


func _on_license_display_name_changed(license: License, item_index: int) -> void:
	var display_name := license.get_display_name()
	%license_options.set_item_text(item_index, display_name)


func _on_database_license_added(_license: License, _index: int) -> void:
	_update_license_options()


func _on_database_license_removed(_license: License, _index: int) -> void:
	_update_license_options()


func _on_open_source_button_pressed() -> void:
	if _selected_asset != null:
		_open_external_link(_selected_asset.source)


func _open_external_link(url: String) -> void:
	_external_link_confirmation_dialog.dialog_text = (
		"Proceed only if you trust the following link:\n\n%s" % url
	)
	_external_link_confirmation_dialog.set_meta(&"target_uri", url)
	EditorInterface.popup_dialog_centered_clamped(_external_link_confirmation_dialog, Vector2(512, 0))


func _create_external_link_confirmation_dialog() -> ConfirmationDialog:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_autowrap = true
	dialog.set_unparent_when_invisible(true)
	dialog.confirmed.connect(_on_external_link_confirmation_dialog_confirmed)
	dialog.canceled.connect(_on_external_link_confirmation_dialog_canceled)
	return dialog


func _on_external_link_confirmation_dialog_confirmed() -> void:
	var url: String = _external_link_confirmation_dialog.get_meta(&"target_uri", "")
	if url:
		OS.shell_open(url)


func _on_external_link_confirmation_dialog_canceled() -> void:
	_external_link_confirmation_dialog.remove_meta(&"target_uri")


func _on_credits_preview_button_pressed() -> void:
	if _selected_asset != null:
		_credits_preview_dialog.dialog_text = _selected_asset.generate_attribution()
		EditorInterface.popup_dialog_centered_clamped(_credits_preview_dialog, Vector2(512, 0))


func _create_credits_preview_dialog() -> AcceptDialog:
	var dialog := AcceptDialog.new()
	dialog.title = "Attribution Preview"
	dialog.dialog_autowrap = true
	dialog.set_unparent_when_invisible(true)
	return dialog


func _create_asset_load_dialog() -> EditorFileDialog:
	var dialog := EditorFileDialog.new()
	dialog.files_selected.connect(_on_asset_load_dialog_files_selected)
	dialog.dir_selected.connect(_on_asset_load_dialog_dir_selected)
	add_child(dialog)
	return dialog


func _on_add_files_button_pressed() -> void:
	_browse_for_files(false)


func _on_add_folder_button_pressed() -> void:
	_browse_for_files(true)


func _browse_for_files(directory: bool) -> void:
	if _selected_asset == null:
		return

	_asset_load_dialog.file_mode = (
		EditorFileDialog.FILE_MODE_OPEN_DIR if directory
		else EditorFileDialog.FILE_MODE_OPEN_FILES
	)

	_asset_load_dialog.clear_filters()

	if not directory and not _tracked_extensions.is_empty():
		var filter := _create_file_dialog_filter_from_extensions(_tracked_extensions)
		_asset_load_dialog.add_filter(filter, "Tracked Files")

	_asset_load_dialog.popup_file_dialog()


func _on_asset_load_dialog_files_selected(paths: PackedStringArray) -> void:
	if _selected_asset != null:
		_add_file(_selected_asset, paths)


func _on_asset_load_dialog_dir_selected(path: String) -> void:
	if _selected_asset == null:
		return
	if not path.ends_with("/"):
		path += "/"
	_add_file(_selected_asset, [path])


func _add_file(asset: LicensedAsset, paths: PackedStringArray) -> void:
	if paths.is_empty():
		return

	_undo_redo.create_action("Add asset path(s)", UndoRedo.MERGE_DISABLE, asset, true)
	for path in paths:
		if path in asset.files:
			continue
		var index := asset.files.bsearch(path)
		# NOTE: evaluate the "do" part immediately, so the insertion indices of the following items are
		#       determined correctly
		asset.add_file(path, index)
		_undo_redo.add_do_method(asset, &"add_file", path, index)
		_undo_redo.add_undo_method(asset, &"remove_file", path, index)
	_undo_redo.commit_action(false)


func _on_remove_file_button_pressed() -> void:
	if _selected_asset == null:
		return

	var paths := PackedStringArray()
	var selected_indices := _file_list.get_selected_items()
	for index in selected_indices:
		var path := _file_list.get_item_text(index)
		paths.push_back(path)

	_remove_files(_selected_asset, paths)


func _remove_files(asset: LicensedAsset, paths: PackedStringArray) -> void:
	if paths.is_empty():
		return

	_undo_redo.create_action("Remove asset path(s)", UndoRedo.MERGE_DISABLE, asset, true)
	for path in paths:
		if path not in asset.files:
			continue
		var index := asset.files.find(path)
		# NOTE: evaluate the "do" part immediately, so the indices of the following items are determined
		#       correctly
		asset.remove_file(path, index)
		_undo_redo.add_do_method(asset, &"remove_file", path, index)
		_undo_redo.add_undo_method(asset, &"add_file", path, index)
	_undo_redo.commit_action(false)


func _update_file_list() -> void:
	_file_list.clear()

	if _selected_asset == null:
		return

	for path in _selected_asset.files:
		_add_file_to_list(path)


func _on_selected_asset_file_added(path: String, index: int) -> void:
	_add_file_to_list(path, index)
	# TODO: check visibility only against changed paths
	_queue_resource_tree_visibility_update()


func _on_selected_asset_file_removed(path: String, index: int) -> void:
	_remove_file_from_list(path, index)
	# TODO: check visibility only against changed paths
	_queue_resource_tree_visibility_update()


func _on_selected_asset_file_changed(path: String, new_path: String, index: int) -> void:
	_update_file_in_list(path, new_path, index)
	# TODO: check visibility only against changed paths
	_queue_resource_tree_visibility_update()


func _add_file_to_list(path: String, index := -1) -> void:
	var initial_index := _file_list.add_item(path)
	var file_type := (
		&"Folder" if DirAccess.dir_exists_absolute(path)
		else (EditorInterface.get_resource_filesystem().get_file_type(path) as StringName)
	)
	var icon := _get_file_icon(file_type)
	_file_list.set_item_icon(initial_index, icon)
	if index >= 0:
		_file_list.move_item(initial_index, index)


func _remove_file_from_list(path: String, index := -1) -> void:
	if index >= 0:
		assert(path == _file_list.get_item_text(index))
		_file_list.remove_item(index)
	else:
		index = _get_file_item(path)
		if index >= 0:
			_file_list.remove_item(index)


func _update_file_in_list(path: String, new_path: String, index := -1) -> void:
	if index >= 0:
		assert(path == _file_list.get_item_text(index))
		_file_list.set_item_text(index, new_path)
	else:
		index = _get_file_item(path)
		if index >= 0:
			_file_list.set_item_text(index, new_path)


func _on_file_list_item_activated(index: int) -> void:
	var path := _file_list.get_item_text(index)
	if path.ends_with("/"):
		_navigate_to(path)
	else:
		_edit_resource_at(path)


func _file_list_can_drop_data(_point: Vector2, data: Variant) -> bool:
	if _selected_asset == null:
		return false

	if typeof(data) != TYPE_DICTIONARY:
		return false

	match data.get(&"type", ""):
		"files", "files_and_dirs": return true

	return false


func _file_list_drop_data(_point: Vector2, data: Variant) -> void:
	if _selected_asset == null:
		return

	if &"files" not in data or typeof(data.files) != TYPE_PACKED_STRING_ARRAY:
		return

	_add_file(_selected_asset, data.files)


func _get_file_item(path: String) -> int:
	for item_index in _asset_list.item_count:
		var item_path := _file_list.get_item_text(item_index)
		if item_path == path:
			return item_index
	return -1


func _get_asset_item(asset: LicensedAsset) -> int:
	for item_index in _asset_list.item_count:
		var item_asset := _get_licensed_item_asset(item_index)
		if item_asset == asset:
			return item_index
	return -1


func _get_selected_assets() -> Array[LicensedAsset]:
	var selected_indices := _asset_list.get_selected_items()
	var selected_assets: Array[LicensedAsset] = []
	for index in selected_indices:
		var asset := _get_licensed_item_asset(index)
		selected_assets.push_back(asset)
	return selected_assets


func _get_licensed_item_asset(index: int) -> LicensedAsset:
	return _asset_list.get_item_metadata(index) if index >= 0 else null


func _check_for_resource_refresh() -> void:
	if _resource_refresh_queued and is_visible_in_tree():
		_refresh_resources.call_deferred()


func _queue_resource_refresh() -> void:
	if not _resource_refresh_queued:
		_resource_refresh_queued = true
		if is_visible_in_tree():
			_refresh_resources.call_deferred()


func _refresh_resources() -> void:
	_resource_refresh_queued = false
	if database == null:
		return

	var fs := EditorInterface.get_resource_filesystem()
	var fs_root := fs.get_filesystem()

	var tree_root := _resource_tree.get_root()
	if tree_root == null:
		tree_root = _resource_tree.create_item()
		tree_root.set_text(0, "res://")
		tree_root.set_metadata(0, "res://")
		tree_root.set_icon(0, _get_editor_icon(&"Folder"))

	_sync_resource_dir_with_item(fs_root, tree_root)
	_update_resource_tree_visibilities()


func _sync_resource_dir_with_item(dir: EditorFileSystemDirectory, dir_item: TreeItem) -> void:
	var subdir_count := dir.get_subdir_count()
	for index in subdir_count:
		var subdir := dir.get_subdir(index)
		var subdir_path := subdir.get_path()
		if not _should_scan_resource_directory(dir.get_path()):
			continue
		var subdir_item := _find_resource_dir_child_item(dir_item, subdir_path, index)
		if subdir_item == null:
			subdir_item = _create_resource_dir_item(dir_item, index, subdir.get_name(), subdir_path)
		_sync_resource_dir_with_item(subdir, subdir_item)

	var running_index := subdir_count
	for index in dir.get_file_count():
		var file_path := dir.get_file_path(index)
		if not _is_resource_tracked(file_path) or not _is_resource_imported(file_path):
			continue
		var file_item := _find_resource_dir_child_item(dir_item, file_path, running_index)
		if file_item == null:
			var file_type := dir.get_file_type(index)
			file_item = _create_resource_file_item(dir_item, running_index, file_path, file_type)
		running_index += 1

	if dir_item.get_child_count() > running_index:
		for item in dir_item.get_children().slice(running_index):
			dir_item.remove_child(item)


func _find_resource_dir_child_item(dir_item: TreeItem, child_path: String, index: int) -> TreeItem:
	if index < dir_item.get_child_count():
		var item := dir_item.get_child(index)
		if item.get_metadata(0) == child_path:
			return item

	for item in dir_item.get_children():
		if item.get_metadata(0) == child_path:
			item.move_before(dir_item.get_child(index))
			return item

	return null


func _create_resource_dir_item(parent_item: TreeItem, index: int, name_: String, path: String) -> TreeItem:
	var item := parent_item.create_child(index)
	item.set_icon(0, _get_file_icon(&"Folder"))
	item.set_text(0, name_)
	item.set_metadata(0, path)
	return item


func _create_resource_file_item(parent_item: TreeItem, index: int, path: String, file_type: StringName) -> TreeItem:
	var item := parent_item.create_child(index)
	item.set_icon(0, _get_file_icon(file_type))
	item.set_text(0, path.get_file())
	item.set_metadata(0, path)
	return item


func _should_scan_resource_directory(path: String) -> bool:
	return not path.begins_with("res://addons/")


func _queue_resource_tree_visibility_update() -> void:
	if not _resource_tree_visibility_update_queued:
		_resource_tree_visibility_update_queued = true
		_update_resource_tree_visibilities.call_deferred()


func _update_resource_tree_visibilities() -> void:
	_resource_tree_visibility_update_queued = false
	var root := _resource_tree.get_root()
	if root != null:
		_update_resource_subtree_visibilities(root)
		root.visible = true


func _update_resource_subtree_visibilities(item: TreeItem) -> bool:
	if item == null:
		return false

	var path: String = item.get_metadata(0)
	var is_dir := path.ends_with("/")

	if _is_resource_licensed(path):
		_set_subtree_visibility(item, false)
		return false

	var contains_unlicensed: bool
	if not is_dir:
		contains_unlicensed = true
	else:
		for child in item.get_children():
			if _update_resource_subtree_visibilities(child):
				contains_unlicensed = true

	item.visible = contains_unlicensed
	return item.visible


func _set_subtree_visibility(item: TreeItem, value: bool) -> void:
	item.visible = value
	for child in item.get_children():
		_set_subtree_visibility(child, value)


func _is_resource_imported(path: String) -> bool:
	return FileAccess.file_exists(path + ".import")


func _is_resource_tracked(path: String) -> bool:
	if _tracked_extensions.is_empty():
		return true

	return path.get_extension() in _tracked_extensions


func _is_resource_licensed(path: String) -> bool:
	for asset in database.assets:
		if path in asset.files:
			return true
	return false


func _on_resource_tree_item_activated() -> void:
	var selected_item := _resource_tree.get_selected()
	if selected_item == null:
		return
	
	var path: String = selected_item.get_metadata(0)
	if path.ends_with("/"):
		_navigate_to(path)
	else:
		_edit_resource_at(path)


func _resource_tree_get_drag_data(point: Vector2) -> Variant:
	var item := _resource_tree.get_item_at_position(point)
	if item == null:
		return null
	
	var paths := PackedStringArray()
	var paths_contain_directory := false

	var selected_item := _resource_tree.get_next_selected(null)
	var selected_items: Array[TreeItem] = []
	while selected_item != null:
		selected_items.push_back(selected_item)
		var path: String = selected_item.get_metadata(0)
		paths.push_back(path)
		if DirAccess.dir_exists_absolute(path):
			paths_contain_directory = true
		selected_item = _resource_tree.get_next_selected(selected_item)

	if paths.is_empty():
		return null

	var preview := _create_drag_preview(selected_items)
	_resource_tree.set_drag_preview(preview)

	return {
		type = "files_and_dirs" if paths_contain_directory else "files",
		files = paths,
	}


func _create_drag_preview(items: Array[TreeItem]) -> Control:
	var vbox := VBoxContainer.new()
	for item in items:
		var hbox := HBoxContainer.new()
		var icon := TextureRect.new()
		icon.texture = item.get_icon(0)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		hbox.add_child(icon)
		var label := Label.new()
		label.text = item.get_text(0)
		hbox.add_child(label)
		vbox.add_child(hbox)
	return vbox


func _edit_resource_at(path: String) -> void:
	if ResourceLoader.exists(path):
		_navigate_to(path)
		EditorInterface.edit_resource(ResourceLoader.load(path))
	else:
		push_warning("Resource does not exist: ", path)


func _navigate_to(path: String) -> void:
	EditorInterface.get_file_system_dock().navigate_to_path(path)


func _create_file_dialog_filter_from_extensions(extensions: PackedStringArray) -> String:
	var filter := ""
	for i in extensions.size():
		if i > 0:
			filter += ", "
		filter += "*." + extensions[i]
	return filter


func _set_asset_property(property: StringName, value: Variant) -> void:
	if _selected_asset[property] == value:
		return

	var action_name: StringName = "Set " + property
	_undo_redo.create_action(action_name, UndoRedo.MERGE_ENDS, _selected_asset)
	_undo_redo.add_do_property(_selected_asset, property, value)
	_undo_redo.add_undo_property(_selected_asset, property, _selected_asset[property])
	_undo_redo.commit_action()


func _set_asset_string_property(text: String, property: StringName, trim := true) -> void:
	if _selected_asset != null:
		if trim:
			text = text.strip_edges()
		_set_asset_property(property, text)


func _setup_button(button: Button, on_pressed: Callable, icon_name := &"") -> void:
	if icon_name and Engine.is_editor_hint():
		button.icon = _get_editor_icon(icon_name)
		button.text = ""
	button.pressed.connect(on_pressed)


func _get_file_icon(file_type: StringName) -> Texture2D:
	return _get_editor_icon(file_type if file_type else &"FileBroken")


func _get_editor_icon(icon_name: StringName) -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon(icon_name, &"EditorIcons")


func _update_editable(control: Control, editable: bool, text := "") -> void:
	control.text = text
	control.editable = editable


func _update_button(control: BaseButton, enabled: bool) -> void:
	control.disabled = not enabled


func _update_text_value(control: Control, value: String, check_trimmed := true) -> void:
	if control.text == value or (check_trimmed and control.text.strip_edges() == value):
		return

	control.text = value
