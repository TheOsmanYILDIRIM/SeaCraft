# AKTİF GÖREV — NET-02

> Bu dosya SeaCraft'ın kanonik aktif uygulama briefidir. Sohbette uzun brief tekrarlanmaz.
>
> Görev tamamlandığında ayrıntılı doğrulama sonucu **yalnız** `GOREV_RAPORU.md` dosyasına, mevcut geçmiş korunarak yeni bir NET-02 bölümü halinde yazılır. Sohbet cevabı kısa tutulur.

## Kimlik

- Sohbet etiketi: `[SOHBET-29 | SeaCraft NET-02 — Spawn, Snapshot ve Temel State Replikasyonu]`
- Repo: `TheOsmanYILDIRIM/SeaCraft`
- Dal: yalnız `main`
- Başlangıç HEAD: `ffb26ca62aa7e17ac82e0a6329bcb131f5ca6bd8`
- NET-01 exact gameplay close: `180282bdc00fca5d40af40943c1fe59d949d7f23`
- Godot: `4.7.2-stable`
- Bağımlılık: NET-01 tamamlandı
- Sonraki göreve geçme: **NET-03'e başlama**

Başlangıç HEAD, NET-01 exact close'un iki commit ilerisindedir. Aradaki değişiklikler `GOREV_RAPORU.md` kapanış raporu ve `SC08_SUPPORT_ANCHOR_FINAL.zip` görsel paketiyle sınırlıdır; bunları ezme veya silme.

Her mesajına yukarıdaki sohbet etiketiyle başla.

## Yürütme

İşi aynı oturumda uygula → doğrula → hata varsa kök nedeni düzelt → yeniden doğrula → exact-commit Actions → export → artifact readback → Beyin kapanışı → `GOREV_RAPORU.md` NET-02 bölümü şeklinde tamamla.

Başlamadan güncel `main` HEAD'i ve diff'i yeniden doğrula. Başka sohbetin değişikliğini ezme.

Avenox Beyin'de NET-02 görevi varsa onu kullan; yoksa tek kanonik task aç. Mükerrer task/receipt oluşturma.

---

# 1. HIZ PROTOKOLÜ — ZORUNLU

NET-01'de 6 Actions run / 5 failure oluştu. NET-02 hedefi:

**1 implementation commit + 1 successful Actions run.**

Gerçek zorunluluk çıkarsa tüm kök nedenleri tek correction commit'inde çöz.

İlk committen önce gerçek diff üzerinde local/statik preflight yap. Özellikle NET-01'de yaşanan hataları tekrar etme:

- native/built-in method isim çakışmaları
- custom MainLoop altında `Node.multiplayer` varsayımı
- SceneTree gerektiren RPC'yi script-only harness'ta çalıştırma
- bare `quit()` / parser hatası
- explicit GDScript type eksikleri
- Variant→typed Array/Dictionary dönüşümü
- int/float JSON normalization
- exact DTO field count
- ANSI log normalization/verifier uyuşmazlığı
- test fixture marker sayısı
- process timeout/readiness cleanup

Network process harness normal SceneTree yolunu kullansın; kanıtlanmış NET-01 harness yapısını mümkün olduğunca reuse et.

Dosya/test/verifier/README/CI için ayrı ayrı commit yapma.

CI fail olursa ilk hataya göre commit atma. İlgili parse/GUT/process/verifier/export loglarının tamamını incele, tek correction patch hazırla.

---

# 2. KANONİK AMAÇ

Plan:

**NET-02 — Spawn, snapshot ve temel state replikasyonu**

Amaç:

Host authoritative world state'i clientlara stable ID ile replike etmek:

- player
- NPC ship
- monster
- loot/world pickup

Minimum sistemler:

- `NetworkEntityRegistry`
- host-only spawn/despawn
- stable-ID proxy lifecycle
- transform/state snapshot
- bounded interpolation buffer
- combat/loot event replication
- sector/AOI visibility
- snapshot ordering/loss guard
- payload byte/frequency telemetry

Kabul:

- host tek spawn/despawn kaynağı
- late-spawned entity iki clientta aynı stable ID ile görünür
- despawn clientlarda ghost bırakmaz
- client authored spawn/HP/state mutasyonu reddedilir
- stale/out-of-order snapshot authoritative state'i geri sarmaz
- AOI dışı entity görünmez
- Resource/Object/RID ağ şemasına girmez

