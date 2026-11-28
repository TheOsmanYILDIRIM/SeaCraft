# SeaCraft — Session Handoff

## Güncel durum

### 2026-11-28 — PLAY-00 UI-first plan ve tasarım sözleşmesi

- Kanonik yeni yürütme sırası `GELISTIRME_GOREV_PLANI.md`: önce PLAY-00 sistem/içerik/UI sözleşmesi, bağımsız PLAY-01 helm ve asset işleri paralel; ilgili ekran grubu kabulünden sonra UI/backend lane'leri açılır. Önceki tek aktif PLAY-01 / sonraki aşamaya geçmeme kuralı tarihsel; cihaz kabulü yine ayrı ve açık.
- PLAY-00 tasarım v1 commit `c7c9c7c854c8659f5131283fda6adcb72967bb83`: gerçek kod envanteri, ekran akışı ve mobil wireframe, adapter payload/snapshot/error sözleşmeleri, 6 gemi/3 top/cephane/ticaret mock matrisi, F01–F19 durumları, ayrı normal NPC/mini raid/gelecek sanal oyuncu sistemleri ve sahiplik. **Tasarım hazır; kullanıcı kabulü bekliyor.** Rakamlar ve yeni işlem adları öneridir; runtime veya fixture kodu yazılmadı.
- Gemi purchase/activate, gerçek batarya adetleri, çok ürünlü pazar, port repair ve ayrı raid lifecycle eksik; mevcut authority tekrar yazılmaz. UI görsel onayı ve gerçek Android/LAN kabulü henüz not_run. PRG-06/sanal oyuncu sandbox askıda. Avenox PLAY-01 revision 5 okundu; PLAY-00 Beyin kaydı DirectSync snapshot doğrulaması yapılmadığından yazılmadı.


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



**Oynanış öncelikli revizyon:** PLAY-01 aktif; PRG-06 askıda, mevcut pilot korunur. PLAY-08/09 kabulünden önce ileri içerik geliştirilmez. Önceki teknik kanıtlar aşağıda tarihsel olarak korunur.

- Repo: `TheOsmanYILDIRIM/SeaCraft`
- Dal: yalnız `main`
- Godot: `4.7.2-stable`
- PRG-01..PRG-04: **kapalı ve doğrulanmış**
- PRG-04 exact kod kapanışı: `cb179949f5a8e04c2507c20a51b17c54e034476a`
- Android gameplay smoke hotfix exact code/test SHA: `79f1367bbc91613f43f34ea696cbd4da87b45d51`
- Hotfix Actions: run `45048643091` — **success**
- Android artifact: `SeaCraft-Android-79f1367bbc91613f43f34ea696cbd4da87b45d51`, ID `14764866787`, ZIP SHA-256 `fe6dd2bda392f8905efa47a3fda7c78f2dc52a1949dd4028b931b0bbc04fdfa9`
- Linux artifact: `SeaCraft-Linux-79f1367bbc91613f43f34ea696cbd4da87b45d51`, ID `14763804453`, ZIP SHA-256 `4865d8939406357ecaf6419fc64a8508c995d6f6d1fb4e93698f02e25c357708`
- Android APK: `80776800` byte, SHA-256 `70ac769d260bc90c993a5b4f4904337587e2eb53d82266bf71cf2f5853b0dcc0`
- Kaynak sprite ZIP arşivleri exporttan çıkarıldı; APK içinde bulunmuyor.
- APK boyutunun ana bileşeni Godot debug engine: `libgodot_android.so` = `76181608` byte.
- Fiziksel Android yeni-build doğrulaması: **awaiting_retest / not_run**
- PRG-05: **active**; son doğrulanmış Android LAN hotfix exact SHA `ecda2d69ea2d79cbc40bb73bc4fcfae12dd41bdf`, CI `45440455081` success, GUT 417/417

- PRG-06: **paused** — checkpoint 1 verified, code `a45e0cc327671fd6b2fe3f141f0f6a56bedb364c`, CI `45457089855` success, GUT 420/420; physical tests not_run.

## Android smoke hotfix

