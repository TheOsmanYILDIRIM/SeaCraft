# AKTİF GÖREV — PRG-03

> Bu dosya SeaCraft'ın kanonik aktif uygulama briefidir. Sohbette uzun brief tekrarlanmaz.
>
> Görev tamamlandığında ayrıntılı doğrulama sonucu yalnız `GOREV_RAPORU.md` dosyasına, mevcut geçmiş korunarak yeni bir PRG-03 bölümü halinde yazılır. Sohbet cevabı kısa tutulur.

## Durum — AKTİF

PRG-02 doğrulanmış biçimde kapalıdır. WAVE 6'nın üçüncü görevi PRG-03 başlatılmıştır. PRG-04, PRG-03 exact teslimi GitHub'dan doğrulanıp kanonik kayıtlar kapatılmadan başlatılmaz.

## Kimlik

- Sohbet etiketi: `[SOHBET-34 | SeaCraft PRG-03 — XP, Skill Tree, Rank ve Local Challenge Meta]`
- Repo: `TheOsmanYILDIRIM/SeaCraft`
- Dal: yalnız `main`
- Uygulama başlangıç HEAD'i: `c1dd69644e7dc77ece909eb62c1cfb1691730eb4`
- PRG-02 exact kod kapanışı: `d6ddfb014ee83ef9826563441453152d15d7d789`
- PRG-02 Actions: `45019833696` — `success`
- PRG-02 artifact ID: `14753292824`
- Godot: `4.7.2-stable`
- Bağımlılık: PRG-02 tamamlandı
- Avenox Beyin görevi: `tasks/seacraft-prg03-xp-skill-tree-rank-local-challenge-meta-20261122.md`
- Sonraki görev: PRG-04 — PRG-03 kapanmadan başlama

Her mesajına yukarıdaki sohbet etiketiyle başla.

Başlamadan güncel `main` HEAD'i, bu dosyayı, `GELISTIRME_GOREV_PLANI.md`, `GOREV_RAPORU.md`, `SESSION_HANDOFF.md` ve `README.md` dosyalarını yeniden doğrula. HEAD değişmişse başkasının değişikliğini ezme; güncel diff ve sahipliği inceleyip yalnız PRG-03 kapsamını güvenli biçimde uygula.

---

# 1. Kanonik amaç

Plan:

**PRG-03 — XP, skill tree, rank ve local challenge meta**

Amaç:

- player growth'u offline-first ve deterministic progression state olarak kurmak
- XP gain'i idempotent ledger ile tek authoritative progression truth içinde tutmak
- level/rank hesaplamasını veri odaklı, bounded ve deterministic yapmak
- skill tree'yi cycle-free prerequisite DAG olarak kurmak
- skill point spend ve respec işlemlerini atomik transaction yapmak
- license/test gates ile progression unlock koşullarını stable-ID sözleşmesiyle bağlamak
- internet gerektirmeyen local challenge/milestone meta sistemi kurmak
- progression kaynaklı bütün stat etkilerini mevcut tek `StatModifierPipeline` üzerinden geçirmek
- LAN'da XP/spend/respec/challenge reward mutasyonlarını host-authoritative yapmak

Mekanik katalog:

- M-021
- M-032
- M-033
- M-035
- M-054

Forum araştırması yalnız progression pattern, objective ve kategori referansıdır. Exact isim, XP eğrisi, rank değeri, challenge ödülü veya görsel doğrudan production içeriğine kopyalanmaz.

---

# 2. PRG-01 / PRG-02 sözleşmelerini koru

Yeni ikinci progression/inventory/modifier truth oluşturma.

Zorunlu reuse:

- PRG-01 `InventoryState` ve atomik transaction modeli
- PRG-01 duplicate transaction / same-ID conflict / lost-ACK idempotency
- PRG-02 trophy/perk unlock ledger pattern'ı gerekiyorsa reuse
- stable-ID `DefinitionRegistry`
- tek `StatModifierPipeline`
- primitive-safe DTO ve persistence/network sınırı
- save migration zinciri
- NET-04/PRG-01/02 host-authoritative session/transaction modeli

XP, skill/rank/challenge state'i authoritative progression altında tek sahipli kalmalı.

---

# 3. XP ledger

Minimum XP modeli:

- player/owner stable ID
- total XP — bounded non-negative integer
- processed XP event ledger
- event stable ID
- source/category metadata yalnız primitive-safe
- grant amount
- resulting total / level/rank view

Kurallar:

