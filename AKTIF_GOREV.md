# AKTİF GÖREV — PRG-05 · faction ve ekonomi (devam ediyor)

Başlangıç: a73633beb1dfec0d70c1b4e640bfd439ff823ede; yalnız `main`; Godot 4.7.2. Kaynak: `GELISTIRME_GOREV_PLANI.md` PRG-05. PRG-04 kapalı; Android smoke hotfix gerçek cihaz retesti ayrı `awaiting_retest`.

**Bu dilim:** host-owned faction relations/reputation, market buy/sell, convoy supply etkisi, outpost ownership, repeat-kill PvP diminishing returns; inventory v5 save/load; LAN client yalnız market_id/quantity ile trade intent gönderebilir. Gemi sprite'larından bağımsızdır.

**Doğrulanmış ek checkpoint:** AI-03 konvoy ve AI-04 FAR world teslim/kayıp settlement adaptörü, Güvenli Liman market içeriği ve dokunmatik pazar paneli. Exact kod SHA `0c821a58c904839a53cd0b51509f55e606e3e323`; [Actions 45249433521](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45249433521) `success`, 403/403 GUT, 9/9 PRG-05, Android/Linux artifact provenance/readback başarılı.

**PRG-05 son doğrulanmış checkpoint:** AI-04 FAR scheduler→market settlement, LAN host market sector/ShipMotor proximity guard, bounty/intel combat proof + event ledger, PRG-01 crew equipment'ını kullanan local company/crew roster ve idempotent maaş settlement, JSON legacy migration ve strict state validation. Exact kod SHA **`11ddde3d4f2311283899e2b873485b38008d6a97`**, [Actions 45272356337](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45272356337) **success**, 410/410 GUT, 29.790 assert, PRG-05 16/16; Android/Linux artifact authenticated readback başarılı.

**Açık PRG-05 kapıları:** Gerçek Android dokunmatik pazar smoke + uzun iki-cihaz LAN ekonomi drift `not_run`; üretim oyun sahnesi/host orchestration'ının uçtan-uca cihaz kabulü ve UI final polish ayrı. LAN/ekonomi kodu ve CI doğrulaması gerçek fiziksel cihaz testi yerine geçmez. PRG-05 `active` tutulur; PRG-06'ya geçilmez.

---

# AKTİF GÖREV — PRG-04

> Bu dosya SeaCraft'ın kanonik aktif uygulama briefidir. Sohbette uzun brief tekrarlanmaz.
>
> Görev tamamlandığında ayrıntılı doğrulama sonucu yalnız `GOREV_RAPORU.md` dosyasına, mevcut geçmiş korunarak yeni bir PRG-04 bölümü halinde yazılır. Sohbet cevabı kısa tutulur.

## Durum — KAPALI

PRG-04 exact kod teslimi, CI/regresyon matrisi, Linux/Android exportu, authenticated artifact readback ve Avenox Beyin strict kapanışı doğrulanmıştır. PRG-05 bu kapanış kapsamında başlatılmadı; durumu `not_started` olarak kalır.

## Kimlik

- Sohbet etiketi: `[SOHBET-35 | SeaCraft PRG-04 — Quest, Journal ve NPC Interaction]`
- Repo: `TheOsmanYILDIRIM/SeaCraft`
- Dal: yalnız `main`
- Uygulama başlangıç HEAD'i: `9f016ef7be3b9d4c09365d6fcace3a61cc573958`
- PRG-03 exact kod kapanışı: `2d8e32e6ff84ca3a8e4b23aa0e52073dc333b584`
- PRG-03 Actions: `45034255905` — `success`
- PRG-03 artifact ID: `14759425694`
- Godot: `4.7.2-stable`
- Bağımlılık: PRG-03 tamamlandı
- Avenox Beyin görevi: `tasks/seacraft-prg04-quest-journal-npc-interaction-20261122.md`
- PRG-04 exact kod SHA: `cb179949f5a8e04c2507c20a51b17c54e034476a`
- PRG-04 Actions: run `45045317837` — `success`
- PRG-04 artifact: `SeaCraft-PRG04-cb179949f5a8e04c2507c20a51b17c54e034476a`, ID `14763222807`
- PRG-04 Avenox Beyin: `done`, revision `2`; commit `e48989da5c444b6342c00f3eb41e30bee8249804`
- PRG-04 receipt: `receipts/a8f03934d465a9465c4585ca5a5ae646bb62ebf8e2d356b36141084775cb528e.md`
- Fiziksel Android cihaz: `not_run`
- Sonraki görev: PRG-05 — `not_started`; bu kapanışta başlatılmadı

