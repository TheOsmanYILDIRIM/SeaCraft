# SeaCraft

Godot **4.7.2-stable** foundation for an offline-first 2D/2.5D maritime game targeting desktop and Android.

## FND-01 contract

- Main scene: `src/presentation/bootstrap.tscn`; it opens the local sector fixture before printing the boot marker; it performs no network or internet access.
- Renderer: Compatibility (`gl_compatibility`) on desktop and mobile.
- Mobile baseline: 1280×720 landscape, `canvas_items` stretch with `expand`; future UI must respect `DisplayServer.get_display_safe_area()` rather than assuming full-screen safe bounds.
- Architecture boundaries are tracked under `src/simulation`, `src/presentation`, `src/data`, and `tests`.
- No autoload is registered yet. FND-01 has no justified global singleton; future autoloads must be introduced only when lifecycle/ownership requires them.
- The simulation boundary must not depend on ENet, RPC, `MultiplayerAPI`, UI, rendering or device input. Offline and later LAN adapters will share the same simulation-facing contracts.

## FND-02 data contract

- Typed definitions: `ShipDefinition`, `WeaponDefinition`, `ItemDefinition`, `FactionDefinition`, `SectorDefinition`.
- Mutable instance state is separate in `EntityRuntimeState`; definitions are treated as read-only content data.
- All persisted/referenced content uses path-independent string stable IDs. `Resource`, `Object`, `Node`, `RID`, `Callable` and runtime object IDs are forbidden from save/network DTOs.
- `DefinitionRegistry` validates lightweight `.tres` index entries for duplicate IDs and missing references, then loads definition `.tres` files lazily with `ResourceLoader`.
- Schema version and content version are distinct compatibility fields.
- Stat modifiers use one deterministic phase/priority/stable-ID ordering pipeline.
- RNG uses separate `world`, `encounter`, and `loot` `RandomNumberGenerator` streams with deterministic SeaCraft seed derivation from a master seed.
- RNG stream state is primitive-safe and restorable for a future save layer. Godot's RNG algorithm itself is not considered a permanent cross-version protocol guarantee.
- Future LAN remains host-authoritative; FND-02 does not add networking, lockstep or save-system code.

## FND-03 input and camera contract

- Device events never mutate authoritative gameplay state. Mouse, keyboard, gamepad and touch are translated into primitive-safe command dictionaries first.
- Primary mouse click and single-touch tap produce the same `move_to_world_position` command for the same world coordinate; secondary mouse click produces `select_world_position`.
- Cancel/deselect, target-cycle, camera pan/zoom and camera recenter intents share the same command layer. FND-04 will consume gameplay commands; FND-03 does not move the ship.
- Touch uses an explicit gesture state machine: one-finger tap targets the world, one-finger drag pans the camera, and two-finger pinch zooms. Entering multi-touch cancels the tap candidate so pinch/pan cannot also fire a gameplay target.
- Touch-to-mouse and mouse-to-touch emulation are disabled to avoid duplicate device events. `Control.accept_event()` plus `_unhandled_input` keeps UI-consumed pointer events out of world command routing.
- `GameplayCamera` is a `Camera2D` presentation node with follow/recenter, free pan, zoom clamp, smoothing, world limits and world↔screen conversion. It never writes simulation state.
- Safe-area conversion remains based on `DisplayServer.get_display_safe_area()`; the FND-03 math helper converts display-pixel safe rectangles into the logical landscape viewport used by `canvas_items` + `expand`.

## FND-04 authoritative ship movement contract