- XP grant yalnız authoritative event/transaction üzerinden
- quantity 0/negative reddi
- overflow reddi
- aynı event ID ikinci XP üretmez
- aynı event ID farklı actor/payload ile conflict
- reject edilen event state değiştirmez
- save/load sonrası processed ledger korunur
- client XP miktarını veya outcome'u seçemez
- global/online leaderboard yok

Event ledger mevcut transaction/idempotency modelini reuse etsin; paralel duplicate sistemi kurma.

---

# 4. Level ve rank

Level/rank progression veri odaklı olmalı.

Minimum definition:

- stable level/rank ID veya deterministic numeric tier
- XP threshold
- prerequisite/gate gerekiyorsa stable ID
- unlock hooks
- skill point grant
- presentation label content-side olabilir

Validator:

- threshold sırası monoton
- duplicate threshold/ID policy açık
- negative threshold yok
- unreachable rank yok
- integer overflow yok

Davranış:

- XP → level/rank sonucu deterministic
- tek XP grant birden çok level aşabiliyorsa doğru uygulanır
- level düşüşü yalnız açık respec/reset policy varsa
- skill point grant bir kez
- save/load sonrası aynı XP aynı level/rank sonucu üretir
- level/rank modifier ise `StatModifierPipeline` üzerinden

---

# 5. Skill DAG

Skill definitions stable-ID prerequisite DAG olmalı.

Minimum skill:

- stable skill ID
- prerequisite skill IDs
- rank/tier
- point cost
- max rank gerekiyorsa bounded
- modifier source IDs veya unlock effect refs
- license/test gate gerekiyorsa stable ID
- mutually-exclusive branch yalnız gerçekten gerekiyorsa açık policy

Validator:

- self-cycle reddi
- indirect cycle reddi
- missing prerequisite reddi
- duplicate edge reddi
- invalid rank/max rank reddi
- negative/zero point cost policy açık
- unreachable node policy açık
- modifier refs valid

Skill state runtime primitive-safe:

- unlocked/learned ranks
- available/unspent points
- stable IDs

---

# 6. Skill spend transaction

Spend tek atomik transaction:

1. host/actor authority
2. skill stable ID
3. prerequisite
4. gate
5. current rank/max rank
6. available point
7. modifier/effect validity
8. commit

Kabul:

- failed spend point tüketmez
- modifier apply failure rollback
- duplicate transaction ikinci rank/point tüketmez
- same-ID conflict reddi
- save/load sonrası ledger idempotency
- client skill sonucunu yazamaz

---

# 7. Respec

Respec atomik ve deterministic olmalı.

Minimum:

- full respec veya açık bounded subtree policy
- refundable point calculation
- non-refundable gate/cost varsa data-driven
- dependency validation
- modifier removal
- restored point total

Kabul:

- respec sonrası prerequisite ihlali bırakılamaz
- kısmi failure tüm state'i rollback eder
- removed skill modifier'ları tek pipeline'dan kalkar
- refunded points doğru ve bir kez
- duplicate respec transaction tekrar refund üretmez
- gerekiyorsa inventory cost PRG-01 InventoryState ile atomik tüketilir

---

# 8. License / test gates

PRG-03 yalnız progression gate altyapısını kurar; quest/dialog content PRG-04 kapsamıdır.

Gate minimum:

- stable gate ID
- gate type: license/test/milestone/rank gibi bounded enum/string
- prerequisites
- completion state
- optional reward/unlock refs

Kurallar:

- gate bypass edilemez
- completion duplicate reward üretmez
- missing prerequisite reddedilir
- cycle gerekiyorsa DAG validator ile reddedilir
- save/load korunur
- host-authoritative
- future PRG-04 quest sistemi bu gate API'yi tüketebilmeli

---

# 9. Local challenge / milestone

M-035 / M-054 internet gerektirmeyen local meta olarak uygulanır.

Minimum challenge definition:

- stable challenge ID
- version/reset key
- objective counter/type
- target value
- reward refs
- recurrence policy: once / session / daily-like local rotation gerekiyorsa explicit
- deterministic local schedule/version metadata

Kurallar:

- global backend/leaderboard yok
- internet yokken tam çalışır
- reward idempotent
- version change/reset fixture deterministic
- system clock exploit-resistant mutlak anti-cheat iddiası yok; policy açık
- save/load progress korunur
- challenge completion reward InventoryState/XP ledger üzerinden atomik
- duplicate completion ikinci reward/XP üretmez

“Daily” benzeri local içerik varsa online servis taklidi yapma; local version/seed contract olarak açık uygula.

---

# 10. StatModifierPipeline entegrasyonu

Skill, rank, gate/perk kaynaklı stat etkileri:

