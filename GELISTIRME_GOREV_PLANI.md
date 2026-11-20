# SeaCraft — Geliştirme Görev ve Bağımlılık Planı

> Plan snapshot: main @ 50fbbf9783f16652fca4f28e6da24477bcb7df30  
> Hedef motor: Godot 4.7  
> Platform: Android + masaüstü  
> Ağ: tamamen offline oynanabilir, isteğe bağlı LAN, host-authoritative  
> Görsel yön: 2D/2.5D 3/4 top-down, ultra-realistic dark maritime Lovecraftian  
> Bu belge planlama çıktısıdır. Kodlama, addon kurulumu ve asset üretimi içermez.

## 0. Planlama ilkeleri

Bu sıra MEKANIK_KATALOGU.md, ICERIK_KATALOGU.md, GODOT_HAZIR_COZUMLER.md, HAZIR_ASSET_ARASTIRMASI.md ve GEMI_GORSEL_TASARIM_VE_SPRITE_PLANI.md birlikte okunarak oluşturulmuştur.

İstenen temel sıra korunur: proje iskeleti → veri modeli → input/kamera → gemi hareketi → dünya/sector → save → combat → NPC/monster → AI → LAN → loot/equipment/crafting/progression → görev/faction/economy → raid/boss → UI → optimizasyon → içerik doldurma.

Üç bilinçli sapma vardır:

1. Vertical slice kabulü loot istediği için M-027/M-028’in yalnız minimum, tek pickup ve tek loot-table sürümü LAN’dan önce gelir. Tam inventory/equipment/crafting LAN sonrasındadır.
2. Vertical slice kabulü en az bir gelişmiş NPC davranışı istediği için tek NPC için patrol → threat → retreat/repair davranışı FIRST PLAYABLE içinde kanıtlanır. Genel utility AI, filo ve world AI SMART WORLD / AI dalgasında genişletilir.
3. Stable ID, typed Resource veri modeli ve seed/RNG sözleşmesi en başta kurulur; aksi halde save, AI ve host-authoritative LAN aynı varlığı farklı biçimde temsil eder.

## 1. Ortak mimari kararlar

- Offline ve LAN iki ayrı oyun çekirdeği olmayacak. Aynı authoritative simulation API offline’da local authority, LAN’da host authority olarak çalışacak.
- İstemci hiçbir zaman hasar, loot sonucu, inventory sonucu, quest ödülü, spawn kararı veya AI kararı üretmeyecek; yalnız intent gönderecek.
- İlk save biçimi FileAccess + JSON olacak. Typed Resource tanımları readonly içerik tanımı, runtime instance state ise primitive DTO olarak tutulacak.
- İlk ağ katmanı ENetMultiplayerPeer + SceneMultiplayer + RPC; spawn için MultiplayerSpawner, seçili primitive state için MultiplayerSynchronizer.
- LAN discovery ilk kabul için zorunlu değil; manuel IPv4:port her zaman çalışır yol olacak. Discovery daha sonra PacketPeerUDP ile eklenir.
- AI için ilk önerilen addon A06 Beehave’dir. State, perception, utility skorları, ekonomi ve filo koordinasyonu SeaCraft özel kodu olarak kalır. A05 LimboAI ilk tercih değildir.
- GDScript testleri için geliştirme/CI aracı olarak A14 GUT planlanır; Android release paketine girmez.
- Inventory karmaşıklığı grid/weight/multi-container gerektirirse A11 GLoot kullanılabilir; basit slot/quantity modeli için özel typed veri daha küçüktür.
- Dallı diyalog büyürse A12 Dialogue Manager 4 kullanılabilir; ilk quest ve merchant etkileşimi için zorunlu değildir.
- M-035 ve M-054 canlı servis olarak kopyalanmaz: global league, login streak ve internet leaderboard yerine save-bazlı challenge/milestone kullanılır.
- M-036 global guild yerine offline/LAN local company/crew yapısına uyarlanır.
- M-034 LAN PvP opsiyoneldir; ana progression PvE’ye bağlı kalır.
- Tüm 661 ICERIK_KATALOGU kaydı doğrudan oyun içeriği değildir. Katalog arketip, stat aralığı ve içerik çeşitliliği kaynağıdır; telifli isim/görsel birebir taşınmaz.

## 2. Görsel üretim ile kod bağımlılığı

İlk kod görevinin ön koşulu tüm gemi görsellerinin bitmesi değildir. Erken sistemler geometric placeholder sprite ile geliştirilebilir. İlk vertical slice hedefi:

- Oyuncu: SC-02 Kül Dikişi, hazır değilse aynı pivot/ölçek sözleşmesini kullanan geometric placeholder.
- NPC: SC-03 Tuz Ambarı, hazır değilse ayrı okunabilir placeholder.
- Ağır gemi doğrulaması: SC-08 Demir Mezar ilk üç pilot sanat paketinden biri olarak daha sonra ölçek/performance testi için kullanılır.
- İlk oynanabilir dilim için bütün minimum 8 gemi beklenmez.
- Runtime sistemler gerçek sprite atlasına değil stable ship ID + visual profile arayüzüne bağlı olur.
- Production-ready sprite, alpha/pivot/socket ve Android texture residency kapısı POL-02’de zorunlu hale gelir.

---

# WAVE 1 — FOUNDATION

## FND-01 — Godot 4.7 proje iskeleti, klasör sınırları ve CI tabanı

**Amaç:** Çalıştırılabilir, headless doğrulanabilir, Android/desktop export’a hazır ama içeriksiz proje iskeleti kurmak.

**Mekanik katalog ID’leri:** Doğrudan gameplay mekaniği yok; sonraki tüm M-001…M-060 için temel.

**Bağımlılıklar:** Yok.

**BUILT_IN / RECOMMENDED_ADDON:** T32 BUILT_IN debugger/profiling; T33 BUILT_IN Android export; A14 GUT RECOMMENDED_ADDON yalnız test/CI için planlanır.

**Sistemler:** project.godot, ana scene bootstrap, autoload sınırları, simulation/presentation/data/test klasör sözleşmesi, export preset şablonları, GitHub Actions headless test/export işleri.

**Görsel/asset bağımlılığı:** Yok.

**Android gereksinimi:** Compatibility renderer başlangıç adayı; orientation, stretch ve safe-area varsayımları belgelenir.

**LAN gereksinimi:** Ağ kodu yok; simulation katmanı network API’den bağımsız tutulur.

**Kabul kriterleri:** Boş oyun desktop ve headless açılır; export presetleri parse edilir; test koşucu çalışır; hiçbir internet servisi boot için gerekmez.

**GitHub Actions doğrulaması:** Godot headless boot; project.godot parse; test runner smoke; Android export preset dry validation.

**Gerçek cihaz doğrulaması:** İlk APK üretildiğinde açılış/çökme kontrolü; bu görevde fiziksel cihaz başarısı zorunlu kapanış kapısı değildir.

**Sonraki görevi engelleyen kapı:** Headless boot ve CI test koşucusu yeşil olmadan FND-02 başlamaz.

## FND-02 — Veri modeli, stable ID ve seed sözleşmesi

**Amaç:** Gemi, silah, item, faction, sector, entity ve runtime state için ağ/save uyumlu tek veri modeli kurmak.

**Mekanik katalog ID’leri:** M-017, M-018, M-019, M-057.

**Bağımlılıklar:** FND-01.

**BUILT_IN / RECOMMENDED_ADDON:** T17 BUILT_IN RandomNumberGenerator; T23 BUILT_IN typed Resource/.tres + ResourceLoader.

**Sistemler:** ShipDefinition, WeaponDefinition, ItemDefinition, FactionDefinition, SectorDefinition, EntityRuntimeState, stable string ID registry, schema/content version, modifier sırası, RNG stream adları.

**Görsel/asset bağımlılığı:** ShipDefinition visual_profile alanı gerçek sprite beklemeden placeholder referanslayabilir.

**Android gereksinimi:** Resource preload ve registry başlangıç maliyeti düşük tutulur; devasa tek JSON kullanılmaz.

**LAN gereksinimi:** Resource/Object/RID ağ şeması yapılmaz; ağ/save DTO’ları primitive alanlardan oluşur.

**Kabul kriterleri:** Duplicate ID reddedilir; readonly definition ile instance state ayrıdır; aynı seed aynı test fixture’ında aynı loot/encounter dizisini verir.

