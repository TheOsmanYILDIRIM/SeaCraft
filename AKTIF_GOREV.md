# AKTİF GÖREV — PLAY-01 · Gemi hareketi, kamera ve mobil kontrol

Kullanıcı 2026-11-24 oynanış öncelikli sırayı onayladı. Kanonik plan `GELISTIRME_GOREV_PLANI.md` üst bölümü. Tek aktif geliştirme PLAY-01; PRG-06 askıda, mevcut kod/kayıtlar korunur; PRG-05 fiziksel LAN kabulü ayrı açık. PLAY-02 öncesi gerçek cihaz oynanış kabulü şart.

Checkpoint 1 ve kıyı rota/sıkışma checkpoint 2 kod+CI+export düzeyinde doğrulandı. Cihaz kabulü: düz/ters yön, yakın hedef, kamera pan/pinch/merkezle, kıyı rotası, durma ve rota okunurluğu; takılma/dokunma sapması ve hareket hissi gözlemi. Hız/dönüş dengesi yalnız gerçek cihaz geri bildirimine göre.


## PLAY-01 — cihaz geri bildirimi düzeltmesi (2026-11-26)

- Kullanıcı gerçek cihazda ara noktalarda durma, alt sınırda geri dönememe ve sprite/heading uyumsuzluğu bildirdi; her küçük düzeltmede APK kurup yeniden test etmek istemiyor. Güncel onaylı SC01/02/03/04/06/08 ve M01/M02 paketleri allowlist ile stage edildi, eski SC07 karşılaştırma prototipi kaldırıldı. SC01 varsayılan oyuncu, SC04 NPC, altı gemi geçici görsel test seçicisinde; LAN gemi/monster proxy görselleri bağlandı. M01/M02 mevcut territory anchor'larında etiketli görsel önizleme; yeni authoritative monster spawn/AI yok. SC01 ve SC04'ün kaynak yön etiketleri pruva/dümene göre 180° ters olduğu gerçek 8 yön QA panosunda görüldü; runtime atlasları 4 hücre kaydırıldı, kaynak ZIP'ler korunur. SC02/06/08 1024px master hücreleri korunur; cihaz bellek/perf ayrıca ölçülecek.
- Helm rota ara noktaları transit, yakın güvenli sonraki leg'e hız sıfırlamadan geçiş; güvenli quadratic köşeler, yuvarlak çizgi eklemleri; fiziksel sınır ile navigation clearance arasından geçerli suya egress, sınırlı düşük hız steerage; sprite nearest 8-dir + residual heading. Gerçek kıyı ve alt sınır testleri, geçiş hız assertion'ları, 8 atlas erişim testleri, tüm eski testler başarılı. Replay coast 74 örnek / 577 tick, boundary 38 örnek / 293 tick; ara örneklerde sıfır hız yok, coast collision=0; hareket yönü vs ölçülen velocity açısal hata <0.00001 derece. Replay CPU görselleştirme, gerçek Godot fizik örnekleri; fiziksel Android görüntü/perf kabulü değildir.
- Exact code `e942000b74e3e7dc5c5592b9653bfdd494d84de0`, [CI 45700755926](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45700755926) **success**, GUT **427/427**, **33461 assertions**, PLAY01_BOUNDARY_EGRESS_OK, PLAY01_APPROVED_ATLASES_OK, PLAY01_REPLAY_OK; NET01–04, PRG05 ve diğer regresyonlar geçti. Android artifact `15062169684`, ZIP SHA256 `b97374196bfbef3c59fdd8e52446a2e96dbc78a6687d79d5f8e490ae4b9a4b57`; Linux `15062733014`, ZIP SHA256 `7c1695ea666e2057bd4c2fd0a8d4b3ea04a0ccfeeaec9b1e308506bac00462c5`; authenticated readback geçti. Visual QA `15062267414`, helm GIF/JSON replay `15064155373`, ikisi indirildi, panolar ve replay örnekleri incelendi.
- PLAY-01 aktif: kullanıcıya her küçük değişiklikte APK kurdurtma; önce CI fizik senaryosu + atlas/trajectory replay ile iterasyon, fiziksel cihaz kabulü yalnız konsolide checkpoint veya cihaz-özel hata için. Nihai hareket hissi ve Android performansı `not_run`; PRG-06 askıda. Kullanıcı onaylı görsel entegrasyon kapsamı PLAY-01 içinde ele alındı, ileri mekanik aşaması başlatılmadı.

