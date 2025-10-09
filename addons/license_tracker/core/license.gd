@tool
extends Resource


signal property_value_changed(property: StringName, value: Variant)


@export var read_only: bool :
	set(value):
		if read_only != value:
			read_only = value
			property_value_changed.emit(&"read_only", value)

@export var short_name: String :
	set(value):
		if short_name != value:
			short_name = value
			property_value_changed.emit(&"short_name", value)

@export var full_name: String :
	set(value):
		if full_name != value:
			full_name = value
			property_value_changed.emit(&"full_name", value)

@export var url: String :
	set(value):
		if url != value:
			url = value
			property_value_changed.emit(&"url", value)

@export_file var file: String :
	set(value):
		if file != value:
			file = value
			property_value_changed.emit(&"file", value)

@export_multiline var text: String :
	set(value):
		if text != value:
			text = value
			property_value_changed.emit(&"text", value)

@export var requires_attribution := true :
	set(value):
		if requires_attribution != value:
			requires_attribution = value
			property_value_changed.emit(&"requires_attribution", value)

@export var allows_modifications: bool :
	set(value):
		if allows_modifications != value:
			allows_modifications = value
			property_value_changed.emit(&"allows_modifications", value)

@export var allows_commercial_use: bool :
	set(value):
		if allows_commercial_use != value:
			allows_commercial_use = value
			property_value_changed.emit(&"allows_commercial_use", value)

@export var allows_redistribution: bool :
	set(value):
		if allows_redistribution != value:
			allows_redistribution = value
			property_value_changed.emit(&"allows_redistribution", value)