**GitHub Actions doğrulaması:** Registry duplicate/missing-ref testi; Resource parse testi; modifier order testi; RNG stream reproducibility testi.

**Gerçek cihaz doğrulaması:** Büyük registry yükleme süresi ve memory ilk Android profilinde ölçülür.

**Sonraki görevi engelleyen kapı:** Stable ID ve DTO sözleşmesi kilitlenmeden FND-03/FND-04 ilerlemez.

## FND-03 — Input, touch/desktop komut katmanı ve kamera

**Amaç:** Aynı gameplay intent’lerini mouse/keyboard/gamepad/touch üzerinden üretmek ve Camera2D davranışını simulation’dan ayırmak.

**Mekanik katalog ID’leri:** M-003, M-004, M-052.

**Bağımlılıklar:** FND-01.

**BUILT_IN / RECOMMENDED_ADDON:** T29 BUILT_IN InputMap/ScreenTouch/Control; T30 BUILT_IN Camera2D.

**Sistemler:** input command mapper, pointer/touch world conversion, target-cycle intent, Camera2D follow/pan/zoom/limits, UI input consumption sınırı.

**Görsel/asset bağımlılığı:** Yok; geometric ship marker yeterlidir.

**Android gereksinimi:** Multi-touch, gesture çatışması, notch/safe-area, portrait değil seçilen landscape düzeni ve 320–411dp aralığı dikkate alınır.

**LAN gereksinimi:** Input doğrudan state yazmaz; ShipCommand üretir. Bu komut ileride hosta gönderilebilir.

**Kabul kriterleri:** Kamera smoothing simülasyon konumunu değiştirmez; UI tıklaması dünya komutuna sızmaz; touch ve mouse aynı world hedefini üretir.

**GitHub Actions doğrulaması:** Input command unit test; world↔screen transform testi; kamera limit/zoom math testi.

**Gerçek cihaz doğrulaması:** Touch target seçimi, pinch/zoom veya seçilen gesture seti, safe-area ve gamepad kontrolü.

**Sonraki görevi engelleyen kapı:** Komut katmanı state-mutating input’tan ayrılmadan FND-04 başlamaz.

## FND-04 — Gemi hareket çekirdeği

**Amaç:** İvme, dönüş yarıçapı, hedefe seyir ve broadside hizasına uygun 2D gemi hareketini deterministic-enough authoritative simulation olarak kurmak.

**Mekanik katalog ID’leri:** M-003, M-013.

**Bağımlılıklar:** FND-02, FND-03.

**BUILT_IN / RECOMMENDED_ADDON:** T10 CUSTOM_REQUIRED CharacterBody2D/Vector2; T11 BUILT_IN NavigationAgent2D yalnız avoidance/path önerisi için.

**Sistemler:** ShipMotor, speed profile, turn rate, arrival steering, collision envelope, damaged-speed hook, movement command validation.

**Görsel/asset bağımlılığı:** Geometric arrow/boat placeholder yeterli; gerçek 8 yön sprite gerekli değildir.

**Android gereksinimi:** Physics tick başına allocation ve path yenileme sınırı; düşük cihazda sabit frame pacing hedefi.

**LAN gereksinimi:** Hareketi yalnız authority uygular; client prediction bu görevde yok.

**Kabul kriterleri:** Aynı command trace aynı başlangıç state’inden tolerans içinde aynı sonuç verir; gemi anlık yön değiştirmez; damaged-speed modifier hook’u çalışır.

**GitHub Actions doğrulaması:** Acceleration/turn/arrival unit testleri; collision boundary testleri; fixed-step command replay testi.

**Gerçek cihaz doğrulaması:** Touch ile uzun rota, dönüş hissi, yoğun input altında frame pacing.

**Sonraki görevi engelleyen kapı:** ShipMotor authoritative command API’si sabitlenmeden FND-05 başlamaz.

## FND-05 — Tek sektör dünya çekirdeği ve sektör grafiği

**Amaç:** Vertical slice için bir sektör ve gelecekte çok sektörlü dünya için graph/transition temelini kurmak.

**Mekanik katalog ID’leri:** M-001, M-002, M-046.

**Bağımlılıklar:** FND-02, FND-04.

**BUILT_IN / RECOMMENDED_ADDON:** T11 BUILT_IN Navigation2D/AStar2D; T15 CUSTOM_REQUIRED spatial hash; T19 CUSTOM_REQUIRED sector/encounter framework.

**Sistemler:** SectorDefinition, SectorRuntime, sector graph, spawn anchors, navigation region, spatial hash, hazard-cost hook, transition gate API.

**Görsel/asset bağımlılığı:** Düz renk deniz ve primitive kıyı collider yeterli.

**Android gereksinimi:** Yalnız aktif/yakın sektör instantiate edilir; gereksiz büyük TileMap/scene preload edilmez.

**LAN gereksinimi:** Sector enter/leave authority kararı olacak şekilde API tasarlanır; ağ henüz yok.

**Kabul kriterleri:** Tek sektör deterministik açılır; graph validation disconnected/invalid edge yakalar; spawn anchor stable ID taşır.

**GitHub Actions doğrulaması:** Sector graph validation; spawn anchor ID uniqueness; navigation fixture path testi; spatial hash query testi.

**Gerçek cihaz doğrulaması:** Sector load süresi ve memory spike ölçümü ilk Android build’de yapılır.

**Sonraki görevi engelleyen kapı:** Tek sektör bootstrap ve graph doğrulaması geçmeden FND-06 başlamaz.

## FND-06 — Save/load baseline

**Amaç:** Oyuncu gemisi, sektör, runtime entity ve RNG state için güvenli ilk persistence katmanını kurmak.

**Mekanik katalog ID’leri:** M-056.

**Bağımlılıklar:** FND-02, FND-05.

**BUILT_IN / RECOMMENDED_ADDON:** T05 BUILT_IN FileAccess + JSON; T06 CUSTOM_REQUIRED migration/backup/recovery; T17 BUILT_IN RNG state.

**Sistemler:** SaveService, schema version, content hash, temp-write + replace, backup, load validation, entity DTO serialization.

**Görsel/asset bağımlılığı:** Yok.

**Android gereksinimi:** user:// kullanımı; app suspend/process kill senaryosu; yalnız clean exit save’e güvenilmez.

**LAN gereksinimi:** İleride host world save sahibi olacak şekilde save owner alanı ve session metadata ayrılır.

**Kabul kriterleri:** Save→load round-trip state’i korur; bozuk JSON kontrollü hata verir; eski schema fixture migration veya açık unsupported sonucu üretir.

**GitHub Actions doğrulaması:** Round-trip, corruption, interrupted-write, migration ve RNG resume testleri.

**Gerçek cihaz doğrulaması:** Android suspend/resume, force-stop sonrası son güvenli save, storage permission gerektirmeden user:// erişimi.

**Sonraki görevi engelleyen kapı:** Round-trip ve corruption testleri yeşil olmadan vertical slice combat başlamaz.

---

# WAVE 2 — FIRST PLAYABLE / VERTICAL SLICE

## VS-01 — Hedefleme, top saldırısı, hasar ve batma

**Amaç:** Tek oyuncu gemisinin tek NPC hedefini seçip top ateşiyle batırabildiği authoritative combat çekirdeğini kurmak.

**Mekanik katalog ID’leri:** M-005, M-006, M-007, M-008, M-009, M-010, M-011, M-013.

**Bağımlılıklar:** FND-04, FND-05, FND-06.

**BUILT_IN / RECOMMENDED_ADDON:** T18 CUSTOM_REQUIRED combat transaction; T17 BUILT_IN RNG.

**Sistemler:** TargetingService, WeaponBattery, CombatTransaction, reload, range/arc, hit/dodge, crit, damage prevention, hull, sunk event.

**Görsel/asset bağımlılığı:** SC-02 Kül Dikişi tercih edilir; hazır değilse aynı pivot ölçeğinde placeholder. Cannon projectile/muzzle geçici primitive olabilir.

**Android gereksinimi:** Touch target lock ve fire butonu; VFX olmadan combat state okunabilir olmalı.

**LAN gereksinimi:** CombatTransaction tek authority API; client ileride yalnız fire intent gönderir.

**Kabul kriterleri:** Menzil/reload dışında ateş reddedilir; sunk olayı tek kez çıkar; hasar formülü aynı seed/state ile tekrar üretilebilir.

**GitHub Actions doğrulaması:** Range/reload/hit/crit/defense testleri; death-once testi; invalid target/friendly target negatif testleri.

