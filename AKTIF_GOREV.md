# AKTİF GÖREV — PRG-02

> Bu dosya SeaCraft'ın kanonik aktif uygulama briefidir. Sohbette uzun brief tekrarlanmaz.
>
> Görev tamamlandığında ayrıntılı doğrulama sonucu yalnız `GOREV_RAPORU.md` dosyasına, mevcut geçmiş korunarak yeni bir PRG-02 bölümü halinde yazılır. Sohbet cevabı kısa tutulur.

## Durum — AKTİF

PRG-01 doğrulanmış biçimde kapalıdır. WAVE 6'nın ikinci görevi PRG-02 başlatılmıştır. PRG-03, PRG-02 exact teslimi GitHub'dan doğrulanıp kanonik kayıtlar kapatılmadan başlatılmaz.

## Kimlik

- Sohbet etiketi: `[SOHBET-33 | SeaCraft PRG-02 — Crafting, Reclamation, Ship Upgrade ve Cores/Trophies]`
- Repo: `TheOsmanYILDIRIM/SeaCraft`
- Dal: yalnız `main`
- Uygulama başlangıç HEAD'i: `160e159a69182cdd4cac6d65a3d3d345de02ec5f`
- PRG-01 exact kod kapanışı: `a3344909e489adc93800f6591238eb7102561542`
- PRG-01 Actions: `45015026436` — `success`
- PRG-01 artifact ID: `14750439866`
- Godot: `4.7.2-stable`
- Bağımlılık: PRG-01 tamamlandı
- Avenox Beyin görevi: `tasks/seacraft-prg02-crafting-reclamation-ship-upgrade-cores-trophies-20261122.md`
- Sonraki görev: PRG-03 — PRG-02 kapanmadan başlama

Her mesajına yukarıdaki sohbet etiketiyle başla.

Başlamadan güncel `main` HEAD'i, bu dosyayı, `GELISTIRME_GOREV_PLANI.md`, `GOREV_RAPORU.md`, `SESSION_HANDOFF.md` ve `README.md` dosyalarını yeniden doğrula. HEAD değişmişse başkasının değişikliğini ezme; güncel diff ve sahipliği inceleyip yalnız PRG-02 kapsamını güvenli biçimde uygula.

---

# 1. Kanonik amaç

Plan:

**PRG-02 — Crafting, reclamation, ship upgrade ve cores/trophies**

Amaç:

- PRG-01'in tek authoritative `InventoryState` gerçeği üzerinde gerçek crafting ve reclamation/salvage loop'u kurmak
- recipe doğrulama, input tüketimi ve output grant işlemlerini tek atomik transaction sınırında çalıştırmak
- salvage/reclamation sonucunu deterministic RNG stream ve persisted RNG state ile üretmek
- ship upgrade progression'ını cycle-free, veri odaklı bir DAG olarak kurmak
- core slotları ve core uygunluk kurallarını build/progression sistemine eklemek
- trophy/perk unlock ledger'ını idempotent ve primitive-safe yapmak
- bütün stat etkilerini mevcut tek `StatModifierPipeline` üzerinden geçirmek
- offline-first davranışı korurken LAN'da craft/salvage/upgrade/core/trophy mutasyonlarını host-authoritative yapmak

Mekanik katalog:

- M-022
- M-023
- M-024
- M-025
- M-026

Güncel 767 kayıtlı forum araştırması yalnız kategori, çeşitlilik, progression pattern ve objective/stat ilişki referansıdır. Forumdaki exact isim/değer/görsel veya ekonomik oran SeaCraft final içeriğine doğrudan kopyalanmaz.

---

# 2. PRG-01 sözleşmelerini koru

PRG-02 yeni bir inventory veya modifier sistemi kurmaz.

Zorunlu reuse:

- `InventoryState` tek authoritative item miktar/container/build truth
- PRG-01 transaction ID / duplicate retry / conflict / rollback modeli
- `ItemDefinition` + stable-ID `DefinitionRegistry`
- `StatModifierPipeline` tek stat modifier implementation'ı
- primitive-safe DTO ve stable-ID persistence/network sınırı
- save migration zinciri
- loot/crafting/reclamation sonucunun aynı authoritative inventory'ye grant edilmesi
- NET-04/PRG-01 host-authoritative LAN ve lost-ACK idempotency modeli
- presentation-only client mirror sınırı