NET-03'e başlama.

---

# 3. NET-01 CONTRACT'I KORU

Mevcut production network katmanı:

- `SessionProtocol`
- `SessionHost`
- `SessionClient`
- `SessionRpcBridge`

korunacak.

NET-01'in:

- protocol/content handshake
- host-owned peer→player mapping
- replay guard
- spoof rejection
- manual IPv4
- offline boot
- simulation/network boundary

kurallarını zayıflatma.

Client hâlâ outcome authority değildir.

---

# 4. NETWORK / SIMULATION SINIRI

`src/simulation/**`, `src/data/**`, `src/persistence/**` network API'siz kalmalı.

Networking yalnız `src/network/**` boundary altında.

Simulation gerekirse readonly primitive snapshot API sağlayabilir; ancak:

- RPC bilmez
- peer ID bilmez
- MultiplayerAPI bilmez
- replication cadence bilmez

Network adapter mevcut simulation state'ini **okur**, mutation authority olmaz.

---

# 5. NETWORK ENTITY REGISTRY

Authority-owned/mirror-aware `NetworkEntityRegistry` veya eşdeğer oluştur.

Her replicated entity için minimum:

- stable `entity_id`
- `entity_kind`
- `sector_id`
- definition/reference ID gerekiyorsa
- spawn generation / lifecycle sequence
- active/despawn state
- host snapshot source/adaptor
- client proxy reference yalnız network/presentation boundary içinde

Entity kinds minimum:

- `player`
- `npc`
- `monster`
- `loot`

Gerekirse wreck/world-object aynı primitive category/tag ile temsil edilebilir; ikinci world-object truth oluşturma.

Registry stable ID'nin tek network lifecycle kaynağı olsun.

---

# 6. HOST TEK SPAWN KAYNAĞI

Client spawn isteği kabul edilmez.

Host:

- authoritative entity mevcut/eligible olduğunda
- stable ID doğrulanınca
- registry duplicate guard geçince

network proxy spawn eder.

Client yalnız hosttan gelen lifecycle'ı mirror eder.

Client tarafında local `add_child` ile authoritative network entity yaratıp registry'ye yazma yolu olmamalı.

---

# 7. MULTIPLAYERSPAWNER

Godot 4.7 built-in `MultiplayerSpawner` kullan.

Spawner network boundary içindeki dedicated replicated root'u yönetebilir.

Spawn data primitive-safe olsun.

Spawn payload minimum:

- entity_id
- entity_kind
- sector_id
- initial transform/state sequence
- readonly visual/definition reference ID gerekiyorsa

Resource/Object/Node/RID payload içinde gönderilmez.

Custom `spawn_function` kullanılıyorsa Godot 4.7 gerçek API/syntaxını committen önce doğrula.

Stable entity ID node name'e kör bağımlılık olmasın; explicit property/registry key olsun.

---

# 8. MULTIPLAYERSYNCHRONIZER + CUSTOM SNAPSHOT SINIRI

T03 gereği built-in `MultiplayerSynchronizer` kullanılabilir; fakat authority contract net olsun.

Tercih edilen model:

- `MultiplayerSpawner`: lifecycle/spawn/despawn
- `MultiplayerSynchronizer`: yalnız güvenli düşük maliyetli primitive proxy alanları gerekiyorsa
- custom bounded snapshot DTO: transform/state stream, sequence, AOI ve telemetry

Aynı property için iki bağımsız replication truth yaratma.

Eğer custom snapshot bir alanın tek kaynağıysa Synchronizer aynı alanı ayrıca yazmasın.

README'de hangi alanın hangi kanaldan geldiği açık olsun.

---

# 9. NETWORK ENTITY PROXY

Client tarafındaki proxy presentation/mirror nesnesidir.

Authoritative simulation entity değildir.

Minimum primitive state:

- entity_id
- entity_kind
- sector_id
- x/y
- heading
- velocity gerekiyorsa
- hull_ratio
- alive
- state/snapshot sequence
- target/status gibi minimum okunabilir semantic state gerekiyorsa

Proxy:

- CombatAuthority'ye damage yazamaz
- ShipMotor authority yazamaz
- LootAuthority mutate edemez
- simulation registry'ye authoritative entity ekleyemez

