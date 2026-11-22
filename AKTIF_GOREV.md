# AKTİF GÖREV — NET-04

> Bu dosya SeaCraft'ın kanonik aktif uygulama briefidir. Sohbette uzun brief tekrarlanmaz.
>
> Görev tamamlandığında ayrıntılı doğrulama sonucu yalnız `GOREV_RAPORU.md` dosyasına, mevcut geçmiş korunarak yeni bir NET-04 bölümü halinde yazılır. Sohbet cevabı kısa tutulur.

## Kimlik

- Sohbet etiketi: `[SOHBET-31 | SeaCraft NET-04 — Discovery, Reconnect, Late Join ve LAN Transaction Hardening]`
- Repo: `TheOsmanYILDIRIM/SeaCraft`
- Dal: yalnız `main`
- Başlangıç HEAD: `64768818e577e2a452aa45cebad90f53d86f9b3e`
- NET-03 exact kod kapanışı: `f0cd18727870d6d49b961c758e49660e53770479`
- Godot: `4.7.2-stable`
- Bağımlılık: NET-03 tamamlandı
- Sonraki göreve geçme: **WAVE 6 / progression görevlerine başlama**

Başlangıç HEAD, NET-03 exact kod SHA'nın yalnız `GOREV_RAPORU.md` kapanış commit'i kadar ilerisindedir. Geçmiş raporu koru.

Her mesajına yukarıdaki sohbet etiketiyle başla.

## Yürütme

İşi aynı oturumda uygula → doğrula → hata varsa kök nedeni toplu düzelt → exact-commit Actions → export → artifact readback → Beyin kapanışı → `GOREV_RAPORU.md` NET-04 bölümü şeklinde tamamla.

Başlamadan güncel `main` HEAD'i yeniden doğrula. Başka sohbetin değişikliğini ezme.

Avenox Beyin'de NET-04 görevi varsa onu kullan; yoksa tek kanonik task aç. Mükerrer task/receipt oluşturma.

---

# 1. Hız protokolü

NET-03 iki kod commit'i / iki Actions run ile kapandı. NET-04 hedefi:

**1 implementation commit + 1 successful Actions run.**

Gerçek zorunluluk çıkarsa bütün kök nedenleri mümkün olduğunca tek correction commit'inde çöz.

İlk committen önce gerçek diff üzerinde preflight yap. Önceki NET görevlerindeki bilinen hata sınıflarını tekrar etme:

- Godot 4.7 API imzaları
- SceneTree gerektiren multiplayer/RPC kodunu custom MainLoop altında çalıştırma
- typed `Array[String]` / Dictionary uyumsuzluğu
- JSON int/float normalization
- exact DTO key/field sayıları
- `var_to_bytes()` Godot 4.7 tek-arg contract
- event/stable ID biçimi
- sequence rollover / stale sequence
- parser ANSI normalization
- shell readiness/timeout/PID cleanup
- native/built-in method isim çakışmaları
- bare `quit()`

NET-01/02/03'ün çalışan process harness'larını ve verifier normalizasyonunu yeniden icat etme.

Diagnostic commit üretme.

---

# 2. Kanonik amaç

Plan:

**NET-04 — Discovery, reconnect, late join ve LAN transaction hardening**

Amaç:

- LAN hostlarını UDP discovery ile bulmak
- manuel IPv4 yolunu korumak
- kısa bağlantı kopuşundan sonra aynı oyuncuyu güvenli biçimde resume etmek
- late join clienta güncel authoritative baseline vermek
- reconnect/retry altında loot ve sonraki host-mutating progression işlemlerinin duplicate reward üretmesini engellemek
- Android 17 / target SDK 37 local-network permission davranışına hazırlanmak
- bozuk/sahte discovery paketlerinin ENet oturumunu etkilemesini engellemek

Mekanik katalog:

- M-027
- M-028
- M-031
- M-047
- M-056
- M-058

**WAVE 6 progression/quest sistemini burada geliştirme.**

---

# 3. Mevcut sözleşmeleri koru

Korunacak production katmanları:

- `SessionProtocol`
- `SessionHost`
- `SessionClient`
- `SessionRpcBridge`
- `NetworkEntityRegistry`
- `NetworkEntityProxy`
- `NetworkReplicationPeer`

NET-01:

- compatibility handshake
- host-owned peer→player mapping
- spoof/replay guard
- manual IPv4

NET-02:

- stable-ID lifecycle
- snapshot sequencing
- AOI
- reliable semantic events

NET-03:

- remote move/target/fire/loot intents
- host-derived actor/heading
- host-only AI
- once-only loot semantics
- combat disconnect behavior

zayıflatılmayacak.

Simulation/data/persistence katmanlarına ENet/RPC/PacketPeerUDP bağımlılığı ekleme.

---

# 4. Protocol version

