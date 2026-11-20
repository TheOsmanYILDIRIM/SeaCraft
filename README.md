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


## CORE-02 monster, harpoon and world-object authority

- Combat remains a single `CombatAuthority`. Authoritative target classes are `ship`, `monster`, `wreck` and `pickup`; `TargetingService` owns the cannon/harpoon target matrix, so presentation snapshots cannot rewrite target tags. Cannon accepts ships only; harpoon accepts monsters and wrecks only. Rejected weapon/target combinations occur before stock, cooldown, RNG or transaction sequence mutation.
- `MonsterDefinition` is a typed read-only content definition for stable ID, health, faction, elemental resistances, loot-table reference and bounded territory radius. Runtime hull, position, cooldown and target state remain authority-owned. Monster registration uses a `monster_territory` `SectorAnchor`; event-driven position updates are clamped to that territory without a per-frame world scan.
- `HarpoonProfile` is a separate typed weapon profile while harpoon damage reuses `CoreCombatRules.damage`. Harpoon transactions validate authority, actor/target state, target class, lock, range, cooldown and optional shared-inventory stock before committing. Lethal monster and wreck events have separate domain signals and are emitted once.
- `WorldObjectAuthority` supplies bounded `chest`, `glitter` and `wreck` archetypes on authored sector anchors. Stable spawn IDs are deterministic hashes of sector ID, anchor ID, archetype and slot. Processed-spawn and claimed ledgers reject duplicate spawn/claim without loot RNG; spatial-hash queries provide bounded nearby pickup selection. Wrecks join the same combat roster and are harpoon targets.
- Monster, chest, glitter and wreck rewards all use `LootAuthority.grant_from_table`, so VS-03/CORE-01 inventory remains the single persisted inventory truth. Generic event IDs share the existing processed-event ledger; duplicate death/claim events do not roll loot twice.
- CORE-02 persistence stores loot/inventory/RNG through the existing FND-06 snapshot and places detached combat/world-object state under the existing primitive-safe `authoritative_state`. Active objects, stable IDs, processed spawns/claims and monster/wreck hull/positions restore without a parallel world truth.
- Simulation stays offline and host-ready: no presentation, storage or network APIs are introduced into the authority layer. Debug/mobile selection can use the existing enlarged world-target radius; harpoon and pickup actions are authority commands and UI touch capture remains separate from movement.

### CORE-02 Android device verification — not_run

CI export is not real-device evidence. The following remain `not_run` until exercised on Android hardware: monster touch selection; harpoon button reach/readability; cannon-versus-harpoon mis-selection risk; small glitter/chest pickup; wreck selection; multiple-small-object overdraw; camera plus monster combat; spam tap; low/mid-device frame pacing; and save/reload world-object persistence.

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

GitHub Actions pins Godot 4.7.2 and validates the official binary/template SHA-256 values before use. CI checks project/resource parsing, headless boot, FND-01 settings, all FND-01 through FND-06 GUT tests, simulation/network separation, Linux desktop export and an Android arm64 debug APK. Android setup follows the Godot 4.7 toolchain baseline (JDK 17, Android Platform/Build Tools 35, CMake 3.10.2 and NDK r28b).


## FND-06 mobile checkpoint baseline

- The offline composition root loads or explicitly refuses the checkpoint before opening any sector. Only the selected sector runtime is restored. A bad/unsupported checkpoint never silently starts a new world or replaces the save.
- One writer uses app-private `user://seacraft-save/`: `world.json`, `world.tmp`, `world.bak`. A JSON DTO is validated, staged and read back; only a verified primary rotates to backup, then verified temp replaces primary. A process kill between renames leaves the verified backup. Temp is never trusted as a recovery source. Read-only backup recovery reports `recovered_backup`; a successful subsequent checkpoint restores primary without rotating the damaged file. This is not a filesystem power-loss/fsync guarantee.
- Player stable ID, active sector ID, motion (including current destination when set), schema/content identity and RNG state are saved. The fixture has no live HP, inventory or quest simulation to persist. RNG's signed 64-bit values use decimal strings; resumption is verified on the same engine build, not guaranteed across Godot versions. Schema 1 is supported; other schemas report `unsupported_version`. Incompatible content reports `unsupported_content` separately. The content fingerprint is documented in `SaveSnapshot` and must be updated when its content inputs change.
- `request_checkpoint()` defers explicit/manual and critical checkpoint writes, including a hook for a future committed sector transition. Dirty movement flushes outside physics at most once per 20 seconds in the periodic path; the app-pause notification flushes only if dirty. Failed writes remain dirty for retry. Runtime and network layers do not write files. A single local owner writes; host ownership/session metadata is reserved without enabling LAN or client world writes.
- CI exports `SeaCraft-FND06-<commit SHA>` and includes `COMMIT_SHA.txt` and `SHA256SUMS.txt` (including the arm64 APK).

### FND-06 real Android device gate — not run by CI

