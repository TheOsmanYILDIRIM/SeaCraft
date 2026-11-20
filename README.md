# SeaCraft

Godot **4.7.2-stable** foundation for an offline-first 2D/2.5D maritime game targeting desktop and Android.

## FND-01 contract

- Main scene: `src/presentation/bootstrap.tscn`; it only prints a local boot marker and performs no network or internet access.
- Renderer: Compatibility (`gl_compatibility`) on desktop and mobile.
- Mobile baseline: 1280×720 landscape, `canvas_items` stretch with `expand`; future UI must respect `DisplayServer.get_display_safe_area()` rather than assuming full-screen safe bounds.
- Architecture boundaries are tracked under `src/simulation`, `src/presentation`, `src/data`, and `tests`.
- No autoload is registered yet. FND-01 has no justified global singleton; future autoloads must be introduced only when lifecycle/ownership requires them.
- The simulation boundary must not depend on ENet, RPC, `MultiplayerAPI`, UI, rendering or device input. Offline and later LAN adapters will share the same simulation-facing contracts.
- Gameplay, ship movement, combat, AI and LAN implementation are intentionally out of scope for FND-01.

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

The addon is ignored by Git and removed before exports, and `tests/**`, `tools/**`, and `addons/**` are excluded by export presets.

## CI/export

GitHub Actions pins Godot 4.7.2 and validates the official binary/template SHA-256 values before use. CI checks project/scene parsing, headless boot, FND-01 settings, GUT smoke tests, Linux desktop export and an Android arm64 debug APK. Android setup follows the Godot 4.7 toolchain baseline (JDK 17, Android Platform/Build Tools 35, CMake 3.10.2 and NDK r28b).
