# SeaCraft — Session Handoff

## Güncel durum

- Repo: `TheOsmanYILDIRIM/SeaCraft`
- Dal: yalnız `main`
- Godot: `4.7.2-stable`
- PRG-01: **kapalı ve doğrulanmış**
- PRG-01 exact kod SHA: `a3344909e489adc93800f6591238eb7102561542`
- PRG-01 Actions: run `45015026436` — `success`
- PRG-01 artifact: `SeaCraft-PRG01-a3344909e489adc93800f6591238eb7102561542`, ID `14750439866`
- PRG-01 Avenox Beyin task: `done`, revision `2`
- Aktif görev: **PRG-02 — Crafting, Reclamation, Ship Upgrade ve Cores/Trophies**
- PRG-02 uygulama başlangıç HEAD'i: `160e159a69182cdd4cac6d65a3d3d345de02ec5f`
- PRG-02 Avenox task: `tasks/seacraft-prg02-crafting-reclamation-ship-upgrade-cores-trophies-20261122.md`
- PRG-03: **blocked / not_started**

Ayrıntılı geçmiş ve PRG-01 kanıtı `GOREV_RAPORU.md` içindedir. Bu dosya yalnız güncel çalışma devrini taşır.

## Aktif görev

`AKTIF_GOREV.md` PRG-02 kanonik briefidir.

Sohbet etiketi:

`[SOHBET-33 | SeaCraft PRG-02 — Crafting, Reclamation, Ship Upgrade ve Cores/Trophies]`

Ana kapı:

**Craft atomikliği, deterministic salvage RNG ve cycle-free upgrade graph doğrulanmadan PRG-03 başlamaz.**

## Teknik başlangıç

- PRG-01 `InventoryState` tek authoritative item/build truth olarak korunur.
- Craft ve salvage source consume + output grant işlemleri aynı transaction modelini kullanır.
- PRG-01 duplicate transaction / conflict / lost-ACK idempotency modeli reuse edilir.
- `RecipeDefinition`, `SalvageTable`, ship upgrade DAG, core slotları ve trophy/perk unlock ledger veri odaklı stable-ID sözleşmesiyle eklenir.
- Salvage mevcut kanonik RNG altyapısını kullanır; reject ve duplicate retry ikinci RNG tüketimi üretmez.
- Upgrade ve core/trophy kaynaklı stat etkileri yalnız mevcut `StatModifierPipeline` üzerinden uygulanır.
- LAN'da bütün PRG-02 mutasyonları host-authoritative kalır; client sonucu/RNG/reward seçemez.
- Forumdaki 767 kayıt yalnız şema/çeşitlilik referansıdır; exact isim/değer/görsel production içeriğine doğrudan taşınmaz.

## Teslim kapısı

PRG-02 çalışma sohbeti:

- görevi uygular,
- ilgili tüm test/regresyonları geçirir,
- failure varsa kök nedeni düzeltip exact commit üzerinde yeniden doğrular,
- Linux ve Android exportu üretip doğrular,
- `SeaCraft-PRG02-<exact SHA>` artifact'ini ve authenticated hash/readback'i doğrular,
- fiziksel Android cihaz yapılmadıysa `not_run` bırakır,
- mevcut Beyin PRG-02 taskını duplicate yaratmadan strict kapatır,
- `GOREV_RAPORU.md` içine tek PRG-02 kapanış bölümü yazar ve geri okur,
- `AKTIF_GOREV.md` ve bu handoff'u kapanış durumuna günceller.

PRG-03 yalnız bu teslim GitHub'dan doğrulandıktan sonra hazırlanır.

## Kısa çalışma sohbeti komutu

`TheOsmanYILDIRIM/SeaCraft/main üzerindeki güncel HEAD, AKTIF_GOREV.md ve SESSION_HANDOFF.md dosyalarını oku. SOHBET-33 / PRG-02 görevini kanonik brief'e göre baştan sona uygula; yalnız PRG-02 kapsamını değiştir, hataları düzeltip exact-commit CI/export/artifact/Beyin/GOREV_RAPORU kapanışına kadar doğrula. PRG-03'e başlama.`
