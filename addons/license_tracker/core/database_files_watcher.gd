extends RefCounted


const LicensedAsset := preload("../core/licensed_asset.gd")

const LicensedAssetDatabase := preload("../core/licensed_asset_database.gd")


var database: LicensedAssetDatabase = null


func _init(database_: LicensedAssetDatabase = null) -> void:
	database = database_

	var fs_dock := EditorInterface.get_file_system_dock()
	fs_dock.files_moved.connect(_update_path)
	fs_dock.folder_moved.connect(_update_path.bind(true))
	fs_dock.file_removed.connect(_remove_path)
	fs_dock.folder_removed.connect(_remove_path.bind(true))


func _update_path(old_path: String, new_path: String, is_dir := false) -> void:
	if database == null:
		return

	if is_dir and not new_path.ends_with("/"):
		new_path += "/"

	var did_change := false
	for asset in database.assets:
		if asset.change_file(old_path, new_path):
			did_change = true

	# NOTE: the database needs to be saved since the editor does not know that it changed and will
	#       not warn about unsaved changed upon closing
	if did_change:
		database.queue_save()


func _remove_path(path: String, is_dir := false) -> void:
	if database == null:
		return

	if is_dir and not path.ends_with("/"):
		path += "/"

	var did_change := false

	if is_dir:
		for asset in database.assets:
			if asset.remove_directory_recursive(path):
				did_change = true
	else:
		for asset in database.assets:
			if asset.remove_file(path):
				did_change = true

	# NOTE: the database needs to be saved since the editor does not know that it changed and will
	#       not warn about unsaved changed upon closing
	if did_change:
		database.queue_save()