Bu brief kapanmıştır. PRG-05 için ayrı kanonik görev açılmadan yeni geliştirme başlatma.

Başlamadan güncel `main` HEAD'i, bu dosyayı, `GELISTIRME_GOREV_PLANI.md`, `GOREV_RAPORU.md`, `SESSION_HANDOFF.md` ve `README.md` dosyalarını yeniden doğrula. HEAD değişmişse başkasının değişikliğini ezme; güncel diff ve sahipliği inceleyip yalnız PRG-04 kapsamını güvenli biçimde uygula.

---

# 1. Kanonik amaç

Plan:

**PRG-04 — Quest, journal ve NPC interaction**

Amaç:

- data-driven görev modelini ve runtime quest instance state'ini kurmak
- bounty/escort/salvage/trade/capture/damage/collect/acquire/timed objective türlerini stable-ID event modeliyle işletmek
- start/turn-in NPC, chain prerequisite, region/map constraint ve target/acquisition rule sözleşmelerini veri odaklı yapmak
- reward ledger'ı idempotent ve atomik kılmak
- NPC interaction authority ile presentation/journal katmanını ayırmak
- save/load sırasında quest progress, objective counters, timer/version ve reward state'ini korumak
- offline-first davranışı korurken LAN'da quest completion/reward doğrulamasını host-authoritative yapmak
- gelecekte PRG-05 faction/economy ve ADV encounter sistemlerinin tüketebileceği stabil objective/reward API bırakmak

Mekanik katalog:

- M-031
- M-032

Forum araştırması yalnız görev zinciri alanları, objective çeşitliliği, start/turn-in NPC, region/map constraint, reward bundle ve daily/raid/Atlantis benzeri etiket şemaları için referanstır. Exact görev isimleri, metinleri, değerleri veya ödülleri SeaCraft production içeriğine doğrudan kopyalanmaz.

---

# 2. Mevcut progression sözleşmelerini koru

PRG-04 yeni inventory, XP, stat veya reward authority kurmaz.

Zorunlu reuse:

- PRG-01 `InventoryState` ve atomik transaction modeli
- PRG-02 reward/item grant ve progression patterns
- PRG-03 XP ledger, gate API ve local challenge idempotency
- stable-ID `DefinitionRegistry`
- tek `StatModifierPipeline`
- primitive-safe DTO ve save/network sınırı
- NET-04/PRG-01..03 transaction ID / lost-ACK / same-ID conflict modeli
- host-authoritative LAN ve presentation-only client mirror sınırı

Quest sistemi item/XP/reward truth'u kendi içinde çoğaltamaz; yalnız mevcut authoritative sistemlere intent/transaction üretir.

---

# 3. QuestDefinition

Minimum `QuestDefinition` alanları:

- stable quest ID
- quest type/tag
- start NPC stable ID
- turn-in NPC stable ID
- prerequisite quest IDs
- prerequisite gate/rank/license IDs gerektiğinde
- region/sector/map constraints
- ordered veya unordered objective listesi
- reward bundle refs
- optional time limit / version key
- repeatability policy
- party share policy
- presentation title/description content-side

Validator:

- duplicate/missing quest ID reddi
- missing start/turn-in NPC refs reddi
- missing prerequisite quest/gate refs reddi
- quest-chain cycle reddi
- invalid region/sector refs reddi
- objective definition/type mismatch reddi
- zero/negative required count reddi
- invalid time limit reddi
- reward refs doğrulanır
- Resource/Node/Object runtime DTO'ya taşınmaz

---

# 4. QuestInstance / lifecycle

Runtime primitive-safe state:

- quest stable ID
- status: locked/available/active/completable/completed/failed gibi bounded state
- objective progress
- accepted/completed version metadata
- timer/tick metadata
- reward-claimed state
- owner/player stable ID
- required minimal event ledger

Lifecycle:

1. availability evaluation
2. authoritative accept
3. objective event application
4. completable evaluation
5. turn-in/completion validation
6. reward transaction
7. completed/reward ledger

Kabul:

- invalid transition reddedilir
- completed quest duplicate reward üretemez
- partial failure state bırakmaz
- repeated completion/retry idempotent
- save/load sonrası lifecycle state korunur

---

# 5. Objective event bus

