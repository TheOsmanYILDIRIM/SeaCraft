extends SceneTree
# QA driver: only real viewport input changes gameplay. Read-only telemetry.
# Render from the actual Godot viewport, never synthesize sprites from traces.
const BOOT := preload("res://src/presentation/bootstrap.tscn")
const PLAYER := FoundationSector.PLAYER
const NPC := "entity.vs02_sc03"
var scene: Node
var motor: ShipMotor
var npc: ShipMotor
var camera: GameplayCamera
var combat: CombatAuthority
var profile := ""
var out := ""
var seed := 1
var rng := RandomNumberGenerator.new()
var frame_no := 0
var captures := 0
var commands := 0
var shots := 0
var hits := 0
var damage := 0.0
var sunk := 0
var path_length := 0.0
var last_position := Vector2.ZERO
var collisions := 0
var actions: Array[Dictionary] = []
var samples: Array[Dictionary] = []
var issues: Array[String] = []
var started_tick := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3:
		push_error("usage: profile output-dir seed")
		quit(2)
		return
	profile = args[0]
	out = args[1]
	seed = int(args[2])
	rng.seed = seed
	if DirAccess.make_dir_recursive_absolute(out) != OK:
		quit(2)
		return
	scene = BOOT.instantiate()
	scene.set("_save_service", SaveService.new("user://visual-qa-%s-%d-%d" % [profile, seed, OS.get_process_id()]))
	scene.set("_streams", SeedStreams.new(seed))
	root.add_child(scene)
	await process_frame
	await process_frame
	if scene.active_sector() == null:
		push_error("production scene failed to boot")
		quit(2)
		return
	motor = scene.get_node("ShipMotor") as ShipMotor
	npc = scene.get("_npc_motor") as ShipMotor
	camera = scene.get_node("GameplayCamera") as GameplayCamera
	combat = scene.get("_combat") as CombatAuthority
	if motor == null or npc == null or camera == null or combat == null:
		quit(2)
		return
	(scene.get_node("InputController") as GameplayInputController).command_emitted.connect(_command)
	combat.hull_damaged.connect(_damage)
	combat.ship_sunk.connect(_sunk)
	started_tick = combat.simulation_tick()
	last_position = motor.global_position
	var ticks := 1200 if profile in ["duelist", "reckless"] else 900
	var goals: Array[Vector2] = []
	match profile:
		"navigator":
			goals = [Vector2(340, 0), Vector2(-240, 0)]
		"reverse":
			goals = [Vector2(-240, -280), Vector2(-240, 280), Vector2(-240, -280), Vector2(-540, 0)]
		"edges":
			goals = [Vector2(-600, -310), Vector2(600, -310), Vector2(600, 310), Vector2(-240, 0)]
		"explorer":
			goals = [Vector2(-440, -220), Vector2(300, -260), Vector2(360, 250)]
		"spam", "duelist", "reckless":
			pass
		_:
			quit(2)
			return
	var goal_index := 0
	var goal := Vector2.INF
	var goal_started := 0
	var arrived := 0
	var last_route_active := false
	for i in range(ticks):
		frame_no = i
		if i == 0:
			_note("start", {"position": _xy(motor.global_position)})
		if profile in ["duelist", "reckless"]:
			if i % 12 == 0 and combat.is_alive(NPC):
				_battle_step(profile == "reckless", i)
			if i % 36 == 0 and not combat.is_alive(NPC):
				var marker := scene.get("_loot_marker") as Node2D
				if marker.visible:
					_world_tap(marker.global_position + Vector2(45, 0), "approach_loot")
				_press(scene.get("_pickup_control") as Button, "pickup")
		elif profile == "spam":
			if i % 24 == 0:
				var target := Vector2(rng.randf_range(-580, 580), rng.randf_range(-290, 290))
				_world_tap(target, "rapid_retarget")
			if i % 120 == 90:
				_press(scene.get_node("UI/Play01Stop") as Button, "stop")
			if i % 180 == 150:
				_press(scene.get_node("UI/Play01Center") as Button, "recenter")
		else:
			if goal.is_finite() and not motor.has_target() and last_route_active:
				var error := motor.global_position.distance_to(goal)
				_note("route_end", {"goal": _xy(goal), "error": error})
				if error <= motor.movement_profile.arrival_radius + 3.0:
					arrived += 1
				else:
					issues.append("route ended short: %.1f" % error)
				goal = Vector2.INF
			if goal.is_finite() and i - goal_started >= 600:
				issues.append("route timeout to " + str(goal))
				goal = Vector2.INF
			if goal_index < goals.size() and (not goal.is_finite() or (profile == "reverse" and i - goal_started >= 190)):
				if profile == "reverse" and goal.is_finite():
					_note("reverse_before_arrival", {"position": _xy(motor.global_position)})
				goal = goals[goal_index]
				goal_index += 1
				goal_started = i
				_world_tap(goal, "sail")
			if profile == "explorer" and i == 240:
				_press(scene.get_node("UI/Core03MapButton") as Button, "open_map", true)
			if profile == "explorer" and i == 300:
				_press(scene.get_node("UI/Core03MapButton") as Button, "close_map", true)
		last_route_active = motor.has_target()
		await process_frame
		var pos := motor.global_position
		if not pos.is_finite() or not motor.velocity.is_finite():
			issues.append("nonfinite physics")
			break
		path_length += pos.distance_to(last_position)
		last_position = pos
		if motor.get_slide_collision_count() > 0:
			collisions += 1
		if i % 12 == 0:
			await RenderingServer.frame_post_draw
			_capture()
	if path_length < 40.0:
		issues.append("no meaningful movement")
	if commands == 0:
		issues.append("no delivered player commands")
	if profile in ["duelist", "reckless"] and hits == 0:
		issues.append("no player damage event observed")
	if profile in ["navigator", "edges", "explorer"] and arrived == 0:
		issues.append("no completed route")
	if combat.simulation_tick() - started_tick < ticks / 2:
		issues.append("physics clock did not advance")
	var report := {"profile": profile, "seed": seed, "physics_ticks": combat.simulation_tick() - started_tick,
		"capture_fps": 5, "frames": captures, "commands": commands, "fire_intents": shots, "player_hits": hits,
		"player_damage": damage, "sunk": sunk, "routes_arrived": arrived, "routes_requested": goal_index,
		"path_length": path_length, "collision_samples": collisions, "issues": issues, "actions": actions, "samples": samples}
	var file := FileAccess.open(out.path_join("trace.json"), FileAccess.WRITE)
	if file == null:
		quit(2)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("VISUAL_QA_RESULT ", JSON.stringify(report).substr(0, 220))
	quit(0 if issues.is_empty() and captures > 0 else 1)