NET-04 reconnect/baseline handshake alanları mevcut exact-shape wire contract'ı değiştireceği için `SessionProtocol.PROTOCOL_VERSION` bump et.

Eski NET-03 client build'i yeni hostla sessizce bağlanmamalı.

Protocol mismatch mevcut deterministic reject davranışını korusun.

Save schema ile network protocol versionı birbirine bağlama.

---

# 5. Discovery mimarisi

Godot built-in:

`PacketPeerUDP`

kullan.

Discovery socket'i ENet game socket'inden tamamen ayrı olmalı.

Minimum üretim sınıfları:

- `LanDiscoveryProtocol` — pure encode/parse/validate
- `LanDiscoveryHost` — beacon yayınlar
- `LanDiscoveryClient` — listen/cache/TTL
- gerekiyorsa küçük `LanPermissionGate`

Discovery sınıfları `src/network/**` altında kalmalı.

mDNS/SSDP/A01 üçüncü parti çözüm ilk tercih değildir.

---

# 6. Discovery port

Discovery port game ENet portundan ayrı sabit/konfigüre port olmalı.

Kurallar:

- game port ile discovery port aynı olamaz
- `SessionProtocol.valid_port()` benzeri bounded validation
- bind failure açık sonuç verir
- port collision session hostu bozmaz
- discovery kapatılsa manuel IPv4 ENet yolu değişmeden kalır

CI test portları environment üzerinden override edilebilir.

---

# 7. Discovery beacon

Beacon raw UDP bytes olarak gönderilsin.

Object/Variant deserialization kullanma; bounded UTF-8 JSON veya eşdeğer object-free encoding tercih et.

Maximum beacon:

**512 byte**

Exact packet alanları minimum:

- magic
- discovery_version
- protocol_version
- schema_version
- content_version
- rng_stream_version
- content_manifest_algorithm
- content_hash
- manifest_entry_count
- session_id
- host_name
- game_port
- player_count
- max_players

Host name maksimum 32 UTF-8 karakter/byte sınırıyla sanitize edilmeli.

Beacon içinde ASLA bulunmayacak:

- reconnect/resume token
- save path
- filesystem data
- player inventory
- peer ID
- auth secret
- machine username
- absolute path

---

# 8. Discovery compatibility

Client beaconı parse ettikten sonra mevcut canonical compatibility stamp ile karşılaştırsın.

Compatible olmak için minimum:

- discovery version
- protocol version
- schema version
- content version
- RNG stream version
- manifest algorithm/hash/count

eşleşmeli.

Incompatible beacon:

- crash oluşturmaz
- otomatik connect edilmez
- istenirse `compatible=false` olarak UI/model için tutulabilir
- ENet handshake'i bypass edemez

Discovery compatibility ENet handshake'in yerine geçmez; handshake yine zorunlu.

---

# 9. Discovery cadence / TTL / budget

Mobile-first bounded değerler tanımla.

Önerilen production başlangıcı:

- beacon interval: 500 ms
- TTL: 2000–3000 ms
- max visible sessions: 16
- max packets processed/frame: 8
- per-source/global packet rate budget

Kesin değerleri kodda constant ve testable yap.

TTL göndericinin timestamp'ine güvenmez.

Client kendi monotonic `Time.get_ticks_msec()` last-seen zamanını kullanır.

Expired session cache'den deterministik çıkar.

---

# 10. Broadcast davranışı

Production discovery default:

- `PacketPeerUDP.set_broadcast_enabled(true)`
- LAN broadcast destination
- ayrı discovery port

olabilir.

CI'da broadcast routing flakiness yaratmamak için production sınıfına **test-only olmayan**, genel configurable destination API verilebilir ve process testinde `127.0.0.1` kullanılır.

Parser/socket yolu aynı production kodu olmalı; mock discovery başarı sayılmaz.

Manual IPv4 fallback her zaman korunmalı çünkü guest Wi-Fi/AP isolation broadcastı engelleyebilir.

---

# 11. Discovery güvenlik sınırı

Discovery internet-auth, encryption veya secure service discovery değildir.

Sahte LAN beaconı mümkün kabul edilir.

Bu nedenle beacon:

- yalnız öneri/listing
- authority vermez
- reconnect token taşımaz
- ENet compatibility handshake'i bypass etmez

Host adını güvenilir kimlik sayma.

---

# 12. Discovery parser hardening

`LanDiscoveryProtocol.parse_packet()` pure/bounded olmalı.

Reddet:

- empty packet
- >512 byte
- invalid UTF-8
- invalid JSON/encoding
- array/scalar root
- missing key
- extra key
- wrong type
- NaN/Inf
- huge string
- invalid port
- invalid session ID
- invalid content hash
- negative player count
- player_count > max_players
- max_players > protocol max
- wrong magic/version

Parser hiçbir durumda ENet/session state mutate etmemeli.

---

# 13. Discovery fuzz