---

# 10. AUTHORITATIVE SNAPSHOT SOURCE

Network katmanı private simulation internals'a doğrudan erişmesin.

Mevcut readonly/presentation snapshot API'lerini reuse et:

- ShipMotor motion/position state
- NpcBrain/NpcStatePresenter için primitive AI snapshot
- CombatAuthority için readonly combat facts
- WorldObjectAuthority presentation snapshot
- LootAuthority readonly drop snapshot

Gerekli eksik bilgi varsa simulation'a network-agnostic readonly primitive snapshot metodu eklemek serbest.

Private `_roster`, `_drops`, `_objects` gibi alanları network katmanından hack'leme.

---

# 11. SNAPSHOT DTO

Tek versioned snapshot schema oluştur.

Minimum top-level:

- protocol version
- snapshot sequence
- server tick
- sector/AOI identifier
- entity rows

Entity rows stable ID'ye göre deterministic sıralansın.

Row minimum:

- entity_id
- entity_kind
- sector_id
- x
- y
- heading
- hull_ratio
- alive

Kind'e özel ekstra alanlar açık bounded alt sözleşmeyle eklenebilir.

DTO primitive-safe ve object-free olmalı.

---

# 12. SNAPSHOT SEQUENCE

Host monotonic snapshot sequence üretir.

Client:

- yeni sequence → kabul
- aynı sequence → ignore
- eski sequence → ignore

Stale packet entity state'i geri saramaz.

Sequence overflow policy explicit olsun.

Wall-clock authority kullanma.

---

# 13. SNAPSHOT CHANNEL

NET-01'de ayrılmış:

`SessionProtocol.CHANNEL_SNAPSHOT = 2`

kullan.

Snapshot RPC:

**authority → clients**

ve:

**unreliable ordered**

olmalı.

Godot 4.7 RPC annotation/channel syntaxını gerçek API ile doğrula.

Client→host snapshot RPC yolu oluşturma.

---

# 14. SNAPSHOT CADENCE

Mobile-first explicit cadence/budget belirle.

Örneğin fixed simulation tick'e bağlı tunable `SNAPSHOT_INTERVAL_TICKS`.

Her physics frame ağ snapshotı zorunlu değil.

Telemetry:

- snapshots sent
- snapshots received
- snapshot entities
- payload bytes
- max payload bytes
- dropped/stale snapshots
- update interval

tutmalı.

CI bu sayıları gerçek Android performansı diye raporlamamalı.

---

# 15. PAYLOAD BYTE BUDGET

Snapshot DTO serialize edilmeden önce bounded.

Object encoding kapalı primitive Variant bytes veya eşdeğer güvenli ölçüm kullanılabilir.

Açık limits:

- max entities/snapshot
- max snapshot bytes
- max string length
- max nested fields

Budget aşılırsa:

- sınırsız packet gönderme
- sessiz truncate ile lifecycle bozma

yerine deterministic batching/AOI reduction/rejection policy kullan.

---

# 16. AOI

NET-02 minimum AOI sector-aware olmalı.

Peer mapping'den host player's authoritative sector/position türetilir.

Minimum visibility:

- same active sector
- bounded local radius veya açık sector visibility policy
- own player her zaman visible

Mevcut `SectorSpatialHash` varsa candidate discovery için reuse et.

Bütün dünya entity listesini her peer için her snapshotta full scan etme.

Far-field AI-04 records doğrudan clientta instantiate edilmemeli.

---

# 17. AOI STABLE VISIBILITY

AOI enter:

- host lifecycle/snapshot yoluyla entity görünür olur

AOI exit:

- client proxy despawn/hide edilir

Bu semantic death değildir.

AOI çıkışı world entity'yi authority'de silmez.

Gerçek entity despawn ile AOI visibility loss ayrımını açık tut.

---

# 18. SPAWN / DESPAWN LIFECYCLE

Host registry lifecycle sequence/idempotency kullan.

Duplicate same stable ID spawn:

- ikinci proxy oluşturmaz

Despawn:

- exact stable ID
- generation/sequence doğrulaması
- registry cleanup
- proxy cleanup

Client despawn sonrası ghost node/registry row bırakmamalı.

---

# 19. LATE SPAWN

İki client READY iken host yeni authoritative entity spawn etsin.

