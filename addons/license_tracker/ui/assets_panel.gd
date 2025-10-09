@tool
extends Control


const License := preload("../core/license.gd")

const LicensedAsset := preload("../core/licensed_asset.gd")

const LicensedAssetDatabase := preload("../core/licensed_asset_database.gd")


@export var is_plugin_instance := false

@export var database: LicensedAssetDatabase : set = _set_database


var _selected_asset: LicensedAsset : set = _set_selected_asset

var _asset_load_dialog := _create_asset_load_dialog()

var _resource_tree_visibility_update_queued := false

var _resource_refresh_queued := true


@onready var _undo_redo := EditorInterface.get_editor_undo_redo()

@onready var _asset_list := %asset_list as ItemList

@onready var _resource_tree := %resource_tree as Tree

@onready var _asset_path_list := %asset_path_list as ItemList


func _ready() -> void:
	if Engine.is_editor_hint() and not is_plugin_instance:
		return

	_database_changed()
	_update_selected_asset_details()

	_setup_button(%add_licensed_button, _on_add_licensed_button_pressed, &"Add")
	_setup_button(%remove_licensed_button, _on_remove_licensed_button_pressed, &"Remove")
	_setup_button(%scan_button, _on_scan_button_pressed, &"Reload")
	_setup_button(%retrieval_now_button, _on_retrieval_now_button_pressed, &"Time")
	_setup_button(%view_license_button, _on_view_license_button_pressed, &"ArrowRight")
	_setup_button(%asset_browse_files_button, _on_asset_browse_files_button_pressed, &"FileBrowse")
	_setup_button(%asset_browse_folder_button, _on_asset_browse_folder_button_pressed, &"FolderBrowse")
	_setup_button(%asset_path_remove_button, _on_asset_path_remove_button_pressed, &"Remove")

	visibility_changed.connect(_on_visibility_changed)

	_asset_list.item_selected.connect(_on_asset_list_item_selected)
	_resource_tree.item_activated.connect(_on_resource_tree_item_activated)
	_resource_tree.set_drag_forwarding(
		_resource_tree_get_drag_data,
		Callable(),
		Callable(),
	)
	_asset_path_list.item_activated.connect(_on_asset_path_list_item_activated)
	_asset_path_list.set_drag_forwarding(
		Callable(),
		_asset_path_list_can_drop_data,
		_asset_path_list_drop_data,
	)

	%original_name_edit.text_changed.connect(_set_asset_string_property.bind(&"original_name"))
	%author_edit.text_changed.connect(_set_asset_string_property.bind(&"author"))
	%description_edit.text_changed.connect(_set_asset_string_property.bind(&"description"))
	%source_edit.text_changed.connect(_set_asset_string_property.bind(&"source"))
	%retrieval_time_edit.text_changed.connect(_set_asset_string_property.bind(&"retrieved"))
	%attribution_edit.text_changed.connect(_set_asset_string_property.bind(&"custom_attribution"))
	%license_options.item_selected.connect(_on_license_options_item_selected)


func _on_visibility_changed() -> void:
	if _resource_refresh_queued and is_visible_in_tree():
		_refresh_resources.call_deferred()


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
		database.property_value_changed.disconnect(_on_database_property_value_changed)

	database = value

	if database != null:
		database.asset_added.connect(_on_database_asset_added)
		database.asset_removed.connect(_on_database_asset_removed)
		database.license_added.connect(_on_database_license_added)
		database.license_removed.connect(_on_database_license_removed)
		database.property_value_changed.connect(_on_database_property_value_changed)

	_database_changed()


func _database_changed() -> void:
	if not is_node_ready():
		return

	_asset_list.clear()

	%add_licensed_button.disabled = database == null
	%remove_licensed_button.disabled = database == null

	if database != null:
		for asset in database.assets:
			_add_asset_to_list(asset)

	_update_license_options()


func _on_database_asset_added(asset: LicensedAsset, index: int) -> void:
	_add_asset_to_list(asset, index)


func _on_database_asset_removed(asset: LicensedAsset, index: int) -> void:
	_remove_asset_from_list(asset, index)
	if asset == _selected_asset:
		_selected_asset = null


