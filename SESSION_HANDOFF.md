# SeaCraft — Session Handoff

## Güncel durum

- Repo: `TheOsmanYILDIRIM/SeaCraft`
- Dal: yalnız `main`
- Godot: `4.7.2-stable`
- PRG-01: **kapalı ve doğrulanmış**
- PRG-02: **kapalı ve doğrulanmış**
- PRG-02 exact kod SHA: `d6ddfb014ee83ef9826563441453152d15d7d789`
- PRG-02 Actions: run `45019833696` — `success`
- PRG-02 artifact: `SeaCraft-PRG02-d6ddfb014ee83ef9826563441453152d15d7d789`, ID `14753292824`
- PRG-02 Avenox Beyin: `done`, revision `2`
- Aktif görev: **PRG-03 — XP, Skill Tree, Rank ve Local Challenge Meta**
- PRG-03 uygulama başlangıç HEAD'i: `c1dd69644e7dc77ece909eb62c1cfb1691730eb4`
- PRG-03 Avenox task: `tasks/seacraft-prg03-xp-skill-tree-rank-local-challenge-meta-20261122.md`
- PRG-04: **blocked / not_started**

Ayrıntılı geçmiş ve PRG-02 kanıtı `GOREV_RAPORU.md` içindedir.

## Aktif görev

`AKTIF_GOREV.md` PRG-03 kanonik briefidir.

Sohbet etiketi:

`[SOHBET-34 | SeaCraft PRG-03 — XP, Skill Tree, Rank ve Local Challenge Meta]`

Ana kapı:

**Progression ledger ve gate API sabitlenmeden PRG-04 başlamaz.**

## Teknik başlangıç

- PRG-01 `InventoryState` ve atomik transaction modeli korunur.
- PRG-02 upgrade/core/trophy progression altyapısı korunur.
- XP eventleri idempotent ledger üzerinden authoritative uygulanır.
- Level/rank deterministic threshold modelidir; drift yaratan ikinci truth kurulmaz.
- Skill tree cycle-free stable-ID DAG olur; spend/respec atomik ve rollback'li.
- License/test gate API gelecekte PRG-04 quest sisteminin tüketebileceği primitive-safe contract olarak kurulur.
- Local challenge/milestone internet gerektirmez; reward idempotent ve save/load uyumlu olur.
- Stat etkileri yalnız mevcut `StatModifierPipeline`.
- LAN mutasyonları host-authoritative; client XP/skill/reward outcome seçemez.

## Teslim kapısı

PRG-03 çalışma sohbeti:

- görevi uygular,
- tüm ilgili test/regresyonları geçirir,
- failure varsa kök nedeni düzeltip exact commit üzerinde yeniden doğrular,
- Linux ve Android exportu üretip doğrular,
- `SeaCraft-PRG03-<exact SHA>` artifact + authenticated hash/readback doğrular,
- fiziksel Android yapılmadıysa `not_run`,
- mevcut Beyin PRG-03 taskını strict kapatır,
- `GOREV_RAPORU.md` içine tek PRG-03 kapanış bölümü yazar,
- `AKTIF_GOREV.md` ve bu handoff'u kapanışa günceller.

PRG-04 yalnız bu teslim GitHub'dan doğrulandıktan sonra hazırlanır.

## Kısa çalışma sohbeti komutu

`TheOsmanYILDIRIM/SeaCraft/main üzerindeki güncel HEAD, AKTIF_GOREV.md ve SESSION_HANDOFF.md dosyalarını oku. SOHBET-34 / PRG-03 görevini kanonik brief'e göre baştan sona uygula; yalnız PRG-03 kapsamını değiştir, hataları düzeltip exact-commit CI/export/artifact/Beyin/GOREV_RAPORU kapanışına kadar doğrula. PRG-04'e başlama.`
