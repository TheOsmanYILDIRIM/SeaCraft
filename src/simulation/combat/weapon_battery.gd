class_name WeaponBattery
extends RefCounted

# One battery for both broadsides in this slice; either side uses its shared reload.
var weapon: WeaponDefinition
var ready_tick := 0
var mounted_side := ShipMotor.SIDE_ALIGNED
var last_side := ShipMotor.SIDE_ALIGNED
var reload_ticks := 1
