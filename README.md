# SeaCraft

Godot **4.7.2-stable** foundation for an offline-first 2D/2.5D maritime game targeting desktop and Android.

## FND-01 contract

- Main scene: `src/presentation/bootstrap.tscn`; it opens the local sector fixture before printing the boot marker; it performs no network or internet access.
- Renderer: Compatibility (`gl_compatibility`) on desktop and mobile.
- Mobile baseline: 1280×720 landscape, `canvas_items` stretch with `expand`; future UI must respect `DisplayServer.get_display_safe_area()` rather than assuming full-screen safe bounds.
- Architecture boundaries are tracked under `src/simulation`, `src/presentation`, `src/data`, and `tests`.
- No autoload is registered. AI-01 keeps the pinned Beehave runtime tree detached and manually scheduler-ticked, so upstream editor/debugger services never become global authoritative state; FND-01 continues to reject autoloads.
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
- Player stable ID, active sector ID, motion, authoritative world/runtime projection and RNG state are saved. CORE-04 advances the current save schema to 2 and migrates legacy v0 → v1 → v2 sequentially; schema-1 fixtures also migrate to v2, while future schemas remain `unsupported_version`. RNG signed 64-bit values use decimal strings; legacy v0 without RNG uses the documented deterministic migration seed. Content identity is derived from the production content manifest rather than a hand-maintained fingerprint.
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

The checkpoint persists encounter RNG progress. CORE-04 now also persists authoritative combat cooldown/state, practice-NPC runtime/route/threat/repair state and scheduler continuation; reload no longer resets these values. The saved player motion and active sector are not overwritten by initializing the practice encounter.

**Android device checks not performed by CI:** ship tap/target lock with no accidental move, one-handed fire reach and perceived input latency, small-screen ring readability, salvo frame pacing, rapid tap/fire spam, target lock while the camera moves, and CPU/frame spikes on low- and mid-tier phones.


## VS-02 mobile NPC AI slice

VS-02 replaces the static practice target with one authority-owned SC-03 placeholder NPC. Its authoritative chain is a small `NpcBrain` custom FSM (`PATROL → ALERT → RETREAT → REPAIR → RESUME → PATROL`) with primitive-safe intent snapshots, integer-tick threat memory/decay, explicit hysteresis and a separate ShipMotor intent executor. Perception queries the FND-05 spatial hash only on scheduled AI decisions; movement remains on ShipMotor's fixed physics path. Open-water destinations use direct steering, and Navigation/AStar is requested only when the destination changes and direct travel is obstructed.

**Beehave decision history:** VS-02 originally shipped with the five-state SeaCraft custom FSM only. AI-01 now keeps that custom authoritative FSM and migrates the same practice NPC onto the reusable Sense → Memory → Utility → FSM/Beehave execution pipeline described below. Beehave is an execution/orchestration layer only; it is not a second authority state, perception store, utility system or replacement FSM.

Combat remains authoritative in `CombatAuthority`. A neutral `hull_damaged` signal feeds the brain's threat hook without making combat depend on AI, and fixed-tick repair uses the same combat hull authority. Presentation receives detached DTO snapshots only; the geometric NPC silhouette plus PATROL/ALERT/RETREAT/REPAIR/RESUME text markers are not authoritative state.

CORE-04 promotes the VS-02 NPC state into the production persistence contract: FSM/intent, patrol index, semantic destination, selected safe point, threat memory, repair timing and scheduler due tick resume from the checkpoint while authored stats remain definition-owned. Determinism here means the same initial state, waypoint data, hull/threat event trace and decision schedule produce the same state/intent trace; Godot floating-point physics is not claimed as lockstep.

**Android device checks not performed by CI:** NPC patrol visual smoothness; Alert/Retreat readability after attack; retreat hitching; Repair/Resume transitions; 30/60 FPS frame pacing; CPU use during long sailing; camera pan/zoom plus NPC state-change spikes; rapid combat-event decision spikes; and AI decision cost on low- and mid-tier phones.


