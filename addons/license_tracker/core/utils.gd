static func scan_editor_resource_directory_for_files(
	directory: EditorFileSystemDirectory,
	predicate := _always_true_file_predicate,
	recursive := true,
	ignored_directories: PackedStringArray = [],
	results := PackedStringArray(),
) -> PackedStringArray:
	if directory.get_path() in ignored_directories:
		return results

	if recursive:
		for i in directory.get_subdir_count():
			scan_editor_resource_directory_for_files(directory.get_subdir(i), predicate, recursive, ignored_directories, results)

	for i in directory.get_file_count():
		var file_path := directory.get_file_path(i)
		if predicate.call(file_path):
			results.push_back(file_path)

	return results


static func find_item_list_item_by_text(list: ItemList, text: String) -> int:
	for index in list.item_count:
		if list.get_item_text(index) == text:
			return index
	return -1


static func is_editor_drag_data(drag_data: Variant, type: String) -> bool:
	return typeof(drag_data) == TYPE_DICTIONARY and drag_data.get("type") == type


static func get_editor_drag_data_type(drag_data: Variant) -> String:
	return drag_data.get("type")


static func get_editor_dragged_files(drag_data: Variant) -> PackedStringArray:
	var files_value: Variant = drag_data.get("files")
	if typeof(files_value) != TYPE_PACKED_STRING_ARRAY:
		return []
	return files_value


static func navigate_to(path: String) -> void:
	EditorInterface.get_file_system_dock().navigate_to_path(path)


static func edit_resource_at(path: String) -> void:
	if ResourceLoader.exists(path):
		navigate_to(path)
		EditorInterface.edit_resource(ResourceLoader.load(path))
	else:
		push_warning("Resource does not exist: ", path)


static func open_path_in_editor(path: String) -> void:
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
		navigate_to(path)

	if ResourceLoader.exists(path):
		EditorInterface.edit_resource(ResourceLoader.load(path))


static func queue(callable: Callable) -> void:
	assert(callable.is_standard())

	var object := callable.get_object()
	if not object.has_meta(&"__queued_calls"):
		object.set_meta(&"__queued_calls", [] as Array[Callable])

	var queued_callables: Array[Callable] = object.get_meta(&"__queued_calls")
	if callable in queued_callables:
		return

	queued_callables.push_back(callable)

	_invoke_queued.call_deferred(callable)


static func _invoke_queued(callable: Callable) -> void:
	if not callable.is_valid():
		return

	callable.get_object().get_meta(&"__queued_calls").erase(callable)
	callable.call()


static func _always_true_file_predicate(_path: String) -> bool:
	return true
