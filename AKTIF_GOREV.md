# AKTİF GÖREV — NET-03

> Bu dosya SeaCraft'ın kanonik aktif uygulama briefidir. Sohbette uzun brief tekrarlanmaz.
>
> Görev tamamlandığında ayrıntılı doğrulama sonucu yalnız `GOREV_RAPORU.md` dosyasına, mevcut geçmiş korunarak yeni bir NET-03 bölümü halinde yazılır. Sohbet cevabı kısa tutulur.

## Kimlik

- Sohbet etiketi: `[SOHBET-30 | SeaCraft NET-03 — Vertical Slice LAN Parity]`
- Repo: `TheOsmanYILDIRIM/SeaCraft`
- Dal: yalnız `main`
- Başlangıç HEAD: `8f7e2c5510d79f6cc9dce29acc1317039a2dc94a`
- NET-02 exact kod kapanışı: `8e26aafe3acd3a23a02755b9c58ef719da10d20a`
- Godot: `4.7.2-stable`
- Bağımlılık: NET-02 tamamlandı
- Sonraki göreve geçme: **NET-04'e başlama**

Başlangıç HEAD, NET-02 exact code SHA'nın yalnız rapor commit'i kadar ilerisindedir. `GOREV_RAPORU.md` geçmişini koru.

Her mesajına yukarıdaki sohbet etiketiyle başla.

## Yürütme

İşi aynı oturumda uygula → doğrula → hatayı kök nedeninden düzelt → exact-commit Actions → export → artifact readback → Beyin kapanışı → `GOREV_RAPORU.md` NET-03 bölümü şeklinde tamamla.

Başlamadan güncel `main` HEAD'i yeniden doğrula. Başka sohbetin değişikliğini ezme.

Avenox Beyin'de NET-03 görevi varsa onu kullan; yoksa tek kanonik task aç. Mükerrer task/receipt oluşturma.

---

# 1. Hız protokolü

NET-02'de 4 Actions run / 3 failure oluştu. NET-03 hedefi:

**1 implementation commit + 1 successful Actions run.**

Gerçek hata çıkarsa tüm kök nedenleri mümkün olduğunca tek correction commit'inde çöz.

İlk committen önce gerçek diff üzerinde statik/preflight doğrulama yap. Özellikle önceki zincirlerde çıkan hataları tekrar etme:

- Godot 4.7 API imzaları; özellikle `var_to_bytes`
- native/built-in method isim çakışmaları
- SceneTree gerektiren multiplayer/RPC kodunu custom MainLoop'ta çalıştırma
- `get_tree().quit(code)` yerine bare `quit()`
- typed `Array[String]` / Dictionary assignment uyumsuzluğu
- numeric-ending stable event ID contract
- snapshot/event sequence int/float normalization
- exact DTO shape
- ANSI normalization/verifier marker sayıları
- process readiness/timeout/PID cleanup
- test assertion ile production reason string uyuşması

NET-01/02'nin çalışan normal SceneTree process harness yaklaşımını reuse et. Diagnostic commit üretme.

---

# 2. Kanonik amaç

Plan:

**NET-03 — Vertical slice LAN parity**

Amaç:

Mevcut VS-04 offline playable vertical slice davranışını gerçek LAN host+client akışında host-authoritative olarak kanıtlamak.

Mekanik kapsam:

- hareket
- hedef seçimi
- top ateşi
- HP/batma
- loot/drop
- loot claim
- NPC AI state progression
- host/client state parity

Ana sistem:

`NetworkVerticalSliceScenario` veya eşdeğer test/adapter katmanı.

Kabul:

- host ve client aynı authoritative NPC sonucunu görür
- AI yalnız hostta karar verir
- client target/fire intent gönderir; host doğrular ve uygular
- loot hostta bir kez claim edilir
- unauthorized damage/loot outcome reddedilir
- combat sırasında client disconnect host simulation'ı bozmaz
- offline VS-04 davranışı regress etmez

**NET-04'e başlama.**

---

# 3. VS-04'ü yeniden yazma

Mevcut:

`tests/fixtures/vertical_slice/vertical_slice_scenario.gd`

offline kanonik senaryodur.

Bunu kopyalayıp ikinci gameplay sistemi oluşturma.

NET-03 test/harness:

- aynı foundation sector
- aynı stable player/NPC kimlikleri
- aynı AI tuning
- aynı loot table/item
- aynı combat/ShipMotor/CombatAuthority/LootAuthority
- aynı seed/fixture mantığı