Her iki client:

- aynı stable entity ID
- aynı kind
- aynı initial state

görmeli.

Bu **late join** değildir.

Clientlar zaten oturumdadır; yalnız entity sonradan doğar.

Late join baseline NET-04 kapsamıdır.

---

# 20. PLAYER REPLICATION

Player proxy host ShipMotor'dan transform snapshot alır.

Client kendi player'ı için de authoritative snapshotı mirror eder.

NET-02'de prediction/reconciliation yazma.

Local input:

client intent → host authority → authoritative snapshot → client proxy.

---

# 21. NPC REPLICATION

NpcBrain yalnız hostta tick eder.

Client NPC brain oluşturmaz/çalıştırmaz.

Client:

- stable NPC ID
- transform
- hull/alive
- gerekirse detached intent/state telegraph

okur.

AI-01/02/03/04 clientta authority olarak çalıştırılmaz.

---

# 22. MONSTER REPLICATION

Monster actual CombatAuthority/sector state'inden host snapshot ile gelir.

Client monster HP/position yazamaz.

Monster kind/tag canonical `TargetingService.MONSTER` contract ile uyumlu olsun.

---

# 23. LOOT REPLICATION

Loot/drop stable IDs mevcut authority kaynaklarından gelir.

Host:

- loot spawn event/lifecycle
- loot claim/despawn event

replike eder.

Client loot miktarı/reward sonucu uyduramaz.

Claim authority hâlâ `LootAuthority` / `WorldObjectAuthority`.

NET-02 remote loot-claim gameplay intent eklemek zorunda değil; NET-03 full slice işi.

---

# 24. COMBAT EVENT REPLICATION

Mevcut `CombatAuthority` signals, özellikle:

- `hull_damaged`
- `ship_sunk`
- `monster_defeated`
- `wreck_destroyed`

network adapter tarafından primitive reliable event'e dönüştürülebilir.

Client event state'i authority değildir.

Event minimum:

- event_id / sequence
- event_type
- source_id
- target_id
- amount/remaining hull gerekiyorsa

Reliable gameplay/control channel kullan.

Duplicate event clientta ikinci kez uygulanmamalı.

---

# 25. LOOT EVENT REPLICATION

Mevcut LootAuthority signals:

- drop_created
- drop_claimed

ve world-object semantic lifecycle kullanılabilir.

Reliable idempotent event ID kullan.

Client duplicate event ile ikinci loot proxy yaratmamalı.

---

# 26. EVENT / SNAPSHOT AYRIMI

Snapshot:

- sık
- current state
- unreliable ordered
- stale ignore

Event:

- seyrek
- semantic one-shot
- reliable
- idempotent/event sequence

Damage event kaybolmamalı; transform snapshot için reliable spam yapma.

---

# 27. INTERPOLATION BUFFER

Client presentation proxy için bounded interpolation buffer ekle.

Minimum:

- last accepted 2–4 transform samples
- server tick/sequence
- finite positions
- bounded max samples

Stale/out-of-order sample buffer'ı geri sarmasın.

Interpolation client visual only.

Simulation state'e yazma.

Extrapolation gerekiyorsa bounded; zorunlu değil.

---

# 28. SNAPSHOT LOSS / ORDER TEST

Unit fixture gerçek UDP paket kaybına güvenmek zorunda değil.

Client snapshot consumer'a sıralı/sırasız sequence besle:

- 10 accepted
- 12 accepted
- 11 ignored
- 12 duplicate ignored
- 13 accepted

Final state sequence 13.

Buffer bound aşılmamalı.

---

# 29. CLIENT MUTATION REJECTION

NET-02 kritik negatif kapı.

Client şunları authoritative olarak gönderemez:

- spawn entity
- despawn entity
- set HP
- set hull
- set position
- set NPC state
- create loot
- claim result

Production network bridge'de client→host bu RPC'ler hiç bulunmamalı veya authority-only contract nedeniyle reddedilmeli.

Real process malicious fixture client-authored spawn ve HP mutation denesin; host state değişmemeli.

NET-01 command envelope'a outcome type ekleme.

---

# 30. NETWORK ENTITY OWNERSHIP

Multiplayer authority ID ile gameplay owner ID'yi karıştırma.

Network proxy'nin Godot multiplayer authority'si host olabilir.

