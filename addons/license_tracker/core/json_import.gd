extends RefCounted


const License := preload("../core/license.gd")

const LicensedAsset := preload("../core/licensed_asset.gd")

const LicensedAssetDatabase := preload("../core/licensed_asset_database.gd")


const OPTIONAL_ASSET_PROPERTIES: Dictionary[String, StringName] = {
	"name" = &"asset_name",
	"author" = &"author",
	"description" = &"description",
	"source" = &"source",
	"retrieved" = &"retrieved",
	"custom_attribution" = &"custom_attribution",
	"is_modified" = &"is_modified",
	"files" = &"files",
}

const OPTIONAL_LICENSE_PROPERTIES: Dictionary[String, StringName] = {
	"read_only" = &"read_only",
	"short_name" = &"short_name",
	"full_name" = &"full_name",
	"url" = &"url",
	"file" = &"file",
	"text" = &"text",
	"requires_attribution" = &"requires_attribution",
	"allows_modifications" = &"allows_modifications",
	"allows_commercial_use" = &"allows_commercial_use",
	"allows_redistribution" = &"allows_redistribution",
}


var _license_map: Dictionary[String, License] = {}


func import_combined(path: String, database: LicensedAssetDatabase, reference_database: LicensedAssetDatabase) -> bool:
	var string := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(string)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid JSON structure. Expected object.")
		return false

	for license in reference_database.licenses:
		var id := _generate_license_id(license, true)
		_license_map[id] = license

	var dict: Dictionary = parsed

	var licenses_array: Variant = dict.get("licenses")
	if licenses_array != null and _check_if_array(licenses_array):
		var licenses := deserialize_licenses(licenses_array)
		for license in licenses:
			database.add_license(license)

	var assets_array: Variant = dict.get("assets")
	if assets_array != null and _check_if_array(assets_array):
		var assets := deserialize_assets(assets_array)
		for asset in assets:
			database.add_asset(asset)

	return true


func deserialize_assets(array: Array) -> Array[LicensedAsset]:
	var assets: Array[LicensedAsset] = []
	for dict in array:
		if not _check_if_dict(dict):
			continue
		var asset := deserialize_asset(dict)
		if asset != null:
			assets.push_back(asset)
	return assets


func deserialize_licenses(array: Array) -> Array[License]:
	var licenses: Array[License] = []
	for dict in array:
		if not _check_if_dict(dict):
			continue
		var license := deserialize_license(dict)
		if license != null:
			licenses.push_back(license)
	return licenses


func deserialize_asset(dict: Dictionary) -> LicensedAsset:
	var asset := LicensedAsset.new()
	_read_optional_properties_from_dict(dict, OPTIONAL_ASSET_PROPERTIES, asset)
	if "license" in dict:
		asset.license = _license_map.get(dict.license)
	return asset


func deserialize_license(dict: Dictionary) -> License:
	if "id" not in dict:
		push_error("Skipping license due to missing ID.")
		return null
	if dict.id in _license_map:
		push_warning("Skipping license due to ID conflict.")
		return null

	var license := License.new()
	_read_optional_properties_from_dict(dict, OPTIONAL_LICENSE_PROPERTIES, license)
	_license_map[dict.id] = license
	return license


func _generate_license_id(license: License, resolve_conflicts: bool) -> String:
	var default_id := (
		license.short_name if license.short_name
		else license.full_name if license.full_name
		else "unnamed license"
	).to_kebab_case()

	var id := default_id

	if resolve_conflicts:
		var counter := 2
		while id in _license_map and _license_map[id] != license:
			id = default_id + "_" + str(counter)
			counter += 1

	return id


func _read_optional_properties_from_dict(dict: Dictionary, properties: Dictionary[String, StringName], object: Object) -> void:
	for property in properties:
		if property in dict:
			object[properties[property]] = dict[property]


func _check_if_dict(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		push_error("Invalid JSON structure. Expected object.")
		return false
	return true


func _check_if_array(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY:
		push_error("Invalid JSON structure. Expected array.")
		return false
	return true
