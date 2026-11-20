# Simulation boundary

Authoritative gameplay state and rules will live here. This layer must remain independent from presentation and networking APIs: no `MultiplayerAPI`, RPC, ENet, UI, camera, rendering or input-device code belongs here. Future offline and LAN modes must call the same simulation-facing command/state contracts through adapters.

FND-01 intentionally contains no gameplay implementation.
