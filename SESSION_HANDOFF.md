# SeaCraft — Session Handoff

## Güncel durum

- Repo: `TheOsmanYILDIRIM/SeaCraft`
- Dal: yalnız `main`
- Godot: `4.7.2-stable`
- NET-04: **kapalı ve doğrulanmış**
- NET-04 exact kod SHA: `ba5fd180b9e359b0dcc146b58c52254fe537f317`
- NET-04 Actions: run `45007820093` / #196 — `success`
- NET-04 artifact: `SeaCraft-NET04-ba5fd180b9e359b0dcc146b58c52254fe537f317`, ID `14748254309`
- Plan ilerlemesi NET-04 kapanışında: **22/35**
- Aktif görev: **PRG-01**
- PRG-02: **blocked / not_started**

Ayrıntılı geçmiş ve NET-04 kanıtı `GOREV_RAPORU.md` içindedir. Bu dosya yalnız güncel çalışma devrini taşır; geçmiş raporu çoğaltmaz.

## Aktif görev

`AKTIF_GOREV.md` artık PRG-01 kanonik briefidir.

Sohbet etiketi:

`[SOHBET-32 | SeaCraft PRG-01 — Inventory, Equipment, Crew, Pet/Companion ve Preset]`

Avenox Beyin kanonik task:

`tasks/seacraft-prg01-inventory-equipment-crew-pet-preset-20261122.md`

PRG-01'in ana kapısı:

**Inventory truth tek authoritative kaynak olmadan PRG-02 başlamaz.**

## Başlangıç protokolü

Yeni çalışma sohbeti önce:

1. güncel `main` HEAD'i,
2. `AKTIF_GOREV.md`,
3. `GELISTIRME_GOREV_PLANI.md`,
4. `GOREV_RAPORU.md`,
5. bu `SESSION_HANDOFF.md`,
6. `README.md`

dosyalarını doğrular.

Başka sohbetin değişikliğini ezmez. HEAD değişmişse güncel diff ve görev kaydını okuyup yalnız kendi PRG-01 kapsamını uygular.

## Mevcut teknik başlangıç

- VS-03/CORE loot akışında `LootAuthority` item miktarını kendi `_inventory: Dictionary` alanında tutuyor.
- PRG-01 bu miktar gerçeğini yeni authoritative `InventoryState` içine taşımalı; LootAuthority drop/claimed/processed-event sorumluluğunu koruyabilir fakat ikinci inventory truth bırakmamalı.
- FND-02 `ItemDefinition`, stable-ID `DefinitionRegistry` ve tek `StatModifierPipeline` sözleşmeleri korunur.
- NET-04 transaction ID / duplicate retry / lost-ACK idempotency modeli equip, transfer, gem/socket ve preset host mutations için reuse/extend edilir.
- GLoot varsayılan değildir; yalnız grid/weight/multi-container ihtiyacı gerçekten kanıtlanırsa değerlendirilir.
- Forumdaki 767 kayıt şema/çeşitlilik referansıdır; exact isim/değer/görsel production içeriğine doğrudan taşınmaz.

## Teslim kapısı

PRG-01 çalışma sohbeti:

- görevi uygular,
- ilgili tüm test/regresyonları geçirir,
- failure varsa kök nedeni düzeltip exact commit üzerinde yeniden doğrular,
- Linux ve Android exportu üretip doğrular,
- `SeaCraft-PRG01-<exact SHA>` artifact'ini ve hash/readback'i doğrular,
- fiziksel Android cihaz yapılmadıysa `not_run` bırakır,
- mevcut Beyin PRG-01 taskını duplicate yaratmadan strict kapatır,
- `GOREV_RAPORU.md` içine tek PRG-01 kapanış bölümü yazar ve geri okur,
- bu handoff'u PRG-01 kapanışı / PRG-02 kapısına günceller.

PRG-02 yalnız bu teslim GitHub'dan doğrulandıktan sonra hazırlanır.

## Kısa çalışma sohbeti komutu

`TheOsmanYILDIRIM/SeaCraft/main üzerindeki güncel HEAD, AKTIF_GOREV.md ve SESSION_HANDOFF.md dosyalarını oku. SOHBET-32 / PRG-01 görevini kanonik brief'e göre baştan sona uygula; yalnız PRG-01 kapsamını değiştir, hataları düzeltip exact-commit CI/export/artifact/Beyin/GOREV_RAPORU kapanışına kadar doğrula. PRG-02'ye başlama.`
