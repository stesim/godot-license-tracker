@tool
extends Resource


const License := preload("./license.gd")

const LicensedAsset := preload("./licensed_asset.gd")


signal license_added(license: License, index: int)

signal license_removed(license: License, index: int)

signal asset_added(asset: LicensedAsset, index: int)

signal asset_removed(asset: LicensedAsset, index: int)


@export_storage var licenses: Array[License]

@export_storage var assets: Array[LicensedAsset]


var _is_save_queued := false


func get_license_by_file(path: String) -> License:
	for license in licenses:
		if license.file == path:
			return license
	return null


func get_asset_by_license_file(path: String) -> LicensedAsset:
	for asset in assets:
		if asset.license_file == path:
			return asset
	return null


func add_license(license: License, index := -1) -> void:
	if index == -1:
		licenses.push_back(license)
	else:
		licenses.insert(index, license)
	license_added.emit(license, index)


func remove_license(license: License, index := -1) -> void:
	if index < 0:
		index = licenses.find(license)
		if index < 0:
			return
		licenses.remove_at(index)
	else:
		assert(licenses[index] == license)
		licenses.remove_at(index)

	license_removed.emit(license, index)


func add_asset(asset: LicensedAsset, index := -1) -> void:
	if index == -1:
		assets.push_back(asset)
	else:
		assets.insert(index, asset)
	asset_added.emit(asset, index)


func remove_asset(asset: LicensedAsset, index := -1) -> void:
	if index < 0:
		index = assets.find(asset)
		if index < 0:
			return
		assets.remove_at(index)
	else:
		assert(assets[index] == asset)
		assets.remove_at(index)

	asset_removed.emit(asset, index)


func generate_attributions(format := LicensedAsset.AttributionFormat.PLAIN) -> PackedStringArray:
	var attributions := PackedStringArray()
	for asset in assets:
		var attribution := asset.generate_attribution(format)
		attributions.push_back(attribution)
	return attributions


func queue_save() -> void:
	if not _is_save_queued:
		_is_save_queued = true
		_save.call_deferred()


func _save() -> void:
	_is_save_queued = false
	if resource_path:
		ResourceSaver.save(self)