## PLAY-01 — 2026-11-25 sprite kaynak derleme düzeltmesi

- Silinen eski SC-03 arşiv referansı yeni `SC03_FINAL_MANUAL_ALIGNED_GITHUB_UPLOAD.zip` ile değiştirildi; onaylı 224 px atlas kaynak çözünürlüğü korundu. Eski arşiv geri getirilmedi; oynanış parametreleri değişmedi.
- Kod `5f3b7e049215539d2e4961098eb6090273578992`, [CI 45688116253](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45688116253) success; GUT 425/425, 33405 assertions, PLAY-01 ve LAN regresyonları başarılı. Linux ve Android export + authenticated artifact readback başarılı. Android artifact `15058320656`, ZIP SHA256 `a14547d7214b0cdfd83706e62cdcc9c0032b8288292831b984032d5a8a36caec`; Linux artifact `15057692304`, ZIP SHA256 `33ebe85e977a05bba79b4ee8aa50a71e159aadaca913a7de076cbffc58fb5e96`.
- Fiziksel Android oynanış kabulü `not_run`; PLAY-01 aktif, PLAY-02 başlamadı. Yeni görsellerin cihaz üzerindeki görünümü ayrıca doğrulanmadı.

## PLAY-01 checkpoint 2 — 2026-11-24

- Bootstrap hareket komutları artık doğrudan kıyıya sürmek yerine mevcut `SectorNavigation.path()` üzerinden bounded waypoint rotası kuruyor. Erişilemez kıyı/ada hedefi reddediliyor; motor ara waypoint'leri izlerken hedef işareti kullanıcının son hedefinde kalıyor ve `Play01Route` kalan rotayı görünür gösteriyor. Sürekli slide collision durumunda 6 tick sonra, son erişilebilir konumu da kullanabilen en fazla 2 replan deneniyor; başarısızlıkta hedef güvenli biçimde iptal ediliyor. LAN rota sahipliği ve sektör geçişi helm rotasını temizliyor.
- Exact code `7ba8cdd871b6d1dac02a91b159359d1eeed5d09e`; [CI 45475985405](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45475985405) **success**, **425/425 GUT**, **33.405 assertions**; `PLAY01_RENDERED_CANVAS_OK`, `PLAY01_PACKED_HELM_OK`, `PLAY01_NEAR_REVERSE_ARRIVAL_OK`, `PLAY01_COAST_ROUTE_OK`, `PLAY01_STUCK_RECOVERY_OK`; VS04, NET01–04 ve PRG05 production regresyonları geçti. Android artifact `14959542092`, ZIP SHA256 `8e483ecda5bbaa307fa84c69e26251a5e9de827dfd86c7c249ce443c0e4660fe`; Linux `14960740912`, ZIP SHA256 `c08f52f71f2c4895f79d3117655e45f460ec871797ac8017f1117ab52923ee53`; ikisi de exact SHA için authenticated readback geçti.
- PLAY-01 active: fiziksel Android touch/pinch/recenter/180° dönüş/yakın varış/DUR/kıyı rota okunurluğu ve hareket hissi `not_run`. Sonraki iş aynı PLAY-01 içinde gerçek cihaz tuning/acceptance; cihaz kanıtı olmadan hız/dönüş değerleri değiştirilmez. PLAY-02 başlamadı; PRG-06 waiting.

## PLAY-01 checkpoint 1 — 2026-11-24

