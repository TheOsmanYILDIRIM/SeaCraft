# SeaCraft Görev Raporları

Bu dosya bundan sonraki uygulama görevlerinin **tek kanonik sohbet-dışı sonuç raporu**dur.

Kurallar:

- Her görev tamamlandığında mevcut içerik korunur ve o görev için yeni bir bölüm eklenir.
- Yalnız doğrulanmış GitHub/CI/artifact/Beyin kanıtları yazılır.
- Actions queued veya ilk commit başarı sayılmaz.
- Gerçek cihaz yapılmadıysa açıkça `not_run` yazılır.
- Sohbete uzun kapanış raporu kopyalanmaz.
- Ayrı görev sonucu için yeni rapor dosyası oluşturulmaz.
- Geçmiş bölümler sonradan sessizce yeniden yazılmaz; kanıt düzeltmesi gerekiyorsa ilgili bölüm altında `Düzeltme` alt başlığı kullanılır.

---

## NET-01 — LAN Session ve Host-Authority Protokolü

Durum: `done`

Kanonik brief: `AKTIF_GOREV.md`

Oturum: `SOHBET-28`

Godot: `4.7.2-stable`

NET-02: `not_started`

### Doğrulanmış hedef ve commit zinciri

- Brief içindeki istenen baseline: `56c5727c161b0801cae024b54242e3b4d2d063ea`
- Güvenli uygulama başlangıç HEAD'i: `b8ab959879240adb8e9e429eaa2de2c98cbbd43b`
- Exact test/export/artifact kod SHA: `180282bdc00fca5d40af40943c1fe59d949d7f23`
- Implementation commit: `b991f1cc190e729ff21a11b0567b2cd2be40670c` — `feat(net01): add LAN host-authority session protocol`
- Correction commit: `6562fba065e074689d370e85c65d227de901e63b` — `fix(net01): avoid Object disconnect override`
- Correction commit: `680bc3999ebe6b01c753bb0e2e105fb856e63fa4` — `test(net01): surface process integration failures`
- Correction commit: `c1ac5dfccd7472283f5bf6537b6ad272a7675bda` — `fix(net01): initialize multiplayer API in process harness`
- Correction commit: `fc4aa9cf7a60a0ca0d8ef69008c34a06aeb6f5e1` — `fix(net01): run process integration in normal SceneTree`
- Final correction / exact green SHA: `180282bdc00fca5d40af40943c1fe59d949d7f23` — `fix(net01): quit process harness through SceneTree`

Başlangıç HEAD'ine gelene kadarki görev dışı dokümantasyon değişiklikleri korunmuş, başka çalışmanın değişiklikleri ezilmemiştir.

### Uygulanan NET-01 sınırı

Ağ kodu `src/network/` altında ayrı bir boundary olarak eklendi:

- `SessionProtocol`: protocol v1, canonical data/content compatibility stamp, bounded primitive intent envelope, strict IPv4/port doğrulaması, deterministic reject nedenleri ve sequence/replay kapısı.
- `SessionRpcBridge`: gerçek Godot high-level RPC; control/handshake channel 0 reliable, gameplay intent channel 1 reliable. Channel 2 yalnız NET-02 için `unreliable_ordered` policy reservation; replication uygulanmadı.
- `SessionHost`: built-in `ENetMultiplayerPeer`, connected/handshaking/ready/rejected lifecycle, host-only peer→player eşleme, disconnect cleanup, sequence authority ve mevcut `ShipMotor.apply_authoritative_command()` köprüsü.
- `SessionClient`: manual IPv4+port join, handshake lifecycle, monoton client sequence ve yalnız intent/GameplayCommand gönderimi; authoritative transform yazımı yok.
- İzinli network gameplay intentleri: `move_to_world_position`, `select_world_position`, `cancel`, `target_cycle`. Camera pan/zoom/recenter local presentation olarak kaldı.
- Client handshake/envelope authoritative `player_id`, `peer_id`, `entity_id`, `owner_id`, `authority_id` taşıyamaz; recursive spoof alanları reddedilir.
- Model host-authoritative'dir; lockstep değildir. Encryption/authentication/anti-cheat/internet service iddiası yapılmadı.
- Discovery, relay, NAT traversal, reconnect ve state replication eklenmedi; bunlar NET-01 kapsamı dışındadır.

### Protocol/content handshake doğrulaması

Handshake canonical kaynakları doğrudan `DataContractVersions.compatibility_stamp()` ve `ContentManifest.metadata()` üzerinden türetiliyor.

Exact green run'da aşağıdaki marker'lar geçti:

- `NET01_PROTOCOL_CONTRACT_OK`
- `NET01_HANDSHAKE_OK`
- `NET01_PROTOCOL_MISMATCH_OK`
- `NET01_CONTENT_MISMATCH_OK`
- `NET01_PEER_MAPPING_OK`
- `NET01_INTENT_AUTHORITY_OK`
- `NET01_SPOOF_REJECTION_OK`
- `NET01_REPLAY_REJECTION_OK`
- `NET01_OFFLINE_BOOT_OK`

Deterministic handshake reject yolları `protocol mismatch`, `schema/version mismatch`, `content version mismatch`, `content hash mismatch`, `malformed handshake` ve `server full` olarak sabitlendi. Protocol, schema/RNG, content version, manifest algorithm/hash/count uyuşmazlıkları ready durumuna geçmeden reddediliyor.

### Gerçek ayrı-process ENet/RPC doğrulaması

CI yalnız unit test ile yetinmedi. `tools/ci/run_net01_process_integration.sh`, localhost `127.0.0.1` üzerinde ayrı Godot host/client process'leri ve gerçek `ENetMultiplayerPeer` + RPC çalıştırdı.

Process verifier tam olarak şu senaryoların marker'larını tekil olarak doğruladı:

- başarılı handshake
- host-owned peer→player mapping
- valid move intent → mevcut GameplayCommand → authoritative ShipMotor
- replay rejection
- recursive identity spoof rejection
- malformed payload rejection
- protocol mismatch rejection
- content mismatch rejection
- pre-handshake intent rejection
- host clean exit / bounded process cleanup

Final marker'lar:

- `NET01_PROCESS_INTEGRATION_OK`
- `NET01_VERIFIER_OK tests=10 real_process_rpc=1 host_authority=1`

Verifier ayrıca host authority diagnostic'inde ilk hazır peer'in `player.alpha` olarak eşlendiğini, sequence `0` move hedefinin `(321.0,-45.0)` olduğunu ve ikinci oyuncunun `beta_has_target=false` kaldığını doğruladı. Böylece bir client intentinin başka oyuncunun authoritative motorunu değiştirmediği process seviyesinde kanıtlandı.

Runner port collision kontrolü, readiness deadline, per-client timeout, PID/trap cleanup ve clean host stop içeriyor. Süreç harness'i normal Godot SceneTree içinde çalıştırılarak Node.multiplayer/RPC davranışı gerçek runtime yoluyla doğrulandı.

### Offline boot ve simulation/network boundary

- Default `project.godot` autoload ile session açmıyor; ağ socket'i yalnız açık `SessionHost.start()` / `SessionClient.join()` çağrısıyla oluşturuluyor.
- Headless default project boot exact green run'da geçti.
- `NET01_OFFLINE_BOOT_OK` geçti.
- CI network guard, `src/simulation`, `src/data`, `src/persistence` ve `src/presentation` altında ENet/Multiplayer/RPC API kullanımını yasaklıyor; guard exact green run'da geçti.
- Mevcut `GameplayCommand` ve `ShipMotor` contract'ları network API bağımlılığı almadan korundu.
- Offline authority davranışı ve önceki simulation katmanları korunmuştur.

### Test ve regresyon kanıtı

Exact green Actions run: `44955450219` / run `#164`

- GUT total: `305`
- Passing Tests: `305`
- NET-01 unit tests: `10/10`
- NET-01 process verifier: `10` contract/process assertions, `real_process_rpc=1`, `host_authority=1`
- VS-01: mevcut test manifesti değişmeden doğrulandı
- VS-02: `38` test execution doğrulandı
- VS-03: `23` test execution doğrulandı
- VS-04: `25` test + integration/checkpoint/soak marker'ları doğrulandı
- CORE-01: `6` test doğrulandı
- CORE-02: `8` test doğrulandı
- CORE-03: `10` test doğrulandı
- CORE-04: `10` test; `entity_count=512`, `encoded_bytes=376584`
- AI-01: `10` test
- AI-02: `11` test
- AI-03: `10` test
- AI-04: `10` test; 100 entity long-soak regresyonu ve `starvation=0`
- GUT failure/parse/load/orphan guard geçti; orphan count: `0`

VS-04 exported/gameplay regresyon kapıları, CORE-02/03/04 ve AI-01/02/03/04 marker kapıları final exact commit üzerinde başarıyla geçti.

### Actions geçmişi

NET-01 uygulama zincirinde toplam `6` push Actions run çalıştı:

| Run | Exact SHA | Sonuç | Kapanış notu |
| --- | --- | --- | --- |
| `44954521879` / #159 | `b991f1cc190e729ff21a11b0567b2cd2be40670c` | failed | SessionClient native `disconnect` isim çakışması GUT strict parse/load kapısında düzeltildi. |
| `44954672108` / #160 | `6562fba065e074689d370e85c65d227de901e63b` | failed | Real-process entegrasyon timeout'u; kök neden diagnostic hardening ile açığa çıkarıldı. |
| `44954855675` / #161 | `680bc3999ebe6b01c753bb0e2e105fb856e63fa4` | failed | Custom `--script` MainLoop altında `Node.multiplayer` null olduğu doğrulandı. |
| `44955059756` / #162 | `c1ac5dfccd7472283f5bf6537b6ad272a7675bda` | failed | Custom MainLoop workaround'u yeterli olmadı; harness normal SceneTree yoluna taşındı. |
| `44955251870` / #163 | `fc4aa9cf7a60a0ca0d8ef69008c34a06aeb6f5e1` | failed | Normal SceneTree harness'te kalan bare `quit()` parse hatası düzeltildi. |
| `44955450219` / #164 | `180282bdc00fca5d40af40943c1fe59d949d7f23` | **success** | Tüm test/process/regression/export/artifact/readback kapıları geçti. |

Sayım: `total=6`, `success=1`, `failed=5`, `cancelled=0`.

Final commit combined status context `seacraft-net01-evidence=success` ve target run `44955450219`.

### Linux / Android export

Linux:

- `Linux Desktop` debug export başarıyla üretildi.
- `build/linux/SeaCraft.x86_64` executable doğrulandı.
- `build/linux/SeaCraft.pck` doğrulandı.
- Export edilmiş Linux executable headless boot etti ve `SeaCraft bootstrap ready` marker'ı doğrulandı.