## VS-03 minimum loot, pickup and persistence

VS-03 consumes the authoritative VS-02 `ship_sunk` event through a dedicated `LootAuthority`. A typed `LootTable` Resource rolls only the existing `loot` RNG stream; the result is copied into primitive-safe drop state with a deterministic stable drop ID. Reprocessing the same sunk event is blocked by a persisted event ledger before another RNG draw can occur. Presentation receives detached drop snapshots and cannot choose loot or mutate authority.

Pickup is one authority-gated transaction. It validates drop existence, claim state, active sector, player distance, stable item ID, positive integer quantity and overflow before atomically recording the claim, incrementing the minimal `stable item ID -> integer quantity` inventory and removing the drop from the sector spatial index. Duplicate pickup returns no reward. Nearby lookup uses the existing FND-05 spatial hash with a bounded radius; there is no whole-world per-frame entity scan, per-item Node inventory, projectile simulation, GLoot dependency, RPC or ENet API.

FND-06 checkpoints include the primitive loot/drop ledger, minimal inventory and processed sunk-event ledger. CORE-04 migration supplies the deterministic empty loot default when upgrading schema-1 data to schema 2; malformed or referentially inconsistent loot state is rejected explicitly. The existing RNG snapshot persists the loot stream, so save/load continues the same authoritative RNG state. Unclaimed drops are re-indexed in their sector; claimed drops remain absent after reload. The runtime remains offline/local-authority today and host-ready for a future adapter where a client sends only pickup intent.

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


## CORE-03 multi-sector transition, safe haven, hazard routing and maps

CORE-03 extends the existing `SectorGraph`, `SectorWorld` and `SectorNavigation` instead of creating parallel world or pathfinding systems. The authored pilot graph contains Foundation Waters, Outer Reach and Ashen Haven as real `SectorDefinition` resources with stable IDs, bounds, anchors, gates, navigation fixtures, hazard/profile metadata and independent authored world-map node positions. Only the active sector owns a full `SectorRuntime`; visited inactive sectors are reduced to bounded primitive-safe runtime snapshots and rehydrated on entry. Combat, loot and world-object authorities keep their persistent sector-tagged primitive state, not a second live scene tree.

Gate traversal is an authority transaction. It validates the actor, current sector, authored gate origin, activation radius, destination, entry anchor and destination runtime before committing. The result is a primitive-safe DTO with `accepted`, `reason`, `from_sector`, `to_sector`, `gate_id` and `entry_anchor`. Rejections leave the active runtime, actor position, authority state and RNG untouched. A committed transition crosses one explicit `SectorRuntimeBinding` composition boundary so combat, loot, world objects and NPC routing point at the new active runtime; the bootstrap then moves the player motor to the authoritative entry position and replaces only the active-sector presentation geometry.

Safe Haven protection is data-driven through stable safe-zone definitions. Hostile cannon, harpoon and hostile action/status damage all pass the same authoritative damage gate immediately before commit. If the attacker or target is protected, the transaction is rejected before damage, stock consumption, cooldown, RNG, transaction-sequence or status mutation. Non-hostile repair remains available.

Hazards reuse the existing `SectorNavigation` AStar2D graph. Storm, shallows, area and faction/hostility costs are finite and bounded, update waypoint weights only when state changes, and invalidate the cached route event-by-event rather than rebuilding paths every physics frame. The same navigation service is used by player route queries and `NpcIntentExecutor`; CORE-03 adds no damage-over-time, weather simulation or combat-debuff system.

World-map data is a detached primitive-safe `SectorGraph` snapshot containing authored sector nodes, labels, layers, connections, Safe Haven flags and presentation tags. `MinimapTransform` provides deterministic world→map and map→world conversion, inverse round trips, aspect-ratio handling and clamp/reject behavior. `SectorMapOverlay` is a lightweight `Control`: the minimap draws current-sector bounds, player/gate/safe-zone markers; the world map draws graph nodes and edges, supports touch pan/pinch zoom plus mouse pan/zoom, and never performs teleportation. While the world map is open, `GameplayInputController` blocks world movement/selection/fire/pickup commands so UI gestures cannot leak into simulation. No second SubViewport, second world render or all-sector instantiation is used.