**Gerçek cihaz doğrulaması:** Touch target, ateş input gecikmesi ve kamera takibi.

**Sonraki görevi engelleyen kapı:** Combat transaction sonuçları testle sabitlenmeden VS-02 başlamaz.

## VS-02 — Tek NPC ve ilk gelişmiş davranış

**Amaç:** SC-03 tipi bir NPC’nin patrol yapması, tehdit algılaması, hasar eşiğinde retreat/repair niyeti üretmesi ve threat decay sonrası rotasına dönmesi.

**Mekanik katalog ID’leri:** M-057. Yardımcı AI kapsamı: AI-02, AI-06, AI-07, AI-09, AI-10, AI-21, AI-22, AI-23, AI-30.

**Bağımlılıklar:** VS-01.

**BUILT_IN / RECOMMENDED_ADDON:** T07 RECOMMENDED_ADDON A06 Beehave; T08 custom FSM; T09 utility scoring; T10 steering; T13 perception/memory. Addon kurulumu bu plan görevinin parçası değildir.

**Sistemler:** NpcBrain pilotu, perception, threat memory, patrol route, retreat threshold, repair state, intent telegraph enum.

**Görsel/asset bağımlılığı:** SC-03 Tuz Ambarı tercih edilir; yoksa oyuncudan farklı geometric silhouette. Tam sprite beklenmez.

**Android gereksinimi:** AI decision tick physics tick’ten seyrek; tek NPC’de dahi allocation telemetry tutulur.

**LAN gereksinimi:** Brain yalnız authority tarafında çalışabilecek şekilde yazılır; presentation intent enum okuyabilir.

**Kabul kriterleri:** NPC patrol eder; oyuncu saldırınca threat değişir; kritik hull’da uygun safe point’e kaçar; güvenli durumda repair ve route resume yapar.

**GitHub Actions doğrulaması:** Seed’li scenario trace; hysteresis test; retreat/repair transition test; unreachable waypoint fallback testi.

**Gerçek cihaz doğrulaması:** Davranış okunabilirliği ve hitch olmadan karar geçişleri.

**Sonraki görevi engelleyen kapı:** En az bir gelişmiş davranış scenario testinde deterministik state geçişleri üretmeden VS-03 başlamaz.

## VS-03 — Minimum loot ve pickup

**Amaç:** Batırılan NPC’den authoritative tek loot drop üretmek, pickup etmek ve save/load sonrası duplicate olmamasını sağlamak.

**Mekanik katalog ID’leri:** M-027, M-028, M-058.

**Bağımlılıklar:** VS-01, VS-02, FND-06.

**BUILT_IN / RECOMMENDED_ADDON:** T28 CUSTOM_REQUIRED loot table/contribution; T17 RNG; T23 typed Resource.

**Sistemler:** LootTable pilotu, LootDrop entity, pickup transaction, claimed/drop stable ID, minimal inventory quantity map.

**Görsel/asset bağımlılığı:** Tek sandık/ışık noktası placeholder yeterli.

**Android gereksinimi:** Pickup touch hedefi büyük ve erişilebilir; çoklu VFX yok.

**LAN gereksinimi:** Drop ID ve claim authority modeli şimdiden host-ready; istemci seed’e sahip olsa da sonuç yetkisi yok.

**Kabul kriterleri:** Aynı sunk event iki loot üretmez; pickup bir kez uygulanır; save/load sonrası claimed drop geri doğmaz.

**GitHub Actions doğrulaması:** Loot seed testleri; idempotent claim; save-resume; invalid pickup range.

**Gerçek cihaz doğrulaması:** Touch pickup ve küçük ekranda okunabilirlik.

**Sonraki görevi engelleyen kapı:** Dupe ve save-resume testleri yeşil olmadan VS-04 kapanmaz.

## VS-04 — Offline vertical slice entegrasyon kapısı

**Amaç:** İlk hedefi tek otomatik senaryoda kanıtlamak: oyuncu + hareket + kamera + bir sektör + bir NPC + hedef + top + hasar/batma + loot + save/load + gelişmiş NPC davranışı.

**Mekanik katalog ID’leri:** Önceki FND/VS görevlerinde kapsanan mekaniklerin entegrasyonu; yeni mekanik yok.

**Bağımlılıklar:** VS-01, VS-02, VS-03.

**BUILT_IN / RECOMMENDED_ADDON:** T32 BUILT_IN profiling/debug; A14 GUT test koşucu.

**Sistemler:** VerticalSliceScenario, smoke test fixture, deterministic save checkpoint.

**Görsel/asset bağımlılığı:** SC-02/SC-03 hazırsa kullanılır; değilse placeholder kabul edilir.

**Android gereksinimi:** Offline başlatma sırasında ağ izni/servisi gerekmemeli.

**LAN gereksinimi:** Bu kapı offline’dır; aynı scenario ID ileride NET-03’te host/client parity için yeniden kullanılır.

**Kabul kriterleri:** Tam scenario baştan sona kullanıcı müdahalesi olmadan test fixture’da tamamlanır; save ortasında alınıp reload sonrası devam eder.

**GitHub Actions doğrulaması:** Full offline vertical slice integration test; headless soak kısa koşu; save checkpoint replay.

**Gerçek cihaz doğrulaması:** Android’de offline uçak modu/bağlantısız açılış, touch ile aynı senaryonun manuel tamamlanması.

**Sonraki görevi engelleyen kapı:** Bu görev ilk büyük milestone’dur; yeşil olmadan CORE SYSTEMS başlamaz.

---

# WAVE 3 — CORE SYSTEMS

## CORE-01 — Savaş derinliği: ammo, repair, boarding, status ve action item

**Amaç:** Vertical slice combatını veri odaklı tam işlem hattına genişletmek.

**Mekanik katalog ID’leri:** M-007, M-008, M-009, M-010, M-012, M-015, M-045, M-053.

**Bağımlılıklar:** VS-04.

**BUILT_IN / RECOMMENDED_ADDON:** T18 CUSTOM_REQUIRED; T17 BUILT_IN RNG.

**Sistemler:** AmmoProfile, status stack rules, repair transaction, boarding check, action item cooldown, element/resistance hooks.

**Görsel/asset bağımlılığı:** Hasar/repair/boarding VFX placeholder olabilir; gameplay sonuçları VFX’e bağlı değildir.

**Android gereksinimi:** Action bar input henüz final UI değil; minimum debug controls yeterli.

**LAN gereksinimi:** Tüm mutasyonlar tek authority transaction yolundan geçer.

**Kabul kriterleri:** Flat/relative modifier sırası açık; repair/boarding cooldown ve resource tüketimi atomik; elemental modifier testlidir.

**GitHub Actions doğrulaması:** Combat formula matrix; boarding success/fail; repair interruption; status stacking; action item cooldown.

**Gerçek cihaz doğrulaması:** Yoğun combat sırasında input ve frame pacing.

**Sonraki görevi engelleyen kapı:** Transaction atomicity ve modifier testleri yeşil olmadan CORE-02 başlamaz.

## CORE-02 — Monster/harpoon ve dünya loot objeleri

**Amaç:** Gemi dışı hedef sınıfını ve harpoon savaşını eklemek; chest/glitter/wreck altyapısını aynı authoritative entity modelinde çalıştırmak.

**Mekanik katalog ID’leri:** M-014, M-028, M-045.

**Bağımlılıklar:** CORE-01.

**BUILT_IN / RECOMMENDED_ADDON:** T18 combat profiles; T19 spawn hooks; T28 loot tables.

**Sistemler:** MonsterDefinition, HarpoonProfile, target-tag validation, territory anchor, chest/glitter/wreck entity archetypes.

**Görsel/asset bağımlılığı:** Monster silhouette ve pickup placeholder yeterli; hazır asset araştırması yalnız referans.

**Android gereksinimi:** Çoklu küçük pickup overdraw bütçesi ve touch selection.

**LAN gereksinimi:** Monster AI ve pickup authority host-ready.

**Kabul kriterleri:** Cannon/harpoon hedef kuralı yanlış silahı reddeder; world object spawn/pickup stable ID kullanır.

**GitHub Actions doğrulaması:** Target tag matrix; harpoon damage; world-object persistence; duplicate spawn/claim.

**Gerçek cihaz doğrulaması:** Monster seçimi ve harpoon input okunabilirliği.