func _on_add_licensed_button_pressed() -> void:
	var asset := LicensedAsset.new()
	asset.original_name = "Unnamed Asset"
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
	var initial_index := _asset_list.add_item(asset.original_name)
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
		_selected_asset.asset_path_added.disconnect(_on_selected_asset_asset_path_added)
		_selected_asset.asset_path_removed.disconnect(_on_selected_asset_asset_path_removed)
		_selected_asset.property_value_changed.disconnect(_on_selected_asset_property_value_changed)
	_selected_asset = value
	if _selected_asset != null:
		_selected_asset.asset_path_added.connect(_on_selected_asset_asset_path_added)
		_selected_asset.asset_path_removed.connect(_on_selected_asset_asset_path_removed)
		_selected_asset.property_value_changed.connect(_on_selected_asset_property_value_changed)
	_update_selected_asset_details()


func _update_selected_asset_details() -> void:
	var asset := _selected_asset
	if asset != null:
		_update_button(%remove_licensed_button, true)
		_update_editable(%author_edit, true, asset.author)
		_update_editable(%original_name_edit, true, asset.original_name)
		_update_editable(%description_edit, true, asset.description)
		_update_editable(%source_edit, true, asset.source)
		_update_editable(%retrieval_time_edit, true, asset.retrieved)
		_update_button(%retrieval_now_button, true)
		_update_editable(%attribution_edit, true, asset.custom_attribution)
		_license_option_select_license(asset.license)
		%license_options.disabled = false
		_update_button(%view_license_button, asset.license != null)
		_update_button(%asset_browse_files_button, true)
		_update_button(%asset_browse_folder_button, true)
		_update_button(%asset_path_remove_button, true)
	else:
		_update_button(%remove_licensed_button, false)
		_update_editable(%author_edit, false)
		_update_editable(%original_name_edit, false)
		_update_editable(%description_edit, false)
		_update_editable(%source_edit, false)
		_update_editable(%retrieval_time_edit, false)
		_update_button(%retrieval_now_button, false)
		_update_editable(%attribution_edit, false)
		_license_option_select_license(null)
		%license_options.disabled = true
		_update_button(%view_license_button, false)
		_update_button(%asset_browse_files_button, false)
		_update_button(%asset_browse_folder_button, false)
		_update_button(%asset_path_remove_button, false)

	_update_asset_path_list()


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
		&"asset_paths": _update_asset_path_list()
		&"author": _update_text_value(%author_edit, value)
		&"original_name":
			_update_text_value(%original_name_edit, value)
			var item_index := _get_asset_item(_selected_asset)
			_asset_list.set_item_text(item_index, value)
		&"license":
			_license_option_select_license(value)
			_update_button(%view_license_button, value != null)
		&"description": _update_text_value(%description_edit, value)
		&"source": _update_text_value(%source_edit, value)
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

	for index in range(1, option_button.item_count):
		var license := option_button.get_item_metadata(index)
		license.property_value_changed.disconnect(_on_license_property_value_changed.bind(license, index))

	option_button.clear()

	if database == null:
		return

	option_button.add_item("None")
	option_button.set_item_metadata(0, null)

	for index in database.licenses.size():
		var license := database.licenses[index]
		var item_index := index + 1
		var license_name := _get_license_display_name(license)
		option_button.add_item(license_name)
		option_button.set_item_metadata(item_index, license)
		license.property_value_changed.connect(_on_license_property_value_changed.bind(license, index + 1))


func _on_license_property_value_changed(property: StringName, value: Variant, license: License, item_index: int) -> void:
	if property != &"short_name" and property != &"full_name":
		return
	
	var display_name := _get_license_display_name(license)
	%license_options.set_item_text(item_index, display_name)


func _on_database_license_added(_license: License, _index: int) -> void:
	_update_license_options()


func _on_database_license_removed(_license: License, _index: int) -> void:
	_update_license_options()


func _create_asset_load_dialog() -> EditorFileDialog:
	var dialog := EditorFileDialog.new()
	dialog.files_selected.connect(_on_asset_load_dialog_files_selected)
	dialog.dir_selected.connect(_on_asset_load_dialog_dir_selected)
	add_child(dialog)
	return dialog


func _on_asset_browse_files_button_pressed() -> void:
	_browse_for_asset_paths(false)


func _on_asset_browse_folder_button_pressed() -> void:
	_browse_for_asset_paths(true)