Crafting, salvage, upgrade, core veya trophy state'i ikinci bir authoritative item gerçeği oluşturamaz.

---

# 3. RecipeDefinition ve crafting veri modeli

Minimum `RecipeDefinition`:

- stable recipe ID
- input listesi: stable item ID + pozitif integer quantity
- output listesi: stable item ID + pozitif integer quantity
- gerekiyorsa bounded craft count
- prerequisite listesi
- ship/upgrade tier veya unlock requirement yalnız gerekli minimumda
- recipe category/tag
- deterministic validation metadata

Kurallar:

- duplicate/missing recipe ID reddedilir
- missing item definition reddedilir
- quantity 0/negative reddedilir
- integer overflow reddedilir
- aynı recipe'nin input/output toplamları primitive-safe kalır
- input ile output aynı stable ID olabilir fakat net mutation transaction içinde doğru hesaplanır
- recipe runtime Node/Resource referansı persist edilmez
- içerik Resource olabilir; runtime intent ve save stable ID/primitive değer taşır

Recipe validator registry/content validation zincirine eklenmeli; dağınık UI string karşılaştırmalarıyla uygulanmamalı.

---

# 4. CraftTransaction — atomik consume + grant

Craft tek transaction olarak doğrulanmalı.

Minimum sıra:

1. actor/session/authority doğrulaması
2. recipe stable ID doğrulaması
3. prerequisite doğrulaması
4. craft count boundary
5. bütün input miktarlarının mevcut olması
6. bütün output grant/stack/capacity kurallarının önceden doğrulanması
7. tek atomik commit
8. deterministic result DTO
9. transaction ledger terminal result kaydı

Kabul:

- herhangi bir input eksikse hiçbir şey tüketilmez
- output inventory kapasitesi/stack/weight yüzünden sığmıyorsa inputlar tüketilmez
- multi-count craft kısmi uygulanmaz
- duplicate transaction ID aynı actor/payload için cached result döndürür
- aynı ID farklı actor/payload ile conflict reddedilir
- lost-ACK retry ikinci tüketim veya grant üretmez
- snapshot/restore sonrası idempotency korunur

PRG-01 InventoryState transaction primitive'lerini mümkün olduğunca reuse et; crafting için paralel item ledger kurma.

---

# 5. Reclamation / salvage

`SalvageTable` veri odaklı olmalı.

Minimum:

- salvage table stable ID
- izinli source item/category
- deterministic reward entries
- bounded min/max quantity
- probability/weight alanları
- prerequisite/tag yalnız gerekli minimumda
- source item consume policy

RNG:

- mevcut kanonik RNG stream altyapısını kullan
- yeni bağımsız gizli/random seed kaynağı kurma
- salvage sonucu authority tarafından üretilir
- RNG state save/load ile devam eder
- reject edilen salvage RNG tüketmez
- duplicate retry RNG'yi ikinci kez ilerletmez
- deterministic fixture aynı seed/state + aynı input için aynı sonucu üretir

Salvage atomikliği:

- source consume + reward grant tek transaction
- reward kapasiteye sığmıyorsa hiçbir mutasyon bırakma
- invalid table/item/category reddedilir
- aynı itemin ekipman/locked state'i varsa uygun policy açık doğrulanmalı
- equipped item doğrudan salvage edilemez; önce authoritative unequip veya explicit policy gerekir

---

# 6. Ship upgrade board — cycle-free DAG

Upgrade progression veri odaklı directed acyclic graph olmalı.

Minimum node:

- stable upgrade ID
- prerequisite upgrade IDs
- material/item cost
- gerekiyorsa currency-benzeri maliyet yalnız mevcut inventory stable item sistemiyle
- tier/level
- unlock effect veya modifier source IDs
- core slot count/type değişikliği gerekiyorsa açık effect
- mutually-exclusive/branch policy yalnız gerekiyorsa

Validator:

- missing prerequisite reddi
- self-cycle reddi
- indirect cycle reddi
- duplicate edge/node reddi
- unreachable/invalid root policy açık
- tier regression veya bounded level ihlali reddi

Upgrade transaction:

- prerequisite'ler tamamlanmadan uygulanmaz
- cost consume + unlock ledger + modifier update tek atomik commit
- duplicate transaction ikinci cost tüketmez
- başarısız modifier/core-slot application tam rollback
- save/load sonrası graph unlock state korunur
- graph tanımı content'tir; unlocked state runtime primitive-safe'dir