**Sonraki görevi engelleyen kapı:** Hedef sınıfı ve world entity yaşam döngüsü ortaklaşmadan CORE-03 başlamaz.

## CORE-03 — Sektör geçişi, safe haven, hazard ve harita

**Amaç:** Tek sektör çekirdeğini küçük çok-sektörlü dünyaya ve güvenli liman/hazard kurallarına genişletmek.

**Mekanik katalog ID’leri:** M-001, M-002, M-004, M-039, M-046.

**Bağımlılıklar:** CORE-02.

**BUILT_IN / RECOMMENDED_ADDON:** T11 Navigation2D/AStar2D; T19 sector/hazard; T20 BUILT_IN minimap/world map; T31 water/hazard presentation.

**Sistemler:** sector transition service, safe-zone rule, hazard cost map, minimap transform, world graph UI data.

**Görsel/asset bağımlılığı:** Basit ikon ve primitive map yeterli; final cartography beklenmez.

**Android gereksinimi:** Harita UI dokunmatik zoom/pan ve memory sınırı.

**LAN gereksinimi:** Transition ve safe-zone rule authority tarafında kalır.

**Kabul kriterleri:** Invalid transition reddedilir; safe-zone’da damage uygulanmaz; hazard path cost AI/player route hesaplarını etkileyebilir.

**GitHub Actions doğrulaması:** Graph transition rules; safe-zone combat negative test; hazard cost path fixture; world↔map transform.

**Gerçek cihaz doğrulaması:** Minimap/world map gesture ve küçük ekran okunabilirliği.

**Sonraki görevi engelleyen kapı:** Çok-sektör state ve safe-zone rule sabitlenmeden CORE-04 başlamaz.

## CORE-04 — Persistence hardening ve içerik registry kapısı

**Amaç:** Save sistemini NPC world state, loot ledger, cooldown, route progress ve content version ile production-adayı hale getirmek.

**Mekanik katalog ID’leri:** M-056, M-057.

**Bağımlılıklar:** CORE-03.

**BUILT_IN / RECOMMENDED_ADDON:** T05/T06 save; T17 RNG; T23 item/resource registry.

**Sistemler:** migration chain, recovery backup, content hash compatibility, persistent entity index, NPC route/cooldown state.

**Görsel/asset bağımlılığı:** Yok.

**Android gereksinimi:** Process kill ve low-storage error handling.

**LAN gereksinimi:** Host-owned world save metadata; client-local settings ayrı dosya.

**Kabul kriterleri:** Eski save fixture migration; unknown content ID açık hata/placeholder policy; partial write kurtarma; NPC state resume.

**GitHub Actions doğrulaması:** Multi-version migration; fuzzed malformed save; large entity round-trip; content-hash mismatch.

**Gerçek cihaz doğrulaması:** Suspend/kill/restore ve düşük depolama davranışı.

**Sonraki görevi engelleyen kapı:** Persistent NPC/world state olmadan SMART WORLD / AI başlamaz.

---

# WAVE 4 — SMART WORLD / AI

## AI-01 — AI çekirdeği: perception + memory + utility + BT/FSM

**Amaç:** Tek NPC pilotunu reusable, veri odaklı AI framework’e dönüştürmek.

**Mekanik katalog ID’leri:** M-057. Yardımcı AI kapsamı: AI-01, AI-06, AI-07, AI-21, AI-22, AI-23, AI-30.

**Bağımlılıklar:** CORE-04.

**BUILT_IN / RECOMMENDED_ADDON:** T07 A06 Beehave RECOMMENDED_ADDON; T08 custom FSM; T09 utility; T13 perception; T15 spatial hash.

**Sistemler:** SenseSnapshot, MemoryBlackboard, UtilityDecision, role weight profiles, BT action library, intent telegraph.

**Görsel/asset bağımlılığı:** Yok; debug telegraph ikonları primitive olabilir.

**Android gereksinimi:** Decision frequency ve perception candidate cap konfigüre edilir.

**LAN gereksinimi:** AI yalnız authority’de tick eder; client’a intent ve gerekli state replike edilir.

**Kabul kriterleri:** Role ağırlıkları aynı framework’te trader/escort/raider davranışını değiştirir; hysteresis target thrash’i önler.

**GitHub Actions doğrulaması:** Utility score unit tests; perception filter; memory decay; BT action timeout/failure; role profile fixtures.

**Gerçek cihaz doğrulaması:** 10–20 NPC’de AI tick spike profili.

**Sonraki görevi engelleyen kapı:** AI kararları testlenebilir pure-data çıktıya ayrılmadan AI-02 başlamaz.

## AI-02 — Taktik savaş AI

**Amaç:** Range band, broadside, ammo seçimi, retreat, repair, boarding ve support kararlarını utility çerçevesine eklemek.

**Mekanik katalog ID’leri:** M-012, M-015, M-045, M-057. Yardımcı AI: AI-08…AI-13, AI-20.

**Bağımlılıklar:** AI-01, CORE-01.

**BUILT_IN / RECOMMENDED_ADDON:** T09 utility; T10 steering; T13 perception; T18 combat transactions.

**Sistemler:** TacticalContext, expected-hit/DPS estimate, ammo utility, escape route scoring, boarding utility, support-call intent.

**Görsel/asset bağımlılığı:** Yok.

**Android gereksinimi:** Expensive scoring candidate sayısı sınırlandırılır.

**LAN gereksinimi:** AI sonucu doğrudan authoritative transaction çağırır; client hesaplamaz.

**Kabul kriterleri:** AI uygun menzili korur, kaynak azsa pahalı ammo harcamaz, kritik durumda kaçış/repair seçebilir, avantajlı değilse boarding yapmaz.

**GitHub Actions doğrulaması:** Scenario matrix; retreat vs fight thresholds; ammo economy; friendly-fire/line-of-fire; boarding decision.

**Gerçek cihaz doğrulaması:** Çoklu combatta karar gecikmesi ve okunabilir telegraph.

**Sonraki görevi engelleyen kapı:** Taktik scenario testleri kararlı olmadan AI-03 başlamaz.

## AI-03 — Filo, formasyon ve savaş dışı dünya davranışı

**Amaç:** Merchant/escort/scout rolleri, convoy, formation, docking, patrol, trade/salvage ve commander emirlerini eklemek.

**Mekanik katalog ID’leri:** M-036, M-038, M-039, M-055, M-059. Yardımcı AI: AI-03, AI-04, AI-05, AI-11, AI-16, AI-17, AI-18, AI-19, AI-24.

**Bağımlılıklar:** AI-02, CORE-03.

**BUILT_IN / RECOMMENDED_ADDON:** T12 formation/convoy; T13 economic/non-combat AI; T26 faction/economy hooks.

**Sistemler:** FleetCoordinator, formation slots, leader succession, dock queue, route jobs, faction relation input, cargo mission abstraction.

**Görsel/asset bağımlılığı:** Çoklu gemi placeholder kabul; final faction visual gerekmez.

**Android gereksinimi:** Formation steering ve dock queue path jobs budget edilir.

**LAN gereksinimi:** Fleet coordinator host authority olacak şekilde tasarlanır.

**Kabul kriterleri:** Convoy leader+escort rota izler; ambush’ta formasyon kırılır; leader kaybında succession/regroup; safe-zone pursuit kesilir.

**GitHub Actions doğrulaması:** Formation slot tests; leader succession; convoy ambush scenario; dock queue fairness; faction relation transitions.

**Gerçek cihaz doğrulaması:** 20+ gemi formasyon/path CPU profili.

**Sonraki görevi engelleyen kapı:** Fleet state stable ID ile persistence’a yazılmadan AI-04 başlamaz.

## AI-04 — AI LOD, far-field simülasyon ve dünya spawn director

**Amaç:** Yakın tam simülasyon, orta seyrek tick ve uzak istatistiksel simülasyonla mobil hostta gelişmiş dünya AI’sını ölçeklemek.

**Mekanik katalog ID’leri:** M-001, M-043, M-046, M-057, M-060. Yardımcı AI: AI-01, AI-25, AI-27, AI-28, AI-29.

**Bağımlılıklar:** AI-03, CORE-04.

**BUILT_IN / RECOMMENDED_ADDON:** T14 AI LOD; T15 spatial partition; T17 RNG; T19 spawn director.

**Sistemler:** SimulationLOD, staggered tick scheduler, path job queue, far-field travel/combat resolver, population budget, admiral counter hook.

