extends RefCounted


const Utils := preload("./utils.gd")


const IGNORED_DIRECTORIES: PackedStringArray = [
	"res://addons/",
]

const SUPPORTED_LICENSE_FILES: PackedStringArray = [
	"LICENSE",
	"LICENSE.txt",
	"LICENSE.md",
]


signal file_changed(path: String)


static func is_file_license(path: String) -> bool:
	var file_name := path.get_file()
	for supported_file in SUPPORTED_LICENSE_FILES:
		if file_name.nocasecmp_to(supported_file) == 0:
			return true
	return false


static func scan_for_license_files(ignored_directories := IGNORED_DIRECTORIES) -> PackedStringArray:
	var root := EditorInterface.get_resource_filesystem().get_filesystem()
	return Utils.scan_editor_resource_directory_for_files(root, is_file_license, true, ignored_directories)


func _init() -> void:
	var fs := EditorInterface.get_resource_filesystem()
	fs.resources_reimported.connect(_on_resources_reimported)


func _on_resources_reimported(paths: PackedStringArray) -> void:
	for path in paths:
		if is_file_license(path):
			file_changed.emit(path)