---

# 7. Core slots

Core sistemi yeni stat engine değildir.

Minimum:

- core item/category definition veya mevcut ItemDefinition uzantısı
- core slot type
- allowed core category/type
- bounded slot count
- unique/duplicate policy
- modifier source IDs
- prerequisite/upgrade gate gerekiyorsa stable ID

Kurallar:

- yanlış core yanlış slota takılamaz
- core inventory'de gerçekten bulunmalı
- insert/remove/replace atomik
- remove sonucu inventory kapasitesi yüzünden sığmıyorsa slot değişmez
- slot unlock ship upgrade DAG'den geliyorsa deterministic ve testli
- core statları yalnız `StatModifierPipeline` üzerinden uygulanır
- aynı core source modifier duplicate uygulanmaz
- preset sistemi core state'i kapsıyorsa PRG-01 preset atomicity sözleşmesini bozma; kapsam gerektirmiyorsa preset şemasını gereksiz genişletme

---

# 8. Trophy / perk unlock ledger

Trophy/perk burada progression unlock ledger olarak kurulur; PRG-03 skill tree'nin yerine geçmez.

Minimum:

- stable trophy/perk ID
- unlock prerequisites veya event key
- unlock state
- optional modifier/reward refs
- idempotent event ledger

Kurallar:

- aynı unlock event ikinci unlock/reward üretmez
- invalid/missing trophy/perk ID reddedilir
- unlock prerequisite bypass edilemez
- reward varsa InventoryState üzerinden atomik grant
- modifier varsa tek `StatModifierPipeline`
- save/load sonrası unlock ledger korunur
- client unlock sonucunu seçemez veya authoritative state yazamaz

PRG-03 XP/skill/rank sistemlerini burada geliştirme.

---

# 9. Persistence ve migration

Crafting/progression state existing save chain'e eklenir.

Persist edilecek minimum:

- unlocked ship upgrades
- installed cores
- trophy/perk unlock ledger
- craft/salvage transaction terminal ledger gerektiği ölçüde
- salvage RNG continuation mevcut RNG snapshot içinde
- gerekli runtime progression metadata

Yasak:

- Resource/Object/Node/RID/Callable
- duplicate inventory truth
- client presentation cache'i authoritative save'e taşımak
- network protocol version ile save schema version'ı birbirine bağlamak

Schema değişirse sequential migration ekle.

Old saves:

- deterministic empty PRG-02 progression default veya açık migration
- corrupt/invalid DTO sessizce kabul edilmez
- missing stable IDs açık validation failure veya documented migration davranışı üretir

---

# 10. LAN / authority

Host-mutating PRG-02 işlemleri:

- craft
- salvage/reclamation
- ship upgrade
- core insert/remove/replace
- trophy/perk unlock/reward mutation

Client intent yalnız bounded primitive data taşır:

- transaction ID
- recipe/table/upgrade/core/trophy stable ID
- craft count/slot index gibi bounded değerler
- gerekli target owner/player stable ID ancak host mapping ile doğrulanmış biçimde

Client:

- RNG sonucu seçemez
- output miktarı seçemez
- unlock sonucunu seçemez
- inventory/stat/progression authoritative yazamaz

NET-04/PRG-01 transaction ledger'ı reuse/extend et. Wire contract değişirse protocol version yalnız gerçekten gerektiğinde bump edilir ve mismatch açık reddedilir.

Spoof/replay/malformed/pre-ready/lost-ACK regresyonlarını koru.

---

# 11. Minimal touch presentation

PRG-02 için final UI değil, doğrulanabilir touch akışı yeterlidir.

Minimum:

- recipe list/select
- craft action
- salvage/reclamation select + confirm
- upgrade board select/apply
- core slot select/insert/remove
- trophy/perk unlock status görünümü

Kurallar:

- drag/drop zorunlu değil
- 48 px veya mevcut mobil contract'a uygun büyük hit target
- safe-area uyumu
- fontScale 1.3 okunabilirlik metadata/test
- presentation authority yazmaz
- confirm/destructive action açık olmalı
- çok adımlı craft UI düşük bellekli, bounded data listeleri kullanmalı

Final polish POL-01 kapsamıdır.

---

# 12. CI / test matrisi