Deterministic fuzz corpus çalıştır.

Minimum:

- fixed seed
- >= 2000 malformed/random packets
- edge-length packets
- nested JSON
- invalid UTF-8
- valid packet mutations
- duplicate/extra/missing fields

Kabul:

- crash yok
- hang yok
- oversized allocation yok
- invalid packet accepted değil
- mevcut ENet session etkilenmiyor

Marker:

`NET04_DISCOVERY_FUZZ_OK`

---

# 14. Session identity

Host start edildiğinde tek session-scoped stable ID üret.

Format:

`session.<bounded-random-id>`

ve `SectorIds.valid()` contractına uyumlu olsun.

Aynı host process/session süresince sabit.

Host stop/restart yeni session ID üretir.

Bu ID mevcut `SaveSnapshot.ownership.session_id` contractıyla uyumlu kullanılmalı; ikinci session-ID sistemi yaratma.

---

# 15. Reconnect capability token

İlk başarılı client sessionında host:

- session_id
- reconnect/resume token
- mapped player_id
- sequence resume bilgisi

döndürsün.

Token:

- en az 128 bit unpredictable entropy
- `Crypto.generate_random_bytes()` veya Godot 4.7'de doğrulanmış eşdeğer
- bounded text encoding
- beacon/log/telemetry'de raw yazılmaz
- hostta tercihen raw yerine hash/digest tutulur

Token **LAN capability token**dır; encryption/login/anti-cheat değildir.

---

# 16. Handshake reconnect alanları

Client hello exact-shape sözleşmesine bounded resume alanları ekle.

Fresh join:

- session_id = empty
- resume_token = empty

Reconnect:

- önceki session_id
- resume_token

gönderir.

Client player_id göndermez.

Host actor mapping yine kendi reservation state'inden türetilir.

---

# 17. Reconnect reservation

Disconnect olduğunda mevcut davranıştaki peer mapping temizliği korunur fakat player slot hemen başka clienta verilmemeli.

Host bounded grace reservation tutmalı.

Öneri:

`RECONNECT_GRACE_MS = 30000`

Reservation minimum:

- session_id
- player_id
- token digest
- expires_at
- last accepted client sequence
- transaction state reference/watermark

Grace süresince reserved player yeni fresh peer'e verilmez.

Expired reservation deterministik temizlenir ve slot tekrar kullanılabilir.

---

# 18. Reconnect token kuralları

Reject reasons explicit:

- reconnect session mismatch
- reconnect token malformed
- reconnect token unknown
- reconnect token expired
- reconnect token already consumed

Başarılı reconnect:

- yeni transport peer ID → aynı player_id
- last sequence continuity korunur
- client authoritative entity silinmez
- fresh baseline gönderilir
- token rotate edilir
- eski token geçersizleşir

İki peer aynı tokenla yarışırsa yalnız biri kazanır.

---

# 19. Sequence continuity

Reconnect yeni peer ID aldığı için NET-01 replay guard sıfırlanmamalı.

Host reservation son accepted client sequence'i korur.

Handshake/baseline result clienta:

- resume/next sequence

bilgisi verir.

Client reconnect sonrası eski sequence'e dönmez.

Eski/replayed envelope reconnect sonrası da rejected.

---

# 20. Client reconnect API

`SessionClient` explicit bounded reconnect API kazansın.

Örnek semantic:

- `can_resume()`
- `resume(address, port)`
- `clear_resume_credentials()`

Automatic sonsuz retry loop yapma.

Reconnect credentials yalnız memory/session-scoped tutulur; disk/save içine raw token yazma.

Manual IPv4 address/port clientta korunabilir.

---

# 21. Late-join baseline state

Fresh late join client READY olmadan önce current authoritative baseline almalı.

Yeni state önerisi:

- connected
- handshaking
- baselining
- ready
- rejected

Client gameplay intent yalnız `ready` sonrası gönderir.

Handshake compatibility success tek başına READY değildir.

---

# 22. Baseline tek truth

Late-join baseline ikinci replication sistemi olmamalı.

Kaynak:

`NetworkEntityRegistry` + mevcut readonly authoritative snapshot source.

Baseline apply:

aynı client registry/proxy lifecycle kodunu reuse etmeli.

`MultiplayerSpawner` ve baseline aynı entity için iki bağımsız truth üretmemeli.

Gerekirse spawner transport olarak kullan; lifecycle/idempotency yine registry generation üzerinden.

---

# 23. Baseline payload

Reliable control channel üzerinde versioned bounded DTO.

Minimum header:

- protocol_version
- baseline_id
- session_id
- player_id
- server_tick
- snapshot_sequence
- event_sequence watermark
- resume_sequence
- chunk_index
- chunk_count
- entity payload rows/spawns

Baseline packet/chunk:

- primitive-safe
- exact shape
- stable IDs
- bounded entity count
- bounded byte size

