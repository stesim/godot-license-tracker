@tool
extends Resource


const License := preload("./license.gd")


enum AttributionFormat {
	PLAIN,
	MARKDOWN,
}


signal file_added(path: String, index: int)

signal file_removed(path: String, index: int)

signal file_changed(previous_path: String, new_path: String, index: int)

signal property_value_changed(property: StringName, value: Variant)


@export var asset_name: String :
	set(value):
		if asset_name != value:
			asset_name = value
			property_value_changed.emit(&"asset_name", value)

@export var author: String :
	set(value):
		if author != value:
			author = value
			property_value_changed.emit(&"author", value)

@export var copyright: String :
	set(value):
		if copyright != value:
			copyright = value
			property_value_changed.emit(&"copyright", value)

@export var license_file: String :
	set(value):
		if license_file != value:
			license_file = value
			property_value_changed.emit(&"license_file", value)

@export var license: License :
	set(value):
		if license != value:
			license = value
			property_value_changed.emit(&"license", value)

@export var description: String :
	set(value):
		if description != value:
			description = value
			property_value_changed.emit(&"description", value)

@export var source: String :
	set(value):
		if source != value:
			source = value
			property_value_changed.emit(&"source", value)

@export var retrieved: String :
	set(value):
		if retrieved != value:
			retrieved = value
			property_value_changed.emit(&"retrieved", value)

@export_multiline var custom_attribution: String :
	set(value):
		if custom_attribution != value:
			custom_attribution = value
			property_value_changed.emit(&"custom_attribution", value)

@export var is_modified := false :
	set(value):
		if is_modified != value:
			is_modified = value
			property_value_changed.emit(&"is_modified", value)

@export_file var files: PackedStringArray :
	set(value):
		if files != value:
			files = value
			property_value_changed.emit(&"files", value)


var original_name: String :
	get: return asset_name
	set(value):
		asset_name = value
		push_warning(get_script().resource_path, ": The property `original_name` is deprecated and will be removed in the future; use `asset_name` instead.")

var asset_paths: PackedStringArray :
	get: return files
	set(value):
		files = value
		push_warning(get_script().resource_path, ": The property `asset_paths` is deprecated and will be removed in the future; use `files` instead.")


func add_file(path: String, index := -1) -> void:
	files.insert(index, path)
	file_added.emit(path, index)


func remove_file(path: String, index := -1) -> bool:
	if index < 0:
		index = files.find(path)
		if index < 0:
			return false
		files.remove_at(index)
	else:
		assert(files[index] == path)
		files.remove_at(index)

	file_removed.emit(path, index)
	return true


func remove_directory_recursive(directory_path: String) -> bool:
	var did_change := false
	for index in range(files.size() - 1, -1, -1):
		var path := files[index]
		if path.begins_with(directory_path):
			files.remove_at(index)
			file_removed.emit(path, index)
			did_change = true
	return did_change


func change_file(current_path: String, new_path: String, index := -1) -> bool:
	if index < 0:
		index = files.find(current_path)
		if index < 0:
			return false
		files[index] = new_path
	else:
		assert(files[index] == current_path)
		files[index] = new_path
	
	file_changed.emit(current_path, new_path, index)
	return true


func generate_attribution(format := AttributionFormat.PLAIN) -> String:
	return (
		_generate_custom_attribution(custom_attribution) if custom_attribution
		else _generate_default_attribution(format)
	)


func _generate_custom_attribution(template: String) -> String:
	var arguments := {
		author = author,
		name = asset_name,
		source = source,
		retrieved = retrieved,
	}
	if license != null:
		arguments["license_short"] = license.short_name
		arguments["license_full"] = license.full_name
		arguments["license_url"] = license.url
	else:
		arguments["license_short"] = ""
		arguments["license_full"] = ""
		arguments["license_url"] = ""
	return template.format(arguments)


func _generate_default_attribution(format: AttributionFormat) -> String:
	match format:
		AttributionFormat.MARKDOWN:
			return _generate_attribution_markdown()
		_:
			return _generate_attribution_plain()


func _generate_attribution_markdown() -> String:
	var title_part := "\"%s\"" % asset_name
	if author:
		title_part += " by " + author
	if source:
		title_part = "[%s](%s)" % [title_part, source]

	var license_part: String
	if license:
		license_part = license.get_display_name()
		if license.url:
			license_part = "[%s](%s)" % [license_part, license.url]
	else:
		license_part += "an unknown license"

	return "%s is licensed under %s." % [title_part, license_part]


func _generate_attribution_plain() -> String:
	var attribution := "\"%s\"" % asset_name
	if author:
		attribution += " by " + author
	if source:
		attribution += " (%s)" % source
	attribution += " is licensed under"
	if license:
		attribution += " " + license.get_display_name()
		if license.url:
			attribution += " (%s)" % license.url
	else:
		attribution += " an unknown license"
	attribution += "."
	return attribution