İlk gerçek cihaz smoke testinde raporlanan world-touch movement, kalıcı `✓/×` core-button feedback ve gemiyle dönen NPC etiketi düzeltildi. Android touch world/UI sahipliği parmak-ID bazında ayrıldı; UI touch world command üretmez, world touch state'i UI sınırı geçişinde takılı kalmaz. Core feedback 0.75 saniyede normal etikete döner. NPC presenter etiketi ekran-yukarı tutar.

Exact SHA üzerinde full GUT ve mevcut VS/CORE/AI/NET regresyonları, Linux export, Android arm64 APK export ve iki ayrı artifact authenticated readback geçti.

## Sonraki kapı

PRG-05 production LAN host composition kod+gerçek süreç+save/replay düzeyinde doğrulandı. Son açık kapı gerçek Android dokunmatik pazar/host-join UX smoke ve uzun iki-cihaz LAN ekonomi state-drift ölçümüdür; bunlar `not_run`. CI bu fiziksel cihaz kanıtının yerine geçmez. PRG-05 fiziksel kabul için `active`; kullanıcı cihaz testini üstlendi. PRG-06 teknik plan kapısı geçildiği için ayrı başladı. Android gameplay smoke hotfix için ayrı fiziksel retest kaydı da `awaiting_retest / not_run` kalır.


## PRG-06 checkpoint 1 — 2026-11-24

- Authored sector mode (surface 0/submarine 1), validated cross-mode gates, Deep Haven and protected entry; surface FAR routing cannot cross into underwater mode. Bootstrap mobile gate button routes to anchor, dives and returns. Existing shared inventory, entity identity, world and persistence retained; predecessor manifest migration narrowly matches verified PRG-05 hash and count. LAN manifest mismatch rejected; underwater LAN host/join blocked, running room cannot transition. Placeholder submarine presentation only.
- Exact code `a45e0cc327671fd6b2fe3f141f0f6a56bedb364c`; [CI 45457089855](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45457089855) **success**, GUT **420/420**, **30,000 asserts**, `PRG06_MODE_GATE_OK`, `PRG06_SHARED_SAVE_OK`, `PRG06_LEGACY_CONTENT_OK`; NET01–04 real-process and PRG05 production save/replay passed. Manifest 25 entries, `2e2621f8506cf623ec41a93298aebbcaee94526f0cc244eb2ec86c0ab740a3a4`; Linux runtime manifest parity and Android source bytes verified. Android artifact `14951033193`, ZIP SHA-256 `d5ac2f48017f5b641bbdbfd7d0a6470805d8517b2ada8657372d1e72f6408774`; Linux artifact `14950518669`, ZIP SHA-256 `21549e8370211004243894cc76c4ed954e40db6656de104f58778ac6d9130741`; authenticated readback passed.
- **Open:** submarine tier/loadout, launcher/torpedo/breach, mode-specific gems/progression, auto-fire, actual underwater host-authoritative combat and network composition; physical Android movement/memory/touch `not_run`. ADV-01 not started.

## Sprite üretim handoff — SC-07 / radial kaynak standardı

