class_name AmmoProfile
extends BaseDefinition

@export var item_id := ""
@export var damage_add := 0.0
@export var damage_scale := 1.0
@export var element_id := "element.neutral"
@export var status_id := ""


func definition_type() -> String:
	return "ammo"


func valid() -> bool:
	return SectorIds.valid(stable_id) and SectorIds.valid(item_id) and SectorIds.valid(element_id) \
		and is_finite(damage_add) and absf(damage_add) <= 100000.0 \
		and is_finite(damage_scale) and damage_scale >= 0.0 and damage_scale <= 8.0 \
		and (status_id.is_empty() or SectorIds.valid(status_id))


func referenced_stable_ids() -> PackedStringArray:
	return PackedStringArray([item_id]) if not item_id.is_empty() else PackedStringArray()