Objective eventleri pure-data, stable-ID ve authority-owned olmalı.

Minimum objective türleri:

- kill
- damage
- capture
- collect
- acquire
- timed
- escort
- salvage
- trade

Her event minimum:

- event ID / transaction ID
- actor/player stable ID
- objective type
- target/source stable IDs
- quantity/value
- sector/region ID gerektiğinde
- authoritative tick/time metadata gerektiğinde

Kurallar:

- duplicate event ikinci progress üretmez
- same-ID farklı payload conflict
- wrong target/region/type progress üretmez
- over-count bounded/clamped
- reject edilen event quest state değiştirmez
- client event outcome veya progress delta seçemez
- objective bus simulation/presentation/network API'lerine sıkı bağımlı ikinci event sistemi kurmaz; mevcut domain events adapter ile bağlanır

---

# 6. Objective semantics

## Kill
- stable target definition/category
- count increment yalnız authoritative death eventinden
- duplicate death ikinci progress üretmez

## Damage
- authoritative applied damage miktarı
- rejected/miss/immune damage progress üretmez
- target/category/region filter

## Capture
- authoritative capture completion event
- failed/aborted capture progress üretmez

## Collect
- quest için authoritative pickup/claim event
- duplicate loot claim progress üretmez

## Acquire
- InventoryState mutation sonrası gerçekten elde edilen miktar
- presentation sayımı değil

## Timed
- wall-clock internet servisi yerine kanonik simulation/save contract
- pause/reload davranışı açık
- deadline bypass yok

## Escort
- stable escort objective/entity/route sonucu
- success/failure explicit domain event

## Salvage
- PRG-02 authoritative salvage transaction sonucu

## Trade
- future PRG-05 economy authority'ye bağımlı adapter contract; PRG-04 minimal event schema kurar, ekonomi sistemi geliştirmez

---

# 7. Chain prerequisite ve region/map constraint

Quest chain DAG olmalı.

- self-cycle reddi
- indirect cycle reddi
- missing prerequisite reddi
- completed prerequisites doğru okunur
- prerequisite reward claim ile completion state ayrımı açık
- region/sector gate current authoritative sector üzerinden
- client fake sector/region ile accept/complete edemez
- safe-zone veya map constraint gerekiyorsa mevcut CORE-03 stable sector/region refs kullanılır

PRG-03 gate API ile quest prerequisites entegre edilir; ikinci gate sistemi kurulmaz.

---

# 8. NPC interaction authority

NPC interaction pure-data command/intent üzerinden ilerler.

Minimum:

- NPC stable ID
- interaction type
- actor/player stable ID
- quest accept / turn-in intent
- bounded choice ID gerekiyorsa
- interaction range/availability validation

Host/offline authority:

- NPC'nin quest sunup sunmadığını belirler
- accept/turn-in prerequisite doğrular
- reward sonucunu belirler
- client yalnız intent gönderir

Dialogue Manager 4 bu görevde **varsayılan olarak eklenmez**. Yalnız dallı diyalog yazarlığı custom modelle gereksiz karmaşık hale gelirse ve Godot 4.7.2/Android/export sınırları doğrulanırsa değerlendir. Quest authority hiçbir addon nesnesine devredilmez.

---

# 9. Reward ledger

Quest reward bir kez ve atomik uygulanmalı.

Reward bundle gerektiğinde:

- item grants → PRG-01 InventoryState
- XP → PRG-03 XP ledger
- gate/license/perk unlock → mevcut progression/gate API
- future reputation/economy hook → yalnız event/ref; PRG-05'i burada geliştirme

Kurallar:

- completion + reward claim tek authoritative transaction sınırında
- herhangi bir reward alt işlemi başarısızsa partial reward bırakılmaz
- duplicate turn-in/reward retry ikinci grant üretmez
- same-ID conflict reddi
- reward ledger save/load sonrası korunur
- client reward miktarı/type seçemez

---

# 10. Party share policy / LAN

PRG-04 group system geliştirmez; yalnız açık policy contract kurar.

Policy minimum:

- owner-only
- eligible-party
- shared-progress / shared-completion ayrımı gerekiyorsa explicit
- contribution event actor doğrulaması

LAN:

- quest accept host
- objective progress host
- completion host
- reward host
- client journal mirror detached DTO

Korunacak:

- spoof/replay/malformed/pre-ready rejection
- duplicate/lost-ACK idempotency
- reconnect/late-join current quest snapshot
- protocol mismatch