FND-06 checkpoints carry `sector_world` inside the primitive-safe authoritative snapshot: active sector runtime state, visited dormant-sector state, active player motion, sector-tagged combat/world-object state, loot ledgers and RNG continuation. CORE-04 schema migration upgrades legacy v0/v1 data before current validation; schema 2 uses strict content-manifest compatibility and transactional restore. The runtime remains offline/local-authority and host-ready; CORE-03 adds no RPC, ENet, discovery, cloud or client-authoritative world writes.

CI requires the original 234 tests plus 10 CORE-03 scenario tests, the existing CORE-01/CORE-02 and VS-04 execution verifiers, parse/load/ignored/failing/orphan guards, Linux export/boot, Android arm64-v8a export, and exact-commit artifact readback. The artifact name is `SeaCraft-CORE03-<SHA>`.

### CORE-03 real Android device gate — not_run

CI export is not real-device evidence. The following remain `not_run` until exercised on Android hardware: sector gate touch/transition; transition sonrası camera/input; minimap readability; world-map open/close; pinch zoom; pan; gesture/world-input çatışması; safe-zone okunabilirliği; hazard route gözlemi; küçük ekran marker okunabilirliği; map memory/frame spike; birkaç sector transition sonrası frame pacing; save/reload ve tekrar sector geçişi.


## CORE-04 persistence hardening and content registry gate

CORE-04 advances the world save contract to **schema 2** and keeps one persistence system. `SaveMigrations` performs deterministic one-step migrations `v0 → v1 → v2`; every step validates its primitive-safe DTO, legacy v0 uses the documented deterministic master seed `10404` when RNG did not exist, schema-1 fixtures migrate to current, and future schemas remain explicitly rejected.

`DefinitionRegistry` is the single stable-ID content registry for ship, weapon, item, faction, sector, ammo, monster, harpoon, safe-zone and loot-table definitions/references. `ContentManifest` derives a deterministic SHA-256 from stable ID, type, canonical resource path, sorted referenced IDs and the authoritative resource bytes. Saves carry content version plus manifest hash/count. A gameplay content-hash mismatch, unknown authoritative content ID, unknown sector or broken reference is rejected before runtime/RNG/inventory commit; there is no best-effort placeholder load for authoritative state.

`PersistentEntityIndex` is a bounded persistence projection, not simulation authority. It stores sorted instance IDs separately from definition IDs with entity kind, sector, position/motion, hull/alive state, semantic route progress, tick cooldowns, inventory and versioned content refs. Maximums are explicit: **2048 persistent entities**, **32 sectors**, bounded inventory/cooldown/content-reference collections, DTO depth/container limits, and a **4 MiB** save-byte cap. Active and dormant visited-sector state remains lazy: only the active `SectorRuntime` is instantiated.

The production checkpoint preserves player/NPC combat cooldowns, NPC FSM/intent/patrol/destination/safe-point/threat/repair state and scheduler timing, loot processed-event/claim/inventory state, world-object processed-spawn/claim state, dormant sector state and RNG continuation. Restore is transactional: parse → migration → schema/content validation → entity/reference/RNG validation → full world restore plan → commit. A failed pre-commit validation leaves the running runtime unchanged.

The existing `world.tmp → verify → backup rotate → primary replace → verify` writer remains the only world writer. CORE-04 fault-injection covers temp open/short-write/verification, backup-rotation and primary-replace/verification failures, backup recovery, corrupt primary+backup and dirty retry; stale temp is never a trusted recovery source. Simulated short-write/no-space-class failure preserves the verified checkpoint and keeps dirty state retryable. This is not a filesystem fsync/power-loss guarantee.