Mevcut 96 replicated entity üst sınırını aşma.

Öneri:

- max 24–32 entities/chunk
- max 8192 byte/chunk

Kesin değerleri testle.

---

# 24. Baseline apply/ack

Client:

1. baseline begin
2. mevcut mirror registry'yi authoritative olarak değil mirror olarak resetler
3. chunkları exact baseline_id/index ile idempotent uygular
4. duplicate chunk ignore eder
5. missing/out-of-order invalid complete oluşturmaz
6. all chunks tamamlanınca current snapshot/event watermarkı set eder
7. baseline ack yollar

Host:

- ack'i gerçek peer'den alır
- baseline_id eşleşmesini doğrular
- sonra state READY yapar

Baseline ack control RPC olabilir; gameplay mutation değildir.

---

# 25. Late join semantic davranışı

World client join olmadan önce ilerlemiş olabilir.

Late join baseline şunları current state olarak göstermeli:

- mevcut player/NPC/monster/loot entity seti
- current hull/alive
- current transform
- current NPC semantic state
- mevcut AOI görünürlüğü
- daha önce claimed/despawn edilmiş loot **yok**
- geçmiş semantic eventler tekrar oynatılmaz

Event watermark baseline öncesi eventleri ignore ettirir.

---

# 26. Reconnect baseline

Reconnect client da fresh baseline almalı.

Amaç:

- disconnect süresinde kaçırdığı snapshot/eventleri current state ile toparlamak
- stale local proxy bırakmamak
- geçmiş damage/drop eventlerini yeniden işlememek

Reconnect baseline tamamlanmadan intent gönderilemez.

---

# 27. Transaction ID

Host-mutating retryable operationlar stable transaction ID kullanmalı.

NET-04 production kapsamındaki zorunlu işlem:

`pickup_loot`

Payload artık minimum:

- drop_id
- transaction_id

Actor/player identity yine payload'da yok.

Transaction ID bounded primitive string.

Client pending işlem ack gelmeden transport koparsa aynı transaction ID ile retry eder.

---

# 28. Host transaction ledger

Pure/bounded bir host transaction ledger oluştur.

Önerilen konum:

`src/network/host_transaction_ledger.gd`

RPC/Node dependency şart değildir; RefCounted pure-data olması tercih edilir.

Key semantic:

`mapped_player_id + transaction_id`

Ledger entry minimum:

- actor_id
- transaction_id
- operation kind
- request fingerprint
- committed result summary
- commit sequence

Max entry açık constant olsun; unbounded dictionary yok.

---

# 29. Transaction semantics

Aynı transaction ID + aynı actor + aynı operation/fingerprint:

- daha önce committed ise mutation tekrar çalışmaz
- cached terminal result döner

Aynı transaction ID farklı payload/operation ile tekrar kullanılırsa:

- `transaction conflict`
- mutation yok

Yeni transaction ID aynı claimed drop için:

- normal LootAuthority `already_claimed` guard
- reward yok

Böylece iki ayrı koruma kanıtlanır:

1. network retry idempotency
2. gameplay duplicate claim idempotency

---

# 30. Lost ACK senaryosu

Gerçek process testinde zorunlu.

Akış:

1. client loot claim transaction T gönderir
2. host claim'i commit eder ve inventory bir kez artar
3. client accepted response'u görmeden transport kesilir
4. host reservation/token state'i korur
5. client resume eder
6. client T'yi tekrar yollar
7. host cached committed result döner
8. LootAuthority ikinci kez çalışmaz
9. inventory quantity aynı kalır
10. ikinci drop/reward yok

Marker:

`NET04_TRANSACTION_IDEMPOTENCY_OK`

---

# 31. Transaction persistence

Ledger primitive snapshot/restore API taşısın.

Host save/checkpoint authoritative state içinde ledger state persist edilebilsin.

Mevcut `SaveSnapshot.authoritative_state` primitive-safe alanını reuse et.

Top-level save schema gereksiz yere değiştirme.

Eğer gerçek save contract değişikliği zorunlu olursa:

- `DataContractVersions.SCHEMA_VERSION` bump
- migration
- CORE-04 migration/regression

zorunlu.

Ama yalnız optional authoritative substate ile yapılabiliyorsa schema bump yapma.

---

# 32. Quest/progression kapsamı

NET-04'te quest sistemi, XP, reward UI veya progression gameplay yazma.

Ama transaction ledger generic olacak şekilde tasarlansın ki WAVE 6 host-mutating:

- quest reward
- contribution reward
- contract turn-in

gibi işlemler aynı apply-once sözleşmesini kullanabilsin.

Production allowlistte yalnız gerçekten implement edilen operation kind aktif olsun.

“Quest transaction hazır” diye olmayan sistemi yapılmış gösterme.

---

# 33. Late join + transaction ilişki

Late join clienta geçmiş transaction history göndermek zorunlu değil.

