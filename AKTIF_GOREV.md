# AKTİF GÖREV — PRG-01

> Bu dosya SeaCraft'ın kanonik aktif uygulama briefidir. Sohbette uzun brief tekrarlanmaz.
>
> Görev tamamlandığında ayrıntılı doğrulama sonucu yalnız `GOREV_RAPORU.md` dosyasına, mevcut geçmiş korunarak yeni bir PRG-01 bölümü halinde yazılır. Sohbet cevabı kısa tutulur.

## Durum — KAPALI

PRG-01 exact kod SHA `a3344909e489adc93800f6591238eb7102561542`, Actions run `45015026436`, artifact ID `14750439866` ve Avenox Beyin strict kapanış commit'i `8c811e1afe2000424a9bf15940db75f54d579be3` ile doğrulanmış biçimde kapalıdır. PRG-02 bu görev kapsamında başlatılmadı.

## Kimlik

- Sohbet etiketi: `[SOHBET-32 | SeaCraft PRG-01 — Inventory, Equipment, Crew, Pet/Companion ve Preset]`
- Repo: `TheOsmanYILDIRIM/SeaCraft`
- Dal: yalnız `main`
- Uygulama başlangıç kod tabanı: `916d87167ecd6f99c99212f4aae29fb615da041f`
- NET-04 exact kod kapanışı: `ba5fd180b9e359b0dcc146b58c52254fe537f317`
- Godot: `4.7.2-stable`
- Bağımlılık: NET-04 tamamlandı
- Avenox Beyin görevi: `tasks/seacraft-prg01-inventory-equipment-crew-pet-preset-20261122.md`
- Sonraki görev: PRG-02 — ayrı görev/brief ile başlatılabilir; bu kapanış PRG-02'yi başlatmaz

Her mesajına yukarıdaki sohbet etiketiyle başla.

Başlamadan güncel `main` HEAD'i, bu dosyayı, `GELISTIRME_GOREV_PLANI.md`, `GOREV_RAPORU.md`, `SESSION_HANDOFF.md` ve `README.md` dosyalarını yeniden doğrula. HEAD değişmişse başkasının değişikliğini ezme; güncel diff ve sahipliği inceleyip yalnız PRG-01 kapsamını güvenli biçimde uygula.

---

# 1. Kanonik amaç

Plan:

**PRG-01 — Inventory, equipment, crew, pet/companion ve preset**

Amaç:

- mevcut loot'u gerçek build/progression sisteminin tek inventory truth'una dönüştürmek
- stack, slot, kapasite/weight ve transfer kurallarını atomik transaction olarak kurmak
- weapon, structure, sail, figurehead, crew, trainer, pet/companion ekipman katmanlarını veri odaklı hale getirmek
- ship/pet gem ve socket progression'ı eklemek
- preset uygulamasını güvenli ve atomik yapmak
- equipment/crew/pet/gem kaynaklı tüm stat değişikliklerini mevcut tek `StatModifierPipeline` üzerinden geçirmek
- offline davranışı korurken LAN'da bütün host-mutating işlemleri host-authoritative ve idempotent yapmak

Mekanik katalog:

- M-016
- M-017
- M-018
- M-019
- M-020
- M-052

Güncel 767 kayıtlı forum araştırması yalnız şema, kategori, çeşitlilik ve objective/stat ilişki referansıdır. Forumdaki exact isim/değer/görsel SeaCraft final içeriğine veya dengesine doğrudan kopyalanmaz.

---

# 2. Mevcut sözleşmeleri koru

Korunacak production doğruları:

- `ItemDefinition` ve stable-ID/DefinitionRegistry yaklaşımı
- `StatModifierPipeline` tek modifier-order implementation'ı
- primitive-safe DTO ve stable-ID persistence/network sınırı
- FND-06/CORE save migration zinciri
- VS-03 / CORE loot akışı
- CORE-02 world-object/loot idempotency
- NET-04 transaction ID + lost-ACK retry/idempotency modeli
- host-authoritative LAN ve presentation-only client mirror sınırı
- simulation katmanında ENet/RPC/UI/render/input API yasağı