Client-local graphics/audio/control preferences are stored separately through `SettingsService`; that store rejects world authority fields and never owns entities, inventory, RNG, loot or combat state. World ownership remains local single-player today with `host` metadata reserved for future LAN; CORE-04 does not implement LAN disconnect/logout gameplay.

CI runs **254 GUT tests**, including **10 CORE-04 tests**, and requires the CORE-04 migration/registry/hash/entity/NPC/recovery/malformed/large-roundtrip markers plus CORE-01/02/03 and VS-04 regressions. The bounded large-world fixture contains **512 persistent entities** and logs entity count, encoded bytes, save time and load/restore time while asserting semantic equality and referential integrity. Exact-commit CI also requires Linux export/boot, Android arm64-v8a APK export and downloaded artifact provenance readback. The artifact is `SeaCraft-CORE04-<SHA>`.

### CORE-04 real Android device gate — not_run

CI export is not real-device evidence. These remain **not_run** until exercised on Android hardware: application suspend/resume; OS process kill; process kill during save; low-storage behavior; corrupt primary/backup recovery; large-world save/load latency; memory use with several hundred persistent entities; save then another sector transition; NPC route/cooldown continuation; and force-close/restart attempts to reset combat, repair, boarding, action-item or scheduler cooldowns.


## AI-01 perception, memory, utility and BT/FSM framework

AI-01 refactors the existing VS-02 practice NPC in place rather than leaving a parallel brain. Each scheduled authority decision follows one explicit chain: **bounded SenseSnapshot → MemoryBlackboard update/decay → pure UtilityDecision + hysteresis → SeaCraft custom FSM transition → manually ticked Beehave action → NpcIntentExecutor → ShipMotor.apply_authoritative_command()**. Utility and memory are primitive-safe data; they do not write transforms, call physics, perform combat transactions, access files, or own presentation state.

Perception uses the existing `SectorSpatialHash` only. `NpcAiTuning` owns radius, candidate cap and query cadence; filtering removes self/friendly/dead/non-selectable/role-irrelevant candidates before deterministic distance + stable-ID ordering and truncation. One decision uses one authoritative `SenseSnapshot`; the utility layer never re-queries the world. `MemoryBlackboard` keeps a bounded stable-ID hostile table with last-known position, threat, recency, deterministic integer-tick decay/expiry, selected target and persisted hysteresis state. The legacy `NpcThreatMemory` surface is only a compatibility adapter over that single memory implementation.

Role content is typed `NpcRoleProfile` gameplay content registered through the CORE-04 `DefinitionRegistry` / deterministic `ContentManifest`. Stable fixtures `ai_role.trader`, `ai_role.escort` and `ai_role.raider` vary patrol/travel, avoidance, protect/investigate, pursuit/aggression and repair/safety weights without creating separate decision code. `UtilityDecision` emits only selected intent ID, target ID, bounded score, debug factors, decision tick/sequence and hysteresis state; stable tie breaks and switch threshold/hold bonus/minimum hold prevent near-equal target thrash.

The authoritative FSM remains SeaCraft-owned and preserves **PATROL / ALERT / RETREAT / REPAIR / RESUME** with primitive transition traces and invalid-transition rejection. Beehave is pinned to official upstream **bitbrain/beehave v2.9.3**, exact commit **773a5f6dd9b3433cdb8735ab35e9043d4cd60674**, MIT license. The vendored runtime subset is byte-for-byte verified against upstream Git blob IDs in CI. It is used only for action lifecycle/status orchestration (RUNNING / SUCCESS / FAILURE, interrupt/reset and deterministic simulation-tick timeout). `BeehaveTree.ProcessThread.MANUAL` is mandatory; `AiDecisionScheduler` is the only production decision/tick driver, so no independent Beehave `_process()` or physics tick creates a second AI update.