Baseline current world truth'u taşır.

Claim edilmiş loot baseline'da yok.

Reconnect eden **aynı session clientı** pending transaction retry için kendi transaction ID'sini memory'de tutar; host ledger authoritative karşılığıdır.

Raw full transaction ledger clienta replike edilmez.

---

# 34. Discovery + reconnect ilişki

Discovery session_id reconnect için yalnız session selection bilgisi olabilir.

Resume token discovery packetinde bulunmaz.

Client discovery sonucu aynı session_id'yi bulursa stored resume credential ile explicit resume deneyebilir.

Bulamazsa:

- manual IP ile resume denenebilir
- veya fresh join

UI/state layer karar verir.

---

# 35. Manual IPv4 fallback

NET-01 manual IPv4 yolu korunmalı.

Discovery başarısızsa kullanıcı:

- IP
- game port

ile bağlanabilmeli.

Discovery timeout hiçbir zaman manual join API'yi disable etmez.

Android 17 permission denied durumunda önemli ayrım:

**Manual IP UI/path erişilebilir kalır ama OS local-network permission olmadan gerçek LAN socket trafiği çalışmaz. Permission denial manual IP ile bypass edilmiş gibi gösterilmez.**

Kullanıcıya:

- permission gerekli
- tekrar izin iste
- offline devam et

durumu açık verilir.

---

# 36. Android 17 local-network permission

22 Kasım 2026 itibarıyla Android'in resmi davranışı:

- Android 17 = API 37
- target SDK 37+ uygulamalar için LAN trafiği default blocked
- runtime permission: `android.permission.ACCESS_LOCAL_NETWORK`
- UDP unicast/multicast/broadcast ve TCP LAN erişimi permission gerektirir
- target <=36 için INTERNET üzerinden legacy implicit behavior sürer; bu durumda ACCESS_LOCAL_NETWORK istememek gerekir

SeaCraft NET-04 artifact'i target SDK 37 olacak şekilde hazırlanmalı ve yeni permission path gerçek üretim kodunda bulunmalı.

Resmi Android kaynak:

https://developer.android.com/privacy-and-security/local-network-permission

---

# 37. Godot 4.7 Android export

Godot 4.7.2 resmi export API şu seçenekleri destekliyor:

- `gradle_build/use_gradle_build`
- `gradle_build/target_sdk`
- `permissions/custom_permissions`

Target SDK 37 gerektiği için Android export'u matching Godot 4.7 Gradle template ile target 37 üretecek şekilde kur.

Godot 4.7 command line:

`--install-android-build-template`

destekler.

CI matching 4.7.2 official `android_source.zip`/template kullanmalı; başka Godot sürümü template'i karıştırma.

Resmi Godot kaynakları:

https://docs.godotengine.org/en/4.7/classes/class_editorexportplatformandroid.html

https://docs.godotengine.org/en/4.7/tutorials/export/android_gradle_build.html

---

# 38. Android manifest/export

Mevcut:

`permissions/internet=true`

korunacak.

Target 37 artifactte manifestte minimum:

- `android.permission.INTERNET`
- `android.permission.ACCESS_LOCAL_NETWORK`

olmalı.

Godot 4.7'de yeni permission built-in toggle olarak yoksa:

`permissions/custom_permissions`

kullan.

UDP broadcast için Godot/cihaz davranışı gerektiriyorsa:

`permissions/change_wifi_multicast_state=true`

ekle ve README'de nedenini yaz.

CI APK/AAB badging/manifest readback ile:

- package
- arm64-v8a
- targetSdkVersion 37
- INTERNET
- ACCESS_LOCAL_NETWORK

doğrulasın.

---

# 39. Android runtime permission gate

LAN socket açmadan önce permission gate çalışmalı.

Godot 4.7'nin gerçek API'sini doğrula:

- `OS.request_permission("android.permission.ACCESS_LOCAL_NETWORK")`
- `MainLoop.on_request_permissions_result`

veya aynı sürümde doğrulanmış eşdeğer.

Permission yalnız kullanıcı LAN/discovery/host/join işlemi başlattığında istenir.

Offline boot sırasında permission dialog açma.

Desktop/Linux'ta Android permission kodu no-op/allowed semantic verir.

---

# 40. Permission denial

Android permission denied/revoked ise:

- discovery socket açma
- ENet host/join socket açma
- crash etme
- busy retry loop yapma
- offline oyun çalışmaya devam eder
- kullanıcıya bounded reason döner

Örnek reason:

`local_network_permission_denied`

Permission sonradan granted ise LAN action tekrar denenebilir.

---

# 41. Guest Wi-Fi / AP isolation

Permission granted olup:

- discovery host bulamıyor
- manual IP timeout oluyor

durumunu permission denial ile karıştırma.

Network diagnostics en az ayırt edebilmeli:

- permission denied
- discovery timeout
- ENet connection failed/timeout
- incompatible protocol/content

“Guest Wi-Fi/AP isolation olabilir” yalnız kullanıcı mesajı/README troubleshooting önerisidir; otomatik kesin teşhis yapma.

---

# 42. App pause/resume

NET-04 reconnect state machine Android background→foreground için hazır olmalı.

Pause sırasında:

- credential kaybolmaz
- raw token loglanmaz

Resume sırasında:

- transport disconnected ise explicit bounded reconnect API çağrılabilir

Sonsuz background polling yapma.

CI fiziksel Android lifecycle testi değildir.

---

# 43. Discovery real-process integration

CI gerçek UDP socket kullanmalı.

Minimum:

- discovery host process
- discovery client process
- production PacketPeerUDP classes
- test destination `127.0.0.1`
- ayrı discovery port
- compatible beacon bulunur
- exact session/game port görülür
- host beacon durunca TTL sonrası listeden çıkar

Marker:

`NET04_DISCOVERY_PROCESS_OK`

---

# 44. NET-04 ana real-process scenario

Tek verimli harness mümkünse:

- 1 host
- client A
- client B late join

Akış:

1. host start → session_id + discovery beacon
2. A discovery ile hostu bulur
3. A fresh join / baseline / READY
4. host world state ilerler
5. loot transaction T hostta commit olur
6. A accepted ACK almadan transport kopar
7. host A/player slotunu grace reservation olarak tutar
8. B fresh late join olur
9. B current baseline alır; claimed loot yok, current NPC hull/AI state doğru
10. A aynı session/token ile yeni peer ID üzerinden resume olur
11. A aynı player_id'ye map edilir
12. A baseline ile current state'i alır
13. A transaction T retry eder
14. cached committed result döner; inventory ikinci kez artmaz
15. old token veya malformed token reject edilir
16. invalid discovery packets UDP listenera gönderilir; ENet oturumu bozulmaz
17. clean disconnect/host shutdown
18. beacon TTL ile expire

---

# 45. Late join negative gates

Test et:

- baseline chunk wrong baseline_id
- duplicate chunk
- chunk_index out of range
- missing chunk
- oversized chunk
- malformed entity row
- protocol mismatch baseline
- stale snapshot/event arriving before/after baseline watermark

Hiçbiri READY state'i yanlış açmamalı.

---

# 46. Resume negative gates

Test et:

- wrong session ID
- malformed token
- unknown token
- expired token
- consumed/old rotated token
- same token race
- reconnect after player reservation expired
- sequence rollback attempt

Host player/entity/inventory yanlış kişiye bağlanmamalı.

---

# 47. Transaction negative gates

Test et:

- same transaction + same payload → cached, no duplicate
- same transaction + different drop → conflict
- different transaction + already claimed drop → already_claimed
- malformed transaction ID → reject
- wrong actor identity payload injection → existing spoof guard
- reconnect retry after lost ACK → once
- save snapshot/restore ledger → same transaction once

---

# 48. Discovery malformed packet during active session

Real process veya güçlü integration test:

- ENet host/client aktif
- UDP discovery listenera malformed/oversized/wrong-version paket burst gönder
- parser rejects
- session READY kalır
- authoritative world state değişmez
- process crash olmaz

Discovery hiçbir zaman SessionHost mutation çağırmamalı.

---

# 49. Offline behavior

Default game boot:

- discovery açmaz
- permission istemez
- PacketPeerUDP bind etmez
- ENet host/client başlatmaz
- reconnect timer başlatmaz

Offline VS-04 aynı davranışta kalır.

Marker:

`NET04_OFFLINE_BOOT_OK`

---

# 50. Host restart sınırı

NET-04 reconnect **transport/session reconnect**tir.

Host process tamamen kapanıp tekrar açılırsa eski reconnect token geçerli olmak zorunda değil.

Save/transaction ledger duplicate rewardı koruyabilir; fakat host migration veya crash-resume network session bu görevde yok.

Bunu README'de açık yaz.

---

# 51. Host migration kapsam dışı

Yapma:

- host migration
- internet relay
- NAT punch
- cloud lobby
- account auth
- encryption protocol
- persistent online identity

SeaCraft LAN/offline-first kalır.

---

# 52. Test stratejisi

Mevcut **325 test korunmalı**.

NET-04 için tercihen 11–15 güçlü test.

Minimum:

1. discovery exact protocol encode/decode
2. discovery malformed/fuzz
3. discovery TTL/rate/session dedupe
4. reconnect token/session reservation
5. reconnect sequence continuity/token rotation
6. late-join baseline chunk/apply/ack
7. stale event/snapshot watermark
8. transaction idempotency/conflict
9. transaction save/restore
10. Android permission state contract
11. offline/manual fallback
12. real UDP discovery
13. real reconnect + late join + lost-ACK transaction