Gameplay player identity hâlâ SessionHost peer→player mapping'dir.

Client proxy authority almak için `set_multiplayer_authority(peer_id)` ile gameplay ownership devri yapma.

---

# 31. RESOURCES AĞDAN GİTMEZ

Network schema'da yasak:

- Resource
- Object
- Node
- RID
- Callable
- PackedScene object
- raw Definition Resource

Yalnız stable definition/content ID.

Client kendi local ContentManifest/DefinitionRegistry'den readonly asset tanımını çözebilir.

Handshake content hash zaten eşleşmeyi garanti eder.

---

# 32. ENTITY KIND / CONTENT VALIDATION

Spawn payload:

- stable ID valid
- kind allowlist
- sector stable ID
- definition/content ID gerekiyorsa canonical registry doğrulaması

Unknown kind/content reject.

Client malformed spawn ile crash olmamalı.

---

# 33. REAL PROCESS INTEGRATION

NET-01 normal SceneTree process harness'ını reuse et.

NET-02 Actions gerçek ENet/RPC process integration çalıştırsın.

Minimum:

- 1 host
- 2 clients
- localhost
- ikisi de NET-01 handshake READY
- host authoritative entity registry aktif

Arbitrary sleep yerine readiness marker/deadline.

PID/trap cleanup korunmalı.

---

# 34. REAL PROCESS SCENARIO

Minimum gerçek süreç akışı:

1. host starts
2. client A connects
3. client B connects
4. ikisi READY
5. host player/NPC/monster/loot proxy setini spawn eder
6. iki client aynı stable IDs görür
7. host entity transform/hull snapshot yollar
8. clientlar aynı newer sequence state'i görür
9. host session sırasında yeni entity spawn eder
10. iki client aynı late-spawn ID görür
11. host bir entity despawn eder
12. iki client registry/proxy'den temizler
13. malicious client spawn/HP mutation denemesi yapar
14. host authoritative state değişmez
15. clean shutdown

---

# 35. AOI PROCESS/UNIT FIXTURE

En az iki sector/AOI grubu kullan.

Client A player sector A'da.

Entity:

- same sector + near → visible
- same sector + outside radius → policy'ye göre invisible
- other sector → invisible

Client B farklı authoritative position/sector ile farklı visibility set alabilsin.

AOI filtering host source'dur.

Client “beni şu sectordayım” diye visibility seçemez.

---

# 36. SNAPSHOT BYTE/FREQUENCY FIXTURE

CI fixture bounded entity set ile loglasın:

- peers
- replicated entities
- spawned
- despawned
- snapshots sent
- max entities/snapshot
- max snapshot bytes
- snapshot interval ticks
- stale ignored
- interpolation max samples
- reliable combat events
- reliable loot events
- rejected client mutations

Bu gerçek cihaz bandwidth benchmark değildir.

---

# 37. MULTIPLAYERSPAWNER NEGATİF KAPI

Spawner'ın spawn yolu yalnız hostta çağrılmalı.

Client local registry API ile spawn üretse bile bu authoritative host registry'yi etkilememeli ve diğer peer'lere yayılmamalı.

Gerçek process test bunu mümkün olduğunca doğrulasın.

---

# 38. MULTIPLAYERSYNCHRONIZER GÜVENLİĞİ

Synchronizer kullanılıyorsa root path/properties yalnız network proxy presentation state'i olmalı.

Simulation/CombatAuthority private state'i doğrudan synchronize etme.

Client property write authority olmamalı.

`public_visibility` / visibility filter kullanılıyorsa AOI hostta kontrol edilmeli.

---

# 39. OFFLINE REGRESSION

Default boot hâlâ:

- SessionHost başlatmaz
- SessionClient başlatmaz
- NetworkEntityRegistry socket açmaz
- MultiplayerSpawner session oluşturmaz

Offline VS-04 davranışı değişmemeli.

---

# 40. LAN SINIRI

NET-02'de henüz:

- prediction
- reconciliation
- reconnect
- late join baseline
- discovery
- transaction replay recovery
- full remote combat/loot input parity

yok.

Bunlar NET-03/NET-04.

---

# 41. TEST STRATEJİSİ

Mevcut **305 test korunmalı**.

NET-02 için tercihen 10–14 güçlü test.

Minimum:

