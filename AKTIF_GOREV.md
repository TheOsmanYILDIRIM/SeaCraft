# AKTİF GÖREV — NET-01

> Bu dosya SeaCraft'ın kanonik aktif uygulama briefidir. Her yeni görevde bu dosyanın içeriği yeni görevle değiştirilir. Sohbette uzun brief tekrarlanmaz.
>
> Görev tamamlandığında ayrıntılı doğrulama sonucu **yalnız** `GOREV_RAPORU.md` dosyasına, mevcut geçmiş korunarak yeni bir bölüm halinde yazılır. Sohbet cevabı kısa tutulur.

## Kimlik

- Sohbet etiketi: `[SOHBET-28 | SeaCraft NET-01 — LAN Session ve Host-Authority Protokolü]`
- Repo: `TheOsmanYILDIRIM/SeaCraft`
- Dal: yalnız `main`
- Başlangıç HEAD: `56c5727c161b0801cae024b54242e3b4d2d063ea`
- Godot: `4.7.2-stable`
- Bağımlılık: AI-04 tamamlandı
- Sonraki göreve geçme: **NET-02'ye başlama**

Her mesajına yukarıdaki sohbet etiketiyle başla.

## Yürütme

İşi tek oturumda uygula → doğrula → hata varsa kök nedeni düzelt → yeniden doğrula → artifact readback → Beyin kapanışı → `GOREV_RAPORU.md` güncellemesi şeklinde bitir.

Başlamadan güncel `main` HEAD'i doğrula. HEAD değişmişse diff'i incele; başka sohbetin değişikliğini ezme.

Avenox Beyin'de NET-01 görevi varsa onu kullan; yoksa tek kanonik task aç. Mükerrer task/receipt oluşturma.

## Hız protokolü

Hedef: **1 implementation commit + 1 successful Actions run**. Gerçek hata çıkarsa en fazla bir toplu correction commit hedefle.

İlk committen önce source/test/CI/README/export değişikliklerini birlikte hazırla ve statik preflight yap. Dosya, test, README, verifier, marker veya diagnostic için ayrı commit üretme.

Özellikle committen önce doğrula:

- Godot 4.7.2 RPC annotation syntax
- explicit GDScript types
- DTO exact shape ve field sayıları
- int/float JSON normalization
- reject reason stringleri
- ENet channel numaraları
- integration port ve process arg sırası
- host-ready synchronization
- shell `trap`/PID cleanup
- mevcut kanıtlanmış ANSI normalization yaklaşımı
- verifier marker sayıları
- Android INTERNET permission
- simulation/network boundary grep'i

CI fail olursa ilk hataya göre commit atma. İlgili logların tamamını incele ve bütün kök nedenleri tek correction commitinde çöz.

## Mimari sınır

Networking simulation'ın dışında özel bir network boundary altında olmalı.

`src/simulation/**`, `src/data/**` ve `src/persistence/**` içinde şunlar yasak kalmalı:

- `ENetMultiplayerPeer`
- `MultiplayerAPI`
- `SceneMultiplayer`
- `@rpc`
- `rpc()`
- `multiplayer.get_remote_sender_id()`
- `multiplayer_peer`

Network boundary dışında gameplay/presentation koduna doğrudan RPC saçma.

FND-01 sözleşmesini koru: autoload yok. Offline boot peer/socket açmadan ve network beklemeden çalışmaya devam etmeli.

## NET-01 amacı

Offline simulation'ı değiştirmeden:

- LAN host
- LAN join
- protocol/content handshake
- peer → player mapping
- primitive bounded command envelope
- host-authority güven sınırı
- reliable/unreliable channel policy

ekle.

Manual IPv4:port ilk zorunlu bağlantı yoludur. Discovery, reconnect ve state replication bu görevde yok.

## SessionProtocol

Tek pure-data protocol contract kullan.

Minimum:

- `PROTOCOL_VERSION`
- compatibility stamp
- channel policy
- maximum peers
- bounded handshake/envelope validation
- explicit rejection reasons

Compatibility mevcut kanonik kaynaklardan türemeli:

- `DataContractVersions.compatibility_stamp()`
- `ContentManifest.metadata()`

Minimum handshake karşılaştırması:

- protocol version
- schema version
- content version
- RNG stream version
- content manifest algorithm
- content hash
- manifest entry count

Content hash hardcode etme.

## Handshake

Client hello primitive-safe olmalı.

Client handshake içinde authoritative kimlik iddiası bulunmamalı:

- player_id
- entity_id
- owner_id
- authority_id

yasak.

Host state lifecycle açık olsun:

- connected
- handshaking
- ready
- rejected/disconnected

Yalnız compatibility tamamen eşleşirse READY.

Explicit deterministic rejection reasons:

- protocol mismatch
- schema/version mismatch
- content version mismatch
- content hash mismatch
- malformed handshake
- server full

## Peer → player mapping

Mapping yalnız host tarafından oluşturulur.

Client kendi player/entity kimliğini seçemez.

RPC sender identity yalnız gerçek multiplayer context'inden türetilir:

`multiplayer.get_remote_sender_id()`

Payload'dan peer/player kimliği alma.

Host available player slotlarını deterministic stable-ID sırasıyla atayabilir.

## Command envelope

Primitive-safe, bounded exact schema.

Minimum:

- protocol_version
- client_sequence
- intent_type
- payload

Envelope içinde sender/player identity **olmayacak**.

Şu extra alanlar explicit reject:

- player_id
- peer_id
- entity_id
- owner_id
- authority_id

Per-peer monotonic sequence tut. Duplicate/older/negative/non-integer/out-of-bound sequence reddedilsin.

Payload için bound koy:

- key count
- string length
- array/nesting count
- finite numeric values
- primitive-only

## İzinli intentler

Mevcut `GameplayCommand` contract'ını reuse et.

NET-01'de network üzerinden yalnız discrete gameplay intent:

- move_to_world_position
- select_world_position
- cancel
- target_cycle

taşınabilir.

Client-local presentation intentleri network'e gönderilmez:

- camera_pan
- camera_zoom
- camera_recenter

Client outcome gönderemez. NET-01'de remote damage/HP/ammo/loot/spawn/inventory-result komutları yok.

## Gerçek authority bridge

NET-01 yalnız protokol testi olarak kalmasın.

En az `move_to_world_position` gerçek host authority yoluna bağlanmalı:

validated client intent
→ host-derived player mapping
→ mevcut authoritative command
→ `ShipMotor.apply_authoritative_command()`

Client transform yazamaz.

Offline command yolu aynı kalır.

## SessionHost

Minimum:

- start(port)
- stop
- peer connected
- handshake
- peer mapping
- validated intent receive
- disconnect cleanup
- telemetry/snapshot

Max peers ve port bounded.

Disconnect:

- mapping temizle
- handshake state temizle
- sequence state temizle

Gameplay entity'yi otomatik delete etme; reconnect/grace NET-04.

## SessionClient

Minimum:

- join IPv4 + port
- disconnect
- handshake send
- accept/reject
- send validated intent
- client sequence
- connection state
- rejection reason

Client simulation authority değildir.

## ENet ve channel policy

Godot built-in `ENetMultiplayerPeer` kullan. Üçüncü parti netcode addon yok.

Semantic policy:

- control/handshake/session lifecycle: **reliable**
- discrete gameplay intent: **reliable**
- state/snapshot: NET-02 için ayrılmış, ileride **unreliable ordered**

NET-01 snapshot replikasyonuna başlamaz.

RPC/channel syntaxını gerçek Godot 4.7.2 API ile doğrula.

## Güvenlik sınırı

LAN protokolünü cryptographically secure, encrypted, internet-authenticated veya anti-cheat-proof diye tanımlama.

Bu görev yalnız host-authoritative trust boundary kurar.

HTTP/WebSocket/cloud/relay/NAT punch yok.

## Android

`export_presets.cfg` Android presetinde LAN socket için:

`permissions/internet=true`

olmalı.

CI exported APK manifest/badging çıktısında:

`android.permission.INTERNET`

bulunduğunu doğrulasın.

Offline boot permission/network erişilebilirliğine bağımlı hale gelmemeli.

## Gerçek process integration

Unit test yetmez.

GitHub Actions gerçek ayrı Godot prosesleri çalıştırmalı:

1. headless host
2. headless client
3. `127.0.0.1:<test-port>`
4. real ENet handshake
5. real RPC
6. clean disconnect
7. clean process exit

Harness:

- startup/client timeout
- host-ready marker
- bounded readiness wait
- port collision kontrolü
- `trap` cleanup
- host/client PID cleanup
- nonzero exit propagation
- log files

Arbitrary sleep tek senkronizasyon yöntemi olmasın.

## Integration senaryoları

### Success

- host starts
- client connects
- compatibility matches
- host assigns player
- client sends valid move intent
- host gerçek remote sender'dan mapping bulur
- envelope/sequence validate edilir
- authoritative command uygulanır

### Protocol mismatch

`protocol_version + 1` → reject, mapping yok, READY yok, command yok.

### Content mismatch

Yanlış content hash → reject, mapping yok, mutation yok.

### Spoof

Forbidden identity field veya başka player adına command → reject; diğer player state değişmez.

### Pre-handshake intent

Handshake READY olmadan intent → reject.

### Replay

Aynı/older sequence → ikinci mutation yok.

### Malformed