- Gerçek rendered canvas hit-test, BoatMarker follow/recenter (boot/teleport/manual), mobil DUR ve GEMİYE DÖN, hedef işareti. Yakın/ters hedef orbit giderimi: arrival radius ×5 içinde dönüş hızı sınırı ve 0.01 settle tolerance; uzun rota davranışı korunur. 20 yakın/ters hedef kombinasyonu ve gerçek packed Bootstrap testleri geçti. İlk CI'da görülen follow ve VS04 broadside regresyonları kaynakta giderildi, testler gevşetilmedi.
- Exact code `8e651ad825c385f15bdcbcc4af0cf681513ff3d6`; [CI 45467139708](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45467139708) success, **423/423 GUT**, **33.381 assertions**; `PLAY01_RENDERED_CANVAS_OK`, `PLAY01_PACKED_HELM_OK`, `PLAY01_NEAR_REVERSE_ARRIVAL_OK`; VS04, NET01–04, PRG05 production save/replay and offline guard passed. Android artifact `14954319289`, ZIP SHA256 `b7c9d795f8461e940db43e13bfca4dae3ddf1ab702b37ea5d69fdbe92570a231`; Linux `14953769621`, ZIP SHA256 `31cfb7407a4ad62a7c73c1be35ee02445046c0bbb621e6449065a572b4cb0cf3`; both authenticated readback passed.
- PLAY-01 active: gerçek cihazda dokunma, pan/pinch, geri merkezleme, 180° dönüş, yakın varış, durma, kıyı/sıkışma ve hız hissi kabulü `not_run`. Kıyı rotası/takılma ve hareket hissi ayarı açık; PLAY-02 başlamadı. PRG-06 waiting; PRG05 fiziksel LAN ayrı açık.

---

# ASKIDA — PRG-06 · Surface/submarine ve içerik genişletme

Plan: `GELISTIRME_GOREV_PLANI.md` PRG-06; kanonik Beyin `tasks/seacraft-prg06-surface-submarine-20261124.md`; yalnız `main`, Godot 4.7.2. PRG-05 ekonomi persistence ve host transaction test gate geçti. Kullanıcı 2026-11-24 fiziksel cihaz testini üstlendi ve plana göre geliştirmeye devam edilmesini istedi. PRG-05 cihaz kabulü `not_run`, ayrı açık kalır.

## PRG-06 checkpoint 1 — 2026-11-24

- Authored sector mode (surface 0/submarine 1), validated cross-mode gates, Deep Haven and protected entry; surface FAR routing cannot cross into underwater mode. Bootstrap mobile gate button routes to anchor, dives and returns. Existing shared inventory, entity identity, world and persistence retained; predecessor manifest migration narrowly matches verified PRG-05 hash and count. LAN manifest mismatch rejected; underwater LAN host/join blocked, running room cannot transition. Placeholder submarine presentation only.
- Exact code `a45e0cc327671fd6b2fe3f141f0f6a56bedb364c`; [CI 45457089855](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45457089855) **success**, GUT **420/420**, **30,000 asserts**, `PRG06_MODE_GATE_OK`, `PRG06_SHARED_SAVE_OK`, `PRG06_LEGACY_CONTENT_OK`; NET01–04 real-process and PRG05 production save/replay passed. Manifest 25 entries, `2e2621f8506cf623ec41a93298aebbcaee94526f0cc244eb2ec86c0ab740a3a4`; Linux runtime manifest parity and Android source bytes verified. Android artifact `14951033193`, ZIP SHA-256 `d5ac2f48017f5b641bbdbfd7d0a6470805d8517b2ada8657372d1e72f6408774`; Linux artifact `14950518669`, ZIP SHA-256 `21549e8370211004243894cc76c4ed954e40db6656de104f58778ac6d9130741`; authenticated readback passed.
- **Deferred:** submarine tier/loadout, launcher/torpedo/breach, mode-specific gems/progression, auto-fire, actual underwater host-authoritative combat and network composition; physical Android movement/memory/touch `not_run`. ADV-01 not started.

---

# AKTİF GÖREV — PRG-05 · faction ve ekonomi (devam ediyor)