1. entity registry stable ID/idempotency
2. spawn DTO primitive/content validation
3. host-only spawn/despawn
4. snapshot ordering/stale rejection
5. interpolation bounded buffer
6. AOI visibility
7. combat event idempotency
8. loot lifecycle/event idempotency
9. client mutation rejection
10. payload byte/entity budget
11. offline/network boundary
12. real host + 2 clients integration

Mikro-test sayısı şişirme.

---

# 42. CI MARKERLARI

Açık marker üret:

- `NET02_ENTITY_REGISTRY_OK`
- `NET02_HOST_SPAWN_OK`
- `NET02_SNAPSHOT_ORDER_OK`
- `NET02_INTERPOLATION_OK`
- `NET02_AOI_OK`
- `NET02_COMBAT_EVENT_OK`
- `NET02_LOOT_EVENT_OK`
- `NET02_CLIENT_MUTATION_REJECT_OK`
- `NET02_BUDGET_OK`
- `NET02_PROCESS_INTEGRATION_OK`

NET-02 verifier:

- tek GUT logunu
- gerçek process integration logunu

birlikte doğrulasın.

NET-01'de çalışan ANSI normalization/harness parser kodunu aynen reuse et.

---

# 43. REGRESSION

Exact NET-02 committe:

- NET-01 10/10 + real process integration
- AI-04 10/10
- AI-03 10/10
- AI-02 11/11
- AI-01 10/10
- CORE-04/03/02/01
- VS-04 checkpoint/replay/soak

geçmeli.

Beehave orphan = 0.

NET-01 spoof/replay/content/protocol mismatch kapıları kaybolmamalı.

---

# 44. CI NETWORK GUARD

Mevcut network boundary guard korunacak.

Ek olarak static guard mümkünse şunları yakalasın:

- `@rpc("any_peer"` ile state/spawn mutation handler
- network boundary dışı MultiplayerSpawner/MultiplayerSynchronizer
- client-side simulation authority write
- Resource/Object network DTO kullanımı

Yanlış pozitif üretip normal simulation kodunu bozma.

---

# 45. CI SÜRE / COMMIT OPTİMİZASYONU

NET-01 process harness ve export setup'ını yeniden icat etme.

Full GUT tek kez çalışsın.

NET-01 + NET-02 verifier aynı GUT logunu kullansın.

Process integration mümkünse tek host process lifecycle'ında ilgili NET-02 scenario'ları çalıştırsın; her assertion için yeni host başlatma.

Mismatch/spoof NET-01 regressions ayrı process başlatmayı gerektiriyorsa mevcut kanıtlanmış harness'i koru ama gereksiz tekrar ekleme.

---

# 46. COMMIT ÖNCESİ PREFLIGHT

İlk implementation committen önce gerçek diff üzerinde tek tek doğrula:

- current HEAD hâlâ doğru
- NET-01 files üzerine güvenli extension yapılmış
- native method/class name collision yok
- bütün yeni RPC Nodes normal SceneTree altında
- MultiplayerSpawner spawn path gerçek NodePath
- custom spawn_function signature Godot 4.7.2 ile doğru
- MultiplayerSynchronizer API/property names Godot 4.7.2 ile doğru
- channel 2 gerçekten unreliable ordered
- authority→client RPC annotation doğru
- client→host state mutation RPC yok
- snapshot exact schema testle aynı
- sequence types explicit int
- JSON/Variant roundtrip numeric normalization
- stable entity IDs SectorIds contract ile uyumlu
- AOI fixture authoritative sector/position kullanıyor
- process harness 1 host + 2 clients için port/readiness doğru
- client process args parse ediliyor
- all process exits use SceneTree-safe `get_tree().quit(code)` veya kanıtlanmış eşdeğer
- shell trap bütün PID'leri temizliyor
- verifier ANSI normalization NET-01 çalışan yöntemle aynı
- GUT expected total doğru
- CI markers exact
- artifact adı NET02
- README NET-03/04 özelliklerini yapılmış göstermiyor

Belirsiz bir madde varsa commit atma; önce düzelt.

---

# 47. ARTIFACT

Artifact adı:

`SeaCraft-NET02-<exact SHA>`

İçerik:

- `COMMIT_SHA.txt`
- `SHA256SUMS.txt`
- Android APK
- Linux executable
- Linux PCK

