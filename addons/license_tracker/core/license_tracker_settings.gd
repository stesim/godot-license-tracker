@tool
extends RefCounted


const PREFIX := "license_tracker/"

const DEFAULT_EXTENSIONS_RESOURCE_TYPES: PackedStringArray = [
	"Texture",
	"AudioStream",
	"PackedScene",
	"Font",
]

const DEFAULT_EXTENSIONS_IGNORED: PackedStringArray = [
	"tres",
	"res",
	"tscn",
	"scn",
]

static var DEFAULT_EXTENSIONS := _collect_default_extensions()


var debug : bool :
	get: return _get_setting("debug", false)
	set(value): _set_setting("debug", value)

var database_file : String :
	get: return _get_setting("database_file", "")
	set(value): _set_setting("database_file", value)

var tracked_extensions : PackedStringArray :
	get: return _get_setting("tracked_extensions", DEFAULT_EXTENSIONS)
	set(value): _set_setting("tracked_extensions", value)


static func initialize_project_settings() -> void:
	_add_setting("database_file", TYPE_STRING, "", PROPERTY_HINT_FILE_PATH, "*.tres, *.res", true)
	_add_setting("tracked_extensions", TYPE_PACKED_STRING_ARRAY, DEFAULT_EXTENSIONS, PROPERTY_HINT_NONE, "", true)


static func _get_setting(setting: String, default_value: Variant) -> Variant:
	return ProjectSettings.get_setting(PREFIX + setting, default_value)


static func _set_setting(setting: String, value: Variant) -> void:
	ProjectSettings.set_setting(PREFIX + setting, value)
	ProjectSettings.save()


static func _add_setting(setting: String, type: Variant.Type, default_value: Variant, hint := PROPERTY_HINT_NONE, hint_string := "", requires_restart := false) -> String:
	var full_name := PREFIX + setting

	if not ProjectSettings.has_setting(full_name):
		ProjectSettings.set_setting(full_name, default_value)

	ProjectSettings.set_initial_value(full_name, default_value)
	ProjectSettings.add_property_info({
		name = full_name,
		type = type,
		hint = hint,
		hint_string = hint_string,
	})
	ProjectSettings.set_as_basic(full_name, true)
	if requires_restart:
		ProjectSettings.set_restart_if_changed(full_name, true)

	return full_name


static func _collect_default_extensions() -> PackedStringArray:
	var extensions: Dictionary[String, bool] = {}
	for type in DEFAULT_EXTENSIONS_RESOURCE_TYPES:
		for extension in ResourceLoader.get_recognized_extensions_for_type(type):
			extensions[extension] = true
	for extension in DEFAULT_EXTENSIONS_IGNORED:
		extensions.erase(extension)
	return PackedStringArray(extensions.keys())