- Verify normal save/load and background → foreground resume.
- Kill the process during checkpoint writes, then force-stop/relaunch; verify the last completed checkpoint or backup is available.
- Corrupt primary on an isolated test install and verify explicit backup recovery.
- Confirm app-private `user://` needs no storage permission.
- Measure save-related frame spikes on a lower-end phone and test controlled failure/retry with low free storage.

## VS-01 mobile combat slice

Tap/click the orange practice ship to lock it (yellow ring); empty primary taps/clicks still move. Right click selects/clears without movement, and cancel clears the lock. Use the large safe-area-aware **ATEŞ** button when the target is on a broadside, within 35–360 units. One shared battery reloads on simulation ticks; hits resolve instantly without projectile physics, AI or loot.

The offline root passes its authoritative ship heading and target intent into `CombatAuthority.fire`. Rejected commands do not consume cooldown, RNG or a transaction sequence. Accepted volleys draw hit and crit rolls from the existing `encounter` stream, including misses. The fixed formula uses base × crit where applicable, the ordered FND-02 attack modifier pipeline, then subtracts flat defense net of penetration. The applied amount is capped at remaining hull; only the first lethal volley emits `ship_sunk`.

No schema or RNG version change: the existing checkpoint persists encounter RNG progress. The practice NPC, hull, target locks, cooldown and combat sequence are **session-only**; they reset on reload. The saved player motion and active sector are not overwritten by initializing the practice encounter.

**Android device checks not performed by CI:** ship tap/target lock with no accidental move, one-handed fire reach and perceived input latency, small-screen ring readability, salvo frame pacing, rapid tap/fire spam, target lock while the camera moves, and CPU/frame spikes on low- and mid-tier phones.


## VS-02 mobile NPC AI slice

VS-02 replaces the static practice target with one authority-owned SC-03 placeholder NPC. Its authoritative chain is a small `NpcBrain` custom FSM (`PATROL → ALERT → RETREAT → REPAIR → RESUME → PATROL`) with primitive-safe intent snapshots, integer-tick threat memory/decay, explicit hysteresis and a separate ShipMotor intent executor. Perception queries the FND-05 spatial hash only on scheduled AI decisions; movement remains on ShipMotor's fixed physics path. Open-water destinations use direct steering, and Navigation/AStar is requested only when the destination changes and direct travel is obstructed.

**Beehave decision:** the T07 candidate was evaluated for this pilot but is intentionally not installed. This slice has only five centralized states and one bounded utility/safe-point choice; adding a per-agent behavior-tree Node graph would add framework/lifecycle cost without making the vertical-slice behavior clearer. The custom FSM is a `RefCounted` brain with no `_process()`, driven by `AiDecisionScheduler` at 10 physics ticks per decision (6 Hz at the 60 Hz authority clock), with a per-physics-tick decision budget and stagger offsets ready for multiple future agents. Beehave remains a later AI-01 candidate if branching behavior complexity justifies the extra runtime structure; it is not mixed with another AI framework here.

Combat remains authoritative in `CombatAuthority`. A neutral `hull_damaged` signal feeds the brain's threat hook without making combat depend on AI, and fixed-tick repair uses the same combat hull authority. Presentation receives detached DTO snapshots only; the geometric NPC silhouette plus PATROL/ALERT/RETREAT/REPAIR/RESUME text markers are not authoritative state.

VS-02 NPC AI state is deliberately **session-only**. FND-06 save schema/version is unchanged; VS-03 owns the later NPC/loot persistence expansion. Determinism here means the same initial state, waypoint data, hull/threat event trace and decision schedule produce the same state/intent trace; Godot floating-point physics is not claimed as lockstep.

**Android device checks not performed by CI:** NPC patrol visual smoothness; Alert/Retreat readability after attack; retreat hitching; Repair/Resume transitions; 30/60 FPS frame pacing; CPU use during long sailing; camera pan/zoom plus NPC state-change spikes; rapid combat-event decision spikes; and AI decision cost on low- and mid-tier phones.


## VS-03 minimum loot, pickup and persistence

VS-03 consumes the authoritative VS-02 `ship_sunk` event through a dedicated `LootAuthority`. A typed `LootTable` Resource rolls only the existing `loot` RNG stream; the result is copied into primitive-safe drop state with a deterministic stable drop ID. Reprocessing the same sunk event is blocked by a persisted event ledger before another RNG draw can occur. Presentation receives detached drop snapshots and cannot choose loot or mutate authority.

Pickup is one authority-gated transaction. It validates drop existence, claim state, active sector, player distance, stable item ID, positive integer quantity and overflow before atomically recording the claim, incrementing the minimal `stable item ID -> integer quantity` inventory and removing the drop from the sector spatial index. Duplicate pickup returns no reward. Nearby lookup uses the existing FND-05 spatial hash with a bounded radius; there is no whole-world per-frame entity scan, per-item Node inventory, projectile simulation, GLoot dependency, RPC or ENet API.