üzerinden host authority'yi kurmalı.

Network katmanı yalnız intent + replication adapter'dır.

Offline VS-04 production/simulation davranışını networking için değiştirme.

---

# 4. Parity tanımı

LAN parity, clientın kendi simulation'ını lockstep çalıştırması değildir.

Client authoritative simulation çalıştırmaz.

Parity şu semantik sonuçlarda kanıtlanmalı:

- player movement hostta geçerli
- NPC patrol gerçek host AI tarafından ilerliyor
- target lock hostta geçerli
- range/reload/broadside kuralları bypass edilmiyor
- client ateşi gerçek `CombatAuthority.fire()` yoluna gidiyor
- NPC damage/alive/hull state client mirror'ına geliyor
- NPC AI transitionları client presentation state'inde görülüyor
- NPC tam bir kez batıyor
- loot tam bir kez oluşuyor
- loot claim tam bir kez reward üretiyor
- loot proxy claim sonrası kayboluyor
- duplicate/unauthorized sonuç ikinci mutation oluşturmuyor

Aynı seed + aynı host-side fixed simulation progression altında kanonik semantic digest üret.

Cross-platform floating-physics lockstep iddiası yapma.

---

# 5. NET-01/02 sözleşmelerini koru

Korunacak:

- `SessionProtocol`
- `SessionHost`
- `SessionClient`
- `SessionRpcBridge`
- `NetworkEntityRegistry`
- `NetworkEntityProxy`
- `NetworkReplicationPeer`

NET-01:

- handshake
- peer→player host mapping
- replay/spoof guard

NET-02:

- stable-ID lifecycle
- AOI
- snapshot sequencing
- reliable semantic eventler
- client mutation rejection

zayıflatılmayacak.

---

# 6. Simulation network bağımsızlığı

`src/simulation/**`, `src/data/**`, `src/persistence/**` network API'siz kalmalı.

Combat/loot/AI simulation classes:

- peer ID bilmez
- RPC bilmez
- MultiplayerAPI bilmez
- client bilmez

Network gameplay adapter hostta mevcut authority API'lerini çağırır.

---

# 7. Yeni remote gameplay intentleri

NET-03'te yalnız gerçek gameplay intentleri ekle.

Minimum:

- `select_combat_target`
- `fire_weapon`
- `pickup_loot`

Mevcut movement intentleri korunur.

Client outcome göndermez.

### select_combat_target payload

Yalnız:

- `target_id`

Host actor ID'yi peer→player mapping'den türetir.

### fire_weapon payload

Yalnız:

- `target_id`

Client:

- heading
- hit
- crit
- damage
- remaining_hull
- ammo sonucu
- transaction sequence

gönderemez.

Host heading'i authoritative `ShipMotor.current_heading()` üzerinden alır.

### pickup_loot payload

Yalnız:

- `drop_id`

Client:

- item_id
- quantity
- reward
- inventory delta
- claimed=true

gönderemez.

---

# 8. Remote intent authority adapter

Network boundary içinde tek adapter oluştur veya mevcut SessionHost'u temiz biçimde genişlet.

Host akışı:

client envelope
→ real remote sender
→ peer→player mapping
→ exact payload validation
→ visibility/AOI validation
→ authoritative simulation method
→ bounded semantic result
→ replication/event

Actor identity hiçbir zaman payload'dan alınmaz.

---

# 9. Target selection

Remote target select:

`CombatAuthority.select(mapped_player_id, target_id)`

ve mevcut TargetingService validation'ını kullanmalı.

Host doğrulasın:

- target stable ID valid
- target authoritative roster'da
- same applicable sector
- selectable
- hostile/valid class
- peer AOI'de görünür

Client görünmeyen/başka sector hedefini stable ID bilse bile lock alamamalı.

---

# 10. Remote fire

Remote fire:

- actor = host peer mapping
- heading = host ShipMotor
- target = payload target_id
- command = `CombatAuthority.fire_intent(target_id)`
- execution = gerçek `CombatAuthority.fire()`

Host mevcut kuralları bypass etmez:

- target lock
- range
- broadside arc
- reload
- ammo
- safe zone
- hit/dodge
- crit
- hull
- sunk

Client sonucu uyduramaz.

---

# 11. Fire result