Android:

- `Android Debug` APK başarıyla üretildi.
- Package: `com.osmanyildirim.seacraft`, version `0.1.0`.
- ABI: yalnız `arm64-v8a` doğrulandı.
- APK zip integrity geçti.
- Export preset `permissions/internet=true`.
- APK manifest/aapt readback: `uses-permission: name='android.permission.INTERNET'` doğrulandı.

### Artifact ve hash readback

Actions artifact:

- ID: `14727373094`
- Ad: `SeaCraft-NET01-180282bdc00fca5d40af40943c1fe59d949d7f23`
- Workflow run: `44955450219`
- Artifact head SHA: `180282bdc00fca5d40af40943c1fe59d949d7f23`
- GitHub artifact size: `57070233` byte
- ZIP SHA-256 / upload digest: `613aece3fbc9ac80d965bdb0b24913e3b3560dfbddefe0c9a6623c8292ecfdb3`
- APK SHA-256: `47b0c8782e006eb15a2bda981dac137b21c0049ab0be61fef1ff3941b8c35bfd`
- Linux executable SHA-256: `1a291d3d15e4180b60b0af96cf6458f11fe143636d76575ddf1e23d1a3f24f2e`
- Linux PCK SHA-256: `9246bcb80635d113648dc9d48d8438c98d691a6f8b9f20ec819147798c5a8e83`

CI authenticated REST readback sonunda:

`NET01_ARTIFACT_READBACK_OK artifact_id=14727373094 rest_zip_sha256=613aece3fbc9ac80d965bdb0b24913e3b3560dfbddefe0c9a6623c8292ecfdb3 upload_digest=613aece3fbc9ac80d965bdb0b24913e3b3560dfbddefe0c9a6623c8292ecfdb3 sha=180282bdc00fca5d40af40943c1fe59d949d7f23`

Artifact ayrıca GitHub'dan yeniden indirildi. İndirilen ZIP'in SHA-256'sı aynı `613ae...` değeri verdi; içindeki `COMMIT_SHA.txt` exact kod SHA'yı verdi ve `sha256sum -c SHA256SUMS.txt` ile APK/Linux/PCK üçü de `OK` doğrulandı.

### Beyin kapanışı

Kanonik Beyin task:

`tasks/seacraft-net01-lan-session-host-authority-20261122.md`

Final readback:

- status: `done`
- revision: `2`
- completion_contract: `strict`
- exact_code_sha: `180282bdc00fca5d40af40943c1fe59d949d7f23`
- actions_success_run: `44955450219`
- artifact_id: `14727373094`
- net02: `not_started`
- strict doctor: `strict_issue_count=0`

Tek final receipt:

`receipts/bd9e04cdf8d72fea3a3ac245ae91e30b2e75aa644bfb17e072b6c6fb0fd20c61.md`

Beyin kapanış commit:

`858db66297fe1df62ded8cff941de788469c7590`

Task ve receipt kapanış commit'inden sonra GitHub'dan geri okunmuş; task `revision=2/status=done` ve receipt `event_id=seacraft-net01-close-180282bd` olarak doğrulanmıştır.

### Gerçek Android cihaz durumu

CI fiziksel cihaz değildir. Brief'in zorunlu gerçek cihaz alanları yürütülmedi:

- desktop host → Android client manual IPv4: `not_run`
- Android host → desktop client: `not_run`
- same Wi-Fi: `not_run`
- Wi-Fi disconnected offline boot: `not_run`
- invalid IP UX: `not_run`
- network loss: `not_run`
- background/foreground: `not_run`

Bu `not_run` alanları CI başarısı gibi gösterilmemiştir.

### Son kapı

NET-01 için offline boot, network boundary, canonical compatibility handshake, host-owned peer mapping, bounded client intents, spoof/replay/malformed/pre-handshake rejection, real ENet/RPC separate-process host authority, Android INTERNET permission, eski regresyonlar, orphan=0, Linux/Android export, exact artifact provenance/readback ve Beyin strict kapanışı doğrulandı.

NET-01 tamamlandı. NET-02 başlatılmadı.

---

## SOHBET-29 — SeaCraft NET-02 — Spawn, Snapshot ve Temel State Replikasyonu

### Kapanış durumu

- Durum: **DONE**
- Exact doğrulanmış kod SHA: `8e26aafe3acd3a23a02755b9c58ef719da10d20a`
- GitHub Actions: run `#171`, ID `44959034942`, sonuç **success**
- CI URL: https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/44959034942
- NET-03: `not_started`
- Gerçek Android cihaz testleri: `not_run` (CI fiziksel cihaz değildir)

NET-02 kapsamı, yalnız `main` üzerinde host-authoritative spawn/despawn, stable-ID player/NPC/monster/loot mirror yaşam döngüsü, bounded snapshot replication, host AOI, reliable combat/loot semantic events, client-side bounded interpolation ve client outcome-mutation rejection olarak tamamlandı. Prediction/reconciliation, reconnect/late-join recovery, discovery ve NET-03 kapsamı başlatılmadı.

### Uygulama mimarisi ve authority sınırı

Yeni/uzatılan ağ katmanı:

- `src/network/session_protocol.gd`: exact-shape primitive DTO validation; stable ID, snapshot/event sequence ve limit sözleşmeleri.
- `src/network/network_entity_proxy.gd`: presentation-only player/NPC/monster/loot mirror; authoritative target state ve en fazla 4 interpolation sample.
- `src/network/network_entity_registry.gd`: stable-ID + generation idempotency, authority/mirror registry, sector-aware spatial index.
- `src/network/network_replication_peer.gd`: host-only `MultiplayerSpawner`, snapshot üretimi, host AOI, semantic event replication ve telemetry.
- `src/network/session_rpc_bridge.gd`: snapshot için `@rpc("authority", "call_remote", "unreliable_ordered", 2)`; semantic combat/loot event için `@rpc("authority", "call_remote", "reliable", 1)`.
- `src/network/session_host.gd` / `session_client.gd`: NET-01 session boundary içine replication peer bağlandı.
- Simulation/data/persistence/presentation katmanları doğrudan peer/RPC/spawner bağımlılığı almadı; offline boot korunmuştur.

Client→host outcome mutation RPC eklenmedi. NET-01 allowlist dışındaki `spawn_entity`, `despawn_entity`, `set_hull`, `set_position`, `set_npc_state`, `create_loot`, `claim_result` benzeri sonuç mutasyonları reddedilir. CI guard, `src/network` dışında `MultiplayerSpawner` / `MultiplayerSynchronizer` kullanımını ve simulation katmanında multiplayer bağımlılığını engellemektedir.

### Stable-ID spawn/despawn ve snapshot sözleşmesi

- Replikasyon aktif-set üst sınırı: `96`.
- Snapshot entity üst sınırı: `64`.
- Snapshot encoded byte üst sınırı: `8192`.
- Snapshot cadence: her `3` authority physics tick.
- Client interpolation buffer: en fazla `4` sample.
- AOI radius: `600.0`.
- Snapshot row'ları stable-ID sırasına göre deterministik; duplicate/out-of-order row ve duplicate/stale snapshot sequence reddedilir/ignore edilir.
- Snapshot transport: channel 2, `unreliable_ordered`.
- Combat/loot semantic event transport: channel 1, `reliable`, monotonik event sequence + stable event ID ile idempotent.
- `MultiplayerSynchronizer` ile aynı state için ikinci truth source oluşturulmadı.

### Gerçek host + 2 client entegrasyonu

`tools/ci/run_net02_process_integration.sh` gerçek ayrı Godot process'leriyle aynı anda:

- 1 ENet host,
- client A → `player.alpha`,
- client B → `player.beta`

çalıştırdı ve `NET02_PROCESS_INTEGRATION_OK host=1 clients=2` ile tamamlandı.

Senaryoda doğrulananlar:

- baseline player/NPC/monster/loot stable-ID spawn seti her iki client'ta oluştu,
- host state update sonrası daha yeni snapshot client mirror'larına ulaştı,
- client A ve B host-authoritative konumlarına göre farklı AOI visible setleri aldı,
- `hull_damaged` combat semantic event iki client'a ulaştı,
- `drop_created` loot semantic event iki client'a ulaştı,
- `npc.late` gameplay sırasında host tarafından spawn edildi ve client'larda görüldü,
- `loot.shared` host tarafından despawn edildi ve iki client registry'sinden kalktı,
- client A sahte `spawn_entity` ve `set_hull` outcome intent'leri gönderdi; iki komut da unsupported intent olarak reddedildi ve host `npc.shared` state'i değişmeden kaldı,
- iki client clean exit yaptı, host stop-file sonrasında clean exit yaptı.

NET-02 verifier sonucu:

`NET02_VERIFIER_OK tests=11 real_process_rpc=1 host=1 clients=2 spawned=8 snapshots_sent=64 max_snapshot_bytes=1360`

Verifier'ın exact host telemetry kapıları ayrıca:

- `despawned=1`
- `snapshots_sent=64`
- observed max snapshot payload: `1360` byte < `8192` limit
- interval: `3` tick
- stale snapshot count: `0`
- interpolation cap: `4`
- combat event count >= `1`
- loot event count >= `1`
- rejected malicious client outcome mutations: `2`

değerlerini doğruladı.

### GUT ve regresyon kapıları

Exact kod SHA üzerinde GUT summary:

- Scripts: `21`
- Tests: `316`
- Passing Tests: `316`
- Asserts: `25875`
- Time: `38.65s`
- Sonuç: `All tests passed!`
- Failing test: `0`
- Parse/load/script fatal: `0`
- Nonzero orphan guard: geçti

NET-02'ye eklenen GUT testleri: `11`. Bunlar registry generation/idempotency, primitive bounded spawn DTO, host-only spawner sınırı, snapshot ordering/stale rejection, bounded interpolation, authority AOI, reliable/idempotent combat events, reliable/idempotent loot events, client outcome mutation denial, snapshot entity/byte budget ve offline/network boundary/channel sözleşmesini kapsar.

Exact run üzerinde eski kapılar da geçti:

- NET-01: `NET01_PROCESS_INTEGRATION_OK`
- NET-01 verifier: `NET01_VERIFIER_OK tests=10 real_process_rpc=1 host_authority=1`
- VS-01 manifest/değişmezlik kapısı: geçti
- VS-02: `38` test execution doğrulandı
- VS-03: `23` test execution doğrulandı
- VS-04: `25` test + integration/checkpoint/soak marker'ları geçti
- CORE-01: `6` test
- CORE-02: `8` test; target tag, harpoon, duplicate spawn/claim ve persistence marker'ları geçti
- CORE-03: `10` test; transition/rebind/safe-zone/hazard/map/persistence kapıları geçti
- CORE-04: `10` test; migration/content registry/recovery/malformed/large-roundtrip kapıları geçti; large roundtrip `entity_count=512`, `encoded_bytes=376584`
- AI-01: `10` test
- AI-02: `11` test; `npc=20 decisions=480 max_per_tick=2 tactical=480`
- AI-03: `10` test; `fleets=6 ships=24 max_formation=4 max_path=4`
- AI-04: `10` test; `world_entities=100 near=20 mid=30 far=50 max_near=8 max_mid=6 max_far=8 max_path=4 max_spawn=4 starvation=0`

### CI düzeltme zinciri

NET-02 kod zincirinde dört exact push run oluştu:

| Run | Exact SHA | Sonuç | Kök neden / düzeltme |
| --- | --- | --- | --- |
| `44958414762` / #168 | `1e0cc10007f7d987d4153cd181d890c9553dd6d8` | failed | Godot 4.7 `var_to_bytes` API'si tek argümanlı; çağrı 4.7 API'ye düzeltildi. |
| `44958640566` / #169 | `13966ba71980c261a451e61ae0fc8ccc55c921db` | failed | Snapshot test duplicate-sequence expectation ve numeric-ending event stable-ID sözleşmesi düzeltildi. |
| `44958815594` / #170 | `1883e8b05febc07c1be725302212d651bc3b59d3` | failed | Gerçek process harness'te untyped literal → `Array[String]` runtime assignment hatası giderildi. |
| `44959034942` / #171 | `8e26aafe3acd3a23a02755b9c58ef719da10d20a` | **success** | Tüm GUT, host+2-client, regression, export, artifact ve readback kapıları geçti. |

Uygulama commit'i: `1e0cc10007f7d987d4153cd181d890c9553dd6d8`.

Düzeltme commit'leri:

- `13966ba71980c261a451e61ae0fc8ccc55c921db`
- `1883e8b05febc07c1be725302212d651bc3b59d3`
- `8e26aafe3acd3a23a02755b9c58ef719da10d20a`

### Linux / Android export

Linux debug export başarıyla üretildi:

- `linux/SeaCraft.x86_64`
- `linux/SeaCraft.pck`

Android debug export başarıyla üretildi:

- `android/SeaCraft-debug.apk`
- APK içinde `android.permission.INTERNET` aapt/readback ile doğrulandı.
- CI log: `Adding permission android.permission.INTERNET`
- CI readback: `uses-permission: name='android.permission.INTERNET'`

Fiziksel Android cihaz / gerçek Wi-Fi cihaz matrisi CI'da çalıştırılmadı ve başarı gibi gösterilmedi: `not_run`.

### Artifact provenance ve bağımsız readback

Artifact:

- Ad: `SeaCraft-NET02-8e26aafe3acd3a23a02755b9c58ef719da10d20a`
- ID: `14728589326`
- Boyut: `57132619` byte
- Workflow run: `44959034942`
- Artifact head SHA: `8e26aafe3acd3a23a02755b9c58ef719da10d20a`
- GitHub artifact ZIP digest: `3970b606f8a4bbb1177ea6c8eec078607e34e136016ed912bec15f5fbd734a29`
- Artifact URL: https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/44959034942/artifacts/14728589326

CI authenticated REST readback exact marker:

`NET02_ARTIFACT_READBACK_OK artifact_id=14728589326 rest_zip_sha256=3970b606f8a4bbb1177ea6c8eec078607e34e136016ed912bec15f5fbd734a29 upload_digest=3970b606f8a4bbb1177ea6c8eec078607e34e136016ed912bec15f5fbd734a29 sha=8e26aafe3acd3a23a02755b9c58ef719da10d20a`

Artifact ayrıca GitHub connector üzerinden yeniden indirildi ve bağımsız doğrulandı:

- ZIP SHA-256: `3970b606f8a4bbb1177ea6c8eec078607e34e136016ed912bec15f5fbd734a29` — GitHub upload digest ile birebir.
- `COMMIT_SHA.txt`: `8e26aafe3acd3a23a02755b9c58ef719da10d20a`
- `sha256sum -c SHA256SUMS.txt`: APK/Linux executable/Linux PCK üçü de `OK`.

Artifact iç hashleri:

- APK: `d823f3663aeb9061c2fdfe956b128162b54fe55584eba44eabdd21695b737c5c`
- Linux executable: `1a291d3d15e4180b60b0af96cf6458f11fe143636d76575ddf1e23d1a3f24f2e`
- Linux PCK: `fd14f1a75300e3a17b0c7ef6a224116520c7231ef01c367b1231686886630c28`

### Beyin strict kapanışı

Kanonik Avenox Beyin task:

`tasks/seacraft-net02-spawn-snapshot-replication-20261122.md`

GitHub final readback:

- status: `done`
- revision: `2`
- completion_contract: `strict`
- exact code SHA: `8e26aafe3acd3a23a02755b9c58ef719da10d20a`
- CI run: `44959034942` / #171 / `success`
- GUT: `316/316`
- real process: `host=1 clients=2`
- artifact ID: `14728589326`
- artifact SHA-256: `3970b606f8a4bbb1177ea6c8eec078607e34e136016ed912bec15f5fbd734a29`
- Android INTERNET: `verified`
- physical Android device tests: `not_run`
- NET-03: `not_started`

Tek kapanış receipt:

`receipts/122f3bc0215bf960a5c98789f9ec9b97ffbe02f2171052bd1b1265e746421f90.md`

Receipt event ID:

`seacraft-net02-complete-8e26aafe3acd3a23a02755b9c58ef719da10d20a`

Beyin kapanış commit:

`c9a43ee8a878e7aea6b3cb1fb5ca37013c775b85`

Task ve receipt bu commit sonrasında `agy-vault/main` üzerinden geri okundu. Resmî Beyin motoru doctor sonucu `task_completion.strict_issue_count=0`, receipt gap `0`, dead instruction ref `0` verdi. Doctor'ın vault-root `.obsidian` uyarısı operasyonel UI/boundary notudur; strict task kapanışına engel değildir.

### Son kapı

NET-02 için host-only stable-ID spawn/despawn, primitive bounded DTO, custom ordered snapshot truth source, host-owned AOI, semantic reliable event replication, bounded interpolation, malicious client outcome-mutation rejection, gerçek ayrı-process `1 host + 2 client` ENet/RPC entegrasyonu, NET-01 + VS/CORE/AI regresyonları, offline/network boundary, Linux/Android export, Android INTERNET permission, exact artifact provenance/readback ve Avenox Beyin strict kapanışı doğrulandı.

**NET-02 tamamlandı. NET-03 başlatılmadı.**

## SOHBET-30 — SeaCraft NET-03 — Vertical Slice LAN Parity

