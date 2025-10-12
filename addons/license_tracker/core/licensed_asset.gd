@tool
extends Resource


const License := preload("./license.gd")


signal asset_path_added(path: String, index: int)

signal asset_path_removed(path: String, index: int)

signal property_value_changed(property: StringName, value: Variant)


@export_file var asset_paths: PackedStringArray :
	set(value):
		if asset_paths != value:
			asset_paths = value
			property_value_changed.emit(&"asset_paths", value)

@export var author: String :
	set(value):
		if author != value:
			author = value
			property_value_changed.emit(&"author", value)

@export var original_name: String :
	set(value):
		if original_name != value:
			original_name = value
			property_value_changed.emit(&"original_name", value)

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


func add_asset_path(asset_path: String, index := -1) -> void:
	asset_paths.insert(index, asset_path)
	asset_path_added.emit(asset_path, index)


func remove_asset_path(asset_path: String, index := -1) -> void:
	if index < 0:
		index = asset_paths.find(asset_path)
		if index >= 0:
			asset_paths.remove_at(index)
	else:
		assert(asset_paths[index] == asset_path)
		asset_paths.remove_at(index)

	asset_path_removed.emit(asset_path, index)


func generate_attribution() -> String:
	return (
		_generate_custom_attribution(custom_attribution) if custom_attribution
		else _generate_default_attribution()
	)


func _generate_custom_attribution(template: String) -> String:
	var arguments := {
		author = author,
		name = original_name,
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


func _generate_default_attribution() -> String:
	var attribution := "\"%s\"" % original_name
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