Test sayısını mikro assertlerle şişirme.

---

# 53. NET-04 markerları

Minimum:

- `NET04_DISCOVERY_PROTOCOL_OK`
- `NET04_DISCOVERY_FUZZ_OK`
- `NET04_DISCOVERY_TTL_OK`
- `NET04_RECONNECT_TOKEN_OK`
- `NET04_RECONNECT_SEQUENCE_OK`
- `NET04_LATE_JOIN_BASELINE_OK`
- `NET04_TRANSACTION_IDEMPOTENCY_OK`
- `NET04_TRANSACTION_PERSISTENCE_OK`
- `NET04_PERMISSION_FALLBACK_OK`
- `NET04_OFFLINE_BOOT_OK`
- `NET04_DISCOVERY_PROCESS_OK`
- `NET04_PROCESS_INTEGRATION_OK`

Final verifier:

`NET04_VERIFIER_OK ...`

---

# 54. Regression

Exact NET-04 code committe:

- NET-03 9/9 + real vertical slice/disconnect
- NET-02 11/11 + real 1 host/2 client
- NET-01 10/10 + real ENet
- AI-04 10/10
- AI-03 10/10
- AI-02 11/11
- AI-01 10/10
- CORE-04/03/02/01
- VS-04 25 test + replay + soak

geçmeli.

Beehave orphan = 0.

---

# 55. CI verimliliği

Full GUT yalnız bir kez.

NET-01/02/03/04 verifier aynı GUT logunu kullanabilsin.

NET-04 process scenario mümkün olduğunca tek host lifecycle'ında discovery + late join + reconnect + transaction retry doğrulasın.

Her assertion için ayrı host açma.

Fuzz unit/pure parser üzerinden hızlı çalışsın.

---

# 56. CI Android setup

NET-04 için target SDK 37 artifact gerekiyorsa workflow:

- matching Godot 4.7.2 templates
- Android platform 37
- Java 17
- Godot 4.7'nin compatible Gradle template/toolchain'i

kullanmalı.

Godot 4.7 docs Android 35 önerisini kör kopyalama; NET-04 target 37 gereksinimi için gereken platformu kur.

Build-tools/Gradle/AGP sürümünü tahmin etme; actual Godot 4.7 template'in istediği compatible sürümü doğrula.

Başka Godot sürümüne geçme.

---

# 57. CI Android checks

Export sonrası:

- APK integrity
- arm64-v8a
- targetSdkVersion 37
- INTERNET permission
- ACCESS_LOCAL_NETWORK permission
- package `com.osmanyildirim.seacraft`

doğrula.

Runtime allow/deny gerçek fiziksel Android olmadan “passed” yazılmaz.

---

# 58. Static network guard

Mevcut guard korunacak.

Ek guard mümkünse:

- `PacketPeerUDP` yalnız `src/network/**`
- raw resume token print/log yasak
- discovery packet reconnect_token içermiyor
- simulation/data/persistence altında multiplayer/discovery API yok
- client-authored player identity/outcome mutation yok

False-positive nedeniyle normal Crypto/hash/session kodunu yasaklama.

---

# 59. Preflight — ilk committen önce

Tek tek doğrula:

- current HEAD değişmedi
- NET-03 report korunuyor
- Godot 4.7.2 PacketPeerUDP gerçek API:
  - bind
  - set_broadcast_enabled
  - set_dest_address
  - get_available_packet_count
  - get_packet
  - get_packet_ip/port
- discovery packet <=512 byte
- UDP process test real socket
- discovery port game porttan ayrı
- reconnect token >=128 bit entropy
- raw token hiçbir log/marker içinde yok
- token rotation çalışıyor
- old token reject
- reservation expiry testable
- peer→player actor host-owned
- reconnect last sequence korunuyor
- baseline READY'den önce
- baseline chunk exact-shape/bounded
- event watermark eski event replayini engelliyor
- transaction same-ID replay mutation yapmıyor
- transaction conflict reject
- transaction ledger bounded
- ledger snapshot primitive-safe
- SaveSnapshot schema gereksiz bump edilmedi
- schema bump varsa migration mevcut
- Android target 37 export gerçekten oluşuyor
- APK ACCESS_LOCAL_NETWORK içeriyor
- offline boot permission istemiyor
- permission denied socket açmıyor
- manual IP API korunuyor
- process cleanup/trap bütün PID'leri temizliyor
- marker names verifier ile exact
- artifact adı NET04
- README Wave 6'yı yapılmış göstermiyor

Belirsizse commit atma.

---

# 60. README

Yalnız gerçekten implement edilen NET-04'ü belge:

- UDP broadcast discovery
- separate discovery/game ports
- packet size/rate/TTL
- compatibility listing
- manual IPv4 fallback
- reconnect grace/token
- token rotation/session scope
- late join reliable baseline
- event/snapshot watermark
- transaction idempotency
- lost-ACK retry
- Android 17 local-network permission
- permission denied/offline behavior
- guest/AP isolation troubleshooting
- host restart sınırı
- no host migration/auth/encryption/relay

