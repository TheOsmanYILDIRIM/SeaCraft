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