FND-06 checkpoints now include the primitive loot/drop ledger, minimal inventory and processed sunk-event ledger while preserving the existing schema/version compatibility path: older schema-1 saves without the additive `loot` field load as an empty loot state, while malformed loot state is rejected explicitly. The existing RNG snapshot persists the loot stream, so save/load continues the same authoritative RNG state. Unclaimed drops are re-indexed in their sector; claimed drops remain absent after reload. The runtime remains offline/local-authority today and host-ready for a future adapter where a client sends only pickup intent.

The mobile slice uses one large safe-area-aware contextual **TOPLA** control next to **ATEŞ** and a lightweight diamond placeholder for the drop. The control consumes touch events so pickup does not leak into world movement; it is only visible while a bounded proximity query finds a pickup.

**VS-03 Android device gate — not run by CI:** verify touch pickup on a real phone; drop and TOPLA readability on small screens; no accidental move/pickup collision; save → force-stop → load for both claimed and unclaimed drops; pickup-time frame spike; and long-session loot/save behavior on low- and mid-tier devices. CI export/boot evidence is not a substitute for these device checks.


## VS-04 offline vertical slice integration gate

VS-04 is the first-playable integration gate, not a new mechanic layer. The reusable `scenario.vs04.offline_first_playable.v1` fixture drives the existing authoritative movement, sector, VS-02 AI, targeting/combat, VS-03 loot/pickup and FND-06 persistence paths with deterministic gameplay commands. It proves patrol → threat/Alert → Retreat → Repair → Resume, real broadside range/reload/hit/damage, single sunk/drop/pickup, and a fresh-runtime checkpoint replay without adding network, login, cloud, RPC, discovery or ENet dependencies.

The checkpoint keeps player motion/active sector and RNG through FND-06, plus the mutable NPC motion, combat authority state, AI/threat state, scheduler tick, loot processed-event/claim ledgers and inventory required to resume the same scenario. Reload reconstructs new runtime objects, restores the authority snapshots, rejects repeated death/drop/pickup rewards, and then continues with real ShipMotor movement. Low-cost T32 diagnostics log scenario phase, decision count, spawn count, checkpoint duration and bounded query counts; they are diagnostics only and never replace authoritative state.

CI requires the real VS-04 test script to execute, verifies integration/checkpoint/soak markers, preserves the prior VS-01/VS-02/VS-03 execution verifiers and parse/load/ignored/failing/orphan guards, keeps offline/network separation, boots the Linux export, exports the Android arm64-v8a APK, and packages exact-commit provenance as `SeaCraft-VS04-<SHA>`. The stable scenario ID is intentionally reusable later by NET-03; no NET-03 implementation is included here.

**VS-04 real Android device gate — not run:** verify airplane-mode/internet-free boot; touch movement; camera follow; target lock; fire; NPC state readability; loot pickup; save; force-close/reopen; load continuation; no duplicate loot/claim; small-screen readability; hitch/frame spikes; and input reliability through the long scenario. CI export evidence is not a real-device pass.

## CORE-01 authority transactions

The practice battery selects a registered `AmmoProfile` by intent; the authority owns actor, heading, target lock, stock and rolls. Legacy VS-01/VS-02 weapon fixtures without mounted ammo retain their baseline; the VS-04 scenario exercises the finite-stock firing path. Live shot, repair, boarding and action costs debit the same stable item quantity map that receives VS-03 loot. Zero quantities survive saving and never refill; pre-CORE-01 saves receive the finite debug starting stock once.

Order: (weapon + ammo flat) × ammo scale → FND-02 flat, percent_add, multiply, clamp_min, clamp_max (priority/ID within phase) → hit using clamp(accuracy × (1 − dodge)) → crit using chance × (1 − prevention), then multiplier → element × (1 − resistance) → effective defense max(0, defense − penetration) → hull clamp. Neutral ignores resistance; fire resistance supports [−1, 1]. A volley uses exactly two encounter rolls even on misses. Rejections consume no rolls or stock. Statuses track source, shared expiry tick and capped stack count (brace refreshes, scorch stacks) centrally.

Player repair spends salvage, is blocked after recent hull damage and uses an authority tick cooldown. The VS-02 NPC uses its authored repair rate and schedule through the same transaction path and retains its retreat/threat interruption logic. Its repair supply is reserved to the NPC in the same quantity map. Boarding compares power to protection without RNG; accepted attempts spend salvage and start cooldown even on a failed check. Success returns a reward hook, not ship capture. The brace action spends salvage, refreshes a temporary defense boost and has its own cooldown. The four touch-captured controls are debug controls, not a final hotbar.

Gameplay DTOs contain only intents/results; no network transport. Combat snapshot holds status, selection, cooldown and sequence, and the existing FND-06 checkpoint carries it alongside stock and RNG. Legacy combat snapshots are accepted without the optional CORE fields. For live offline input there is no transport retry ledger; repeated actions must pass the authoritative cooldown and stock checks.

Real Android device: **not_run** — dense combat input, ammo switching, repair, boarding, action item, spam taps, camera + combat, frame pacing, low/mid-range CPU spikes and long-fight state/cooldown readability are separate device checks.