**Görsel/asset bağımlılığı:** Yok.

**Android gereksinimi:** Host Android için CPU/time budget ana kabul ölçütüdür.

**LAN gereksinimi:** Yalnız host far-field sonuç üretir; client görünür sektör snapshot alır.

**Kabul kriterleri:** LOD geçişinde entity ID/state kaybolmaz; uzak sonuç deterministic seed ile üretilir; spawn budget aşılmaz.

**GitHub Actions doğrulaması:** LOD transition; far-field deterministic replay; population cap; scheduler budget unit test; long simulated time soak.

**Gerçek cihaz doğrulaması:** Android hostta 50/100+ world entity karşılığı CPU, memory ve thermal profil.

**Sonraki görevi engelleyen kapı:** Hostta ölçeklenebilir authoritative world state olmadan LAN MULTIPLAYER başlamaz.

---

# WAVE 5 — LAN MULTIPLAYER

## NET-01 — LAN session ve host-authority protokolü

**Amaç:** Offline simulation’ı değiştirmeden host/join session katmanını ve intent güven sınırını eklemek.

**Mekanik katalog ID’leri:** M-002, M-047.

**Bağımlılıklar:** AI-04.

**BUILT_IN / RECOMMENDED_ADDON:** T01 BUILT_IN ENetMultiplayerPeer/SceneMultiplayer/RPC; T04 CUSTOM_REQUIRED session/authority.

**Sistemler:** SessionHost, SessionClient, protocol/content version handshake, peer→player mapping, command envelope, reliable/unreliable channel policy.

**Görsel/asset bağımlılığı:** Yok.

**Android gereksinimi:** INTERNET izni LAN soketi için planlanır; offline oyun izin reddinde çalışmaya devam eder.

**LAN gereksinimi:** Manuel IPv4:port ilk zorunlu yol.

**Kabul kriterleri:** Version mismatch reddedilir; peer kendi player kimliğini sahteleyemez; client yalnız intent gönderir.

**GitHub Actions doğrulaması:** Headless host+client process integration; handshake mismatch; spoofed peer/command rejection.

**Gerçek cihaz doğrulaması:** Aynı Wi-Fi üzerinde Android↔desktop manuel IP bağlantısı.

**Sonraki görevi engelleyen kapı:** Authority boundary negatif testleri geçmeden NET-02 başlamaz.

## NET-02 — Spawn, snapshot ve temel state replikasyonu

**Amaç:** Oyuncu, NPC, monster ve loot entity’lerini hosttan clientlara stable ID ile replike etmek.

**Mekanik katalog ID’leri:** M-005, M-006, M-011, M-027, M-028, M-047, M-058.

**Bağımlılıklar:** NET-01.

**BUILT_IN / RECOMMENDED_ADDON:** T03 BUILT_IN MultiplayerSpawner/MultiplayerSynchronizer; T04 snapshot/AOI.

**Sistemler:** NetworkEntityRegistry, spawn/despawn, transform snapshot, interpolation buffer, combat/loot event replication.

**Görsel/asset bağımlılığı:** Placeholder yeterli.

**Android gereksinimi:** Snapshot byte budget ve update frequency telemetry.

**LAN gereksinimi:** Host tek spawn kaynağı; Resource/Object doğrudan replike edilmez.

**Kabul kriterleri:** Late spawned entity iki clientta aynı ID; despawn ghost bırakmaz; client authored spawn/HP değişimi reddedilir.

**GitHub Actions doğrulaması:** Two-process spawn/despawn; snapshot ordering/loss simulation; invalid client mutation; AOI visibility fixture.

**Gerçek cihaz doğrulaması:** Wi-Fi jitter altında movement interpolation ve combat event okunabilirliği.

**Sonraki görevi engelleyen kapı:** Stable ID replication ve client mutation rejection geçmeden NET-03 başlamaz.

## NET-03 — Vertical slice LAN parity

**Amaç:** VS-04 senaryosunu host + client ile aynı authoritative davranışta kanıtlamak.

**Mekanik katalog ID’leri:** M-003, M-005, M-006, M-011, M-027, M-047.

**Bağımlılıklar:** NET-02.

**BUILT_IN / RECOMMENDED_ADDON:** T01/T03/T04.

**Sistemler:** NetworkVerticalSliceScenario, remote target/fire intent, host AI-only tick, replicated loot claim.

**Görsel/asset bağımlılığı:** SC-02/SC-03 veya placeholder.

**Android gereksinimi:** Bir Android client/host kombinasyonu gerçek cihaz kapısıdır.

**LAN gereksinimi:** Bu görevin ana kapsamı.

**Kabul kriterleri:** Host ve client aynı NPC state’ini görür; AI yalnız hostta karar verir; client fire intent hostta doğrulanır; loot bir kez claim edilir.

**GitHub Actions doğrulaması:** Headless 1 host + 1 client full scenario; unauthorized damage/loot attempts; disconnect during combat.

**Gerçek cihaz doğrulaması:** Android↔desktop ve mümkünse Android↔Android aynı Wi-Fi; 10+ dakikalık oturum.

**Sonraki görevi engelleyen kapı:** Offline davranış parity ve authority negatif testleri geçmeden NET-04 başlamaz.

## NET-04 — Discovery, reconnect, late join ve LAN transaction hardening

**Amaç:** LAN kullanımını pratik hale getirmek ve save/loot/quest transactionlarını reconnect/late join altında korumak.

**Mekanik katalog ID’leri:** M-027, M-028, M-031, M-047, M-056, M-058.

**Bağımlılıklar:** NET-03.

**BUILT_IN / RECOMMENDED_ADDON:** T02 PacketPeerUDP discovery; T04 reconnect/late snapshot; T28 idempotent claim; T29/T33 Android. A01 yalnız gerekirse alternatif, ilk tercih değil.

**Sistemler:** discovery beacon, timeout/TTL/rate limit, reconnect token/session mapping, late-join baseline snapshot, transaction IDs.

**Görsel/asset bağımlılığı:** Yok.

**Android gereksinimi:** Android 17+/target SDK 37+ ACCESS_LOCAL_NETWORK davranışı cihazda doğrulanır; izin reddinde manual IP ve offline davranış açık kalır. Guest Wi-Fi/AP isolation hatası anlaşılır gösterilir.

**LAN gereksinimi:** Discovery ENet bağlantısından ayrı port; paketler sürüm/alan boyutu sınırına tabi.

**Kabul kriterleri:** Reconnect duplicate reward üretmez; late join güncel world state alır; sahte/bozuk discovery paketi oturumu bozmaz.

**GitHub Actions doğrulaması:** Discovery parser fuzz; reconnect/late join; duplicate transaction; protocol mismatch.

**Gerçek cihaz doğrulaması:** Android permission allow/deny, guest/AP isolation mümkünse, app background→foreground reconnect.

**Sonraki görevi engelleyen kapı:** LAN transaction idempotency geçmeden progression sistemleri host-mutating olarak genişletilmez.

---

# WAVE 6 — PROGRESSION / CONTENT

## PRG-01 — Inventory, equipment, crew, pet/companion ve preset

**Amaç:** Loot’u gerçek build sistemine dönüştürmek.

**Mekanik katalog ID’leri:** M-016, M-017, M-018, M-019, M-020, M-052.

**Bağımlılıklar:** NET-04.

**BUILT_IN / RECOMMENDED_ADDON:** T22 RECOMMENDED_ADDON A11 GLoot yalnız grid/weight/multi-container ihtiyacı doğrulanırsa; T23 BUILT_IN item/resource DB.

**Sistemler:** InventoryState, stack/slot transaction, weapon/structure/crew slots, extension modifiers, gem/socket/preset, companion slot.

**Görsel/asset bağımlılığı:** Item ikonları placeholder olabilir; gerçek icon seti polish/content aşamasında.

**Android gereksinimi:** Drag/drop’a bağımlı olmayan touch alternatifleri; büyük hit targets.

**LAN gereksinimi:** Equip/transfer transaction host doğrular; istemci GLoot nesnesi replike edilmez.

**Kabul kriterleri:** Slot type/weight/quantity kuralları atomik; preset savaş/safe-state kuralını ihlal edemez.

**GitHub Actions doğrulaması:** Equip compatibility; transfer rollback; stack boundaries; preset restrictions; duplicate transaction.

**Gerçek cihaz doğrulaması:** Touch inventory akışı ve fontScale 1.3.