Clienta bounded reliable semantic intent-result dönmek gerekiyorsa tek exact schema kullan.

Minimum güvenli alanlar:

- client_sequence
- intent_type
- accepted
- reason
- transaction/event sequence gerekiyorsa
- target_id

World state'in gerçeği yine NET-02 replication snapshot/eventlerinden gelir.

Fire result ikinci authority truth değildir.

---

# 12. Loot claim

Remote loot claim:

- actor = host mapping
- drop_id = bounded payload
- AOI/visibility = host
- range = host
- ownership/inventory = host
- claim = gerçek `LootAuthority.pickup()` veya mevcut world-object authority yolu

Claim kabul edilirse:

- reward host inventory'ye bir kez girer
- reliable loot event gönderilir
- network entity despawn olur
- client proxy kalkar

Duplicate claim ikinci reward üretmemeli.

---

# 13. Unauthorized damage/loot negatif kapı

Clientın şu outcome iddiaları hâlâ unsupported/rejected:

- `set_hull`
- `damage_entity`
- `sink_entity`
- `spawn_loot`
- `create_loot`
- `claim_result`
- `set_inventory`
- `grant_item`
- `despawn_entity`

Malicious real-process test:

- NPC hull değişmemeli
- loot ledger değişmemeli
- inventory artmamalı
- registry lifecycle değişmemeli

---

# 14. Host-only AI

NPC için:

- `NpcBrain`
- `AiDecisionScheduler`
- Beehave execution
- tactical decision

yalnız hostta çalışmalı.

Clientta NpcBrain/scheduler instantiate etme.

Client yalnız replicated semantic AI presentation state alır.

Kanıt:

- host `decision_count > 0`
- client AI decision count = 0 / AI executor yok
- host NPC transition trace gerçek AI state'lerinden gelir
- client aynı transitionların mirror/presentation bilgisini görür

---

# 15. NPC semantic replication

NET-02 proxy state'ini minimum gerekli alanlarla genişlet.

NPC için bounded semantic state:

- `ai_state_id`
- `ai_intent_id`
- gerekirse `target_entity_id`

Yalnız primitive.

Client bu değerlerden karar üretmez; sadece görüntüler.

Host AI state'i authoritative source.

---

# 16. NetworkVerticalSliceScenario aşamaları

Gerçek process senaryo minimum şu aşamalardan geçsin:

### A — Boot / handshake

- 1 host
- 1 client
- manual localhost
- NET-01 handshake READY
- mapped player doğrulanır

### B — Baseline replication

- player stable ID
- NPC stable ID
- client mirror'ları oluşur
- NPC host AI patrol eder
- client NPC hareketini snapshotta görür

### C — Remote movement

Client gerçek `move_to_world_position` intent gönderir.

Host ShipMotor hareket eder.

Client authoritative hareket snapshotını görür.

### D — Out-of-range / target

Client NPC target intent gönderir.

Host target selection doğrular.

Out-of-range fire denemesi mevcut combat reason ile reddedilir veya accepted=false olur.

### E — Broadside + first damage

Client hareket intentleriyle host player'ı uygun konuma taşır.

Client target/fire gönderir.

Host gerçek fire transaction ile NPC'yi hasarlar.

Client yeni hull state + damage event görür.

### F — AI reaction

Host AI gerçek:

- PATROL
- ALERT
- RETREAT
- REPAIR
- RESUME

semantic transition zincirini üretir.

Client mirror bu geçişleri gözlemler.

### G — Final combat

Client remote fire intentlerle NPC'yi batırır.

Host:

- sunk exactly once
- drop exactly once

üretir.

Client:

- NPC dead/sunk state
- loot proxy

görür.

### H — Remote loot claim

Client host player'ı loot range içine hareket ettirir.

Client `pickup_loot` intent gönderir.

Host gerçek LootAuthority claim yapar.

- inventory > 0
- claim count = 1
- loot proxy despawn

### I — Duplicate guard

Yeni sequence ile aynı drop tekrar claim edilmeye çalışılır.

İkinci reward yok.

### J — Complete

Host ve client semantic digest karşılaştırılır.

---

# 17. Offline parity

Mevcut VS-04 offline fixture exact committe aynen geçmeli.

NET-03 verifier şu offline semantic kapıları da kontrol etsin:

- `VS04_SCENARIO_COMPLETE`
- `VS04_CHECKPOINT_REPLAY_OK`
- `VS04_SOAK_OK`