Reusable Beehave-backed actions cover destination/route, wait/observe, stop, repair and target/investigate. They call SeaCraft semantic/authority adapters rather than storing world truth in a Beehave blackboard. Navigation stays on `SectorNavigation`; movement stays on `NpcIntentExecutor` and `ShipMotor.apply_authoritative_command()`. AI-01 intentionally does not add AI-02 cannon/ammo/boarding tactics, RPC, ENet or client authority.

Persistence extends the existing CORE-04 checkpoint with role stable ID, bounded memory table, selected intent/target, hysteresis/hold data, FSM state/trace, semantic destination/patrol progress, minimum resumable BT semantic state and scheduler next-due timing. No Beehave Node, Resource or runtime blackboard object is serialized. Restore rebuilds runtime objects from SeaCraft primitive state and resumes on the next scheduled authority decision. Role-profile references participate in the content manifest, so the existing strict content-hash mismatch policy remains unchanged.

Primitive telemetry includes decision/sense/utility counts, candidate/inspected counts, selected intent/target, FSM state, BT status/failure/timeout counts and scheduler due/budget metrics. `NpcStatePresenter` consumes only a detached snapshot (state, intent, role and optional target) and cannot mutate AI. CI runs a deterministic 20-NPC bounded fixture to verify budget, stagger, no starvation, spatial-query inspection bounds and one manual Beehave tick per AI decision; this is not a real-device benchmark.

### AI-01 real Android device gate — not_run

The following checks remain **not_run** until exercised on physical Android hardware: 10 NPC AI tick spike; 20 NPC AI tick spike; perception-heavy scene; simultaneous memory/utility update; BT action timeout/failure; sector transition + NPC AI; suspend/resume AI continuation; long-session frame pacing; low/mid-range device CPU; thermal throttling. Linux/Android CI export and deterministic 20-NPC fixtures are not substitutes for these device measurements.


## AI-02 tactical combat AI

AI-02 extends the AI-01 production chain in place: **SenseSnapshot → MemoryBlackboard → UtilityDecision → TacticalContext → TacticalDecision → SeaCraft FSM / manually scheduled Beehave execution → NpcIntentExecutor / CombatAuthority**. It does not add a second brain. `TacticalContext` reads authority/world state and returns a detached primitive-safe DTO only; `CombatAuthority.tactical_snapshot()` exposes bounded read-only combat facts without leaking `CombatantState`, consuming RNG, advancing transaction sequence, spending stock or changing cooldowns. Tactical scoring is deterministic and uses no RNG.

Expected hit and DPS reuse `CoreCombatRules.hit_chance()` and `CoreCombatRules.damage()` with accuracy, dodge, crit/prevention, ammo damage, elemental resistance/weakness, defense, penetration and reload. Range behavior derives the preferred band from weapon min/max range with hysteresis. Broadside validity uses actor heading, target bearing, weapon broadside arc and mounted side; deterministic port/starboard selection preserves an existing valid side, mounted-side constraints, the shorter turn and then a stable tie-break. Tactical destinations cover close, hold, open, broadside alignment and retreat, while movement still goes only through `NpcIntentExecutor → ShipMotor.apply_authoritative_command()`; pathfinding remains `SectorNavigation` and is not recalculated every physics frame.

Ammo scoring is bounded by explicit `NpcAiTuning` caps and evaluates expected DPS, elemental matchup, stock, scarcity reservation, target tactical value, current selection and switch cost. Zero-stock ammo is not a candidate; scarce expensive ammo is penalized for low-value targets, while sufficient-stock elemental ammo can win against a valuable weakness and loses value against resistance. Actual ammo selection is still `CombatAuthority.transact(AMMO_SELECT)`; a select attempt is never chained into a fire transaction in the same scheduled decision. Actual cannon damage remains exclusively `CombatAuthority.fire()`.