---

# 61. Artifact

Artifact adı:

`SeaCraft-NET04-<exact SHA>`

İçerik:

- `COMMIT_SHA.txt`
- `SHA256SUMS.txt`
- Android APK
- Linux executable
- Linux PCK

Upload sonrası authenticated readback yap.

ZIP/APK/Linux/PCK hashlerini exact code SHA için yeniden doğrula.

---

# 62. Gerçek Android cihaz

Bu görevde gerçek cihaz doğrulaması önemli fakat CI fiziksel cihaz değildir.

Mevcut araçlarla cihaz yoksa açıkça `not_run`:

- Android 17 / target37 permission prompt allow
- permission deny
- permission revoke
- desktop host ↔ Android client
- Android host ↔ desktop client
- discovery broadcast aynı Wi-Fi
- guest/AP isolation mümkünse
- manual IP
- background→foreground reconnect
- 10+ dakika LAN session

Bunları CI success gibi yazma.

---

# 63. Beyin kapanışı

NET-04 task bir kez açılır.

Ara fail'ler için Beyin update yapma.

Exact successful code SHA + Actions + artifact readback sonrası:

- task revision → done
- tek receipt
- geri okuma

Facts minimum:

- exact code SHA
- implementation/correction commits
- Actions run counts
- total tests / NET-04 tests
- discovery fuzz count
- real UDP discovery
- reconnect same player/token rotation
- late join baseline
- lost ACK transaction once
- transaction persistence
- protocol mismatch
- offline/manual fallback
- Android targetSdk/manifest
- NET-03/02/01 regressions
- AI/CORE/VS regressions
- orphan count
- artifact ID/name/hashes
- physical Android status
- WAVE 6 not_started

---

# 64. GOREV_RAPORU.md

Görev bitince mevcut geçmişi koru.

Aynı dosyaya:

`## SOHBET-31 — SeaCraft NET-04 — Discovery, Reconnect, Late Join ve LAN Transaction Hardening`

bölümü ekle.

Yeni rapor dosyası oluşturma.

Yalnız doğrulanmış kanıtları yaz:

- exact SHA
- run/commit sayıları
- tests
- discovery protocol/fuzz
- UDP process
- reconnect
- token rotation/expiry
- late join baseline
- transaction lost-ACK/idempotency
- persistence
- permission/export
- regressions
- orphan
- artifact
- Beyin
- Android not_run/passed

Sohbete uzun raporu kopyalama.

---

# Son kapı

NET-04 ancak aşağıdakiler doğrulanırsa tamamdır:

- production PacketPeerUDP discovery çalışıyor
- discovery ENet game portundan ayrı
- beacon <=512 byte ve exact bounded DTO
- malformed/fuzz paketleri crash/session mutation yapmıyor
- TTL/rate/cache bounded
- manual IPv4 yolu korunuyor
- fresh session host-owned session_id üretiyor
- resume token unpredictable ve raw loglanmıyor
- disconnect reservation player slotunu grace süresince koruyor
- reconnect yeni peer ID ile aynı player'a dönüyor
- sequence continuity korunuyor
- token rotate ediliyor; eski token geçersiz
- late join READY'den önce current reliable baseline alıyor
- claimed/despawn edilmiş loot late baseline'da geri gelmiyor
- historical events baseline sonrası replay olmuyor
- reconnect baseline stale mirrorı temizliyor
- transaction lost-ACK retry ikinci reward üretmiyor
- same transaction/different payload conflict reject
- different transaction/already-claimed drop ikinci reward üretmiyor
- transaction ledger bounded ve save/restore sonrası idempotent
- Android targetSdk 37 artifact üretiliyor
- APK INTERNET + ACCESS_LOCAL_NETWORK içeriyor
- offline boot permission istemiyor/socket açmıyor
- permission denial graceful; offline devam ediyor
- gerçek process discovery + reconnect + late join + transaction scenario geçiyor
- NET-03/02/01 regressions geçiyor
- AI/CORE/VS regressions geçiyor
- orphan=0
- Linux export/boot geçiyor
- Android arm64 export geçiyor
- exact artifact readback geçiyor
- Beyin strict kapanışı geri okunuyor
- `GOREV_RAPORU.md` NET-04 kanıtlarıyla güncel

Eksikse düzeltmeye devam et.

**WAVE 6 progression görevlerine başlama.**

## Nihai sohbet cevabı

Yalnız kısa söyle:

- NET-04 tamamlandı / gerçek engel
- exact SHA
- successful Actions run
- test total
- artifact
- ayrıntılı raporun `GOREV_RAPORU.md` içinde olduğu

Uzun kapanış raporunu sohbete yazma.