Mevcut `LootAuthority` içindeki `_inventory: Dictionary` PRG-01'de ikinci bir inventory truth olarak kalmamalı. Loot drop/claimed/processed-event sorumlulukları korunabilir; item miktarı ve build/equipment gerçeği tek bir authoritative `InventoryState` tarafından sahiplenilmeli.

`EntityRuntimeState.inventory`, presentation cache, network mirror veya üçüncü parti addon nesnesi ikinci authoritative inventory kaynağına dönüşmemeli.

---

# 3. InventoryState ve atomik transaction çekirdeği

Minimum üretim modeli:

- `InventoryState` — authoritative miktar/stack/container/slot gerçeği
- bounded stack/slot kayıtları
- item stable ID
- quantity
- container/owner stable ID
- gerekiyorsa weight/capacity metadata
- deterministic snapshot/restore
- primitive-safe validation

İşlemler mümkün olduğunca tek bir transaction sınırından geçmeli:

- add/grant
- remove/consume
- transfer
- equip
- unequip
- gem/socket insert/upgrade/remove
- preset apply

Kurallar:

- quantity 0/negative reddedilir
- stack_limit aşılmaz
- integer overflow yok
- invalid/missing stable ID reddedilir
- başarısız transaction hiçbir kısmi mutasyon bırakmaz
- transfer kaynakta azaltıp hedefte başarısız olursa tam rollback
- duplicate transaction ID aynı actor/payload için cached terminal result döndürür; ikinci item/stat ödülü üretmez
- aynı transaction ID farklı payload/actor ile conflict olarak reddedilir
- snapshot/restore sonrası transaction idempotency devam eder

Weight veya multi-container gerçekten gerekiyorsa bounded ve testli uygula. Sırf A11 listede olduğu için GLoot ekleme.

---

# 4. GLoot kararı

A11 GLoot yalnız **grid/weight/multi-container ihtiyacı mevcut custom modelle gereksiz karmaşık hale geliyorsa** ve Godot 4.7.2 + Android + save/LAN sınırlarına uygunluğu kanıtlanabiliyorsa kullanılır.

Varsayılan karar:

- PRG-01'i custom pure-data `InventoryState` ile uygula
- GLoot'u authoritative/network replicated object olarak kullanma
- client GLoot nesnesi replike etme
- addon eklenmezse bunu eksiklik sayma

GLoot eklenirse neden gerekli olduğu, lisans/pin, import, export ve authoritative ownership açık testle kanıtlanmalı.

---

# 5. Item/equipment veri şeması

Mevcut `ItemDefinition` stable-ID sözleşmesini genişletirken backwards compatibility ve registry doğrulamasını koru.

Minimum kategoriler/slot hedefleri:

- material / consumable / ammo gibi inventory-only öğeler gerektiği kadar
- weapon
- structure
- sail
- figurehead
- crew
- trainer
- pet / companion
- ship gem
- pet gem

Her equippable item için veri odaklı uygunluk:

- izinli slot türü
- gerekli item/category class
- stackability
- unique/duplicate policy gerekiyorsa açık
- modifier source IDs
- gem/socket compatibility gerekiyorsa açık
- requirement/prerequisite alanları yalnız PRG-01 kapsamı için gerekli minimumda

String karşılaştırmalarını dağınık UI koduna gömme; tek şema/validator kullan.

---

# 6. Equipment / crew / trainer / pet

Authoritative build state inventory ile aynı sahiplik modelinde kalmalı.

Slotlar:

- weapon
- structure
- sail
- figurehead
- crew
- trainer
- pet/companion

Kabul davranışı:

- yanlış kategori yanlış slota equip edilemez
- equip item inventory'de gerçekten bulunmalı
- equip/unequip atomik olmalı
- aynı item instance/quantity iki yerde birden authoritative olarak bulunamaz
- unequip hedef inventory kapasitesi/stack kuralı yüzünden başarısız olursa equipped state değişmemeli
- crew/trainer/pet yalnız veri/modifier source'tur; ayrı stat sistemi kurmaz
- pet/companion slotu tek authoritative build truth içinde tutulur

---

# 7. Gem / socket progression