Retreat/fight scoring combines hull pressure, threat, numerical pressure, ammo outlook, expected DPS and an escape-route fact set. Escape candidates are capped and reuse `SectorNavigation.path()` plus the existing AStar hazard weights through a read-only weighted route-cost calculation; safe/clear routes can beat a shorter dangerous route. Repair remains the existing AI repair transaction and is favored only in a disengaged window. Boarding utility reads the authority-owned board range/threshold plus power/protection, surrounding pressure, self hull and target tactical value; the real attempt remains `CombatAuthority.transact(BOARD)`. Support is a bounded primitive semantic intent with persisted cooldown only; AI-02 does **not** implement `FleetCoordinator`, reinforcement spawning, convoy orchestration or any AI-03 system.

The line-of-fire guard uses the existing sector spatial hash and a bounded attacker→target corridor inspection. An alive same-faction ship inside the corridor blocks the AI fire decision; blocked tactical fire consumes no ammo, RNG or combat sequence. Safe-zone hostility and the cannon/harpoon target-class matrix remain authoritative in `CombatAuthority` / `TargetingService`. `authority_enabled=false` leaves tactical presentation/snapshots readable but prevents scheduled AI mutations. The practice SC-03 NPC now uses the same cannon-capable production `NpcBrain` tactical path instead of a test-only fixture.

Trader, escort and raider continue using one scorer with data-driven role weights: traders conserve scarce ammo and retreat/repair earlier, escorts weight fighting/support more strongly, and raiders weight pursuit/boarding and high-value ammo use more strongly. Persistent AI state stores only semantic range-band hysteresis, desired broadside side, support cooldown and last tactical intent/target; transient TacticalContext, expected-DPS/cache/candidate arrays, Beehave nodes and authority-owned ammo/boarding/combat cooldown state are not serialized. `NpcStatePresenter` reads the detached tactical telegraph (fight/retreat/repair, ammo, range/broadside, boarding/support) and cannot write gameplay state.

The LAN boundary remains unchanged: tactical decisions are host/authority-side simulation work; no RPC, ENet or client-side tactical authority is introduced. CI verifies the bounded tactical scenario matrix, expected-DPS no-RNG behavior, range/broadside hysteresis, ammo economy, retreat/repair, line-of-fire, boarding, support cooldown, persistence and a 20-NPC scheduled tactical fixture, while retaining AI-01, CORE-04/03/02/01 and VS-04 regressions. Exact-commit export produces Linux and Android arm64-v8a outputs and the `SeaCraft-AI02-<SHA>` provenance artifact.

### AI-02 real Android device gate — not_run

CI export and headless fixtures are not physical-device evidence. These remain **not_run**: 10 NPC simultaneous combat; 20 NPC simultaneous combat; broadside maneuver frame pacing; dense-fleet line-of-fire; ammo scoring spike; escape path scoring spike; multiple boarding candidates; support-intent burst; long-combat thermal profile; low/mid-range Android CPU; combat-AI resume after sector transition; and suspend/resume tactical state.


### AI-03 fleet, formation and world behavior

AI-03 extends the existing AI-01/AI-02 chain rather than creating a second NPC brain. The authority-owned `FleetCoordinator` stores fleet/leader/member stable IDs, merchant/escort/scout roles, deterministic column/line/wedge slots, semantic fleet goals, break/regroup state, deterministic succession, bounded support dispatch and primitive-safe persistence. Fleet identity is independent of leader identity. Formation updates only emit `FleetCommand` DTOs; NPC movement still flows through `NpcIntentExecutor -> ShipMotor.apply_authoritative_command()`, while AI-02 remains authoritative for local tactical target/range/ammo/retreat/repair/boarding decisions.

`FactionRelationResolver` provides one typed friendly/neutral/hostile input for AI perception and combat snapshots without implementing the later reputation system. Safe-zone targets are removed from AI pursuit and stale hostile memory/locks are invalidated before local world behavior resumes. `WorldJob` provides pure-data patrol/trade/salvage/escort/dock jobs plus cargo-mission references and idempotency-ready economy events; it does not simulate prices, markets, guilds or reputation. `DockAuthority` enforces bounded capacity, deterministic FIFO/stable-ID queue fairness, idempotent requests, cleanup and separated wait anchors.