**Sonuç (2026-11-22): tamamlandı.** Kanonik kod SHA: [`f0cd18727870d6d49b961c758e49660e53770479`](https://github.com/TheOsmanYILDIRIM/SeaCraft/commit/f0cd18727870d6d49b961c758e49660e53770479). Godot 4.7.2-stable CI: [#174, run 44966391971, success](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/44966391971) ([job 137036272753](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/44966391971/job/137036272753)). İki kod commit'i ve iki Actions koşusu: uygulama `3b3758508fe1432da459e467f47cc51818441912` üzerindeki [#173](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/44966249519) loot yaklaşımında tam konuma varış zaman aşımıyla durdu. Düzeltme, client rotasını loot merkezine değil gerçek pickup yarıçapı içine yönlendirdi ve host konumunu doğruladı. Başarılı #174 bu exact düzeltme SHA'sını çalıştırdı.

**Test ve gerçek süreç kanıtı.** GUT: **325/325**, önceki 316 + 9 NET-03; orphan **0**. `NET03_PROCESS_INTEGRATION_OK host=1 clients=1 cases=2` ayrı Godot süreçleri ve gerçek ENet/RPC ile tam dikey kesit ile aktif çatışmada kopuşu doğruladı. `NET03_VERIFIER_OK tests=9 host=1 clients=1 cases=2` offline VS-04, host ve client digest'lerinin eşitliğini doğruladı: SHA-256 `2c9cea2fb6cad5e2ca5226d7a1f6e30fb944f594413c2572943ca04a31d22693`. VS-04'ün 25 testi ve replay/soak sinyalleri geçti. NET-01: 10 test ve gerçek ENet; NET-02: 11 test ve 1 host + 2 client; AI/CORE/VS regresyon kapıları geçti. Offline headless açılış ve Linux export açılışı `SeaCraft bootstrap ready` ile geçti.

**Oynanış ve yetki.** Client hareketi host ShipMotor tarafından uygulandı; hedef CombatAuthority tarafından seçildi, ateş gerçek range/reload/broadside kontrollerinden geçti. Oyuncu ve heading hosttan türetildi. Sabit adımlarda yalnız host AI karar verdi; client aynı `PATROL → ALERT → RETREAT → REPAIR → RESUME` zincirini ve host hull/alive durumunu replika üzerinden gördü. Seed `424242` ile 5 kabul edilen isabet, 1 batış, 1 drop `drop.entity_vs02_sc03.seq_14` ve 1 claim sonucu **2 salvage** elde edildi. Loot proxy claim sonrası kaldırıldı. Tekrar sequence ve tekrar claim reddedildi; ikinci ödül yok. AOI dışı hedef/loot, actor ve heading sahteciliği ve yetkisiz hull/loot/envanter mutasyonları reddedildi; otoriter durum değişmedi. İlk gerçek hasar sonrası client ayrıldığında peer eşlemesi, state ve sequence temizlendi; host AI ilerledi, mevcut gemi, hasar ve loot ledger korundu, çift ödül veya batış oluşmadı.

**Export ve artifact.** Linux executable/PCK ve Android debug APK oluşturuldu; APK `arm64-v8a` ve `android.permission.INTERNET` doğrulandı. [`SeaCraft-NET03-f0cd18727870d6d49b961c758e49660e53770479`](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/44966391971/artifacts/14731951086), artifact ID **14731951086**. CI `NET03_ARTIFACT_READBACK_OK` ile authenticated ZIP'i geri indirdi; yükleme ve ZIP hash'i eşleşti. Bağlayıcı üzerinden ayrıca indirilen ZIP, `COMMIT_SHA.txt`, `SHA256SUMS.txt` ve üç dosya bağımsız olarak doğrulandı. Fiziksel Android Wi-Fi (cihaz/masaüstü kombinasyonları, 10+ dakika, combat/loot, jitter ve interpolation) **not_run**; CI bir fiziksel cihaz testi değildir.

| İçerik | SHA-256 |
| --- | --- |
| ZIP | `3c8fe99b0946fe46bf8d829093cc84f1d9ae60a3a97cfbd9aa04b49fde864e1d` |
| Android APK | `486f06f23087df366ef4c539e32b2d7b90b8b9bceea7c1ba60b1cfc88206dd25` |
| Linux executable | `1a291d3d15e4180b60b0af96cf6458f11fe143636d76575ddf1e23d1a3f24f2e` |
| Linux PCK | `f47d44ca43cd4649415520c188f7df70c4baa3e7dca8f135e45fa9d19043c97f` |

**Beyin.** [Tek kanonik task](https://github.com/TheOsmanYILDIRIM/agy-vault/blob/9454df4cba6eacd02e824ca62e39b4d5e2f0b00c/tasks/seacraft-net03-vertical-slice-lan-parity-20261122.md) `done` revizyon 2; [tek receipt](https://github.com/TheOsmanYILDIRIM/agy-vault/blob/9454df4cba6eacd02e824ca62e39b4d5e2f0b00c/receipts/17cca67ee6a7f677f93d10f87d190fb5424d6208d89e65a5e8d439e01680ae25.md) exact kod SHA, Actions ve artifact kanıtıyla aynı Beyin commit'inden geri okundu. DirectSync strict doctor sorun sayısı 0. **NET-04: not_started.**

## SOHBET-31 — SeaCraft NET-04 — Discovery, Reconnect, Late Join ve LAN Transaction Hardening

**Sonuç (2026-11-22): tamamlandı.** Exact kod SHA: `ba5fd180b9e359b0dcc146b58c52254fe537f317`. Godot 4.7.2-stable CI: [#196, run 45007820093, success](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45007820093). SOHBET-31 handoff sonrasındaki kapanış düzeltme zinciri 6 code/CI commit'inden oluştu: `8b491dc3908cafdf8393d0b3b7c7f5221e7f9ff1`, `6f008f0e2398da3500ba552639d409dfb131fa4c`, `ed7318314eb9f5339bf557a4874b60ed5f446130`, `93c24ff73686fd60db6fc39652f8a682f1cd6195`, `3a4cac13ffbc7c6be1fe042fcd5f68746c768fda`, `ba5fd180b9e359b0dcc146b58c52254fe537f317`. Handoff kapanış koşuları #190–#196 içinde final #196 exact SHA üzerinde geçti; daha eski NET-04 geliştirmesi file-by-file incremental commitlerle hazırlanmıştı.

### Test ve regresyon kanıtı

Exact SHA üzerinde GUT sonucu **339/339**, **28018 assert**. Parse/load/script failure yok; failing test yok; nonzero orphan guard geçti. NET-04 verifier: `NET04_VERIFIER_OK unit=13 fuzz=2000 discovery_process=1 reconnect=1 late_join=1 lost_ack=1`.

Eski ağ/regresyon kapıları da aynı run üzerinde geçti:

- NET-01: `NET01_PROCESS_INTEGRATION_OK`; verifier `tests=10 real_process_rpc=1 host_authority=1`.
- NET-02: `NET02_PROCESS_INTEGRATION_OK host=1 clients=2`; verifier `tests=11 real_process_rpc=1 host=1 clients=2 spawned=8 snapshots_sent=64 max_snapshot_bytes=1360`.
- NET-03: `NET03_PROCESS_INTEGRATION_OK host=1 clients=1 cases=2`; verifier `tests=9 host=1 clients=1 cases=2`; semantic SHA-256 `2c9cea2fb6cad5e2ca5226d7a1f6e30fb944f594413c2572943ca04a31d22693`.
- VS-04 scenario/checkpoint/soak kapıları; CORE-01..04; AI-01..04 doğrulama marker ve verifier kapıları geçti.

### NET-04 discovery, reconnect, late join ve transaction

Gerçek ayrı Godot process senaryosu 1 host + client A + client B ile tamamlandı:

- UDP discovery gerçek `PacketPeerUDP` üzerinden, game ENet portundan ayrı discovery portunda çalıştı.
- Client A discovery ile hostu buldu, baseline aldı, lost-ACK simülasyonunda koptu ve yeni peer üzerinden aynı `entity.player` kimliğine resume oldu; `next_sequence=2`.
- Reconnect rezervasyonu ve token sözleşmesi korundu; unit kontratı 128-bit entropy ve 30000 ms grace doğruladı. Token rotation / eski-token rejection ve protocol mismatch v3 deterministic kaldı.
- Client B late join sırasında current authoritative baseline aldı; `current_x=321.0` ve daha önce claim edilmiş loot baseline'da geri gelmedi.
- Lost-ACK transaction retry ikinci ödül üretmedi: `NET04_TRANSACTION_IDEMPOTENCY_OK transaction=txn.net04.lost_ack quantity=2`.
- Host transaction ledger `entries=1 commit_sequence=1 reservations=1` ile temiz kapandı; transaction persistence round-trip, same-ID conflict ve duplicate claim korumaları unit testlerinde geçti.
- Discovery fuzz sabit seed ile 2000 paket; TTL `2500 ms`, visible cache üst sınırı `16`; malformed/bounded parser, permission fallback, offline boot ve manual IPv4 sözleşmeleri geçti.

Reconnect failureının kök nedeni iki parçalıydı: transport kopuşunda eski mirror handle'ları serbest bırakıldığı halde registry stale handle tutabiliyordu; full session reset sonrasında generation geçmişi de korununca authoritative baseline'daki geçerli aynı generation stale sayılıp spawn reddediliyordu. Registry artık freed proxy'yi cast etmeden doğruluyor; disconnect full replication reset yapıyor; full session clear generation geçmişini de sıfırlıyor. Normal despawn generation koruması değişmedi. NET-03 gerçek-process önkoşulunda loot transiti de production pickup-radius sözleşmesiyle hizalandı.

### Android / Linux export

Linux debug export üretildi:

- `linux/SeaCraft.x86_64`
- `linux/SeaCraft.pck`
- export edilen Linux binary headless açılışı `SeaCraft bootstrap ready` ile geçti.

Android debug export üretildi:

- `android/SeaCraft-debug.apk`
- package: `com.osmanyildirim.seacraft`
- `targetSdkVersion: 37`
- native ABI: yalnız `arm64-v8a`
- `android.permission.INTERNET`
- `android.permission.ACCESS_LOCAL_NETWORK`

Godot resmi 4.7.2 export template'i pinned SHA ile indirildi; headless build-template installer hang'i yerine aynı resmi `android_source.zip` deterministik olarak kuruldu. Android 17 platformu SDK manager'da yayınlanan `platforms;android-37.0` preview paketi üzerinden kuruldu ve integer compileSdk tüketicileri için `android-37` aliası doğrulandı.

Fiziksel Android 17 permission allow/deny/revoke, desktop↔Android aynı Wi-Fi, Android host, guest/AP isolation, background→foreground reconnect ve 10+ dakika cihaz LAN oturumu bu CI ortamında çalıştırılmadı: **not_run**.

### Artifact provenance ve readback

Artifact:

- Ad: `SeaCraft-NET04-ba5fd180b9e359b0dcc146b58c52254fe537f317`
- ID: `14748254309`
- Boyut: `58669047` byte
- ZIP SHA-256: `a47363f1c63d9024ce69a7f53710278acf6a1d0d94d7bf2bf0e6b6f56835968e`
- URL: https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45007820093/artifacts/14748254309

CI authenticated REST readback:

`NET04_ARTIFACT_READBACK_OK artifact_id=14748254309 rest_zip_sha256=a47363f1c63d9024ce69a7f53710278acf6a1d0d94d7bf2bf0e6b6f56835968e upload_digest=a47363f1c63d9024ce69a7f53710278acf6a1d0d94d7bf2bf0e6b6f56835968e sha=ba5fd180b9e359b0dcc146b58c52254fe537f317`

Artifact ayrıca GitHub connector ile yeniden indirildi; ZIP digest, `COMMIT_SHA.txt` ve `SHA256SUMS.txt` bağımsız geri okumada doğrulandı. Üç payload da `OK`:

| İçerik | SHA-256 |
| --- | --- |
| Android APK | `876382eed8ee1854c1ac630fb48980112bccfca2bb4d6273e7f59700d6e34f29` |
| Linux executable | `1a291d3d15e4180b60b0af96cf6458f11fe143636d76575ddf1e23d1a3f24f2e` |
| Linux PCK | `80c9ec9860fb6294283240c5fbfbf847f8854854e5f5788084322b3d9962b9f1` |

### Avenox Beyin strict kapanışı

Kanonik task:

`tasks/seacraft-net04-lan-hardening-20261122.md`

Beyin `agy-vault/main` readback:

- status: `done`
- revision: `2`
- evidence: `notes/seacraft-net04-verification-20261122.md`
- receipt: `receipts/d6891c3597216f06884b1a2d5dddf454b20d7e8faa24fd54fdd409d49012ddf7.md`
- receipt event ID: `seacraft-net04-close-ba5fd180b9e359b0dcc146b58c52254fe537f317`
- Beyin kapanış commit'i: `2bcb04c6d67b01f633537d67a6b78b7b14f14bab`

Task, evidence ve tek receipt aynı kapanış commit'i sonrasında uzak `agy-vault/main` üzerinden geri okundu. Yeni NET-04 task/receipt kopyası oluşturulmadı.

NET-04 ile doğrulanmış plan ilerlemesi **22/35** oldu. **NET-04 tamamlandı. WAVE 6 başlatılmadı.**


## SOHBET-32 — SeaCraft PRG-01 — Inventory, Equipment, Crew, Pet/Companion ve Preset

**Sonuç (2026-11-22): uygulama ve teslim kapıları doğrulandı; Beyin strict kapanışı bu oturumun son kanonik adımıdır.** Exact kod SHA: `a3344909e489adc93800f6591238eb7102561542`. Godot `4.7.2-stable` CI: run `45015026436` — **success**; status context `seacraft-prg01-evidence=success`.

### PRG-01 uygulama sınırı

- Loot item miktarı ikinci authoritative sözlük olmaktan çıkarıldı; `LootAuthority` item miktarı için tek `InventoryState` gerçeğini kullanıyor.
- Bounded stack/slot/weight/container kuralları, atomik transfer, equip/unequip, crew/trainer/pet slotları, ship/pet gem socket progression ve preset apply tek progression state içinde kuruldu.
- Equipment/gem stat etkileri mevcut tek `StatModifierPipeline` üzerinden uygulanıyor; ikinci modifier engine eklenmedi.
- Duplicate transaction ID aynı actor/payload için cached terminal result; farklı payload conflict. Progression ledger snapshot/restore sonrası idempotency korunuyor.
- LAN wire contract progression intentleri için protocol v4'e yükseltildi; transfer/equip/unequip/socket/preset mutasyonları host tarafından doğrulanıyor. NET-04 transaction ledger reuse edildi.
- Minimal touch presentation authority yazmıyor; tap/select intent üretimi, 48 px minimum target ve fontScale 1.3 sözleşmesi eklendi.
- GLoot eklenmedi; custom pure-data model yeterli olduğu için addon authoritative/network truth yapılmadı.
- Checkpoint akışında progression snapshot/restore canlı save state'e bağlandı.

### Test / regresyon / CI

Final run `45015026436` exact SHA `a3344909e489adc93800f6591238eb7102561542` üzerinde GUT ve bütün mevcut VS/CORE/AI/NET regresyonları geçti. PRG-01 verifier; stack/schema, transfer rollback, equipment slotları, socket progression, modifier pipeline, preset atomicity, transaction persistence/idempotency, LAN authority, tek inventory truth ve touch UI marker'larını doğruladı.

İlk iki düzeltme koşusundaki hatalar kapatıldı: legacy content registry uyumluluğu korundu; NET-04 protocol expectation v4 ile hizalandı; socket stable ID formatı düzeltildi. Final exact run'da parse/load/test/orphan failure yoktur.

### Linux / Android export

Linux debug export:
- `linux/SeaCraft.x86_64`
- `linux/SeaCraft.pck`

Android debug export:
- `android/SeaCraft-debug.apk`
- arm64-v8a / targetSdk 37 sözleşmesi ve LAN izin kapıları mevcut CI/export zincirinde korundu.

Fiziksel Android cihazda touch/save/LAN retry matrisi: **not_run**. CI gerçek cihaz kanıtı olarak gösterilmedi.

### Artifact provenance ve authenticated readback

Artifact:
- Ad: `SeaCraft-PRG01-a3344909e489adc93800f6591238eb7102561542`
- ID: `14750439866`
- Boyut: `58711191` byte
- Workflow run: `45015026436`
- Artifact head SHA: `a3344909e489adc93800f6591238eb7102561542`
- ZIP SHA-256 / upload digest: `7ca5d49332f13afacb73b15952968171b993cf9b024a30a7f51fa91e9228f304`
- URL: https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45015026436/artifacts/14750439866

CI authenticated REST readback marker:

`PRG01_ARTIFACT_READBACK_OK artifact_id=14750439866 rest_zip_sha256=7ca5d49332f13afacb73b15952968171b993cf9b024a30a7f51fa91e9228f304 upload_digest=7ca5d49332f13afacb73b15952968171b993cf9b024a30a7f51fa91e9228f304 sha=a3344909e489adc93800f6591238eb7102561542`

Artifact GitHub connector üzerinden ayrıca indirildi. ZIP SHA-256 aynı digest ile eşleşti; `COMMIT_SHA.txt` exact kod SHA'yı taşıyor ve `SHA256SUMS.txt` üç payload için doğrulandı:

| İçerik | SHA-256 |
| --- | --- |
| Android APK | `08092b9fd9e7359a016135ccdd842afb1c8dc8da64bba564b740c77383529971` |
| Linux executable | `1a291d3d15e4180b60b0af96cf6458f11fe143636d76575ddf1e23d1a3f24f2e` |
| Linux PCK | `ad6b5f70d2b6cecfbf2103f229186e0446eb79a2f1ba657ba3e4107d10072882` |

### Avenox Beyin strict kapanışı

Kanonik görev: `tasks/seacraft-prg01-inventory-equipment-crew-pet-preset-20261122.md`.

Uzak `TheOsmanYILDIRIM/agy-vault/main` readback:
- status: `done`
- revision: `2`
- completion_contract: `strict`
- evidence_refs: `receipts/1db2c7592ce3f81f80a91e751c06857d9162724fae4bff8d3ca7e865dc5efddc.md`
- receipt event ID: `seacraft-prg01-close-a3344909e489adc93800f6591238eb7102561542`
- Beyin kapanış commit: `8c811e1afe2000424a9bf15940db75f54d579be3`

Resmî Avenox Beyin v3.12.0 motoru ile üretilen task-update ve tek receipt GitHub'a tek kapanış commit'iyle yazıldı; task ve receipt uzak `agy-vault/main` üzerinden geri okundu. Local DirectSync doctor: `task_completion.strict_issue_count=0`, potential missing receipt `0`, dead instruction ref `0`. Geçici DirectSync vault'undaki `.obsidian` boundary uyarısı cihaz/Obsidian UI durumudur; source/task kapanışını geçersiz kılmaz.

**PRG-01 tamamlandı. PRG-02 başlatılmadı.**

## SOHBET-33 — SeaCraft PRG-02 — Crafting, Reclamation, Ship Upgrade ve Cores/Trophies

**Sonuç (2026-11-22): tamamlandı ve doğrulandı.** Exact kod SHA: [`d6ddfb014ee83ef9826563441453152d15d7d789`](https://github.com/TheOsmanYILDIRIM/SeaCraft/commit/d6ddfb014ee83ef9826563441453152d15d7d789). Godot `4.7.2-stable` final CI: [run 45019833696 — success](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45019833696), job `137200052654`; commit status context `seacraft-prg02-evidence=success`.

Final exact kod SHA'dan sonra kullanıcı tarafından `8e185686cbaa6a297976b544122b799ae03e977c` commit'iyle yalnız `SC06_PERCIN_HATTI_ALIGNED_FINAL.zip` eklendi. Bu görev dışı upload korunmuş, PRG-02 exact CI/artifact kanıtının SHA'sı değiştirilmemiştir.

### Uygulanan PRG-02 sınırı

- `RecipeDefinition`, `SalvageTable`, `ShipUpgradeDefinition` ve `TrophyDefinition` stable-ID, bounded ve deterministic validation sözleşmeleriyle eklendi.
- Craft consume + output grant tek atomik inventory delta sınırında çalışır; missing input, count bound, output capacity ve overflow reddinde kısmi mutation bırakmaz.
- PRG-01 transaction cache/ledger modeli reuse edildi; same transaction + same payload cached result verir, conflict reddedilir, lost-ACK retry ikinci consume/grant üretmez.
- Salvage mevcut `SeedStreams.STREAM_LOOT` üzerinden deterministic yürür; reject/capacity rollback RNG state'ini geri alır, save/load sonrası RNG devamlılığı korunur.
- Ship upgrade progression cycle/missing prerequisite/tier regression kontrolleri olan veri odaklı DAG'dir; cost consume, unlock ve core slot etkileri atomik uygulanır.
- Core slot insert/remove/replace type compatibility, unique core policy, capacity rollback ve modifier source guard ile uygulanır; stat etkileri yalnız mevcut `StatModifierPipeline` üzerinden geçer.
- Trophy/perk unlock event ledger idempotenttir; prerequisite bypass ve ikinci reward engellenir.
- Progression persistence `InventoryState` v2 alt-sözleşmesine yükseltildi; PRG-01 v1 progression state geriye uyumlu migrate edilir. Runtime Node/Resource save/network sınırına taşınmaz.
- LAN wire sözleşmesi PRG-02 mutation intentleri için protocol v5'e yükseltildi. Client yalnız primitive stable ID/count/slot intenti yollar; output, RNG veya unlock sonucunu seçemez. `SessionHost` mevcut host transaction ledger üzerinden authoritative kalır.
- `ProgressionPanel` yalnız intent üretir; mevcut minimum 48 px touch target ve font scale 1.3 korunur. PRG-03 XP/skill/rank sistemi uygulanmadı.

### Test, hata düzeltme ve regresyon

Final run'da GUT sonucu **359/359 passing**. `PRG02_VERIFIER_OK tests=10 craft_atomic=1 salvage_rng=1 upgrade_dag=1 cores=1 trophies=1 persistence=1 lan=1 touch=1`.

İki ara doğrulama hatası finalden önce kapatıldı: run `45019502751` test fixture typed-array ve stable slot ID sorununu; run `45019690044` ise nested terminal craft sonucunun `HostTransactionLedger` primitive/depth persistence sınırını aşmasını görünür kıldı. Fixture/stable ID düzeltildi ve craft/trophy terminal result DTO'ları deterministic primitive-flat hale getirildi. Final run `45019833696` aynı exact kod SHA üzerinde yeşildir.

Aynı final run'da eski ağ/regresyon kapıları da geçti:

- `NET01_VERIFIER_OK tests=10 real_process_rpc=1 host_authority=1`
- `NET02_VERIFIER_OK tests=11 real_process_rpc=1 host=1 clients=2 spawned=8 snapshots_sent=64 max_snapshot_bytes=1360`
- `NET03_VERIFIER_OK tests=9 host=1 clients=1 cases=2`
- `NET04_VERIFIER_OK unit=13 fuzz=2000 discovery_process=1 reconnect=1 late_join=1 lost_ack=1`
- mevcut VS/CORE/AI doğrulama ve offline/network boundary kapıları geçti.

### Linux / Android export

Linux debug export başarıyla üretildi:

- `linux/SeaCraft.x86_64`
- `linux/SeaCraft.pck`

Android debug export başarıyla üretildi:

- `android/SeaCraft-debug.apk`
- package: `com.osmanyildirim.seacraft`
- targetSdk: `37`
- native ABI: `arm64-v8a`
- `android.permission.INTERNET`
- `android.permission.ACCESS_LOCAL_NETWORK`

Fiziksel Android cihaz / gerçek Wi-Fi touch-save-LAN matrisi bu ortamda çalıştırılmadı ve başarı gibi gösterilmedi: **not_run**.

### Artifact provenance ve bağımsız readback

Artifact:

- Ad: `SeaCraft-PRG02-d6ddfb014ee83ef9826563441453152d15d7d789`
- ID: `14753292824`
- Boyut: `58782265` byte
- URL: https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45019833696/artifacts/14753292824
- ZIP / upload digest SHA-256: `ef205786cd23ee69910235446a63e0a0571ae8c64096a1b23b7e1c2e0015f5a8`

CI authenticated REST readback marker:

`PRG02_ARTIFACT_READBACK_OK artifact_id=14753292824 rest_zip_sha256=ef205786cd23ee69910235446a63e0a0571ae8c64096a1b23b7e1c2e0015f5a8 upload_digest=ef205786cd23ee69910235446a63e0a0571ae8c64096a1b23b7e1c2e0015f5a8 sha=d6ddfb014ee83ef9826563441453152d15d7d789`

Artifact ayrıca GitHub connector üzerinden authenticated olarak yeniden indirildi. ZIP SHA-256 upload digest ile birebir eşleşti; `COMMIT_SHA.txt` exact kod SHA'yı taşıdı ve `sha256sum -c SHA256SUMS.txt` üç payload için `OK` verdi.

| İçerik | SHA-256 |
| --- | --- |
| Android APK | `c1ff24deed7e05ed745c67790759dcf6cdb69249eb965dfb3d747f480b97eb27` |
| Linux executable | `1a291d3d15e4180b60b0af96cf6458f11fe143636d76575ddf1e23d1a3f24f2e` |
| Linux PCK | `fd970672770be5aacaa2192ee605308687d474e295794a2d3ae6587b31107209` |

### Avenox Beyin strict kapanışı

Resmî Avenox Beyin v3.12.0 Project ZIP'i kullanıldı; ZIP SHA-256: `d8dbf97a38a50046d3f48205ae08ff65364b92292999fef611f882839d6e9696`.

Kanonik task:

`tasks/seacraft-prg02-crafting-reclamation-ship-upgrade-cores-trophies-20261122.md`

Uzak `TheOsmanYILDIRIM/agy-vault/main` readback:

- status: `done`
- revision: `2`
- completion_contract: `strict`
- evidence_refs: `receipts/0f69a7954949a09d7b5131e46b0efbf1f24d389fee5c18b84e9c6b79077adce2.md`
- receipt event ID: `seacraft-prg02-close-d6ddfb014ee83ef9826563441453152d15d7d789`
- Beyin kapanış commit: `29cebab9b10cd7164d9366c75c647a3d77d71e67`

Resmî motorun local DirectSync doctor sonucunda `task_completion.strict_issue_count=0`, potential missing receipt `0`, dead instruction ref `0` doğrulandı. Geçici DirectSync vault'undaki `.obsidian` boundary uyarısı UI/yerel vault sınırı notudur; strict task kapanışına engel değildir. Motorla üretilen task revision 2 ve tek receipt aynı CAS kapanış commit'i sonrasında uzak `agy-vault/main` üzerinden geri okundu.

### Son kapı

PRG-02 craft/reclamation, deterministic salvage RNG, ship upgrade DAG, core/trophy progression, persistence migration, host-authoritative LAN intents, Linux/Android export, exact artifact provenance/readback ve Avenox Beyin strict kapanışı doğrulandı.

**PRG-02 tamamlandı. PRG-03 başlatılmadı ve `not_started` olarak kalır.**

## SOHBET-34 — SeaCraft PRG-03 — XP, Skill Tree, Rank ve Local Challenge Meta

**Sonuç (2026-11-22): tamamlandı ve doğrulandı.** Exact kod SHA: [`2d8e32e6ff84ca3a8e4b23aa0e52073dc333b584`](https://github.com/TheOsmanYILDIRIM/SeaCraft/commit/2d8e32e6ff84ca3a8e4b23aa0e52073dc333b584). Godot `4.7.2-stable` final CI: [run 45034255905 — success](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45034255905), job `137244362873`; commit status context `seacraft-prg03-evidence=success`.

### Uygulanan PRG-03 sınırı

- XP tek authoritative progression ledger içinde event-ID idempotency, conflict ve overflow guard ile uygulanır; client XP miktarı/outcome seçemez.
- Rank/level görünümü XP thresholdlarından deterministic türetilir; redundant authoritative rank truth eklenmez. Skill point grantleri thresholdlardan türetilir ve spend state ile hesaplanır.
- Stable-ID skill DAG; missing prerequisite/cycle/tier validation, atomik spend, lost-ACK idempotency ve full respec/refund ile kuruldu.
- License/test/milestone/rank progression gate API primitive-safe ve host-authoritative olarak eklendi; PRG-04 quest içeriği başlatılmadı.
- Local challenge meta version-key reset, deterministic counter progress ve idempotent inventory/XP reward ile offline çalışır.
- Rank/skill stat etkileri yalnız mevcut `StatModifierPipeline` üzerinden akar; ikinci modifier engine kurulmadı.
- Progression persistence `InventoryState` v3'e yükseltildi; v1/v2 migration ve canonical JSON integer readback uyumu eklendi.
- LAN wire contract protocol v6'ya yükseltildi. Skill spend/respec/gate/challenge bounded intentleri host transaction ledger üzerinden authoritative kalır; doğrudan XP-grant network intenti yoktur.
- Touch progression panel node seçimi, spend/respec/gate/challenge intentleri ve bounded zoom/pan sözleşmesiyle genişletildi; mevcut 48 px minimum touch target ve fontScale 1.3 korunur.

### Test / regresyon / CI

Final exact run `45034255905` üzerinde GUT sonucu **369/369 passing**, **28,758 assert** ve unexpected failing/ignored parse koşulu olmadan tamamlandı.

PRG-03 execution verifier:

`PRG03_VERIFIER_OK tests=10 xp=1 rank=1 skill_dag=1 spend_respec=1 gates=1 challenges=1 persistence=1 lan=1 touch=1 offline=1`

Aynı run'da PRG-01/02 verifier'ları ile mevcut VS/CORE/AI/NET regresyon ve offline/network separation kapıları da geçti. Ara doğrulamalarda görülen typed reward delta, JSON integer migration ve stable event/transaction ID hataları düzeltilip exact final commit üzerinde yeniden doğrulandı.

### Linux / Android export

Linux debug export başarıyla üretildi:
- `linux/SeaCraft.x86_64`
- `linux/SeaCraft.pck`

Android debug export başarıyla üretildi:
- `android/SeaCraft-debug.apk`
- package/ABI/target ve LAN permission sözleşmeleri mevcut CI zincirinde korundu.

Fiziksel Android cihazda skill-tree touch/save/LAN matrisi bu ortamda çalıştırılmadı ve başarı gibi gösterilmedi: **not_run**.

### Artifact provenance ve authenticated readback

Artifact:
- Ad: `SeaCraft-PRG03-2d8e32e6ff84ca3a8e4b23aa0e52073dc333b584`
- ID: `14759425694`
- Boyut: `58835440` byte
- URL: https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45034255905/artifacts/14759425694
- ZIP / upload digest SHA-256: `6da0d0a5dfa3b53b14399b130562c30ce834e86b6f4ff2f604c9dad139bddf5d`

CI authenticated REST readback marker:

`PRG03_ARTIFACT_READBACK_OK artifact_id=14759425694 rest_zip_sha256=6da0d0a5dfa3b53b14399b130562c30ce834e86b6f4ff2f604c9dad139bddf5d upload_digest=6da0d0a5dfa3b53b14399b130562c30ce834e86b6f4ff2f604c9dad139bddf5d sha=2d8e32e6ff84ca3a8e4b23aa0e52073dc333b584`

Artifact ayrıca authenticated GitHub connector üzerinden indirildi; ZIP digest GitHub digest ile birebir eşleşti. `COMMIT_SHA.txt` exact kod SHA'yı taşıdı ve `sha256sum -c SHA256SUMS.txt` üç payload için `OK` verdi.

| İçerik | SHA-256 |
| --- | --- |
| Android APK | `a4453663b909da9b2fec416d76278affe04bc9d198eff41fff20530bc9aaa490` |
| Linux executable | `1a291d3d15e4180b60b0af96cf6458f11fe143636d76575ddf1e23d1a3f24f2e` |
| Linux PCK | `7c5ba76e5633845c720cd358f8f217b7229fa46a602d66fd2a3f5cb3a90278ed` |

### Avenox Beyin strict kapanışı

Resmî Avenox Beyin v3.12.0 Project ZIP'i kullanıldı; ZIP SHA-256: `d8dbf97a38a50046d3f48205ae08ff65364b92292999fef611f882839d6e9696`.

Kanonik task:
`tasks/seacraft-prg03-xp-skill-tree-rank-local-challenge-meta-20261122.md`

Uzak `TheOsmanYILDIRIM/agy-vault/main` readback:
- status: `done`
- revision: `2`
- completion_contract: `strict`
- evidence_refs: `receipts/7bd576a04c1148524ad9275be0183c6bd6455b69e0540ad44194fd9a27c17b85.md`
- receipt event ID: `seacraft-prg03-close-2d8e32e6ff84ca3a8e4b23aa0e52073dc333b584`
- Beyin kapanış commit: `3e3ab2f3995ee71e11b0c1488e5474a801112e18`

Resmî motorun DirectSync doctor sonucunda `task_completion.strict_issue_count=0`, potential missing receipt `0` ve dead instruction ref `0` doğrulandı. Motorla üretilen task revision 2 ve tek receipt aynı CAS kapanış commit'i sonrasında uzak `agy-vault/main` üzerinden geri okundu.

### Son kapı

PRG-03 XP/rank, skill DAG/spend/respec, progression gates, local challenge meta, persistence migration, host-authoritative LAN, touch sözleşmesi, Linux/Android export, exact artifact provenance/readback ve Avenox Beyin strict kapanışı doğrulandı.

**PRG-03 tamamlandı. PRG-04 başlatılmadı ve `not_started` olarak kalır.**

## SOHBET-35 — SeaCraft PRG-04 — Quest, Journal ve NPC Interaction

**Sonuç (2026-11-22): tamamlandı ve doğrulandı.** Exact kod SHA: [`cb179949f5a8e04c2507c20a51b17c54e034476a`](https://github.com/TheOsmanYILDIRIM/SeaCraft/commit/cb179949f5a8e04c2507c20a51b17c54e034476a). Godot `4.7.2-stable` final CI: [run 45045317837 — success](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45045317837), job `137278544612`; commit status context `seacraft-prg04-evidence=success`.

### Uygulanan PRG-04 sınırı

- Stable-ID `QuestDefinition` ve runtime quest state; start/turn-in NPC, prerequisite quest/gate/rank, region/sector, repeatability, party-share ve ordered-objective sözleşmeleri eklendi.
- Objective authority matrisi kill, damage, capture, collect, acquire, timed, escort, salvage ve trade türlerini kapsar. Objective eventleri host/offline authority bağlamı, target/source/region/sector filtresi, duplicate-ID idempotency ve same-ID payload conflict korumasıyla işlenir.
- Quest-chain missing-reference ve cycle doğrulaması ile region/NPC/rank/gate referans validation'ı data-driven katalog sınırında tutulur.
- Reward path mevcut `InventoryState` ve PRG-03 XP/gate API'lerini reuse eder; item + XP + gate sonucu atomik rollback sınırındadır. Lost-ACK/same transaction retry ikinci reward üretmez.
- Persistence `InventoryState` v4'e yükseltildi; v1/v2/v3 migration, quest progress/timer/event ledger/reward state round-trip ve corrupt DTO/referans reddi eklendi.
- Journal detached primitive-safe snapshot olarak available/active/completable/completed/failed grupları, objective progress, reward preview ve timer bilgisini taşır. UI authoritative state'i doğrudan değiştirmez; accept/turn-in intent ve local tracking üretir.
- LAN protocol v7'de accept/turn-in bounded intentleri host transaction ledger'a bağlandı. Objective outcome client wire intenti değildir. Handshake quest snapshot'ı reconnect ve late-join client mirror'ına aktarır.
- Touch sözleşmesinde minimum 48 px hedef ve font scale 1.3 korunur. PRG-05 faction/economy geliştirmesi yapılmadı.

### Hata düzeltme ve exact CI

İlk uygulama run `45044970051` GDScript type-inference parse hatalarını, ikinci run `45045036454` ise eski protocol/migration regresyon beklentileri ile quest reward event-ID/network intent eksiklerini görünür kıldı. Kök nedenler düzeltilip yeni exact commit üzerinde yeniden çalıştırıldı.

Final exact run `45045317837` sonucu:

- GUT: **378/378 passing**
- `PRG04_VERIFIER_OK tests=9 markers=37 objectives=9 atomic_reward=1 persistence=1 lan=1 journal=1 touch=1`
- PRG-01/02/03 regression testleri geçti.
- NET-01/02/03/04 gerçek process/integration kapıları geçti.
- Mevcut VS/CORE/AI verifier'ları ve offline/network boundary kapıları geçti.
- Parse/load, export preset ve headless boot kapıları geçti.

### Linux / Android export

Linux debug export başarıyla üretildi:

- `linux/SeaCraft.x86_64`
- `linux/SeaCraft.pck`

Android debug export başarıyla üretildi:

- `android/SeaCraft-debug.apk`
- package: `com.osmanyildirim.seacraft`
- targetSdk: `37`
- native ABI: `arm64-v8a`
- `android.permission.INTERNET`
- `android.permission.ACCESS_LOCAL_NETWORK`

Fiziksel Android cihazda NPC/journal/touch/save/LAN matrisi bu ortamda çalıştırılmadı ve başarı gibi gösterilmedi: **not_run**.

### Artifact provenance ve authenticated readback

Artifact:

- Ad: `SeaCraft-PRG04-cb179949f5a8e04c2507c20a51b17c54e034476a`
- ID: `14763222807`
- Boyut: `58905878` byte
- ZIP / upload digest SHA-256: `ead25a16d2f6ec8a251e09c08863b975736e8bf170c302391424e5da8b6faab4`
- Expires: `2026-12-06T16:45:40Z`

CI authenticated REST readback marker:

`PRG04_ARTIFACT_READBACK_OK artifact_id=14763222807 rest_zip_sha256=ead25a16d2f6ec8a251e09c08863b975736e8bf170c302391424e5da8b6faab4 upload_digest=ead25a16d2f6ec8a251e09c08863b975736e8bf170c302391424e5da8b6faab4 sha=cb179949f5a8e04c2507c20a51b17c54e034476a`

Artifact ayrıca authenticated GitHub connector üzerinden yeniden indirildi. İndirilen ZIP SHA-256 GitHub artifact digest ile birebir eşleşti; `COMMIT_SHA.txt` exact kod SHA'yı taşıdı ve `sha256sum -c SHA256SUMS.txt` üç payload için `OK` verdi.

| İçerik | SHA-256 |
| --- | --- |
| Android APK | `42fc59b141060d2f5ace190a4976f2371f7bd4df0f7b66626cd2b4b40f5ea3e2` |
| Linux executable | `1a291d3d15e4180b60b0af96cf6458f11fe143636d76575ddf1e23d1a3f24f2e` |
| Linux PCK | `2f4b7df1f1d5b4e1e4f65c9bc0893891bbfc95bb30606f770a4351ce1d09b76d` |

### Avenox Beyin strict kapanışı

Resmî Avenox Beyin v3.12.0 Project ZIP'i kullanıldı; ZIP SHA-256: `d8dbf97a38a50046d3f48205ae08ff65364b92292999fef611f882839d6e9696`.

Kanonik task:

`tasks/seacraft-prg04-quest-journal-npc-interaction-20261122.md`

Uzak `TheOsmanYILDIRIM/agy-vault/main` readback:

- status: `done`
- revision: `2`
- completion_contract: `strict`
- evidence_refs: `receipts/a8f03934d465a9465c4585ca5a5ae646bb62ebf8e2d356b36141084775cb528e.md`
- receipt event ID: `seacraft-prg04-close-cb179949-20261122`
- Beyin kapanış commit: `e48989da5c444b6342c00f3eb41e30bee8249804`

Resmî motorun DirectSync doctor sonucunda `task_completion.strict_issue_count=0` doğrulandı. Motorla üretilen task revision 2 ve tek receipt aynı CAS kapanış commit'i sonrasında uzak `agy-vault/main` üzerinden geri okundu.

### Son kapı

PRG-04 quest/objective authority, atomik reward, persistence/migration, detached journal, NPC interaction, host-authoritative LAN, Linux/Android export, exact artifact provenance/readback ve Avenox Beyin strict kapanışı doğrulandı.

**PRG-04 tamamlandı. PRG-05 başlatılmadı ve `not_started` olarak kalır.**



## Android gerçek cihaz smoke hotfix — 2026-11-22

Kullanıcının PRG-04 Android buildi üzerinde yaptığı ilk gerçek cihaz smoke testinde üç oynanış sorunu doğrulandı: denize dokunarak gemi hareket ettirilemedi, combat/core debug butonları başarısız işlemden sonra kalıcı `×` metninde kaldı ve NPC/gemi durum etiketi gemiyle birlikte döndü. Ayrıca Linux ve Android aynı artifact içindeydi.

### Düzeltmeler

- Android touch girişleri GUI tarafından yutulmadan önce güvenli world-touch yoluna alındı; görünür UI hit-test sınırı korunur. Parmak-ID ownership ile world üzerinde başlayan gesture UI alanına taşsa bile state takılı kalmaz; UI üzerinde başlayan touch world command üretmez.
- Core/debug aksiyon geri bildirimi `✓/×` artık geçicidir ve 0.75 saniye sonra asıl buton etiketi geri gelir.
- NPC state/name presenter global rotation'ı sıfırlar; etiket gemi dönüşünden bağımsız ekran-yukarı kalır.
- Export presetleri kaynak `*.zip` arşivlerini dışlar.
- GitHub Actions Android ve Linux çıktısını iki ayrı artifact olarak paketler ve her ikisini ayrı authenticated readback ile doğrular.

### Exact doğrulama

- Exact code/test SHA: `79f1367bbc91613f43f34ea696cbd4da87b45d51`
- Actions run: `45048643091` — **success**
- Full GUT + VS/CORE/AI/NET regresyonları: **success**
- Linux export: **success**
- Android arm64-v8a debug APK export: **success**
- Platform artifact authenticated readback: **success**

Android artifact:
- ad: `SeaCraft-Android-79f1367bbc91613f43f34ea696cbd4da87b45d51`
- ID: `14764866787`
- artifact ZIP boyutu: `30173071` byte
- artifact ZIP SHA-256: `fe6dd2bda392f8905efa47a3fda7c78f2dc52a1949dd4028b931b0bbc04fdfa9`

Linux artifact:
- ad: `SeaCraft-Linux-79f1367bbc91613f43f34ea696cbd4da87b45d51`
- ID: `14763804453`
- artifact ZIP boyutu: `28736757` byte
- artifact ZIP SHA-256: `4865d8939406357ecaf6419fc64a8508c995d6f6d1fb4e93698f02e25c357708`

Android artifact ayrıca indirildi ve içerik geri okundu. `SeaCraft-debug.apk` boyutu `80776800` byte, SHA-256 `70ac769d260bc90c993a5b4f4904337587e2eb53d82266bf71cf2f5853b0dcc0`. APK içinde kaynak SC sprite ZIP arşivleri artık bulunmuyor. APK boyutunun ana nedeni assetler değil, Godot debug engine binary'sidir: `lib/arm64-v8a/libgodot_android.so` tek başına `76181608` byte.

### Cihaz kapısı

Yeni exact APK fiziksel Android cihazda henüz tekrar çalıştırılmadı. Kod/regresyon/export/artifact zinciri yeşildir; gerçek cihazda hareket, transient buton geri bildirimi ve ekran-yukarı NPC etiketi sonucu **awaiting_retest / not_run** olarak kalır.

PRG-05 başlatılmadı.

---

## Android gemi görsel pilotu — SC-02 / SC-03

**Durum:** SC-02 ve SC-03 ile erken pilot doğrulandı. SC-07: `missing_approved_atlas`. Fiziksel Android: `not_run`. PRG-05 ve tam POL-02 başlatılmadı.

- Başlangıç `main`: `95a3862a8720061bb69f6a1734b23792b003fa26`. Exact pilot kodu ve Android export: `f0f254bdb179b1e5e01981fe82c17f2d1546f006`.
- [GitHub Actions 45069957749](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45069957749): **success**, GUT **394/394**, ARM64 Android debug export ve authenticated artifact readback başarılı.
- [Android artifact 14772826966](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45069957749/artifacts/14772826966): APK **81 165 486 bayt**, SHA-256 `88e94f08643ce3ce4b57dde20d4a709fa397c46b67f880e8d5cc7126154bb3e7`. ZIP SHA-256 `59a1d3050998051b2ed311792f41f782c4f8177ebc8c3ed93b36afd00d653e97`. İndirilen APK'nın arşiv bütünlüğü, gömülü exact commit, yalnız `arm64-v8a`, SC-02/SC-03 dokuları ve kaynak ZIP/orijinal master PNG yokluğu ayrıca denetlendi.
- [Görsel kanıt 14772409496](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45069957749/artifacts/14772409496): iki deniz, 1×/2×, 8 yön; dört PNG açılıp karşılaştırıldı. Bu inceleme gerçek çalışma dokularının yazılımsal kompozitidir; Godot Android ekran görüntüsü, shader performansı veya cihaz oynanış kanıtı değildir.

### Yerleşim ve yön

SC-02 oyuncu: onaylı 4×2 master atlastan **160 px** hücre; SC-03 NPC: AUTO FINAL arşivindeki sekiz onaylı RGBA masterdan **224 px** hücre. SC-03'ün opak contact-sheet'i kullanılmadı. Sıra `N, NE, E, SE / S, SW, W, NW`; pivotlar sırasıyla `(80,80)` ve `(112,112)`. Toplu küçültme dışında karelerin hizasına, rengine veya yön sırasına müdahale edilmedi. Sprite ekranda ayrıca döndürülmüyor; gerçek yön 45° sektör olarak atlas karesini seçiyor. SC-07 arşivi bulunamadı; sahnede sahte varlık yok. Mevcut deniz ve GDQuest yaklaşımını temel alan basit shader, `Deniz` tuşuyla değişiyor. Hareket, çarpışma, savaş, köpük, wake ve final HUD değiştirilmedi.

### 1× / 2× görsel karar

- **Suya oturuş ve boyut:** SC-03 geniş ve ağır, SC-02 daha dar ve alçak okunuyor. Arma hariç E/W gövde uzunluğu görsel ölçümle 1×'ta yaklaşık SC-02 **70–78 px**, SC-03 **105–115 px**; 2×'ta yaklaşık **140–156 px** ve **210–230 px**. 2D zemin gövde-suyu ayırmaya yardımcı oluyor, gövde tabanını örten efekt yok. Bu ölçü gerçek telefon piksel ölçüsü değil.
- **Yön/pivot:** Sekiz karenin merkez referansı aynı. E/W'de gövde oturuşu daha tutarlı; SC-02 N/S görünüşünde aynı pivot çevresinde pruva-kıç orta noktasında birkaç 1× piksel görünür fark var; SC-03 N/S ile çaprazları arasında da benzer küçük destek farkı görünüyor. Bunlar bake edilmiş perspektif/siluet farkı; canlı dönüşte cihaz doğrulaması yapılmadı. Master alfa sınır teması SC-02 **E/W**, SC-03 **SE/SW/W**; kaynak yerleşime dokunulmadı.
- **Işık/kontrast:** İki zemin de yelken-gövde ayrımını koruyor. SC-02 E/W/NW yelken vurguları N/S'den daha güçlü; SC-03 sekiz yönde daha tutarlı ve koyu borda 1×'ta okunuyor. Önizleme suyu belirgin parlak çizgi üretmedi.
- **Gerçek piksel yoğunluğu:** 1× E/W gövde izdüşümüne göre runtime atlasın gövdedeki örnek sayısı yaklaşık SC-02 **108–120**, SC-03 **178–195**; bu değerler hücre ölçüsü değildir. SC-03 normalizasyon arşivindeki **ham gövde ekseni** ölçüleri, yön sırasıyla **633 / 964 / 1031 / 883 / 675 / 956 / 1256 / 1251 px**. SC-02'nin ham, normalize öncesi görüntüleri bu arşivde yok; ham yoğunluk `unverified`. 2×'ta SC-02 E/W'nin ince kaplaması daha yumuşak; kullanılan 160 px runtime atlasın 208 px'e görüntülenmesi tek başına ham kaynakta AI upscale gerektiğini kanıtlamıyor. İncelenen karelerde zorunlu **AI upscale gerekli** kararı çıkmadı; SC-07 için karar `not_run`. AI upscale uygulanmadı.


---

## PRG-05 — İlk doğrulanmış kodlama checkpoint'i (faction/economy + combat diplomacy)

**Durum:** `verified_checkpoint`, genel PRG-05 görevi `active`; bu kayıt PRG-05 kapanış receipt'i değildir.

- Kanonik Beyin görev kaynağı: `tasks/seacraft-prg05-faction-economy-trade-20261123.md` (resmî v3.12 task-create, revision 1, active, readback).
- Başlangıç main: `a73633beb1dfec0d70c1b4e640bfd439ff823ede`; doğrulanmış kod commit'i `6140a383ff47b354968cf2966bec2686f5d6d28d`.
- [CI run 45232141806](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45232141806): **success**; 29 GUT script, **400/400** test, **29439** assert, PRG-05 **6/6** test + marker; NET04 real-process/reconnect/discovery/lost-ACK; Linux ve Android export.
- [Android artifact 14847088562](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45232141806/artifacts/14847088562): authenticated readback başarı, artifact ZIP SHA-256 `928953d72fc793210202746b3861f8ebf45642ebcf7e72a0b7779ea655e83290`.
- [Linux artifact 14846294929](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45232141806/artifacts/14846294929): authenticated readback başarı, artifact ZIP SHA-256 `f338c78a43b7b226792fc22482f438ed310b2b15367109f32617d9e899c6244b`.
- Kapsam: typed host economy state, reputation, faction relations, trade idempotency + atomic inventory/funds/stock, convex scarcity+convoy disruption price, region outpost ownership, repeat-kill PvP reward, JSON round-trip save v5/legacy migration, server-bound LAN intents, economy reputation ile CombatAuthority runtime hostility (NPC ve oyuncu karşılıklı, faction-safe), bootstrap wiring.
- **Henüz doğrulanmamış:** Android cihazda uzun LAN ekonomi drift, gerçek market UI, far-field olayının markete otomatik bağı, company/crew ve bounty/intel. Görsel asset/sprite üretimi bu dilime bağımlı değildir; eski Android smoke fiziksel cihaz retesti `not_run`. PRG-05 `active` kalır, PRG-06 `not_started`.

---

## PRG-05 — Konvoy ekonomisi, AI-04 uzak dünya ve Güvenli Liman mobil pazar checkpoint'i

**Durum:** `verified_checkpoint`; PRG-05 kanonik görevi hâlâ **active**. PRG-06 başlatılmadı. Bu rapor PRG-05 kapanış receipt'i değildir.

- Kod doğrulaması (main): `2f229ac4eeb7d95c5809d879624be18d4c0ca101` (AI-03 market köprüsü) → `3396fff4779237353b8580db1a3ee0ae80f3416b` (AI-04 FAR varış/batma köprüsü) → **`0c821a58c904839a53cd0b51509f55e606e3e323`** (gerçek Güvenli Liman pazarı + dokunmatik UI).
- [Son exact CI run 45249433521](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45249433521): **success**; 403/403 GUT test, 29546 assert, PRG-05 verifier **9/9**; ENet real-process NET-01/02/03/04 kontrolleri, Linux/Android debug export ve authenticated artifact readback başarılı. İlk iki checkpoint'in CI'ları da sırasıyla [45247201073](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45247201073) ve [45248332851](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45248332851): success.
- [Android artifact 14855516010](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45249433521/artifacts/14855516010): readback **OK**, ZIP SHA-256 `cc7f9610a85b1c1a769e718d2317f25c13b52250d0aa4fbb4f348b0c068a7e9b`; SHA eşleşmesi exact.
- [Linux artifact 14855416066](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45249433521/artifacts/14855416066): readback **OK**, ZIP SHA-256 `95c0c1ebbfb2df965f1ece8353e3bf65c1f802174f85e258668f63efc0f7318d`; SHA eşleşmesi exact.
- İşlenen alan: host-owned stok/price için AI-03 trade teslim/kayıp olay bağlama, AI-04 FAR world authoritative varış/batma sonucu settlement, stable event ID + idempotent replay/save roundtrip, limanda gerçekten kayıtlı `market.haven.salvage`, dokunmatik ekran paneli, yalnız güvenli limanda gösterme/alış-satış ve fiyat/kimlik sahteciliğini kabul etmeyen host-side UI adapter. Yeni test markerları: `PRG05_CONVOY_WORLD_BRIDGE_OK`, `PRG05_FAR_WORLD_BRIDGE_OK`, `PRG05_MOBILE_MARKET_INTENT_OK`.
- **Açık sınırlar:** AI-04 world scheduler→economy bridge otomatik event-dispatch wiring'i (şu an güvenilir host çağrısıyla çalışan adaptör), bounty/intel ve local company/crew domain, LAN tarafında gerçek market proximity/sector proof, telefonda gerçek dokunmatik pazar smoke ve uzun LAN ekonomi drift testi **not_run**. Artifact oluşması cihaz testi değildir. PRG-05 kanonik kapatma geçidi henüz tamamlanmadı; PRG-06 `not_started`.

---

## PRG-05 — AI-04 otomatik konvoy ikmali, LAN pazar konum koruması, bounty/intel ve local company/crew

**Durum:** `verified_checkpoint`; PRG-05 görevi **active**, PRG-06 `not_started`. Bu checkpoint bir PRG-05 kapanışı veya gerçek Android LAN cihaz testi değildir.

- Exact kod SHA: **`11ddde3d4f2311283899e2b873485b38008d6a97`**. Yeni kod + regresyonlar önceki `0c821a58` checkpoint üstüne geldi. [CI 45272356337](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45272356337): **completed/success**, tam GUT **410/410**, **29.790 assert**, PRG-05 verifier **16/16** marker. NET-01/02/03/04 gerçek ENet süreç/host+client/reconnect/lost-ACK doğrulama başarılı; Godot 4.7.2.
- [Android artifact 14864279786](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45272356337/artifacts/14864279786): authenticated ZIP artifact readback **OK**, SHA-256 `621c0c06b51db0c9eb3e19ebccf248aeb248a3fc0772e407c60381351280405e`, provenance `11ddde3d4f2311283899e2b873485b38008d6a97`.
- [Linux artifact 14864479699](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45272356337/artifacts/14864479699): authenticated ZIP artifact readback **OK**, SHA-256 `4ed6dfb8fe69d87c104880c0c9392828020956e526b26e41a2b93b8ca4513a8f`, aynı exact SHA.
- Uygulama: `Prg05EconomyWorldRunner` ile AI-04 FAR scheduler/encounter → host-owned teslim/batma settlement → market stock/disruption/quote; `Prg05MarketAccessGuard` ile LAN market işlemi için sunucunun sektör, ShipMotor konum ve menzil kanıtı (cache/lost-ACK uyumu); `Prg05BountyCombatBridge` ile sunucu CombatAuthority lethal+ship_sunk proof → bounty credit ve intel event ledger, save/replay; local `Prg05EconomyState` şirket-kaptan-üye/rütbe/ücret/tek-tick idempotent maaş settlement. Mürettebat slotunun asıl kayıt kaynağı PRG-01 inventory/equipment; şirket bunu yalnızca okur; LAN client'ına serbest company/bounty/price mutasyon intent'i açılmaz.
- Persistence: PRG-05 internal state `VERSION=2`, eski `VERSION=1` save göçü destekli; company roster, ödeme ledger, idempotent retry, JSON numeric receipt type canonicalization, bozuk/fractional schema ve wage/role spoof reddi GUT ile test edildi. Üst inventory progression `VERSION=5` korundu.
- **Kalan doğrulamalar:** Gerçek Android cihazda dokunmatik pazar smoke, uzun 2-cihaz LAN economy state drift, pazar kapısının fiziksel mesafe davranışı ve canlı çok oyunculu kullanım **not_run**. AI-04 runner/market guard/bounty/crew sunucu alanları kod+fixture ile doğrulandı; tüm oyun sahnelerindeki uçtan-uca canlı içerik/ekonomi orchestration'ını ve üretim UX'i gerçek cihazda doğrulanmış sayma. PRG-05 kapanış receipt'i yok; PRG-06 başlamaz.