Ship ve pet gem progression veri odaklı ayrı profile/category kurallarıyla çalışmalı.

Minimum doğrulamalar:

- socket sahibi stable ID
- socket türü / gem türü uyumluluğu
- bounded socket count
- bounded progression/level
- upgrade prerequisite ve cost doğrulaması
- invalid level/type/socket reddi
- consume + progression mutation tek atomik transaction
- duplicate transaction ikinci tüketim veya ikinci upgrade üretmez
- save/load sonrası socket/progression korunur

Exact forum gem değerleri final denge olarak taşınmaz. SeaCraft test fixture değerleri özgün ve küçük tutulur.

---

# 8. Tek modifier pipeline

Equipment, crew, trainer, pet ve gem kaynaklı bütün stat etkileri:

`StatModifierPipeline`

üzerinden uygulanmalı.

Kurallar:

- paralel ikinci modifier engine yok
- modifier stable ID deterministik
- aynı kaynak duplicate uygulanmaz
- equip/unequip sonrası doğru ekle/çıkar
- preset uygulaması sonunda pipeline tek tutarlı build state görür
- save/load sonrası aynı build aynı modifier sonucunu üretir

Movement/combat gibi mevcut stat tüketicilerini kırma; yalnız gerekli adapter/source katmanını ekle.

---

# 9. Preset

Preset pure-data stable-ID referanslarıyla çalışmalı.

Minimum:

- preset ID
- hedef equipment/crew/trainer/pet/gem seçimleri
- validation
- atomik apply
- save/load

Restriction:

- savaşta preset değişimi reddedilir
- gerekli safe-state/port kuralı açık ve testli olmalı
- reddedilen preset hiçbir item/equipment/stat durumunu kısmen değiştirmez
- missing item / incompatible slot / full return inventory gibi herhangi bir alt hata tüm preset transaction'ını rollback eder
- duplicate transaction idempotent kalır

PRG-01 yalnız restriction contract'ını kurar; daha sonraki faction/economy sistemlerini burada geliştirme.

---

# 10. Persistence ve migration

Mevcut save snapshot/migration zincirini kullan.

- inventory/build/equipment/pet/gem/preset state primitive-safe olmalı
- stable ID dışı Resource/Object/Node/RID/Callable persist edilmez
- save schema değişmesi gerekiyorsa canonical sequential migration ekle
- eski fixture/save'ler açık deterministic migration veya açık unsupported davranışı göstermeli
- loot snapshot ile inventory arasında iki kopya authoritative miktar saklama
- invalid/corrupt inventory DTO sessiz default ile kabul edilmez
- restore transaction ledger/idempotency tutarlılığını korur

Network protocol version ile save schema version'ı birbirine bağlama.

---

# 11. LAN / NET-04 entegrasyonu

Host-mutating PRG-01 işlemleri:

- transfer
- equip/unequip
- gem/socket mutation
- preset apply

host tarafından doğrulanır.

Client:

- yalnız bounded primitive intent + stable IDs + transaction ID gönderir
- quantity/slot/item hedefi talep eder ama sonucu seçemez
- authoritative inventory/equipment/stat yazamaz
- GLoot/Object/Resource replike etmez

NET-04 transaction ledger davranışını yeniden icat etme; mevcut idempotency/lost-ACK sözleşmesini mümkün olduğunca reuse/extend et.

Spoof/replay/malformed/pre-ready yolları mevcut network authority sınırlarını zayıflatmamalı.

Wire contract değişirse protocol version yalnız gerçekten gerektiğinde bump edilir; eski client sessiz uyumlu sayılmaz.

---

# 12. Minimal touch UI

PRG-01 kapsamı için production authority değil, kullanılabilir touch presentation oluştur.

- drag/drop zorunlu olmasın
- tap/select + açık equip/transfer aksiyonları olsun
- büyük hit target
- safe-area uyumu
- fontScale 1.3 ile okunabilirlik
- gerçek ikon zorunlu değil; placeholder kabul
- UI hiçbir authoritative state'i doğrudan yazmaz
- local presentation cache truth değildir

Geniş final UI/UX polish sonraki UI wave'lerinin kapsamıdır.