- Son kanonik sprite rehber commit'i: `9e149b66c787ad9b126787b3a8a81b9206f1e060`.
- SC-07 · Akıntı Bıçağı 8-yön radial kaynak üretildi, yönler ayrıldı ve manuel hizalama kullanıcı JSON'u ile düzeltildi.
- Kullanıcı manuel hizalama dosyası değerleri final kabul kaynağıdır; otomatik support-anchor yalnız aday/QA'dır. Final rotation görselinde pivot oturuşu kullanıcı ayarıyla doğrulanır.
- Tarihsel final teslim paketi standardı **12 dosya** (güncel dört dosyalı atlas-only standardı için üretim rehberi §18/§24G): 8 final yön PNG + 4×2 atlas + final rotation GIF + `manifest.json` + orijinal üretim kaynağı PNG.
- Debug/extraction/normalize ara dosyaları final ZIP'e girmez.
- Orijinal radial kaynak zorunlu arşiv öğesidir.
- 8 yön tek kareden üretildiğinde kaynak yönlerin gerçek piksel yoğunluğu ayrıca kontrol edilir. Yetersizse açıkça **“AI upscale gerekli”** denir; ChatGPT/pipeline kendi başına AI upscale yapmaz. Kullanıcı kaliteli haricî upscaler ile ayrılmış 8 yönü yükseltir; upscale normalizasyon/ShowLook/final atlas öncesinde yapılır.
- GitHub kanonik manuel hizalama aracı: `tools/sprite_manual_aligner_template.html`. Yeni gemilerde ad-hoc HTML yazılmaz; gerekiyorsa bu template kullanılır ve 8 PNG bunun içine gömülür.
- Kanonik radial extractor: `tools/sprite_radial_extract.py`; yeni gemilerde ad-hoc kesim scripti yazılmaz.
- Kanonik renk hattı: `sprite_normalize.py → seacraft_showlook.py --stage v3 → final PNG/atlas`.
- SC-07 final oyun hücresi: 224×224; atlas sırası `N, NE, E, SE / S, SW, W, NW`.
- Bu sprite işi PRG-04/PRG-05 gameplay görev durumunu değiştirmez; `AKTIF_GOREV.md` kapalı PRG-04 kaydı olarak bırakıldı.


## PRG-05 kodlama checkpoint — 2026-11-23

- Exact kod SHA: `6140a383ff47b354968cf2966bec2686f5d6d28d`; [CI 45232141806](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45232141806) **success**, GUT **400/400**, PRG-05 **6/6**, NET04 gerçek süreç testleri geçti.
- Android artifact ID `14847088562`, ZIP SHA-256 `928953d72fc793210202746b3861f8ebf45642ebcf7e72a0b7779ea655e83290`; Linux artifact ID `14846294929`, ZIP SHA-256 `f338c78a43b7b226792fc22482f438ed310b2b15367109f32617d9e899c6244b`; ikisi de authenticated readback geçmiştir.
- Kod: sunucu yetkili faction/reputation, piyasa fiyat/stok, atomik al/sat, konvoy kayıp etki API'si, karakol sahipliği, tekrarlı PvP ödül azaltımı; economy save v5; runtime CombatAuthority dinamik faction/reputation hostility ve canlı safe-zone kontrollerini kullanır. Client fiyat/owner belirleyemez.
- **PRG-05 açık:** far-field/NPC convoy world event adaptörü, market içerikleri ve Android UI, bounty/intel, company/crew, uzun LAN ekonomi drift gerçek cihaz gözlemi. Sprite üretimi bağımsız; PRG-06'ya geçilmedi. Android gameplay smoke fiziksel cihaz retesti halen `not_run`.

## PRG-05 son checkpoint — 2026-11-24

**PRG-05 checkpoint 4 — 2026-11-24:** gerçek liman pazarı anchor/128 world-unit menzil, offline/LAN ortak sektör ve motor konum kanıtı, menzil dışına çıkınca panel kapanışı; NET-04 gerçek ENet süreçlerinde alım, reconnect cached replay ve uzak client reddi. Exact kod SHA `5de54a10623cf1a7aee10dd5295e859e25486667`; [CI 45348969786](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45348969786) **success**, full GUT ve regresyonlar, Android/Linux export ve authenticated artifact readback başarılı. Android artifact `14899013500`, ZIP SHA-256 `994982a114d1a5b16ec158f81baf2d4da6c19811c94f874af82863022a7dfb73`; Linux artifact `14898834070`, ZIP SHA-256 `754b17e4ba6a75dd0986ac201849890e46de432002a0450af419b4f2bc0f3d29`. Gerçek Android dokunmatik ve uzun iki cihaz LAN drift `not_run`; üretim sahnesi/host orchestration uçtan-uca cihaz kabulü açık, PRG-05 active; PRG-06 başlamadı.


