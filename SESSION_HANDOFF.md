# SeaCraft — Session Handoff

## Güncel durum

- Repo: `TheOsmanYILDIRIM/SeaCraft`
- Dal: yalnız `main`
- Godot: `4.7.2-stable`
- PRG-01: **kapalı ve doğrulanmış**
- PRG-02: **kapalı ve doğrulanmış**
- PRG-03: **kapalı ve doğrulanmış**
- PRG-03 exact kod SHA: `2d8e32e6ff84ca3a8e4b23aa0e52073dc333b584`
- PRG-03 Actions: run `45034255905` — `success`
- PRG-03 artifact: `SeaCraft-PRG03-2d8e32e6ff84ca3a8e4b23aa0e52073dc333b584`, ID `14759425694`
- PRG-03 Avenox Beyin: `done`, revision `2`
- Aktif görev: **PRG-04 — Quest, Journal ve NPC Interaction**
- PRG-04 uygulama başlangıç HEAD'i: `9f016ef7be3b9d4c09365d6fcace3a61cc573958`
- PRG-04 Avenox task: `tasks/seacraft-prg04-quest-journal-npc-interaction-20261122.md`
- PRG-05: **blocked / not_started**

Ayrıntılı geçmiş ve PRG-03 kanıtı `GOREV_RAPORU.md` içindedir.

## Aktif görev

`AKTIF_GOREV.md` PRG-04 kanonik briefidir.

Sohbet etiketi:

`[SOHBET-35 | SeaCraft PRG-04 — Quest, Journal ve NPC Interaction]`

Ana kapı:

**Quest/reward ledger stabil olmadan PRG-05 başlamaz.**

## Teknik başlangıç

- PRG-03 gate API ve XP ledger korunur.
- QuestDefinition/QuestInstance stable-ID ve primitive-safe modeldir.
- Objective event bus kill/damage/capture/collect/acquire/timed yanında escort/salvage/trade adapterlarını destekler.
- Quest-chain ve region/map constraints authority tarafında doğrulanır.
- Reward ledger inventory/XP/gate sistemlerini yeniden kullanır; ikinci reward truth kurulmaz.
- NPC interaction authority host/offline owner'dadır; client yalnız intent üretir.
- Journal detached view modeldir, authoritative state değildir.
- Dialogue Manager 4 varsayılan olarak eklenmez; yalnız gerçekten gerekli dallı yazarlık karmaşıklığı kanıtlanırsa değerlendirilir.
- LAN completion/reward host-authoritative, spoof/replay/lost-ACK korumaları korunur.

## Teslim kapısı

PRG-04 çalışma sohbeti:

- görevi uygular,
- objective type matrisi ve tüm ilgili regresyonları geçirir,
- failure varsa kök nedeni düzeltip exact commit üzerinde yeniden doğrular,
- Linux ve Android exportu üretip doğrular,
- `SeaCraft-PRG04-<exact SHA>` artifact + authenticated hash/readback doğrular,
- fiziksel Android yapılmadıysa `not_run`,
- mevcut Beyin PRG-04 taskını strict kapatır,
- `GOREV_RAPORU.md` içine tek PRG-04 kapanış bölümü yazar,
- `AKTIF_GOREV.md` ve bu handoff'u kapanışa günceller.

PRG-05 yalnız bu teslim GitHub'dan doğrulandıktan sonra hazırlanır.

## Kısa çalışma sohbeti komutu

`TheOsmanYILDIRIM/SeaCraft/main üzerindeki güncel HEAD, AKTIF_GOREV.md ve SESSION_HANDOFF.md dosyalarını oku. SOHBET-35 / PRG-04 görevini kanonik brief'e göre baştan sona uygula; yalnız PRG-04 kapsamını değiştir, hataları düzeltip exact-commit CI/export/artifact/Beyin/GOREV_RAPORU kapanışına kadar doğrula. PRG-05'e başlama.`