Başlangıç: a73633beb1dfec0d70c1b4e640bfd439ff823ede; yalnız `main`; Godot 4.7.2. Kaynak: `GELISTIRME_GOREV_PLANI.md` PRG-05. PRG-04 kapalı; Android smoke hotfix gerçek cihaz retesti ayrı `awaiting_retest`.

**Bu dilim:** host-owned faction relations/reputation, market buy/sell, convoy supply etkisi, outpost ownership, repeat-kill PvP diminishing returns; inventory v5 save/load; LAN client yalnız market_id/quantity ile trade intent gönderebilir. Gemi sprite'larından bağımsızdır.

**Doğrulanmış ek checkpoint:** AI-03 konvoy ve AI-04 FAR world teslim/kayıp settlement adaptörü, Güvenli Liman market içeriği ve dokunmatik pazar paneli. Exact kod SHA `0c821a58c904839a53cd0b51509f55e606e3e323`; [Actions 45249433521](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45249433521) `success`, 403/403 GUT, 9/9 PRG-05, Android/Linux artifact provenance/readback başarılı.

**PRG-05 son doğrulanmış checkpoint:** AI-04 FAR scheduler→market settlement, LAN host market sector/ShipMotor proximity guard, bounty/intel combat proof + event ledger, PRG-01 crew equipment'ını kullanan local company/crew roster ve idempotent maaş settlement, JSON legacy migration ve strict state validation. Exact kod SHA **`11ddde3d4f2311283899e2b873485b38008d6a97`**, [Actions 45272356337](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45272356337) **success**, 410/410 GUT, 29.790 assert, PRG-05 16/16; Android/Linux artifact authenticated readback başarılı.

**PRG-05 checkpoint 4 — 2026-11-24:** gerçek liman pazarı anchor/128 world-unit menzil, offline/LAN ortak sektör ve motor konum kanıtı, menzil dışına çıkınca panel kapanışı; NET-04 gerçek ENet süreçlerinde alım, reconnect cached replay ve uzak client reddi. Exact kod SHA `5de54a10623cf1a7aee10dd5295e859e25486667`; [CI 45348969786](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45348969786) **success**, full GUT ve regresyonlar, Android/Linux export ve authenticated artifact readback başarılı. Android artifact `14899013500`, ZIP SHA-256 `994982a114d1a5b16ec158f81baf2d4da6c19811c94f874af82863022a7dfb73`; Linux artifact `14898834070`, ZIP SHA-256 `754b17e4ba6a75dd0986ac201849890e46de432002a0450af419b4f2bc0f3d29`. Gerçek Android dokunmatik ve uzun iki cihaz LAN drift `not_run`; üretim sahnesi/host orchestration uçtan-uca cihaz kabulü açık, PRG-05 active; PRG-06 başlamadı.

**PRG-05 checkpoint 5 — 2026-11-24:** shipped offline Bootstrap bounty (80 currency), AI-04 FAR pilot supply convoy (+4 stock), market UI read-only status and authoritative trade; packed-scene combat → mid-route save/reload → delivery → real sector gates → market buy and out-of-range rejection verified. Exact code SHA `fb11a171c53a9974e5009adcf66b4dd836a69bf3`; [CI 45357962822](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45357962822) **success**, GUT **414/414**, 29,884 asserts, PRG-05 **19/19** (18 explicit verifier markers); NET04 real-process, Android/Linux export and authenticated artifact readback success. Fixed legacy full-width RNG seed derivation, empty exported registry / source-pack content manifest parity (23 entries, Android byte-exact definitions), random transaction ID invalid numeric prefix (all 16 prefixes tested). Android artifact `14903422223`, ZIP SHA-256 `ad4287d027b53ad671e54854290f13aece1ba8d7851b8fa643e8ddb360c6ff68`; Linux artifact `14903252987`, ZIP SHA-256 `817df7b595d26c0bf5a3af04b08760b6db1a90af51e72d45017dbce7eb37fb52`. Actual physical Android touch/long two-device LAN drift `not_run`; full production LAN host composition and UI device acceptance remain open; PRG-05 active, PRG-06 not started.

