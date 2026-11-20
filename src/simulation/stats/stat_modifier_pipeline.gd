class_name StatModifierPipeline
extends RefCounted

const PHASE_ORDER := {
	"flat": 0,
	"percent_add": 1,
	"multiply": 2,
	"clamp_min": 3,
	"clamp_max": 4,
}


static func apply(base_value: float, modifiers: Array[Dictionary]) -> float:
	var ordered: Array[Dictionary] = modifiers.duplicate(true)
	ordered.sort_custom(_modifier_less)

	var value := base_value
	for modifier in ordered:
		var operation := str(modifier.get("operation", ""))
		var amount := float(modifier.get("value", 0.0))
		match operation:
			"flat":
				value += amount
			"percent_add":
				value += value * amount
			"multiply":
				value *= amount
			"clamp_min":
				value = maxf(value, amount)
			"clamp_max":
				value = minf(value, amount)
			_:
				push_error("Unsupported stat modifier operation: %s" % operation)
	return value


static func apply_from_dictionary(base_value: float, modifiers_by_id: Dictionary) -> float:
	var modifiers: Array[Dictionary] = []
	for modifier_id in modifiers_by_id:
		var source: Dictionary = modifiers_by_id[modifier_id]
		var modifier := source.duplicate(true)
		modifier["id"] = str(modifier_id)
		modifiers.append(modifier)
	return apply(base_value, modifiers)


static func _modifier_less(left: Dictionary, right: Dictionary) -> bool:
	var left_phase := int(PHASE_ORDER.get(str(left.get("operation", "")), 999))
	var right_phase := int(PHASE_ORDER.get(str(right.get("operation", "")), 999))
	if left_phase != right_phase:
		return left_phase < right_phase

	var left_priority := int(left.get("priority", 0))
	var right_priority := int(right.get("priority", 0))
	if left_priority != right_priority:
		return left_priority < right_priority

	return str(left.get("id", "")) < str(right.get("id", ""))