func _browse_for_asset_paths(directory: bool) -> void:
	if _selected_asset == null:
		return

	_asset_load_dialog.file_mode = (
		EditorFileDialog.FILE_MODE_OPEN_DIR if directory
		else EditorFileDialog.FILE_MODE_OPEN_FILES
	)

	_asset_load_dialog.clear_filters()

	if not directory and not database.tracked_extensions.is_empty():
		var filter := _create_file_dialog_filter_from_tracked_extensions()
		_asset_load_dialog.add_filter(filter, "Tracked Files")

	_asset_load_dialog.popup_file_dialog()


func _on_asset_load_dialog_files_selected(paths: PackedStringArray) -> void:
	if _selected_asset != null:
		_add_asset_paths(_selected_asset, paths)


func _on_asset_load_dialog_dir_selected(path: String) -> void:
	if _selected_asset == null:
		return
	if not path.ends_with("/"):
		path += "/"
	_add_asset_paths(_selected_asset, [path])


func _add_asset_paths(asset: LicensedAsset, paths: PackedStringArray) -> void:
	if paths.is_empty():
		return

	_undo_redo.create_action("Add asset path(s)", UndoRedo.MERGE_DISABLE, asset, true)
	var previous_index := -1
	for path in paths:
		if path in asset.asset_paths:
			continue
		var index := asset.asset_paths.bsearch(path)
		# NOTE: evaluate the "do" part immediately, so the insertion indices of the following items are
		#       determined correctly
		asset.add_asset_path(path, index)
		_undo_redo.add_do_method(asset, &"add_asset_path", path, index)
		_undo_redo.add_undo_method(asset, &"remove_asset_path", path, index)
	_undo_redo.commit_action(false)


func _on_asset_path_remove_button_pressed() -> void:
	if _selected_asset == null:
		return

	var paths := PackedStringArray()
	var selected_indices := _asset_path_list.get_selected_items()
	for index in selected_indices:
		var path := _asset_path_list.get_item_text(index)
		paths.push_back(path)

	_remove_asset_paths(_selected_asset, paths)


func _remove_asset_paths(asset: LicensedAsset, paths: PackedStringArray) -> void:
	if paths.is_empty():
		return

	_undo_redo.create_action("Remove asset path(s)", UndoRedo.MERGE_DISABLE, asset, true)
	for path in paths:
		if path not in asset.asset_paths:
			continue
		var index := asset.asset_paths.find(path)
		# NOTE: evaluate the "do" part immediately, so the indices of the following items are determined
		#       correctly
		asset.remove_asset_path(path, index)
		_undo_redo.add_do_method(asset, &"remove_asset_path", path, index)
		_undo_redo.add_undo_method(asset, &"add_asset_path", path, index)
	_undo_redo.commit_action(false)


func _update_asset_path_list() -> void:
	_asset_path_list.clear()

	if _selected_asset == null:
		return

	for path in _selected_asset.asset_paths:
		_add_asset_path_to_list(path)


func _on_selected_asset_asset_path_added(path: String, index: int) -> void:
	_add_asset_path_to_list(path, index)
	# TODO: check visibility only against changed paths
	_queue_resource_tree_visibility_update()


func _on_selected_asset_asset_path_removed(path: String, index: int) -> void:
	_remove_asset_path_from_list(path, index)
	# TODO: check visibility only against changed paths
	_queue_resource_tree_visibility_update()


func _add_asset_path_to_list(path: String, index := -1) -> void:
	var initial_index := _asset_path_list.add_item(path)
	var file_type := (
		&"Folder" if DirAccess.dir_exists_absolute(path)
		else EditorInterface.get_resource_filesystem().get_file_type(path)
	)
	var icon := _get_editor_icon(file_type)
	_asset_path_list.set_item_icon(initial_index, icon)
	if index >= 0:
		_asset_path_list.move_item(initial_index, index)


func _remove_asset_path_from_list(path: String, index := -1) -> void:
	if index >= 0:
		assert(path == _asset_path_list.get_item_text(index))
		_asset_path_list.remove_item(index)
	else:
		index = _get_asset_path_item(path)
		if index >= 0:
			_asset_path_list.remove_item(index)


