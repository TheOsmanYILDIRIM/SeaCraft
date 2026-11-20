# Data boundary

Typed `Resource` definitions, stable-ID index metadata and the single validated definition registry live here. Runtime authoritative state belongs to simulation DTO/state structures, not mutable content definitions.

## FND-02 contract

- Content definitions are small typed `.tres` resources: `ShipDefinition`, `WeaponDefinition`, `ItemDefinition`, `FactionDefinition`, and `SectorDefinition`.
- Every definition owns a path-independent persistent string `stable_id`. Runtime object IDs, RIDs and file paths are never persistence/network identity.
- `DefinitionRegistry` validates lightweight index-entry resources first and loads actual definition resources only on demand through `ResourceLoader.CACHE_MODE_IGNORE`. This keeps the startup registry index-based instead of retaining every content resource.
- Duplicate stable IDs and missing stable-ID references reject the whole registry build.
- The index records resource paths only as local lookup locations; save/network contracts refer to stable IDs only.
- `DataContractVersions` separates integer schema version from content version so later save migration and host/client compatibility checks can make independent decisions.
- Test fixtures under `tests/fixtures/content` are deliberately tiny and are not final game content.

Definitions are treated as read-only source data after loading. Mutable HP, position, inventory and other per-entity values belong to runtime state instead.