**PRG-05 checkpoint 6 — 2026-11-24:** shipped `Bootstrap` artık gerçek production LAN host orchestration'ını kuruyor: gerçek Safe Haven market sector/ShipMotor authority, UDP discovery/manual IP join, authoritative guest movement + market intent, host-owned save, reload sonrası guest inventory/motion ve transaction-ledger geri yükleme, aynı transaction ID için cached replay ile ikinci mutation oluşmaması. Bu uçtan-uca production path, non-home-sector save boot sırasında dormant NPC AI/combat restore açıklarını da ortaya çıkardı; dormant brain rebind ve dormant combat weapon battery restore kökten düzeltildi ve regresyon testleri eklendi. Exact code SHA **`ef470b821332d85846b345d20e09c5b22f2d50ea`**; [CI 45365494569](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45365494569) **success**, GUT **416/416**, **29,910 assert**; NET-01/02/03/04 gerçek süreç doğrulamaları, production LAN integration + verifier, VS/CORE/AI regresyonları, Linux/Android export ve authenticated artifact readback başarılı. Production LAN kanıtı: `host_bootstrap=1 save_reload=1 cached_replay=1`, save `owner=host stock=7 guest_quantity=1 ledger=1`, reload/replay sonunda `stock=7 balance=988 quantity=1 ledger=1`. Android artifact `14905973534`, ZIP SHA-256 `846a2848b8278e5a87b2ea0207c34de72c162f93ee571c32c7903c8bd1e7ef22`; Linux artifact `14907086350`, ZIP SHA-256 `f9d1c66b5aa06331c34c0983ca18a3a56378159fac2b654ac8b86e9016a48001`. Production composition artık kod+gerçek süreç+save/replay düzeyinde doğrulanmıştır; fiziksel Android dokunmatik pazar kabulü ve uzun iki cihaz LAN ekonomi drift testi hâlâ `not_run`. PRG-05 `active`, PRG-06 başlamadı.

**PRG-05 Android LAN izin hotfix — 2026-11-24:** Kullanıcının `415919e9c471` build'inde `requested` döngüsü: Android SDK <37 için gereksiz runtime gate kaldırıldı; SDK ≥37 gerçek izin grant'i, async callback + timeout/recheck, host/guest single-flight ve cancel; Android UDP broadcast receive ve `CHANGE_WIFI_MULTICAST_STATE` manifest doğrulaması eklendi. Exact code SHA `ecda2d69ea2d79cbc40bb73bc4fcfae12dd41bdf`; [CI 45440455081](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45440455081) **success**, GUT **417/417**, **29,960 asserts**, `NET04_PERMISSION_CALLBACK_OK grant=1 denied=1 false_grant=1 unrelated=1 timeout=1 broadcast=1`; NET01–04 ve PRG05 production integration, Android/Linux export ve authenticated artifact readback geçti. Android artifact `14944915113`, ZIP SHA-256 `73405fa9c09242e535b765eec5ee31bb71023d96f6faa9fd5102e47ba7b9569d`, APK SHA-256 `5ad80bd3a0feabe7b3ae8f802dc559efc8d372d83b5a129a537178e81e5bf996`; Linux artifact `14943621158`, ZIP SHA-256 `490d89cc9e0bdba3d58d1099d07c7846d0e5e03d0bf358779266b43a343914dc`. Fiziksel Android izin, host/join UX ve uzun iki-cihaz ekonomi drift retesti `not_run`; PRG-05 active; PRG-06 başlamadı.

**Açık PRG-05 kapıları:** Gerçek Android dokunmatik pazar smoke + uzun iki-cihaz LAN ekonomi drift `not_run`; production host orchestration kod+gerçek süreç+save/replay düzeyinde doğrulandı, fakat fiziksel cihazda host/join/pazar UX kabulü ve uzun süreli iki cihaz state-drift gözlemi hâlâ gereklidir. CI fiziksel cihaz testi yerine geçmez. PRG-05 fiziksel kabul için `active` tutulur; 2026-11-24 kullanıcı cihaz testini üstlendi, planın teknik kapısı geçildiği için PRG-06 ayrıca başlatıldı.

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