func _on_asset_path_list_item_activated(index: int) -> void:
	var path := _asset_path_list.get_item_text(index)
	if path.ends_with("/"):
		_navigate_to(path)
	else:
		_edit_resource_at(path)


func _asset_path_list_can_drop_data(_point: Vector2, data: Variant) -> bool:
	if _selected_asset == null:
		return false

	if typeof(data) != TYPE_DICTIONARY:
		return false

	match data.get(&"type", ""):
		"files", "files_and_dirs": return true

	return false


func _asset_path_list_drop_data(_point: Vector2, data: Variant) -> void:
	if _selected_asset == null:
		return

	if &"files" not in data or typeof(data.files) != TYPE_PACKED_STRING_ARRAY:
		return

	_add_asset_paths(_selected_asset, data.files)


func _get_asset_path_item(path: String) -> int:
	for item_index in _asset_list.item_count:
		var item_path := _asset_path_list.get_item_text(item_index)
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


func _on_database_property_value_changed(property: StringName, value: Variant) -> void:
	match property:
		&"tracked_extensions":
			_queue_resource_refresh()


func _queue_resource_refresh() -> void:
	if not _resource_refresh_queued:
		_resource_refresh_queued = true
		if is_visible_in_tree():
			_refresh_resources.call_deferred()


func _on_scan_button_pressed() -> void:
	_queue_resource_refresh()


func _refresh_resources() -> void:
	_resource_refresh_queued = false

	_resource_tree.clear()

	var fs := EditorInterface.get_resource_filesystem()
	var root_dir := fs.get_filesystem()
	var root_item := _resource_tree.create_item()
	root_item.set_text(0, "res://")
	root_item.set_metadata(0, "res://")
	root_item.set_icon(0, _get_editor_icon(&"Folder"))
	_scan_dir_for_imported_assets(root_dir, root_item)
	_queue_resource_tree_visibility_update()


func _scan_dir_for_imported_assets(dir: EditorFileSystemDirectory, dir_item: TreeItem) -> bool:
	if not _should_scan_resource_directory(dir.get_path()):
		return false

	var found_files := false

	var subdir_item: TreeItem = null
	for i in dir.get_subdir_count():
		var subdir := dir.get_subdir(i)
		if subdir_item == null:
			subdir_item = dir_item.create_child()
			subdir_item.collapsed = true
		if _scan_dir_for_imported_assets(subdir, subdir_item):
			found_files = true
			subdir_item.set_text(0, subdir.get_name())
			subdir_item.set_metadata(0, subdir.get_path())
			subdir_item.set_icon(0, _get_editor_icon(&"Folder"))
			subdir_item = null

	if subdir_item != null:
		dir_item.remove_child(subdir_item)

	for i in dir.get_file_count():
		var file := dir.get_file_path(i)
		if _is_resource_tracked(file) and _is_resource_imported(file):
			found_files = true
			var file_item := dir_item.create_child()
			file_item.set_text(0, file.get_file())
			file_item.set_metadata(0, file)
			var file_type := dir.get_file_type(i)
			file_item.set_icon(0, _get_editor_icon(file_type))

	return found_files


func _should_scan_resource_directory(path: String) -> bool:
	return not path.begins_with("res://addons/")


func _queue_resource_tree_visibility_update() -> void:
	if not _resource_tree_visibility_update_queued:
		_resource_tree_visibility_update_queued = true
		_update_resource_tree_visibilities.call_deferred()


func _update_resource_tree_visibilities() -> void:
	var root := _resource_tree.get_root()
	if root != null:
		_update_resource_subtree_visibilities(root)
		root.visible = true


func _update_resource_subtree_visibilities(item: TreeItem) -> bool:
	_resource_tree_visibility_update_queued = false

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
	if database.tracked_extensions.is_empty():
		return true

	return path.get_extension() in database.tracked_extensions


func _is_resource_licensed(path: String) -> bool:
	for asset in database.assets:
		if path in asset.asset_paths:
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
		var path := selected_item.get_metadata(0)
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


func _get_license_display_name(license: License) -> String:
	return license.short_name if license.short_name else license.full_name


func _create_file_dialog_filter_from_tracked_extensions() -> String:
	var filter := ""
	for i in database.tracked_extensions.size():
		if i > 0:
			filter += ", "
		filter += "*." + database.tracked_extensions[i]
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