Upload sonrası authenticated readback yap.

ZIP, APK, Linux ve PCK hashlerini tekrar doğrula.

---

# 48. ANDROID

Mevcut INTERNET permission korunmalı.

Gerçek cihaz kapıları `not_run`:

- Android client Wi-Fi snapshot jitter
- Android host 2 clients
- interpolation frame pacing
- 20+ replicated entities
- snapshot bandwidth/CPU
- spawn/despawn burst
- network loss
- background/foreground

CI bunları passed diye raporlamaz.

---

# 49. README

Yalnız gerçekten uygulanan NET-02'yi belge:

- host-only NetworkEntityRegistry
- MultiplayerSpawner lifecycle
- Synchronizer/custom snapshot field ownership
- stable IDs
- player/NPC/monster/loot proxy model
- unreliable ordered snapshots
- reliable combat/loot events
- AOI
- interpolation
- payload telemetry
- client mutation rejection
- offline behavior
- NET-03/04 kapsam dışı

---

# 50. BEYİN KAPANIŞI

NET-02 task başlangıçta bir kez açılır.

Ara CI failure için Beyin update yapma.

Final exact commit + successful Actions + artifact readback sonrası:

- task final update
- tek receipt
- geri okuma

yap.

Task facts minimum:

- exact main SHA
- implementation/correction commits
- Actions run counts
- total tests / NET-02 tests
- host+2 clients integration
- stable spawn/despawn
- late spawn same ID
- stale snapshot rejection
- interpolation bound
- AOI
- combat/loot events
- client spawn/HP mutation rejection
- snapshot budget metrics
- NET-01 regression
- AI/CORE/VS regressions
- orphan count
- artifact ID/name/hashes
- real Android `not_run`
- NET-03 `not_started`

---

# 51. GOREV_RAPORU.md

Görev bitince mevcut rapor geçmişini **koru**.

Aynı dosyaya yeni:

`## NET-02 — ...`

bölümü ekle.

Yeni rapor dosyası oluşturma.

Bölümde yalnız doğrulanmış kanıtlar:

- exact SHA
- commit/run sayıları
- tests
- process integration
- registry/spawn/despawn
- snapshot ordering
- interpolation
- AOI
- events
- mutation rejection
- byte/frequency telemetry
- regressions
- orphan
- export
- artifact hashes
- Beyin closure
- Android `not_run`

olsun.

Sohbet cevabına bu uzun raporu kopyalama.

---

# SON KAPI

NET-02 ancak gerçek kanıtla tamamdır:

- NET-01 authority sınırı korunmuş
- host tek spawn/despawn kaynağı
- player/NPC/monster/loot stable ID ile replike
- lifecycle duplicate spawn üretmiyor
- late-spawn entity iki hazır clientta aynı ID
- despawn ghost bırakmıyor
- snapshot sequence monotonic
- stale/out-of-order snapshot geri saramıyor
- snapshot channel unreliable ordered
- semantic combat/loot eventleri reliable ve idempotent
- interpolation bounded ve presentation-only
- AOI host authoritative
- AOI dışı entity görünmüyor
- far-field dünya clientta full instantiate edilmiyor
- Resource/Object/RID network DTO yok
- client spawn/HP/position/state outcome yazamıyor
- malicious client mutation host state'i değiştirmiyor
- snapshot payload/entity/frequency budget bounded
- gerçek 1 host + 2 client process integration geçiyor
- NET-01 regressions geçiyor
- AI-04/03/02/01 geçiyor
- CORE-04/03/02/01 geçiyor
- VS-04 geçiyor
- orphan=0
- offline boot ağsız çalışıyor
- Linux export/boot geçiyor
- Android arm64 export ve INTERNET permission geçiyor
- exact artifact readback geçiyor
- Beyin task+receipt geri okunuyor
- `GOREV_RAPORU.md` NET-02 kanıtlarıyla güncel

Eksikse düzeltmeye devam et.

**NET-03'e başlama.**

## Nihai sohbet cevabı

Yalnız kısa söyle:

- NET-02 tamamlandı / engel
- exact SHA
- Actions success run
- test total
- artifact
- ayrıntılı raporun `GOREV_RAPORU.md` dosyasında olduğu

Uzun kapanış raporunu sohbete yazma.