---

# 13. CI / test matrisi

Exact PRG-01 code SHA üzerinde minimum yeni kapılar:

1. item category / slot schema validation
2. equip compatibility matrisi
3. stack boundaries: 0, 1, stack_limit, overflow
4. capacity/weight kullanılıyorsa boundary tests
5. atomic transfer + rollback
6. equip/unequip rollback
7. crew/trainer/pet slot kuralları
8. ship/pet gem + socket type/level/progression
9. consume+upgrade atomikliği
10. modifier pipeline deterministic result ve duplicate source guard
11. preset apply success
12. preset combat/safe-state rejection
13. preset partial-failure full rollback
14. save/load + migration + invalid DTO
15. duplicate transaction / same-ID conflict / lost-ACK retry
16. LAN host authority / spoof outcome rejection
17. mevcut loot grant/pickup ve NET-04 idempotency regresyonu

Bütün mevcut ilgili VS/CORE/AI/NET regresyonlarını koru. Testleri azaltarak veya güvenlik kapılarını gevşeterek yeşil sonuç alma.

Parse/load/orphan failure'ları da başarısızlık sayılır.

---

# 14. Export / artifact

Exact green SHA için:

Linux:

- debug export
- executable + PCK doğrulaması
- export edilmiş executable headless boot

Android:

- arm64-v8a debug APK
- package mevcut contract'ı korur
- targetSdk 37
- `android.permission.INTERNET`
- `android.permission.ACCESS_LOCAL_NETWORK`
- APK integrity/readback

Artifact:

`SeaCraft-PRG01-<exact SHA>`

İçerik minimum:

- Android APK
- Linux executable/PCK
- `COMMIT_SHA.txt`
- `SHA256SUMS.txt`

Actions artifact'i authenticated readback ile yeniden doğrula; artifact adı, ID, exact SHA ve hashler `GOREV_RAPORU.md` kapanışına işlenir.

---

# 15. Gerçek Android cihaz kapısı

CI gerçek cihaz değildir.

Mümkünse:

- touch inventory/select/equip/transfer
- drag/drop olmadan tam temel akış
- fontScale 1.3
- safe area
- küçük ekran hit targets
- save/reload build
- LAN host/client equip/transfer retry

Fiziksel cihaz yoksa bunları açıkça `not_run` bırak. CI/export'u cihaz kanıtı gibi gösterme.

---

# 16. Çalışma sohbeti / GitHub iletişim protokolü

SOHBET-32 başlamadan:

- güncel `main` HEAD'i ve kanonik briefi yeniden oku
- sahiplik alanını belirle
- başka sohbetin commit'ini ezme

Çalışırken:

- yalnız PRG-01 kapsamını değiştir
- başkasının bağımsız değişikliklerini koru
- HEAD ilerlerse günceli yeniden oku ve sadece çakışmayan alanı yeniden uygula
- sonuç/test/commit/engel kanıtını GitHub'daki mevcut kanonik kayda işle
- uzun sonuç raporunu sohbete dökme

Bağımlı PRG-02 ancak PRG-01 exact GitHub kapanışı doğrulandıktan sonra açılır.

---

# 17. Kapanış

Tamamlandı demeden:

1. exact code SHA'yı doğrula
2. full CI/test ve PRG-01 verifier/marker'larını doğrula
3. eski regresyonların geçtiğini doğrula
4. Linux + Android exportu doğrula
5. artifact upload + authenticated readback + hashleri doğrula
6. fiziksel cihaz yoksa `not_run` yaz
7. mevcut Avenox PRG-01 taskını duplicate yaratmadan strict done revision ile kapat
8. tek kapanış receipt üret ve geri oku
9. `GOREV_RAPORU.md` içine geçmişi koruyan tek PRG-01 bölümü ekle ve geri oku
10. `SESSION_HANDOFF.md` güncel kapalı durumu ve sıradaki PRG-02 kapısını yansıtsın
11. bütün kapılar geçmeden PRG-02'ye başlama

İlk commit/workflow queue başarı değildir. Hata varsa logu aç, kök nedeni düzelt, aynı exact teslim zincirini yeniden doğrula.