- FND-03 gameplay `move_to_world_position` and `cancel` commands enter simulation only through `ShipMotor.apply_authoritative_command`; device input and presentation never write authoritative position, velocity or rotation.
- `ShipMotor` is a `CharacterBody2D` driven only from fixed physics steps. A typed `ShipMovementProfile` Resource owns acceleration, deceleration, maximum forward speed, minimum maneuvering speed, turn rate, arrival radius, collision radius and stop epsilon.
- Heading changes are turn-rate limited and speed-gated; target approach uses braking-distance speed limiting so the ship slows into its arrival radius instead of snapping or teleporting.
- Collision uses a real CharacterBody2D circular envelope and `move_and_slide()`. FND-04 does not build island navigation or pathfinding.
- Damaged speed enters through the FND-02 `StatModifierPipeline`; removing the modifier restores the base movement profile speed.
- Broadside preparation is combat-agnostic: current heading, desired heading, signed angular difference, port/starboard side and current turn radius are exposed as pure helper data.
- Simulation remains network-API independent and authority-gated. Offline play uses the same authoritative command API a future host adapter can call; ENet, RPC, prediction and reconciliation are outside FND-04.
- Same-build replay with the same initial state, movement profile, fixed delta and command trace is expected to reproduce within tolerance. This is not a cross-platform lockstep guarantee.
- The bootstrap movement profile is placeholder tuning for foundation verification, not final ship-content balance.

## FND-05 mobile sector core

- Bootstrap loads only the active typed sector; the graph stores paths, anchor IDs and directed gate metadata without loading sector definitions or scenes. The world owner replaces its active runtime only after destination validation succeeds. Presentation owns disposable local colliders/visuals; no background sector tick, global map or entity node requirement.
- The authoritative player spawns at a stable anchor and is indexed after its fixed ship step. The fixture uses simple static rectangles on a coast layer; ships query only that layer.
- Use direct steering for unobstructed water. The optional visibility-graph route uses Godot AStar2D, clearance and bounded waypoint weights; callers retain packed paths and request reroutes on events, not per tick. No navigation agent runs in the background and ShipMotor does not depend on navigation.
- Vector2i spatial buckets accept caller-reused arrays, inspect only intersecting cells, and return unordered exact-radius matches. Keep entity/LOD scheduling independent of rendering; target 60 FPS with a 30 FPS rendering fallback and unchanged fixed simulation timing.
- Gate requests require the simulation owner's capability and an indexed entity within the gate's exit-anchor radius. FND-05 supplies logical enter/leave and validated entry metadata; no transition UI, remote replication or save/load.

### Android device verification note

FND-05 device checklist (not executed by CI): cold sector load time, startup memory and sector load spike, 30/60 FPS frame pacing, navigation query load, thermal behavior during sustained sailing, and CPU load with dense entities.

CI verifies parsing, simulation logic and APK export, but a real Android device is still required later for tap world targeting, one-finger drag/pan, pinch zoom, notch/safe-area placement, UI/world input conflicts, a long touch route, ship turning feel and frame pacing under dense input. Test the 1280×720 landscape baseline plus small 320–411dp-class screens; these real-device checks are explicitly separate evidence from CI.

## Local boot

With Godot 4.7.2 installed, project boot needs no network connection:

```bash
godot --headless --path . --quit-after 1
```

## Tests

GUT is a development/CI-only dependency. `tools/ci/install_gut.sh` downloads the official GUT source pinned to commit `aeb5d4f3f7f0a6c9b5e178876d6c99b791fda605` (the immutable commit behind GUT v9.7.1 / Godot 4.7). After installation:

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

The suite preserves the 25 FND-01/FND-02/FND-03 tests and adds FND-04 authoritative movement coverage for acceleration, deceleration, turn limits, arrival/overshoot, deterministic-enough fixed-step replay, authority gating, damaged-speed modifiers, collision and broadside heading helpers.

The addon is ignored by Git and removed before exports, and `tests/**`, `tools/**`, and `addons/**` are excluded by export presets.

## CI/export

GitHub Actions pins Godot 4.7.2 and validates the official binary/template SHA-256 values before use. CI checks project/resource parsing, headless boot, FND-01 settings, all FND-01 through FND-05 GUT tests, simulation/network separation, Linux desktop export and an Android arm64 debug APK. Android setup follows the Godot 4.7 toolchain baseline (JDK 17, Android Platform/Build Tools 35, CMake 3.10.2 and NDK r28b).