**Sonraki görevi engelleyen kapı:** Inventory truth tek kaynak olmadan PRG-02 başlamaz.

## PRG-02 — Crafting, reclamation, ship upgrade ve cores/trophies

**Amaç:** Loot ve equipment için uzun vadeli üretim/salvage loop’u eklemek.

**Mekanik katalog ID’leri:** M-022, M-023, M-024, M-025, M-026.

**Bağımlılıklar:** PRG-01.

**BUILT_IN / RECOMMENDED_ADDON:** T24 CUSTOM_REQUIRED; T17 RNG; T23 Resources.

**Sistemler:** RecipeDefinition, CraftTransaction, SalvageTable, ship upgrade board, core slots, trophy/perk unlock ledger.

**Görsel/asset bağımlılığı:** UI icon placeholder kabul.

**Android gereksinimi:** Çok adımlı craft UI düşük bellek ve touch dostu.

**LAN gereksinimi:** Host tek doğrula-tüket-ver transaction; istemci sonucu seçemez.

**Kabul kriterleri:** Başarısız craft kısmi tüketim bırakmaz; salvage RNG seed/state kaydedilir; upgrade prerequisite cycle yoktur.

**GitHub Actions doğrulaması:** Recipe validation; atomic craft rollback; salvage deterministic fixture; upgrade DAG checks.

**Gerçek cihaz doğrulaması:** Craft/inventory geçişlerinde UI ve save performansı.

**Sonraki görevi engelleyen kapı:** Craft atomikliği ve upgrade graph doğrulaması geçmeden PRG-03 başlamaz.

## PRG-03 — XP, skill tree, rank ve local challenge meta

**Amaç:** Player growth’u offline-first şekilde kurmak.

**Mekanik katalog ID’leri:** M-021, M-032, M-033, M-035, M-054.

**Bağımlılıklar:** PRG-02.

**BUILT_IN / RECOMMENDED_ADDON:** T27 CUSTOM_REQUIRED perk DAG/rank; T21 progression gate hooks.

**Sistemler:** XP ledger, level/rank, skill DAG, respec, license/test gates, local challenge/milestone.

**Görsel/asset bağımlılığı:** Skill icon placeholder.

**Android gereksinimi:** Skill tree zoom/pan ve erişilebilir font.

**LAN gereksinimi:** XP/skill spend host transaction; global leaderboard yok.

**Kabul kriterleri:** XP duplicate event uygulanmaz; skill cycle/prerequisite doğrulanır; respec atomik; M-035/M-054 internet gerektirmez.

**GitHub Actions doğrulaması:** XP ledger idempotency; DAG cycle; spend/respec; challenge reset/version fixture.

**Gerçek cihaz doğrulaması:** Skill tree touch navigation.

**Sonraki görevi engelleyen kapı:** Progression ledger ve gate API sabitlenmeden PRG-04 başlamaz.

## PRG-04 — Quest, journal ve NPC interaction

**Amaç:** Data-driven görevler, bounty/escort/salvage/trade objective’leri ve ödül ledger’ı kurmak.

**Mekanik katalog ID’leri:** M-031, M-032.

**Bağımlılıklar:** PRG-03.

**BUILT_IN / RECOMMENDED_ADDON:** T21 CUSTOM_REQUIRED quest model; T25 A12 Dialogue Manager 4 RECOMMENDED_ADDON yalnız dallı yazarlık büyürse.

**Sistemler:** QuestDefinition, QuestInstance, objective event bus, reward ledger, NPC interaction authority, journal view model.

**Görsel/asset bağımlılığı:** Portre/diyalog sanatı zorunlu değil.

**Android gereksinimi:** Journal/diyalog touch ve fontScale 1.3.

**LAN gereksinimi:** Party share policy açık; completion/reward host doğrular.

**Kabul kriterleri:** Objective eventleri stable ID ile işler; reward bir kez; save/load quest progress korunur; invalid remote completion reddedilir.

**GitHub Actions doğrulaması:** Objective types; branching prerequisite; reward idempotency; save/load; host spoof rejection.

**Gerçek cihaz doğrulaması:** Quest tracking ve dialog UI okunabilirliği.

**Sonraki görevi engelleyen kapı:** Quest/reward ledger stabil olmadan PRG-05 başlamaz.

## PRG-05 — Faction, reputation, ekonomi, trade, outpost ve opsiyonel LAN PvP

**Amaç:** Yaşayan dünya AI’sını gerçek ekonomik/faction sonuçlarına bağlamak.

**Mekanik katalog ID’leri:** M-029, M-030, M-034, M-036, M-037, M-038, M-039, M-055, M-059.

**Bağımlılıklar:** PRG-04, AI-03.

**BUILT_IN / RECOMMENDED_ADDON:** T26 CUSTOM_REQUIRED faction/economy/trade; T28 contribution/ledger.

**Sistemler:** faction relation matrix, reputation, regional ownership, shop price/stock, convoy supply influence, bounty/intel, outpost/tower state, local company/crew, optional PvP rules.

**Görsel/asset bağımlılığı:** Faction flags/emblems final art beklemez; iki bağımsız visual marker ilkesi POL-02’de uygulanır.

**Android gereksinimi:** Market/faction UI daha sonra final polish.

**LAN gereksinimi:** Host world save sahibi; trade/price/rep/PvP reward authority host.

**Kabul kriterleri:** Convoy loss stock/price hook’u etkileyebilir; reputation hostility/safety davranışına yansır; PvP tekrar-kill diminishing return uygulanabilir.

**GitHub Actions doğrulaması:** Faction relation transitions; market price fixture; trade ledger; outpost ownership; PvP repeat-kill policy.

**Gerçek cihaz doğrulaması:** Uzun LAN oturumunda ekonomi state drift gözlemi.

**Sonraki görevi engelleyen kapı:** Faction/economy state persistence ve host transaction testleri geçmeden PRG-06 başlamaz.

## PRG-06 — Surface/submarine katmanı ve içerik genişletme altyapısı

**Amaç:** Atlantis referansını SeaCraft’a ayrı content mode olarak uyarlamak; mevcut çekirdeği çoğaltmadan surface/sub mode tag’i eklemek.

**Mekanik katalog ID’leri:** M-049, M-050, M-051, M-060.

**Bağımlılıklar:** PRG-05.

**BUILT_IN / RECOMMENDED_ADDON:** T18 shared combat profiles; T19 sector layers; T21 progression gates; T22/T23 inventory/data; T27 progression.

**Sistemler:** mode tag, submarine loadout, torpedo/breach profile, auto-fire intent, sub sector/transition, shared progression bridge.

**Görsel/asset bağımlılığı:** Submarine production art ayrı lane; placeholder ile sistem doğrulanabilir.

**Android gereksinimi:** Yeni layer memory/texture budget aşmamalı.

**LAN gereksinimi:** Mode transition ve combat host-authoritative.

**Kabul kriterleri:** Surface ve sub aynı entity/save/network çekirdeğini kullanır; özel silah target/range kuralları ayrı profile’dır.

**GitHub Actions doğrulaması:** Mode transition; torpedo/breach; shared inventory/progression; save/load; LAN mode mismatch rejection.

**Gerçek cihaz doğrulaması:** Sector-layer geçiş memory spike ve touch combat.

**Sonraki görevi engelleyen kapı:** Shared-core mode ayrımı kanıtlanmadan BOSS / ADVANCED CONTENT başlamaz.

---

# WAVE 7 — BOSS / ADVANCED CONTENT

## ADV-01 — Raid, wave/bonus map ve handcrafted event framework

**Amaç:** 1–4 oyuncu ölçekli instanced/sector event, wave director ve reward flow kurmak.

**Mekanik katalog ID’leri:** M-040, M-041, M-042, M-058.

**Bağımlılıklar:** PRG-06.

**BUILT_IN / RECOMMENDED_ADDON:** T19 spawn/encounter director; T21 objective state; T28 contribution/reward.

**Sistemler:** EncounterDefinition, WaveDirector, instance/sector state, scalable spawn budget, contribution ledger, event save/resume.

**Görsel/asset bağımlılığı:** Boss/raid final art gerekli değil; telegraph primitives kabul.

**Android gereksinimi:** Spawn/VFX cap ve pause/background behavior.

**LAN gereksinimi:** Host encounter state; 1–4 player scaling host tarafında.

**Kabul kriterleri:** Wave state save edilir; reconnect contribution kaybetmez/dupe üretmez; player count scaling deterministic.

