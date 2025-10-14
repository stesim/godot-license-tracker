extends RefCounted


const License := preload("../core/license.gd")

const LicensedAsset := preload("../core/licensed_asset.gd")


const OPTIONAL_ASSET_PROPERTIES_1: Dictionary[StringName, StringName] = {
	asset_name = &"name",
	author = &"author",
}

const OPTIONAL_ASSET_PROPERTIES_2: Dictionary[StringName, StringName] = {
	description = &"description",
	source = &"source",
	retrieved = &"retrieved",
	custom_attribution = &"custom_attribution",
	is_modified = &"is_modified",
	files = &"files",
}

const OPTIONAL_LICENSE_PROPERTIES: Dictionary[StringName, StringName] = {
	read_only = &"read_only",
	short_name = &"short_name",
	full_name = &"full_name",
	url = &"url",
	file = &"file",
	text = &"text",
	requires_attribution = &"requires_attribution",
	allows_modifications = &"allows_modifications",
	allows_commercial_use = &"allows_commercial_use",
	allows_redistribution = &"allows_redistribution",
}


var _license_map: Dictionary[License, String] = {}


func export_combined(path: String, assets: Array[LicensedAsset], licenses: Array[License]) -> void:
	var dict := serialize_combined(assets, licenses)
	var string := JSON.stringify(dict, "\t", false)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(string)


func serialize_combined(assets: Array[LicensedAsset], licenses: Array[License]) -> Dictionary[String, Variant]:
	var dict: Dictionary[String, Variant] = {}
	if not licenses.is_empty():
		dict.licenses = serialize_licenses(licenses)
	if not assets.is_empty():
		dict.assets = serialize_assets(assets)
	return dict


func serialize_assets(assets: Array[LicensedAsset]) -> Array[Dictionary]:
	var exported_assets: Array[Dictionary] = []
	exported_assets.resize(assets.size())
	for i in exported_assets.size():
		exported_assets[i] = serialize_asset(assets[i])
	return exported_assets


func serialize_licenses(licenses: Array[License]) -> Array[Dictionary]:
	var exported_licenses: Array[Dictionary] = []
	exported_licenses.resize(licenses.size())
	for i in exported_licenses.size():
		exported_licenses[i] = serialize_license(licenses[i])
	return exported_licenses


func serialize_asset(asset: LicensedAsset) -> Dictionary[String, Variant]:
	var dict: Dictionary[String, Variant] = {}
	_add_optional_properties_to_dict(asset, OPTIONAL_ASSET_PROPERTIES_1, dict)
	if asset.license:
		dict.license = _get_license_reference(asset.license)
	_add_optional_properties_to_dict(asset, OPTIONAL_ASSET_PROPERTIES_2, dict)
	return dict


func serialize_license(license: License) -> Dictionary[String, Variant]:
	var dict: Dictionary[String, Variant] = { id = _get_license_reference(license) }
	_add_optional_properties_to_dict(license, OPTIONAL_LICENSE_PROPERTIES, dict)
	return dict


func _get_license_reference(license: License) -> String:
	if license == null:
		return ""

	if license in _license_map:
		return _license_map[license]

	var id := _generate_license_id(license)
	_license_map[license] = id

	return id


func _generate_license_id(license: License) -> String:
	var default_id := (
		license.short_name if license.short_name
		else license.full_name if license.full_name
		else "unnamed license"
	).to_kebab_case()

	var id := default_id
	var counter := 2
	var existing_ids := _license_map.values()
	while id in existing_ids:
		id = default_id + "_" + str(counter)
		counter += 1

	return id


func _add_optional_properties_to_dict(object: Object, properties: Dictionary[StringName, StringName], dict: Dictionary[String, Variant]) -> void:
	for property in properties:
		if object[property]:
			dict[properties[property]] = object[property]