Exact PRG-02 code SHA üzerinde minimum yeni kapılar:

1. RecipeDefinition schema/registry validation
2. missing/duplicate recipe/item refs
3. craft quantity boundaries
4. atomic craft consume+grant success
5. craft missing input rejection
6. craft output-capacity failure full rollback
7. duplicate craft transaction + same-ID conflict
8. lost-ACK craft retry idempotency
9. SalvageTable schema validation
10. deterministic salvage fixture with persisted RNG continuation
11. rejected salvage consumes no RNG
12. salvage consume+reward rollback
13. upgrade DAG self/indirect cycle rejection
14. missing prerequisite/invalid edge
15. upgrade cost + unlock atomicity
16. core slot compatibility + insert/remove rollback
17. core modifier pipeline deterministic/duplicate guard
18. trophy/perk unlock idempotency
19. save/load + migration + corrupt DTO
20. LAN host authority / spoof/replay/malformed rejection
21. PRG-01 inventory/equipment/preset regression
22. existing VS/CORE/AI/NET regression suite

Testleri veya güvenlik kapılarını gevşeterek yeşil sonuç alma. Parse/load/orphan/failing/ignored beklenmeyen durumları başarısızlık say.

---

# 13. Export / artifact

Exact green SHA için:

Linux:

- debug export
- executable + PCK doğrulaması
- exported executable headless boot

Android:

- arm64-v8a debug APK
- package `com.osmanyildirim.seacraft`
- targetSdk 37
- INTERNET ve ACCESS_LOCAL_NETWORK izinleri korunur
- APK integrity/readback

Artifact:

`SeaCraft-PRG02-<exact SHA>`

İçerik minimum:

- Android APK
- Linux executable/PCK
- `COMMIT_SHA.txt`
- `SHA256SUMS.txt`

Actions artifact authenticated readback ile yeniden doğrulanır; artifact adı, ID, exact SHA ve hashler `GOREV_RAPORU.md` kapanışına işlenir.

---

# 14. Gerçek Android cihaz kapısı

CI gerçek cihaz değildir.

Mümkünse:

- recipe list/select/craft
- salvage confirmation
- upgrade board touch navigation
- core insert/remove
- inventory ↔ craft ekran geçişi
- fontScale 1.3
- safe area / küçük ekran
- save/reload progression
- LAN host/client duplicate retry

Fiziksel cihaz yoksa açıkça `not_run` bırak. CI/export'u cihaz kanıtı gibi gösterme.

---

# 15. Çalışma sohbeti / GitHub iletişim protokolü

SOHBET-33 başlamadan:

- güncel `main` HEAD'i ve kanonik briefi yeniden oku
- başka sohbetin commit'ini ezme
- yalnız PRG-02 kapsamını değiştir

Çalışırken:

- PRG-01 sözleşmelerini koru
- başkasının bağımsız değişikliklerini koru
- HEAD ilerlerse günceli yeniden oku ve yalnız çakışmayan alanı yeniden uygula
- sonuç/test/commit/engel kanıtını GitHub'daki mevcut kanonik kayda işle
- uzun sonuç raporunu sohbete dökme

Bağımlı PRG-03 ancak PRG-02 exact GitHub kapanışı doğrulandıktan sonra açılır.

---

# 16. Kapanış

Tamamlandı demeden:

1. exact code SHA'yı doğrula
2. full CI/test ve PRG-02 verifier marker'larını doğrula
3. PRG-01 ve eski regresyonların geçtiğini doğrula
4. Linux + Android exportu doğrula
5. artifact upload + authenticated readback + hashleri doğrula
6. fiziksel cihaz yoksa `not_run` yaz
7. mevcut Avenox PRG-02 taskını duplicate yaratmadan strict done revision ile kapat
8. tek kapanış receipt üret ve geri oku
9. `GOREV_RAPORU.md` içine geçmişi koruyan tek PRG-02 bölümü ekle ve geri oku
10. `AKTIF_GOREV.md` durumunu KAPALI yap
11. `SESSION_HANDOFF.md` PRG-02 kapanışını ve PRG-03 kapısını yansıtsın
12. bütün kapılar geçmeden PRG-03'e başlama

İlk commit/workflow queue başarı değildir. Hata varsa logu aç, kök nedeni düzelt ve exact teslim zincirini yeniden doğrula.
