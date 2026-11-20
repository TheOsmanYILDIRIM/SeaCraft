# Simulation boundary

Authoritative gameplay state and rules live here. This layer must remain independent from presentation and networking APIs: no `MultiplayerAPI`, RPC, ENet, UI, camera, rendering or input-device code belongs here. Future offline and LAN modes must call the same simulation-facing command/state contracts through adapters.

## FND-02 contracts

- `EntityRuntimeState` owns mutable instance data and emits only primitive-safe DTO fields plus stable content IDs.
- `StatModifierPipeline` is the single canonical modifier-order implementation. Phase, priority and modifier ID sorting prevents Dictionary/Array iteration order from changing results.
- `SeedStreams` derives independent `world`, `encounter`, and `loot` seeds from one master seed and owns one Godot `RandomNumberGenerator` per stream.
- Seed derivation is a versioned SeaCraft contract; Godot's internal RNG algorithm is explicitly **not** treated as a cross-Godot-version persistence or network protocol guarantee.
- RNG state can be snapshotted/restored as a primitive-safe DTO for a future save layer. FND-02 does not implement save/load or LAN lockstep.
- Future LAN remains host-authoritative: the host owns authoritative RNG state/seed and simulation state; clients must not treat a shared seed as authority.
