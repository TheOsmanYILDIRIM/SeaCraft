class_name CombatantState
extends RefCounted

# Owned by CombatAuthority, never handed to input or presentation.
var faction_id: String
var max_hull: float
var hull: float
var selectable := true
var dodge := 0.0
var defense := 0.0
var battery: WeaponBattery
var locked_id := ""
var normal_damage := 0.0
var critical_damage := 0.0


func sunk() -> bool:
	return hull <= 0.0