`StatModifierPipeline`

üzerinden uygulanmalı.

Kurallar:

- ikinci stat engine yok
- modifier source stable ID deterministic
- duplicate source guard
- spend/respec sonrası doğru add/remove
- save/load sonrası aynı progression aynı stat sonucu
- existing equipment/core/trophy modifier kaynaklarıyla deterministic order korunur

---

# 11. Persistence / migration

Persist minimum:

- total XP
- processed XP ledger
- level/rank state veya yalnız XP'den türetilebiliyorsa redundant truth yaratmadan gerekli metadata
- skill ranks
- unspent/earned point ledger
- gate completion
- local challenge progress/version/reward ledger
- transaction terminal ledger gerektiği ölçüde

Yasak:

- Resource/Object/Node/RID/Callable
- redundant authoritative level/rank truth drift riski
- presentation cache
- online-service dependency

Schema değişirse sequential migration ekle. Corrupt/invalid DTO sessiz default ile kabul edilmez.

---

# 12. LAN / authority

Host-mutating PRG-03 işlemleri:

- XP grant/event application
- skill spend
- respec
- gate completion/reward
- challenge completion/reward

Client yalnız bounded intent/event request gönderir; authoritative amount/outcome seçemez.

Korunacak:

- spoof rejection
- replay rejection
- malformed/pre-ready rejection
- lost-ACK retry idempotency
- protocol mismatch
- offline parity

Wire contract değişirse protocol version gerektiği kadar bump edilir; save schema ile bağlanmaz.

---

# 13. Minimal touch presentation

Final UI değil; doğrulanabilir touch akışı:

- XP / rank summary
- skill tree view
- zoom/pan
- node select
- spend confirm
- respec confirm
- license/test gate state
- local challenge list/progress

Kurallar:

- safe area
- fontScale 1.3
- büyük hit target
- presentation authority yazmaz
- zoom/pan world command'a sızmaz
- node seçimi ile camera gesture çakışmaz
- icon placeholder kabul

Final polish POL-01 kapsamıdır.

---

# 14. CI / test matrisi

Exact PRG-03 code SHA üzerinde minimum:

1. XP positive/boundary/overflow validation
2. XP duplicate event idempotency
3. same-event-ID payload conflict
4. save/load XP ledger
5. level/rank threshold validation
6. multi-level gain
7. one-time point grants
8. skill DAG self/indirect cycle
9. missing prerequisite/invalid ref
10. skill spend success
11. insufficient point/gate rejection rollback
12. duplicate spend/lost-ACK retry
13. respec atomic refund + modifier removal
14. respec dependency consistency
15. gate prerequisite/completion idempotency
16. local challenge progress/completion/reward
17. challenge version/reset fixture
18. offline/no-internet dependency guard
19. modifier deterministic/duplicate source guard
20. save/load + migration + corrupt DTO
21. LAN host authority/spoof/replay/malformed
22. PRG-01 inventory/equipment regression
23. PRG-02 craft/upgrade/core/trophy regression
24. existing VS/CORE/AI/NET full regression

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
- INTERNET + ACCESS_LOCAL_NETWORK korunur
- APK integrity/readback

Artifact:

`SeaCraft-PRG03-<exact SHA>`

Minimum içerik:

- Android APK
- Linux executable/PCK
- `COMMIT_SHA.txt`
- `SHA256SUMS.txt`

Authenticated artifact readback zorunlu.

---

# 16. Gerçek Android cihaz

Mümkünse:

- skill tree zoom/pan
- node select/spend
- respec confirm
- fontScale 1.3
- safe area
- small-screen readability
- save/reload progression
- LAN retry/spend

Yapılmadıysa `not_run`; CI gerçek cihaz değildir.

---

# 17. Kapanış

Tamamlandı demeden:

1. exact code SHA
2. full CI/test + PRG-03 verifier
3. PRG-01/02 ve tüm eski regresyonlar
4. Linux + Android export
5. artifact upload + authenticated readback + hashes
6. physical device yoksa `not_run`
7. mevcut Avenox PRG-03 task strict done revision
8. tek receipt ve readback
9. `GOREV_RAPORU.md` tek PRG-03 kapanış bölümü
10. `AKTIF_GOREV.md` KAPALI
11. `SESSION_HANDOFF.md` PRG-03 kapanış / PRG-04 kapısı
12. bütün kapılar geçmeden PRG-04'e başlama

İlk commit veya workflow queue başarı değildir. Hata varsa kök nedeni düzelt ve exact teslim zincirini yeniden doğrula.
