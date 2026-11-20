# SeaCraft

Godot **4.7.2-stable** foundation for an offline-first 2D/2.5D maritime game targeting desktop and Android.

## FND-01 contract

- Main scene: `src/presentation/bootstrap.tscn`; it only prints a local boot marker and performs no network or internet access.
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

### Android device verification note

CI verifies parsing, logic tests and APK export, but a real Android device is still required later for tap world targeting, one-finger drag/pan, pinch zoom, notch/safe-area placement and UI/world input conflict checks. Test the 1280×720 landscape baseline plus small 320–411dp-class screens; real-device results are separate evidence from CI.

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

The suite keeps FND-01 smoke coverage and adds FND-02 registry, typed-resource, runtime-state, modifier, RNG and primitive-DTO contract tests.

The addon is ignored by Git and removed before exports, and `tests/**`, `tools/**`, and `addons/**` are excluded by export presets.

## CI/export

GitHub Actions pins Godot 4.7.2 and validates the official binary/template SHA-256 values before use. CI checks project/scene parsing, headless boot, FND-01 settings, all GUT tests, Linux desktop export and an Android arm64 debug APK. Android setup follows the Godot 4.7 toolchain baseline (JDK 17, Android Platform/Build Tools 35, CMake 3.10.2 and NDK r28b).
