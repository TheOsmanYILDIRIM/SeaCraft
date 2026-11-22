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
- PRG-05: **not_started**

## Android smoke hotfix

İlk gerçek cihaz smoke testinde raporlanan world-touch movement, kalıcı `✓/×` core-button feedback ve gemiyle dönen NPC etiketi düzeltildi. Android touch world/UI sahipliği parmak-ID bazında ayrıldı; UI touch world command üretmez, world touch state'i UI sınırı geçişinde takılı kalmaz. Core feedback 0.75 saniyede normal etikete döner. NPC presenter etiketi ekran-yukarı tutar.

Exact SHA üzerinde full GUT ve mevcut VS/CORE/AI/NET regresyonları, Linux export, Android arm64 APK export ve iki ayrı artifact authenticated readback geçti.

## Sonraki kapı

Yeni Android artifact fiziksel telefona kurulup hareket/buton/etiket smoke testi tekrar yapılmalıdır. Bu cihaz kanıtı tamamlanana kadar yalnız cihaz sonucu `awaiting_retest / not_run` kalır. PRG-05 ayrı kanonik görev açılmadan başlatılmaz.
