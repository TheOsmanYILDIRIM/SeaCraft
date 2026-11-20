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
var attack_modifiers: Dictionary = {}
var ammo_damage: Dictionary = {}
var selected_ammo := ""
var crit_prevention := 0.0
var resistances: Dictionary = {}
var statuses: Dictionary = {}
var ready: Dictionary = {}
var damage_tick := -1
var repair_amount := 0.0
var repair_interval := 0
var repair_item := ""
var repair_is_ai := false
var boarding_power := 0.0
var boarding_protection := 0.0


func sunk() -> bool:
	return hull <= 0.0