LAN scenario'nun semantic sonuçlarını offline contract ile kıyasla:

- AI transition set/order
- single sunk
- single drop
- single pickup
- accepted fire path
- final inventory positive
- authoritative stable IDs

Checkpoint/reload'u LAN clienta taşımaya çalışma.

Reconnect/late-join restore NET-04 kapsamıdır.

---

# 18. Disconnect during combat

Ayrı gerçek process negatif senaryo veya aynı harness içinde kontrollü faz:

1. client READY
2. player/NPC combat başlar
3. ilk authoritative damage oluşur
4. client disconnect eder
5. host mapping/session state temizlenir
6. gameplay entity otomatik silinmez
7. NPC host AI tick etmeye devam eder
8. host authoritative state valid kalır
9. duplicate reward/drop oluşmaz
10. host clean exit

Reconnect yapma.

NET-04 kapsamına girmez.

---

# 19. Disconnect authority kuralı

Network disconnect:

- player gameplay entity = otomatik destroy değil
- CombatAuthority state = hostta korunur
- AI tick = hostta devam edebilir
- peer mapping = temizlenir

Rejoin/reconnect token yok.

---

# 20. AOI / hidden target guard

Remote target/fire/loot intents host AOI visibility ile çapraz kontrol edilmeli.

Client stable ID tahmin ederek:

- başka sector NPC'ye ateş edemez
- görünmeyen loot'u claim edemez

Bu yalnız UI filtresi değildir; authority validation olmalı.

---

# 21. Combat event replication

NET-02 reliable/idempotent event sistemi reuse edilir.

Gerçek host events:

- hull_damaged
- ship_sunk

clienta ulaşmalı.

Duplicate reliable event client presentation state'ini ikinci kez mutate etmemeli.

Snapshot final hull/alive truth kaynağıdır.

---

# 22. Loot event replication

NET-02 loot event lifecycle reuse edilir.

Minimum semantic events:

- drop_created
- drop_claimed

Client:

- duplicate drop yaratmaz
- claim sonrası proxy ghost bırakmaz

Final inventory authority hosttadır.

---

# 23. Presentation-only client

Client proxy/interpolation:

- simulation ShipMotor değildir
- CombatAuthority değildir
- LootAuthority değildir
- NpcBrain değildir

Client presentation smoothing authoritative state'i geri yazmaz.

---

# 24. Scenario determinism

Host scenario fixed-step progression kullansın.

Arbitrary wall-clock combat kararlarıyla flaky test oluşturma.

Process harness readiness wall-clock timeout olabilir; **gameplay simulation progression fixed host ticks** ile kontrol edilmeli.

Seed explicit.

---

# 25. Replay / intent sequence

NET-01 sequence guard korunacak.

Combat/loot intentleri de aynı monotonic client sequence sözleşmesini kullanmalı.

Duplicate sequence → replay reject.

Aynı loot drop için yeni sequence → simulation duplicate claim guard tarafından no second reward.

İki farklı korumayı ayrı test et.

---

# 26. Result DTO bounds

Intent-result/transaction summary eklenirse:

- primitive-safe
- exact shape
- bounded strings
- finite numbers
- stable IDs
- max byte/entity budget

Resource/Object/Node/RID/Callable yok.

---

# 27. SessionProtocol allowlist

`NETWORK_INTENTS` yalnız gerekli yeni intentlerle genişlet.

Her intent için ayrı exact payload validator.

Generic arbitrary dictionary gameplay execution ekleme.

Presentation camera intentleri hâlâ network dışı.

---

# 28. Process harness

NET-02 normal SceneTree harness yapısını reuse et.

NET-03 gerçek:

- 1 host process
- 1 client process

çalıştırmalı.

Host process gerçek vertical slice runtime'ı kurmalı; client gerçek SessionClient kullanmalı.

Mock RPC/multiplayer ile success üretme.

---

# 29. Process cleanup

Zorunlu:

- port collision check
- host-ready marker
- client-ready marker
- bounded wait
- per-stage timeout
- trap
- PID cleanup
- nonzero exit propagation
- clean host stop
- client disconnect scenario için explicit expected exit

Timeout ile öldürülmüş process success değildir.

---

# 30. NET-03 markerları

En az:

- `NET03_REMOTE_MOVE_OK`
- `NET03_REMOTE_TARGET_OK`
- `NET03_REMOTE_FIRE_OK`
- `NET03_HOST_AI_ONLY_OK`
- `NET03_AI_PARITY_OK`
- `NET03_COMBAT_REPLICATION_OK`
- `NET03_LOOT_CLAIM_ONCE_OK`
- `NET03_AUTHORITY_REJECTION_OK`
- `NET03_DISCONNECT_COMBAT_OK`
- `NET03_OFFLINE_PARITY_OK`
- `NET03_PROCESS_INTEGRATION_OK`

Verifier ayrıca tek summary marker üretsin:

`NET03_VERIFIER_OK ...`

---

# 31. Test stratejisi

Mevcut **316 test korunmalı**.

NET-03 için 8–12 güçlü yeni test tercih et.

Minimum:

1. combat target intent exact payload
2. fire intent actor/heading host-derived
3. hidden target rejection
4. loot claim host-only / once
5. duplicate sequence vs duplicate claim ayrımı
6. client outcome mutation rejection
7. host-only AI
8. NPC semantic state replication
9. disconnect preserves host authority
10. offline semantic parity
11. real process full scenario

Test sayısı hedef değil; gereksiz mikro-test ekleme.

---

# 32. Existing regression

Exact NET-03 code commit:

- NET-02 11/11 + real host/2-client regression
- NET-01 10/10 + real ENet regression
- AI-04 10/10
- AI-03 10/10
- AI-02 11/11
- AI-01 10/10
- CORE-04/03/02/01
- VS-04 25 test + replay + soak

geçmeli.

Beehave orphan = 0.

---

# 33. CI verimliliği

Full GUT yalnız bir kez.

NET-01/02/03 verifier mümkün olduğunca aynı GUT logunu kullansın.

NET-03 real-process full scenario tek host/client lifecycle'ında ana parity akışını çalıştırsın.

Disconnect alt senaryosu ayrı process gerekiyorsa yalnız bir kez çalıştır.

Eski NET-01/02 process regressionlarını tamamen silme; gerekiyorsa aynı kanıtlanmış harness'i çağır.

---

# 34. CI preflight

İlk implementation committen önce doğrula:

- Godot 4.7 RPC annotation gerçek syntax
- SessionProtocol new intent payload exact shapes
- actor identity payload'dan alınmıyor
- fire heading clienttan alınmıyor
- target/loot AOI host-validation
- `CombatAuthority.select/fire` gerçek method signature
- `LootAuthority.pickup` gerçek method signature
- combat clock/tick progression gerçek hostta ilerliyor
- AI scheduler yalnız host
- clientta NpcBrain oluşturulmuyor
- NPC semantic fields snapshot row validatorla uyumlu
- event stable IDs SectorIds contract ile uyumlu
- typed arrays explicit
- var_to_bytes Godot 4.7 signature doğru
- process SceneTree kullanıyor
- process args doğru
- cleanup/trap doğru
- expected markers exact
- ANSI parser mevcut proven yaklaşım
- artifact adı NET03
- README NET-04 özelliklerini yapılmış göstermiyor

Bu listede belirsizlik varsa commit atma.

---

# 35. Authority negative tests

Real process veya güçlü integration testte doğrula:

- client direct set_hull → reject
- client damage outcome → reject
- client loot reward → reject
- client hidden target → reject
- client hidden loot claim → reject
- client identity spoof → NET-01 guard
- replay sequence → NET-01 guard

Host state mutation yok.

---

# 36. Offline boot

Default bootstrap hâlâ:

- host başlatmaz
- client başlatmaz
- RPC session açmaz
- LAN beklemez

Offline VS-04 aynı şekilde çalışır.

---

# 37. NET-04 kapsam dışı

Yapma:

- discovery beacon
- reconnect token
- late join baseline recovery
- session resume
- reconnect transaction replay
- background/foreground reconnect
- UDP discovery fuzz
- host migration

Bunlar NET-04.

---

# 38. README

Yalnız gerçekten uygulanan NET-03'ü belge:

- VS-04 LAN parity
- remote move/target/fire/loot intents
- actor/heading host-derived authority
- host-only AI
- semantic NPC state replication
- combat/loot event path
- once-only loot claim
- AOI target/loot validation
- disconnect-during-combat behavior
- offline parity
- no prediction/lockstep claim
- NET-04 not implemented

---

# 39. Artifact

Artifact adı:

`SeaCraft-NET03-<exact SHA>`

İçerik:

- `COMMIT_SHA.txt`
- `SHA256SUMS.txt`
- Android APK
- Linux executable
- Linux PCK

Upload sonrası authenticated readback yap.

ZIP/APK/Linux/PCK SHA-256 exact commit için doğrula.

---

# 40. Android gerçek cihaz

Bu görevde gerçek cihaz plan kapısı vardır fakat CI fiziksel cihaz değildir.

Mevcut araçlarla fiziksel cihaz erişimi yoksa açıkça `not_run`:

- Android client ↔ desktop host same Wi-Fi
- desktop client ↔ Android host
- mümkünse Android ↔ Android
- 10+ dakika session
- combat + loot
- Wi-Fi jitter
- interpolation okunabilirliği

Bunları CI passed diye yazma.

NET-03 kod/CI kapanışı gerçek cihaz `not_run` ile kaydedilebilir; fiziksel cihaz kanıtını ayrı tut.

---

# 41. Beyin kapanışı

NET-03 task bir kez açılır.

Ara CI fail'leri için Beyin update yapma.

Exact successful code SHA + Actions + artifact readback sonrası:

- task revision → done
- tek receipt
- geri okuma

Facts minimum:

- exact code SHA
- implementation/correction commits
- Actions run counts
- total tests / NET-03 tests
- full 1 host + 1 client process integration
- offline parity
- remote move/target/fire
- host-only AI
- AI transitions observed
- combat replication
- single sunk/drop/loot claim
- duplicate claim blocked
- unauthorized mutation rejected
- disconnect-combat result
- NET-02/01 regressions
- AI/CORE/VS regressions
- orphan
- artifact ID/name/hashes
- Android physical test status
- NET-04 not_started

---

# 42. GOREV_RAPORU.md

Görev bitince mevcut geçmişi koru.

Aynı dosyaya yeni:

`## SOHBET-30 — SeaCraft NET-03 — Vertical Slice LAN Parity`

bölümü ekle.

Yeni rapor dosyası oluşturma.

Yalnız doğrulanmış:

- exact SHA
- run/commit sayıları
- tests
- process scenario
- parity
- remote intents
- AI host-only
- combat/loot
- duplicate guards
- negative authority
- disconnect
- regressions
- export
- artifact
- Beyin
- Android not_run/passed

kanıtlarını yaz.

Sohbete uzun raporu kopyalama.

---

# Son kapı

NET-03 ancak şunların tamamı doğrulanırsa bitmiş sayılır:

- gerçek 1 host + 1 client ENet/RPC vertical slice çalışıyor
- client movement intent host ShipMotor'a gidiyor
- client target intent host CombatAuthority select'e gidiyor
- client fire intent actor/heading spoof edemiyor
- fire gerçek CombatAuthority range/reload/broadside kurallarından geçiyor
- client authoritative NPC hull/alive mirror'ını görüyor
- AI yalnız hostta karar veriyor
- host NPC PATROL→ALERT→RETREAT→REPAIR→RESUME zinciri gerçek
- client semantic AI mirror aynı zinciri gözlemliyor
- NPC tam bir kez batıyor
- loot tam bir kez spawn oluyor
- client loot claim hostta doğrulanıyor
- inventory reward tam bir kez
- duplicate claim ikinci reward üretmiyor
- loot proxy despawn ghost bırakmıyor
- hidden target/loot authority'de reddediliyor
- unauthorized damage/loot outcome state değiştirmiyor
- disconnect sırasında host combat/AI state bozulmuyor
- offline VS-04 replay/soak ve semantic davranış geçiyor
- NET-02/NET-01 regressions geçiyor
- AI/CORE regressions geçiyor
- orphan=0
- offline boot ağsız çalışıyor
- Linux export/boot geçiyor
- Android arm64 export + INTERNET permission geçiyor
- exact artifact readback geçiyor
- Beyin strict kapanışı geri okunuyor
- `GOREV_RAPORU.md` NET-03 bölümü güncel

Eksikse düzeltmeye devam et.

**NET-04'e başlama.**

## Nihai sohbet cevabı

Yalnız kısa söyle:

- NET-03 tamamlandı / gerçek engel
- exact SHA
- successful Actions run
- test total
- artifact
- ayrıntılı raporun `GOREV_RAPORU.md` içinde olduğu

Uzun kapanış raporunu sohbete yazma.