**GitHub Actions doğrulaması:** Wave progression; scaling; contribution partial reward; save/reconnect.

**Gerçek cihaz doğrulaması:** Android host + client uzun encounter performansı.

**Sonraki görevi engelleyen kapı:** Encounter state machine ve reward ledger geçmeden ADV-02 başlamaz.

## ADV-02 — Admiral trigger, boss phases, hazards ve immunity

**Amaç:** Region-level organic boss spawn ve çok fazlı Lovecraftian boss encounter kurmak.

**Mekanik katalog ID’leri:** M-043, M-044, M-045, M-046, M-060.

**Bağımlılıklar:** ADV-01, AI-04.

**BUILT_IN / RECOMMENDED_ADDON:** T07 A06 Beehave veya boss BT actionları; T08 phase FSM; T18 combat; T19 spawn director; T32 telegraph/profiling.

**Sistemler:** AdmiralCounter, BossPhaseDefinition, add/hazard spawner, immunity windows, telegraph intent, enrage/fail conditions.

**Görsel/asset bağımlılığı:** SC-14 Dip Çanı ve ağır pilot SC-08 final boss/scale testinde değerlidir; ayrı H/S sprite üretimi bu görevin kod başlamasını engellemez, fakat POL-02 final görsel kabulte gerekir.

**Android gereksinimi:** Boss VFX cap ve telegraph görünürlüğü.

**LAN gereksinimi:** Boss phase ve hazard host-authoritative.

**Kabul kriterleri:** Trigger threshold tek spawn; phase transition idempotent; immunity yanlış hasarı reddeder; add/hazard budget sınırlı.

**GitHub Actions doğrulaması:** Trigger counter; phase transition; immunity; add budget; wipe/retry; reconnect mid-phase.

**Gerçek cihaz doğrulaması:** Android’de boss+adds+VFX frame pacing ve telegraph okunabilirliği.

**Sonraki görevi engelleyen kapı:** Phase/trigger testleri geçmeden ADV-03 başlamaz.

## ADV-03 — Group system ve AI bot assistant

**Amaç:** LAN co-op party rolleri ve eksik oyuncu rolünü doldurabilen host-authoritative companion AI eklemek.

**Mekanik katalog ID’leri:** M-047, M-048, M-058.

**Bağımlılıklar:** ADV-02, NET-04.

**BUILT_IN / RECOMMENDED_ADDON:** T12 role/formation; T13 AI; T21 party objective; T26 local group/faction.

**Sistemler:** PartyState, role assignment, ping/order intent, bot fill policy, contribution rules.

**Görsel/asset bağımlılığı:** Yeni gemi gerektirmez; mevcut role profile kullanır.

**Android gereksinimi:** Party command UI POL-01’de finalleşir.

**LAN gereksinimi:** Party state host; bot yalnız hostta AI tick eder.

**Kabul kriterleri:** Client disconnect bot takeover üretirse aynı stable player slot policy korunur; bot ödülü/loot kuralı açıktır.

**GitHub Actions doğrulaması:** Join/leave/role; bot takeover; contribution; reconnect reclaim.

**Gerçek cihaz doğrulaması:** 2 cihaz + bot ile raid senaryosu.

**Sonraki görevi engelleyen kapı:** Co-op state stabil olmadan final UI/polish dalgası başlamaz.

---

# WAVE 8 — POLISH / ANDROID / OPTIMIZATION

## POL-01 — Final HUD, minimap/world map, hotbar ve erişilebilirlik

**Amaç:** Debug UI’ları production mobile/desktop HUD’a dönüştürmek.

**Mekanik katalog ID’leri:** M-004, M-052, M-053.

**Bağımlılıklar:** ADV-03.

**BUILT_IN / RECOMMENDED_ADDON:** T20 map UI; T25 interaction presentation; T29 mobile HUD; T30 camera; T32 telegraph.

**Sistemler:** HUD view models, target panel, hull/ward, ammo/reload, hotbar, quest tracker, minimap, world map, inventory/skill/party screens, accessibility settings.

**Görsel/asset bağımlılığı:** UI border/icon packs yalnız lisans ve art-direction kabulünden sonra; placeholder’dan final’e geçiş.

**Android gereksinimi:** 320–360dp, 392–411dp, fontScale 1.3; safe area; touch targets; controller fallback.

**LAN gereksinimi:** UI state mutasyonu yapmaz; host komut API’sini kullanır.

**Kabul kriterleri:** Tüm önemli combat/world state renk dışında shape/text ile de okunur; hiçbir UI doğrudan authoritative state yazmaz.

**GitHub Actions doğrulaması:** UI scene load smoke; command routing; localization key completeness; layout metadata sanity.

**Gerçek cihaz doğrulaması:** Üç ekran matrisi + fontScale, notch, touch, gamepad.

**Sonraki görevi engelleyen kapı:** Mobil kullanılabilirlik kapısı geçmeden POL-02 final asset entegrasyonu tamamlanmış sayılmaz.

## POL-02 — Gemi sprite, su/VFX, audio ve art-direction entegrasyonu

**Amaç:** Placeholder’ları SeaCraft’ın gerçek görsel diliyle değiştirmek ve sprite üretim planındaki teknik sözleşmeyi motorda doğrulamak.

**Mekanik katalog ID’leri:** M-003, M-006, M-011, M-014, M-044, M-046.

**Bağımlılıklar:** POL-01.

**BUILT_IN / RECOMMENDED_ADDON:** T31 BUILT_IN CanvasItem shader/wake/foam; T33 audio/localization. Hazır asset raporundaki lisanslı/CC0 kaynaklar yalnız gereken boşluklarda.

**Sistemler:** visual profile resolver, 8-direction AtlasTexture mapping, pivot/socket binding, wake/foam, cannon/hit/fire/smoke, sinking presentation, audio buses.

**Görsel/asset bağımlılığı:** İlk zorunlu production kabul: SC-02, SC-03 ve SC-08 pilotları. Ardından minimum set. SC-14 S boss için; tam 15 gemi bu görevin ilk alt kapısını engellemez.

**Android gereksinimi:** Texture residency, overdraw, mip/filter testi, alpha fringe, low-quality VFX mode.

**LAN gereksinimi:** Görseller local presentation; gerçek heading/combat/intent host state’inden gelir.

**Kabul kriterleri:** 4×2 N,NE,E,SE/S,SW,W,NW atlas mapping doğru; pivot ≤1 final px; socket/occlusion yönleri doğru; VFX gameplay hitbox değiştirmez.

**GitHub Actions doğrulaması:** Asset path/atlas dimension validation; missing socket/profile checks; import smoke; audio reference completeness.

**Gerçek cihaz doğrulaması:** Android Compatibility’de pilot üç gemi 360° dönüş, socket, wake/VFX, shimmer/overdraw ve yoğun filo testi.

**Sonraki görevi engelleyen kapı:** Pilot üç gemi teknik art kapısını geçmeden geniş sprite üretimi production-ready sayılmaz.

## POL-03 — Android/performance optimizasyonu ve soak

**Amaç:** AI, world, LAN, VFX ve UI’ı gerçek mobil host bütçesine indirmek.

**Mekanik katalog ID’leri:** M-001, M-003, M-047, M-056.

**Bağımlılıklar:** POL-02.

**BUILT_IN / RECOMMENDED_ADDON:** T14 AI LOD; T15 spatial hash; T16 pooling yalnız profiler gerekçesiyle; T29 mobile; T32 profiler; T33 Android export.

**Sistemler:** quality tiers, AI/path budgets, snapshot budgets, VFX cap, optional pools, texture/audio budget, load-time telemetry.

**Görsel/asset bağımlılığı:** Minimum sprite/VFX setinin gerçek dosyaları ölçülür.

**Android gereksinimi:** Ana kapsam; thermal throttling ve uzun oturum.

**LAN gereksinimi:** Android host/client throughput ve reconnect soak.

**Kabul kriterleri:** Hedef cihaz sınıfında tanımlanmış frame/memory/network bütçeleri aşılırsa içerik yoğunluğu otomatik/ayar ile düşebilir; gameplay authority korunur.

**GitHub Actions doğrulaması:** Performance regression için deterministic entity-count benchmark; headless soak; export artifact size budget; leak-like growth checks mümkün olduğu ölçüde.

**Gerçek cihaz doğrulaması:** 30–60 dk offline soak, 30–60 dk LAN host soak, background/resume, thermal, battery, memory, Wi-Fi jitter.

