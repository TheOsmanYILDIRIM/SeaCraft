# SeaCraft — Session Handoff

## Güncel durum

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
- PRG-05: **active**; 400/400 CI-doğrulanmış ilk ekonomi/diplomasi dilimi (`6140a383ff47b354968cf2966bec2686f5d6d28d`)

## Android smoke hotfix

İlk gerçek cihaz smoke testinde raporlanan world-touch movement, kalıcı `✓/×` core-button feedback ve gemiyle dönen NPC etiketi düzeltildi. Android touch world/UI sahipliği parmak-ID bazında ayrıldı; UI touch world command üretmez, world touch state'i UI sınırı geçişinde takılı kalmaz. Core feedback 0.75 saniyede normal etikete döner. NPC presenter etiketi ekran-yukarı tutar.

Exact SHA üzerinde full GUT ve mevcut VS/CORE/AI/NET regresyonları, Linux export, Android arm64 APK export ve iki ayrı artifact authenticated readback geçti.

## Sonraki kapı

Yeni Android artifact fiziksel telefona kurulup hareket/buton/etiket smoke testi tekrar yapılmalıdır. Bu cihaz kanıtı tamamlanana kadar yalnız cihaz sonucu `awaiting_retest / not_run` kalır. PRG-05 kanonik Beyin görevi `tasks/seacraft-prg05-faction-economy-trade-20261123.md` resmî motorla açıldı; dünya olayı entegrasyonu, company/crew ve gerçek Android LAN ekonomi drift ölçümü açık. PRG-06 başlamadı.


## Sprite üretim handoff — SC-07 / radial kaynak standardı

- Son kanonik sprite rehber commit'i: `9e149b66c787ad9b126787b3a8a81b9206f1e060`.
- SC-07 · Akıntı Bıçağı 8-yön radial kaynak üretildi, yönler ayrıldı ve manuel hizalama kullanıcı JSON'u ile düzeltildi.
- Kullanıcı manuel hizalama dosyası değerleri final kabul kaynağıdır; otomatik support-anchor yalnız aday/QA'dır. Final rotation görselinde pivot oturuşu kullanıcı ayarıyla doğrulanır.
- Final teslim paketi standardı artık **12 dosya**: 8 final yön PNG + 4×2 atlas + final rotation GIF + `manifest.json` + orijinal üretim kaynağı PNG.
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