Fleet, dock and relation snapshots are primitive-safe and included in the existing authoritative checkpoint envelope. Near-field budgets are explicit (`MAX_FLEETS_ACTIVE=8`, `MAX_FLEET_MEMBERS=8`, `MAX_FORMATION_UPDATES_PER_TICK=8`, `MAX_PATH_JOBS_PER_TICK=4`, `MAX_SUPPORT_RECIPIENTS=4`); formation destination hysteresis prevents per-frame path churn. The CI fixture covers 6 convoys / 24 ships, deterministic formation, ambush break/regroup, succession, docking, relation transitions, safe-zone pursuit cutoff, jobs, support loop guards and persistence, while retaining all AI-02/AI-01/CORE/VS-04 regressions and Linux/Android exports. This is not AI-04 far-field/LOD simulation. Physical Android checks for 20+/24-ship formation, path spikes, dock congestion, moving succession, safe-zone cutoff, sector transition, suspend/resume, long-session thermal/CPU and low/mid-tier device frame pacing remain `not_run`.


## AI-04 simulation LOD, far-field world simulation and spawn direction

AI-04 keeps the AI-01/AI-02/AI-03 near-field production chain as the only full NPC/fleet/combat simulation and adds an authority-owned world scale layer around it. `SimulationLOD` classifies stable entities as `near`, `mid` or `far` from authoritative sector graph distance, explicit relevance, combat involvement and job/fleet importance. Data-driven hysteresis plus minimum residency prevents boundary thrash. Near entities continue to use the existing `NpcBrain`, `AiDecisionScheduler`, `FleetCoordinator`, `ShipMotor` and `CombatAuthority`; AI-04 does not create a second near-field brain or combat stack.

MID keeps the same persistent semantic entity/fleet/job truth but advances at a sparse cadence without running every physics/perception/path update. FAR uses primitive-safe `FarFieldEntityState` projections stored under each CORE-04 `PersistentEntityIndex` record, so runtime despawn is not world retirement and inactive sectors do not require live SceneTree/physics resources. `FarTravelResolver` routes over the existing `SectorGraph` snapshot with deterministic authored hazard cost/delay/risk. `FarCombatResolver` is a bounded deterministic coarse resolver for FAR only; near combat remains `CombatAuthority`. Far RNG uses versioned stable-ID substreams derived from `SeedStreams` without consuming near combat/world stream state or wall-clock time.

`WorldWorkScheduler` bounds near/mid/far orchestration, global path jobs and spawn jobs with deterministic stable-ID ordering, coalescing and age-preserving fairness. `WorldSpawnDirector` validates definitions through the CORE-04 registry, applies hard total/near/sector/faction-role population caps, emits deterministic idempotent stable IDs, persists its ledgers/sequences, and includes the bounded M-043 Admiral event counter/cooldown hook plus low/high behavioral region profiles. `WorldSimulationAuthority` persists LOD residency, primitive far state, scheduler queues, spawn/admiral ledgers, far RNG/event sequence, pending bounded encounters and AI-03 fleet state transactionally. Presentation can read only detached summaries.

SeaCraft LAN remains future host-authoritative snapshot replication, **not deterministic physics lockstep**. AI-04 adds no ENet, RPC, `MultiplayerSpawner` or `MultiplayerSynchronizer`; FAR determinism is a host-authority coarse world resolver and future clients will observe snapshots. CI covers 100 persistent entities (20 near / 30 mid / 50 far), 1,440 simulated coarse ticks, deterministic replay, LOD transitions, path/spawn budgets, population/admiral caps, persistence continuation and all prior regressions. Linux export/boot and Android arm64 export are CI gates; physical Android checks for 50/100 entities, 100+ LOD transitions, mixed LOD, queue/spawn spikes, long sessions, memory, CPU/frame pacing, thermals, suspend/resume and host-equivalent load remain `not_run`.
