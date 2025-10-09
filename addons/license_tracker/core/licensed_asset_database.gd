@tool
extends Resource


const License := preload("./license.gd")

const LicensedAsset := preload("./licensed_asset.gd")


signal license_added(license: License, index: int)

signal license_removed(license: License, index: int)

signal asset_added(asset: LicensedAsset, index: int)

signal asset_removed(asset: LicensedAsset, index: int)

signal property_value_changed(property: StringName, value: Variant)


@export var tracked_extensions: PackedStringArray :
	set(value):
		if tracked_extensions != value:
			tracked_extensions = value
			property_value_changed.emit(&"tracked_extensions", value)

@export var licenses: Array[License]

@export var assets: Array[LicensedAsset]


func add_license(license: License, index := -1) -> void:
	licenses.insert(index, license)
	license_added.emit(license, index)


func remove_license(license: License, index := -1) -> void:
	if index < 0:
		index = licenses.find(license)
		if index >= 0:
			licenses.remove_at(index)
	else:
		assert(licenses[index] == license)
		licenses.remove_at(index)

	license_removed.emit(license, index)


func add_asset(asset: LicensedAsset, index := -1) -> void:
	assets.insert(index, asset)
	asset_added.emit(asset, index)


func remove_asset(asset: LicensedAsset, index := -1) -> void:
	if index < 0:
		index = assets.find(asset)
		if index >= 0:
			assets.remove_at(index)
	else:
		assert(assets[index] == asset)
		assets.remove_at(index)

	asset_removed.emit(asset, index)