**PRG-05 checkpoint 5 — 2026-11-24:** shipped offline Bootstrap bounty (80 currency), AI-04 FAR pilot supply convoy (+4 stock), market UI read-only status and authoritative trade; packed-scene combat → mid-route save/reload → delivery → real sector gates → market buy and out-of-range rejection verified. Exact code SHA `fb11a171c53a9974e5009adcf66b4dd836a69bf3`; [CI 45357962822](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45357962822) **success**, GUT **414/414**, 29,884 asserts, PRG-05 **19/19** (18 explicit verifier markers); NET04 real-process, Android/Linux export and authenticated artifact readback success. Fixed legacy full-width RNG seed derivation, empty exported registry / source-pack content manifest parity (23 entries, Android byte-exact definitions), random transaction ID invalid numeric prefix (all 16 prefixes tested). Android artifact `14903422223`, ZIP SHA-256 `ad4287d027b53ad671e54854290f13aece1ba8d7851b8fa643e8ddb360c6ff68`; Linux artifact `14903252987`, ZIP SHA-256 `817df7b595d26c0bf5a3af04b08760b6db1a90af51e72d45017dbce7eb37fb52`. Actual physical Android touch/long two-device LAN drift `not_run`; full production LAN host composition and UI device acceptance remain open; PRG-05 active, PRG-06 not started.

## PRG-05 production LAN checkpoint 6 — 2026-11-24

- Exact code SHA: `ef470b821332d85846b345d20e09c5b22f2d50ea`; [CI 45365494569](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45365494569) **success**, GUT **416/416**, **29.910 assert**.
- Shipped Bootstrap üzerinde gerçek production LAN host composition doğrulandı: Safe Haven authority, UDP discovery/manual join, authoritative remote guest movement/replication, market buy, HOST save, reload ve transaction-ledger cached replay. Verifier: `host_bootstrap=1 save_reload=1 cached_replay=1`.
- Reload testinin açığa çıkardığı non-home-sector dormant NPC AI/combat restore hataları kökten düzeltildi; dormant brain rebind ve dormant weapon-battery state shape için regresyonlar eklendi.
- Android artifact `14905973534`, ZIP SHA-256 `846a2848b8278e5a87b2ea0207c34de72c162f93ee571c32c7903c8bd1e7ef22`; Linux artifact `14907086350`, ZIP SHA-256 `f9d1c66b5aa06331c34c0983ca18a3a56378159fac2b654ac8b86e9016a48001`; authenticated readback başarılı.
- Fiziksel Android dokunmatik pazar/host-join UX ve uzun iki cihaz LAN economy drift `not_run`; bunlar tamamlanmadan PRG-05 kapanmaz ve PRG-06 başlamaz.

## PRG-05 Android LAN izin hotfix — 2026-11-24

**PRG-05 Android LAN izin hotfix — 2026-11-24:** Kullanıcının `415919e9c471` build'inde `requested` döngüsü: Android SDK <37 için gereksiz runtime gate kaldırıldı; SDK ≥37 gerçek izin grant'i, async callback + timeout/recheck, host/guest single-flight ve cancel; Android UDP broadcast receive ve `CHANGE_WIFI_MULTICAST_STATE` manifest doğrulaması eklendi. Exact code SHA `ecda2d69ea2d79cbc40bb73bc4fcfae12dd41bdf`; [CI 45440455081](https://github.com/TheOsmanYILDIRIM/SeaCraft/actions/runs/45440455081) **success**, GUT **417/417**, **29,960 asserts**, `NET04_PERMISSION_CALLBACK_OK grant=1 denied=1 false_grant=1 unrelated=1 timeout=1 broadcast=1`; NET01–04 ve PRG05 production integration, Android/Linux export ve authenticated artifact readback geçti. Android artifact `14944915113`, ZIP SHA-256 `73405fa9c09242e535b765eec5ee31bb71023d96f6faa9fd5102e47ba7b9569d`, APK SHA-256 `5ad80bd3a0feabe7b3ae8f802dc559efc8d372d83b5a129a537178e81e5bf996`; Linux artifact `14943621158`, ZIP SHA-256 `490d89cc9e0bdba3d58d1099d07c7846d0e5e03d0bf358779266b43a343914dc`. Fiziksel Android izin, host/join UX ve uzun iki-cihaz ekonomi drift retesti `not_run`; PRG-05 active; PRG-06 başlamadı.