Client başka oyuncu adına quest tamamlayamaz veya reward yazamaz.

---

# 11. Persistence / migration

Persist minimum:

- active/completed quest stable IDs
- objective progress
- accepted/completed status
- timers/ticks/version
- processed objective event ledger gerektiği kadar
- reward claimed ledger
- NPC interaction minimal continuation state gerekiyorsa
- party-share policy sonucu gereken primitive state

Schema değişirse sequential migration.

Kurallar:

- invalid quest/objective refs açık failure
- corrupt DTO sessiz default değil
- old save deterministic empty PRG-04 state veya explicit migration
- Resource/Object/Node/RID/Callable yok
- presentation journal cache authoritative save değildir

---

# 12. Journal view model

Journal authority değildir.

Minimum:

- available/active/completable/completed groups
- objective progress text model
- region/target hints
- reward preview
- timer display
- tracked quest stable ID

Presentation yalnız detached snapshot tüketir.

UI quest state'i doğrudan mutasyona uğratmaz; accept/turn-in/track işlemleri intent üretir.

---

# 13. Minimal touch UI

Final POL-01 UI değil; doğrulanabilir akış:

- quest list
- quest detail
- objective progress
- accept
- turn-in
- journal tracking
- NPC interaction prompt
- timed quest countdown

Kurallar:

- safe area
- fontScale 1.3
- 48 px+ hit target
- drag/drop yok
- scroll ve touch world input çatışmaz
- interaction prompt world movement'a sızmaz
- icon/portrait placeholder kabul

---

# 14. CI / test matrisi

Exact PRG-04 code SHA üzerinde minimum:

1. QuestDefinition schema validation
2. missing/duplicate quest/NPC/region refs
3. quest-chain self/indirect cycle
4. accept prerequisite success/rejection
5. start/turn-in NPC validation
6. region/map constraint
7. kill objective
8. damage objective
9. capture objective
10. collect objective
11. acquire objective
12. timed objective
13. escort/salvage/trade adapter fixtures
14. duplicate objective event idempotency
15. same-event-ID payload conflict
16. objective wrong target/region rejection
17. completion state transition
18. reward atomic success
19. partial reward failure rollback
20. duplicate turn-in/reward retry
21. save/load + migration + corrupt DTO
22. reconnect/late-join quest snapshot
23. host authority/spoof/replay/malformed
24. journal/NPC touch intent tests
25. PRG-01 inventory regression
26. PRG-02 craft/upgrade/core/trophy regression
27. PRG-03 XP/skill/gate/challenge regression
28. existing VS/CORE/AI/NET full regressions

Parse/load/orphan/failing/ignored unexpected conditions failure sayılır.

---

# 15. Export / artifact

Exact green SHA:

Linux:
- debug export
- executable + PCK
- exported executable headless boot

Android:
- arm64-v8a debug APK
- package `com.osmanyildirim.seacraft`
- targetSdk 37
- INTERNET + ACCESS_LOCAL_NETWORK
- APK integrity/readback

Artifact:

`SeaCraft-PRG04-<exact SHA>`

Minimum:
- Android APK
- Linux executable/PCK
- `COMMIT_SHA.txt`
- `SHA256SUMS.txt`

Authenticated artifact readback zorunlu.

---

# 16. Gerçek Android cihaz

Mümkünse:

- NPC interaction prompt
- accept/turn-in
- journal scrolling
- objective tracking
- timed countdown
- fontScale 1.3
- safe area
- small-screen readability
- save/reload quest state
- LAN reconnect quest mirror

Yapılmadıysa `not_run`; CI gerçek cihaz değildir.

---

# 17. Kapanış

Tamamlandı demeden:

1. exact code SHA
2. full CI/test + PRG-04 verifier
3. PRG-01/02/03 ve tüm eski regresyonlar
4. Linux + Android export
5. artifact upload + authenticated readback + hashes
6. physical device yoksa `not_run`
7. mevcut Avenox PRG-04 task strict done revision
8. tek receipt ve readback
9. `GOREV_RAPORU.md` tek PRG-04 kapanış bölümü
10. `AKTIF_GOREV.md` KAPALI
11. `SESSION_HANDOFF.md` PRG-04 kapanış / PRG-05 kapısı
12. bütün kapılar geçmeden PRG-05'e başlama

İlk commit veya workflow queue başarı değildir. Hata varsa kök nedeni düzelt ve exact teslim zincirini yeniden doğrula.