Missing/unknown type, non-finite, oversized string, extra identity, invalid sequence, wrong protocol → crash olmadan reject.

## CI markerları

- `NET01_PROTOCOL_CONTRACT_OK`
- `NET01_HANDSHAKE_OK`
- `NET01_PROTOCOL_MISMATCH_OK`
- `NET01_CONTENT_MISMATCH_OK`
- `NET01_PEER_MAPPING_OK`
- `NET01_INTENT_AUTHORITY_OK`
- `NET01_SPOOF_REJECTION_OK`
- `NET01_REPLAY_REJECTION_OK`
- `NET01_OFFLINE_BOOT_OK`
- `NET01_PROCESS_INTEGRATION_OK`

Verifier hem GUT logunu hem gerçek process integration logunu kontrol etsin.

AI-04'te kanıtlanmış ANSI normalization yaklaşımını aynen reuse et; yeni regex deneme zinciri oluşturma.

## Test stratejisi

Mevcut 295 test korunmalı.

NET-01 için tercihen 8–12 güçlü scenario/test:

- protocol stamp
- handshake
- envelope
- peer mapping
- sequence/replay
- spoof
- payload bounds
- offline/network boundary

ve gerçek process integration:

- valid host/client
- protocol mismatch
- content mismatch
- valid intent
- spoof/replay rejection

## Regression

Exact NET-01 committe:

- AI-04 10/10
- AI-03 10/10
- AI-02 11/11
- AI-01 10/10
- CORE-04/03/02/01
- VS-04 checkpoint/replay/soak

geçmeli.

Beehave orphan = 0.

## NET-02 kapsam dışı

Yapma:

- MultiplayerSpawner production replication
- MultiplayerSynchronizer production replication
- NPC/monster/loot replication
- transform snapshots
- interpolation
- AOI
- late join
- reconnect
- discovery

## Artifact

Ad:

`SeaCraft-NET01-<exact SHA>`

Standard payload:

- COMMIT_SHA.txt
- SHA256SUMS.txt
- Android APK
- Linux executable
- Linux PCK

Upload sonrası yeniden indir ve bütün hashleri exact commit ile doğrula.

## README

Yalnız gerçekten uygulananı belge:

- manual IPv4
- SessionHost/Client
- protocol/content handshake
- peer→player host mapping
- intent-only client
- channel policy
- simulation boundary
- offline behavior
- Android INTERNET permission
- no discovery
- no replication yet
- host-authoritative, not lockstep
- no encryption/authentication claim

## Gerçek Android

CI fiziksel cihaz değildir.

Şunlar `not_run`:

- desktop host → Android client manual IPv4
- Android host → desktop client
- same Wi-Fi
- Wi-Fi disconnected offline boot
- invalid IP UX
- network loss
- background/foreground

## Beyin kapanışı

NET-01 task bir kez açılır. Ara failures için Beyin update yapma.

Final exact commit + Actions success + artifact readback sonrası task final update + tek receipt oluştur ve geri oku.

## Nihai rapor — sohbet yerine GitHub

Görev bitince `GOREV_RAPORU.md` dosyasındaki geçmişi koru ve en üste veya sona **NET-01** başlıklı yeni bölüm ekle.

Bölümde yalnız doğrulanmış kanıt yaz:

- exact main SHA
- implementation/correction commitleri
- Actions run sayısı / success / failed / cancelled
- total tests / NET-01 tests
- real process integration
- protocol/content mismatch
- peer mapping
- spoof/replay rejection
- offline boot
- simulation/network boundary
- APK INTERNET permission
- regressions
- orphan count
- artifact ID/name
- ZIP/APK/Linux/PCK SHA-256
- Beyin revision/status
- receipt + Beyin kapanış commit
- real Android status

Son chat cevabı kısa olsun; ayrıntılı raporu sohbete kopyalama.

## Son kapı

NET-01 ancak şu kanıtlarla tamamdır:

- offline boot ağ açmadan çalışıyor
- network API simulation'dan tamamen ayrı
- gerçek ENet host/client manual IPv4 bağlantısı çalışıyor
- gerçek process-to-process RPC çalışıyor
- protocol/content handshake var
- mismatch deterministik reject
- peer→player yalnız host mapping
- client identity claim authority değil
- client yalnız intent gönderiyor
- valid move intent host authority'den uygulanıyor
- pre-handshake/spoof/replay/malformed rejected
- camera intent network dışı
- APK INTERNET permission var
- tüm eski regressions geçiyor
- orphan=0
- Linux export/boot ve Android arm64 export geçiyor
- exact artifact readback geçiyor
- Beyin task+receipt geri okunuyor
- `GOREV_RAPORU.md` NET-01 sonucu ile güncellenmiş

Eksikse düzeltmeye devam et.

**NET-02'ye başlama.**