func _xy(v: Vector2) -> Array:
	return [v.x, v.y]

func _note(kind: String, payload: Dictionary = {}) -> void:
	actions.append({"frame": frame_no, "tick": combat.simulation_tick(), "action": kind, "payload": payload})

func _command(command: Dictionary) -> void:
	commands += 1
	if command.get("type") == CombatAuthority.FIRE:
		shots += 1
	_note("delivered_command", command)

func _damage(target: String, attacker: String, amount: float, remaining: float, sequence: int) -> void:
	_note("hull_damage", {"target": target, "attacker": attacker, "amount": amount, "remaining": remaining, "sequence": sequence})
	if attacker == PLAYER:
		hits += 1
		damage += amount

func _sunk(id: String, sequence: int) -> void:
	_note("sunk", {"id": id, "sequence": sequence})
	if id == NPC:
		sunk += 1

func _tap(point: Vector2, mouse: bool = false) -> void:
	for down in [true, false]:
		if mouse:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.position = point
			event.global_position = point
			event.pressed = down
			root.push_input(event, true)
		else:
			var event := InputEventScreenTouch.new()
			event.index = 0
			event.position = point
			event.pressed = down
			root.push_input(event, true)

func _press(button: Button, label: String, mouse: bool = false) -> void:
	if is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled:
		var point := button.get_global_rect().get_center()
		_note(label, {"screen": _xy(point)})
		_tap(point, mouse)

func _world_tap(world: Vector2, label: String) -> bool:
	var point := camera.world_to_screen_position(world)
	if not root.get_visible_rect().has_point(point) or scene._ui_captures_touch(point):
		_note("occluded_" + label, {"world": _xy(world), "screen": _xy(point)})
		return false
	_note(label, {"world": _xy(world), "screen": _xy(point)})
	_tap(point)
	return true

func _battle_step(reckless: bool, i: int) -> void:
	var offset := npc.global_position - motor.global_position
	var distance := offset.length()
	if combat.locked_target(PLAYER) != NPC:
		_world_tap(npc.global_position, "select_npc")
	var broadside := absf(absf(wrapf(offset.angle() - motor.rotation, -PI, PI)) - PI * 0.5) < deg_to_rad(40.0)
	if combat.locked_target(PLAYER) == NPC and (reckless or (distance > 35.0 and distance < 350.0 and broadside)):
		_press(scene.get("_fire_control") as Button, "fire")
	if i % 48 != 0:
		return
	if distance > 330.0:
		var approach := npc.global_position - offset.normalized() * 150.0
		_world_tap(approach, "approach")
	else:
		var tangent := offset.normalized().orthogonal()
		for direction in [1.0, -1.0]:
			var goal: Vector2 = motor.global_position + tangent * 160.0 * float(direction)
			if scene.active_sector().navigation.accessible(goal) and scene._target_at(goal).is_empty():
				if _world_tap(goal, "broadside_maneuver"):
					break

func _capture() -> void:
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		issues.append("empty rendered frame")
		return
	image.resize(960, 540, Image.INTERPOLATE_LANCZOS)
	var path := out.path_join("frame_%05d.png" % captures)
	if image.save_png(path) != OK:
		issues.append("frame write failed")
		return
	var sprite := scene.get("_surface_sprite") as Sprite2D
	samples.append({"frame": captures, "tick": combat.simulation_tick(), "position": _xy(motor.global_position),
		"velocity": _xy(motor.velocity), "heading": motor.rotation, "sprite_frame": sprite.frame if is_instance_valid(sprite) else -1,
		"sprite_residual": sprite.global_rotation if is_instance_valid(sprite) else 0.0,
		"npc_position": _xy(npc.global_position), "player_hull": combat.hull(PLAYER), "npc_hull": combat.hull(NPC),
		"locked": combat.locked_target(PLAYER), "route_active": motor.has_target(), "collisions": motor.get_slide_collision_count()})
	captures += 1