**Sonraki görevi engelleyen kapı:** Gerçek cihaz budget ölçümü olmadan final content fill yoğunluğu kilitlenmez.

## POL-04 — İçerik doldurma, dengeleme ve final offline/LAN acceptance

**Amaç:** ICERIK_KATALOGU ve mekanik katalog kapsamasını veri odaklı içerikle doldurmak; canlı servis bağımlılığı yaratmadan final kabul matrisi oluşturmak.

**Mekanik katalog ID’leri:** M-035, M-054, M-057, M-060; ayrıca M-001…M-060 kapsama denetimi.

**Bağımlılıklar:** POL-03.

**BUILT_IN / RECOMMENDED_ADDON:** T17 seed; T21 quest; T23 data registry; T26 economy; T27 progression; T28 loot; T32 test/profiling; T33 localization/audio.

**Sistemler:** content packs, balance tables, region escalation, local challenge rotations, validation reports, offline/LAN acceptance suite.

**Görsel/asset bağımlılığı:** Minimum ship set önce; tam 15 gemi ve ileri boss/monster içerikleri katmanlı olarak doldurulur. Hazır assetlerin lisans kaydı dosya-bazlı tutulur.

**Android gereksinimi:** İçerik hacmi arttıkça APK size, memory ve load time bütçesi tekrar ölçülür.

**LAN gereksinimi:** Aynı content hash zorunlu; mismatch join reddi.

**Kabul kriterleri:** M-001…M-060 her biri ya implemented/adapted ya da açıkça out-of-scope adaptation olarak izlenir; offline internet yokken tam oynanabilir; LAN host-authoritative acceptance suite geçer.

**GitHub Actions doğrulaması:** Content schema/ID/ref validation; mechanics coverage manifest; deterministic balance smoke; full offline vertical + LAN parity regression; Android export.

**Gerçek cihaz doğrulaması:** Final Android offline uçak modu, LAN iki cihaz, save migration, uzun soak, UI/accessibility ve boss encounter.

**Sonraki görevi engelleyen kapı:** Bu son release-readiness kapısıdır.

---

# 3. Vertical Slice kabul özeti

Vertical slice tamamlanmış sayılmak için aşağıdaki tek akış doğrulanır:

1. Oyun tamamen offline açılır.
2. SC-02 veya eşdeğer placeholder oyuncu gemisi tek sektörde hareket eder.
3. Camera2D takip/pan/zoom çalışır.
4. SC-03 veya eşdeğer placeholder NPC patrol eder.
5. NPC threat algılar ve en az retreat/repair gibi gelişmiş state değişimi gösterir.
6. Oyuncu hedef kilitler, top ateşler, reload/range/hasar kuralları uygulanır.
7. NPC batar ve tek authoritative loot doğar.
8. Loot bir kez alınır.
9. Save alınır; load sonrası player/sector/NPC/loot ledger/RNG tutarlıdır.
10. Aynı senaryo NET-03’te host + client ile tekrarlanır; AI, combat ve loot yalnız hostta authoritative kalır.

# 4. Addon karar kapıları

| Addon | Durum | İlk değerlendirileceği görev | Kullanım kapısı |
|---|---|---|---|
| A06 Beehave | RECOMMENDED_ADDON | VS-02 pilot, AI-01 genel kullanım | Godot 4.7 testleri + Android export/cihaz; yalnız host AI |
| A11 GLoot | RECOMMENDED_ADDON | PRG-01 | Grid/weight/multi-container gerçekten gerekiyorsa; basit slotta özel model tercih |
| A12 Dialogue Manager 4 | RECOMMENDED_ADDON | PRG-04 | Dallı yazarlık büyürse; Android UI/import doğrulaması |
| A14 GUT | RECOMMENDED_ADDON | FND-01 | Headless Godot 4.7 CI; release export’a dahil edilmez |
| A01 LANServerBroadcast | OPTIONAL, varsayılan değil | NET-04 | PacketPeerUDP özel çözüm yetersizse ve 4.7/Android doğrulanırsa |
| A02 netfox | OPTIONAL, varsayılan değil | NET-02 sonrası ölçüm | Yalnız ölçülen interpolation/prediction ihtiyacı varsa |
| A05 LimboAI | OPTIONAL alternatif | AI-01 sonrası | Beehave + custom FSM yetersizse; Android GDExtension yükleme kanıtı |
| A04 Godot SQLite | OPTIONAL | CORE-04 sonrası ölçüm | JSON persistence ölçeği gerçekten yetersizse |

# 5. IMPLEMENTATION ORDER

| Sıra | Görev ID | Dalga | Başlaması için ana kapı |
|---:|---|---|---|
| 1 | FND-01 | FOUNDATION | Yok |
| 2 | FND-02 | FOUNDATION | FND-01 |
| 3 | FND-03 | FOUNDATION | FND-01 |
| 4 | FND-04 | FOUNDATION | FND-02, FND-03 |
| 5 | FND-05 | FOUNDATION | FND-02, FND-04 |
| 6 | FND-06 | FOUNDATION | FND-02, FND-05 |
| 7 | VS-01 | FIRST PLAYABLE / VERTICAL SLICE | FND-04, FND-05, FND-06 |
| 8 | VS-02 | FIRST PLAYABLE / VERTICAL SLICE | VS-01 |
| 9 | VS-03 | FIRST PLAYABLE / VERTICAL SLICE | VS-01, VS-02, FND-06 |
| 10 | VS-04 | FIRST PLAYABLE / VERTICAL SLICE | VS-02, VS-03 |
| 11 | CORE-01 | CORE SYSTEMS | VS-04 |
| 12 | CORE-02 | CORE SYSTEMS | CORE-01 |
| 13 | CORE-03 | CORE SYSTEMS | CORE-02 |
| 14 | CORE-04 | CORE SYSTEMS | CORE-03 |
| 15 | AI-01 | SMART WORLD / AI | CORE-04 |
| 16 | AI-02 | SMART WORLD / AI | AI-01, CORE-01 |
| 17 | AI-03 | SMART WORLD / AI | AI-02, CORE-03 |
| 18 | AI-04 | SMART WORLD / AI | AI-03, CORE-04 |
| 19 | NET-01 | LAN MULTIPLAYER | AI-04 |
| 20 | NET-02 | LAN MULTIPLAYER | NET-01 |
| 21 | NET-03 | LAN MULTIPLAYER | NET-02 |
| 22 | NET-04 | LAN MULTIPLAYER | NET-03 |
| 23 | PRG-01 | PROGRESSION / CONTENT | NET-04 |
| 24 | PRG-02 | PROGRESSION / CONTENT | PRG-01 |
| 25 | PRG-03 | PROGRESSION / CONTENT | PRG-02 |
| 26 | PRG-04 | PROGRESSION / CONTENT | PRG-03 |
| 27 | PRG-05 | PROGRESSION / CONTENT | PRG-04, AI-03 |
| 28 | PRG-06 | PROGRESSION / CONTENT | PRG-05 |
| 29 | ADV-01 | BOSS / ADVANCED CONTENT | PRG-06 |
| 30 | ADV-02 | BOSS / ADVANCED CONTENT | ADV-01, AI-04 |
| 31 | ADV-03 | BOSS / ADVANCED CONTENT | ADV-02, NET-04 |
| 32 | POL-01 | POLISH / ANDROID / OPTIMIZATION | ADV-03 |
| 33 | POL-02 | POLISH / ANDROID / OPTIMIZATION | POL-01 |
| 34 | POL-03 | POLISH / ANDROID / OPTIMIZATION | POL-02 |
| 35 | POL-04 | POLISH / ANDROID / OPTIMIZATION | POL-03 |

## 6. Kapsama kontrolü

Bu plan M-001’den M-060’a kadar mekanik kataloğunun tamamını en az bir görev paketine bağlar. AI-01…AI-30 maddeleri ise VS-02 ve AI-01…AI-04 görevlerinde uygulanabilir alt davranışlar olarak izlenir. İçerik kataloğunun 661 somut kaydı, ilk vertical slice’ın ön koşulu değildir; POL-04’e kadar veri paketleri halinde kademeli doldurulur.

En kritik sıra kapısı şudur:

**FND-06 save → VS-04 offline vertical slice → AI-04 ölçeklenebilir authoritative dünya → NET-03 aynı vertical slice LAN parity → progression/economy → raid/boss → final UI/art → Android/performance → content fill.**
