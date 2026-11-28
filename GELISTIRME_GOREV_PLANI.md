# SeaCraft — Oynanış Öncelikli Geliştirme Planı

**2026-11-28 — Mobil/offline/LAN ilk oynanabilir sürüm ve paralel geliştirme revizyonu.** Bu üst bölüm, 2026-11-24 PLAY-01…10 seri yürütme sırasını ve tek aktif geliştirme kısıtını geçersiz kılar. PLAY kimlikleri tarihsel kanıtlarla bağlantı için korunur; mevcut kod, test, save/network sözleşmesi ve onaylanmış asset kaynakları silinmez. Bu revizyon planlamadır, yeni runtime kodu veya cihaz kabulü değildir.

## 1. Ürün kapsamı ve temel eğlence

SeaFight araştırması yalnız esin/katalog kaynağıdır. SeaCraft mobil öncelikli, offline-first ve isteğe bağlı host-authoritative LAN denizcilik sandbox RPG'sidir; MMO değildir. İlk hedef: küçük fakat gerçek oynanabilir yüzey dünyasında 30–60 dakikalık tekrar edilebilir oyun; ilk 15 dakikada hareket → savaş/av → loot → liman → satın alma/onarım → yeniden açılma. Miktarlar ve süreler ilk denge hipotezidir, ölçüme göre ayarlanır. Görevler dünyayı destekler, bütün oynanışı yönetmez.

- Koru: seyir/harita, top ve zıpkın savaşı, ganimet/batık, liman/tamir, gemi alımı, NPC ticaret/av/devriye, basit görev ve LAN. NPC filosu/formasyon kapasitesini kaldırma.
- Gelişim gemi çeşitliliği merkezli: farklı gemi gövdeleri ve stat profilleri; mevcut top, mühimmat ve basit ekipman sistemi. Her gemiye ayrı görsel modüler gövde/yelken/mürettebat üretimi veya çok katmanlı upgrade ağacı zorunlu değil.
- Sadeleştir: M-007/008/009/010/016–019/021–026/029/030/032/033/038/055/059/060; mevcut işleyen authority korunur. Tek para birimi; az ekipman/mühimmat; açık etkiler; tehlike derecesi, zorunlu seviye/grind kapısı değil; basit ticaret, faction/itibar yalnız ilk oynanışa hizmet ettiği ölçüde. Crew, crafting, skill/rank, gem/core/castle/trophy katmanlarının hangisinin ilk ekrana gerçekten çıkacağı ilk görevde netleştirilir; hepsini tamamlamak ilk sürüm önkoşulu değildir.
- İlk sürümden çıkar: M-020 pet/trainer, M-011 ayrı Voodoo kalkanı (hull korunur), M-034/035/036/054 PvP puanı kasma, MMO guild/lig, günlük giriş/sezon/sıralama ve canlı servis ekonomisi. LAN co-op korunur; PvP ileride isteğe bağlı olabilir. MMO guild'i çıkarmak sandbox AI filosunu çıkarmak anlamına gelmez.
- Ertele: boarding/ele geçirme M-015, outpost hakimiyeti M-037'nin dinamik genişlemesi, PRG-06 denizaltı/torpido M-049–051, büyük boss/raid haritaları, karmaşık element/weather/action item ve paralel progression. Geçici korsan raid karşılaşması aşağıdaki dar kapsamda ilk sürümdedir.

### Birbirinden bağımsız üç dünya popülasyonu

| Sistem | Yaşam döngüsü ve sahiplik | İlk sürüm |
|---|---|---|
| Normal NPC | Rol/archetype tabanlı yerel popülasyon: tüccar, korsan, devriye, savaş gemisi; canavar ayrı davranış profili. Mevcut NPC/monster authority, spawn, AI ve loot kuralları. | Evet: görünür devriye, tehdit, takip, ateş, kaçış, tamir, canavar avı. |
| Raid / geçici hedef ve görev | Bağımsız encounter sahibi ve lifecycle: tetiklenme → geçici 2–4 gemilik korsan grubu (öneri, dengeyle değişir) → görev bildirimi/izleme → zafer/başarısızlık/sona erme → ödül/temizlik. Lider ve grup koordinasyonu; tekrar oluşabilir. Kalıcı oyuncu kimliği, kişisel ekonomi, bölge hakimiyeti veya sanal oyuncu gelişimi yok. | Evet: küçük açık deniz raid'i; büyük instanced raid/boss sistemi gerektirmez. |
| Sanal oyuncu NPC (simulated player) | Ayrı, kalıcı sandbox population ve karar/gelişim sahibi. Oyuncu gibi gelir/harcama, loot, gemi satın alma, tamir, av, ticaret, ittifak, kalıcı filolar ve dinamik bölge hakimiyeti. Normal NPC'nin upgrade'i veya raid'in kalıcı sürümü değildir. | Hayır; sonraki bağımsız genişleme. |

Üç sistem aynı ShipMotor, CombatAuthority, LootAuthority, inventory, market/transaction, stable ID, save ve host-authority servislerini tüketebilir; ancak spawn registry/kimlik kapsamı, yaşam döngüsü, karar ve progression state'i birbirine dönüştürülmez. İlk sürümde sanal oyuncu altyapısının uygulanması, placeholder sanal oyuncu veya geleceğe dönük ayrı economy engine zorunlu değil. Yeni API'ler tek bir NPC türünü varsaymamalı; mevcut AI LOD/filo altyapısı korunur. Daha sonra yakın tam simülasyon, uzak seyrek/istatistiksel olaylar, oyun kapalıyken durma yaklaşımıyla sandbox eklenir. Mevcut faction kontrolü ilk sürümde sabit veri olabilir.

## 2. İlk görev — PLAY-00: sistem + içerik + UI sözleşmesini kesinleştir

**İlk yapılacak iş budur.** Önce ekranların hangi sistemlere bağlanacağını belirle; bütün backend kodunun bitmesini bekleme. README, MEKANIK_KATALOGU, ICERIK_KATALOGU, güncel kod/definition/fixture/asset ve mevcut UI panellerini karşılaştır. Her satır için mevcut/eksik/sadeleştir/askıda durumu ve gerçek kod yolu, ekran sözleşmesi, mevcut authoritative işlem, gereken ek işlem ve içerik ID'leri belirle. Hazır sistemi tekrar kodlama. Tasarım kararı ile doğrulanmış runtime durumunu ayır.

Aşağıdaki ekran envanteri ilk tasarım girdisidir; nihai ekran/alan/aksiyon seçimleri PLAY-00'da sabitlenir. Sayısal fiyat, slot ve stat dengesi sonradan içerik verisiyle ayarlanır.

| Ekran / panel | Gösterilecek veri | Oyuncu aksiyonu / servis |
|---|---|---|
| Ana menü / save | Yeni oyun, kayıt, son konum, offline/LAN | Yeni/Devam, Host/Katıl, ayarlar; Save/NET |
| Deniz HUD | Hull, seçili hedef hull/tür, aktif top ve mühimmat, reload, menzil/borda, para, görev özeti | Hareket, dur, merkezle, hedef seç, ateş/zıpkın, gerekirse otomatik ateş, etkileşim; ShipMotor/CombatAuthority |
| Harita | Bölge/tehlike, liman, rota, aktif olay, oyuncu konumu, sabit faction etiketi | Pan/zoom, hedef/rota, bölge geçişi; SectorGraph |
| Liman hub | Güvenli alan, servisler, bakiye, gemi durumu | Gemi pazarı, donanım, mühimmat, ticaret, tamir, görev; mevcut NPC/market authority |
| Gemi satın alma | Hazır gemi görseli, isim, fiyat, hull, hız, manevra, top/ekipman kapasitesi, sahiplik, karşılaştırma | Satın al, sahip olunan gemiyi seç; bakiye/liman/kapasite/aktif gemi kontrolü. Gemi değiştirme ve ekipman aktarımı kuralını kesinleştir. |
| Gemi / donanım | Aktif gemi, top slotları/kapasite, takılı silah, menzil/reload/hasar, sade ekipman | Tak/çıkar/değiştir, stat farkı; Inventory/Loadout/StatModifierPipeline |
| Top pazarı | Top tipi, fiyat, menzil, hasar, reload, uyum, stok | Adet, satın al; satma mevcut kurallarla; market/inventory |
| Mühimmat / zıpkın | Tür, adet, fiyat, etkisi, uyum, takılı tür, stok | Satın al/adet, aktif tür seç; market/combat stock. Mühimmatsız durumda kilitlenmeyi önleyen başlangıç kuralı. |
| Ticaret | Mal türü, mevcut stok, fiyat, sahip olunan adet, toplam | Al/sat, adet seç, bakiye/menzil/stock kontrolü; PRG-05 market authority |
| Envanter / loot | Eşya kategorisi, miktar, değer, son ganimet, varsa kapasite | Ganimet al, kullan/sat/tak; tek inventory truth |
| Tamir | Mevcut/maksimum hull, maliyet ve beklenen sonuç | Onar, yetersiz bakiye bildirimi; CombatAuthority/market |
| Görev / raid | Aktif/hedef/tamamlanmış görev, konum, grup kalan gemi sayısı, ödül, süre varsa | Kabul/izle/teslim veya otomatik tamamlanma kuralı; QuestAuthority + bağımsız raid lifecycle |
| LAN / duraklat / ayar | Oda, oyuncular, bağlantı, kaydın sahibi, ses ve kontrol, yeniden bağlantı durumu | Host, katıl/IP, çık, reconnect; offline pause ve checkpoint, LAN pause yerine yerel menü |

PLAY-00 teslimi: ekran akış haritası (ana menü → deniz → liman → pazar/donanım/görev; geri dönüşler); mobil landscape wireframe'ler; her ekran için view-model alanları, stable ID, komut payload/sonuç/hata kodları ve authority sahibi; başlangıç gemi/top/mühimmat/mal fiyat/istatistik veri matrisi; gerekli ikon/sprite/VFX/ses listesi; mock fixture (gerçekçi boş/dolu/başarılı/başarısız durumlar) ve UI/backend entegrasyon kabulü. Satın alma ve satma atomik, tekrarlı istek idempotent; UI bakiye veya hasar gerçeği yaratmaz. Ekranlarda loading, empty, disabled, insufficient funds/stock, out-of-range, incompatible, disconnect/retry ve save error durumları tasarlanır. Gereksiz ekranlar birleştirilir; 48dp civarı dokunma hedefi, landscape safe area, küçük ekran ve fontScale 1.3, touch capture ve savaş sırasında minimal HUD. Sürükle-bırak zorunlu değil.

**Çıkış kapısı:** ekran kapsamı, navigasyon, veri/komut sözleşmesi ve fixture'lar kullanıcı tasarım kabulüne hazır; UI uygulaması gerçek backend'i beklemeden başlayabilir. Eksik işlem yalnız ilgili backend iş paketine atanır. Bu görev ilk sürümün kapsamını dondurur, yeni özellik listesi büyütmez.

### PLAY-00 teslimi — UI/işlem sözleşmesi v1, 2026-11-28

**Durum: tasarım hazır, kullanıcı kabulü bekliyor.** Kaynak incelemesi main `a2a3cb2d82a2b290459bd90fec146173f1535bd8` üzerinde yapıldı. Aşağıdaki kararlar ilk prototip için önerilen bağlayıcı tasarım adaylarıdır; fiyat/stat rakamları denge verisidir, çalışan kod değildir. Yeni runtime implementasyonu/test yapılmadı.

#### A. Ürün kararları ve ekran hiyerarşisi

- Oyuncu bir aktif gemiyi kontrol eder. Satın aldığı gemiler tersanede saklanan sahiplik listesine eklenir; limanda diğer gemiye geçebilir. İlk sürümde aynı gemi türünden bir tane; gemi satışı/filo yönetimi yok. Gemi çeşitliliği esas, ayrı gövde/yelken/crew görsel montajı yok. Gemi değiştirme sırasında eski hull durumu ve gemi donanımı saklanır; yeni satın alınan gemi tam hull. Mühimmat ve ticaret malları oyuncu envanterinde ortak; donanım gemiye bağlı; geçişte mükerrer item yaratılmaz. Hasarlı gemiyi değiştirerek bedava iyileştirme yok.
- Top donanımı: her geminin top kapasitesi ve bir top bataryası tipi; aynı tipten takılı top adedi kapasiteye kadar. Tek reload, tek hedef, tek salvo; tek tek top mikro yönetimi yok. Limanda tak/çıkar; hasar = authoritative batarya hesabı, tek gülle hasarı ve salvo önizlemesi ayrı etiketlenir. Tek tip batarya kuralı ilk sürüm tercihi; karışık top dizilimi sonraya. Mevcut silah/slot kodu bunu henüz sağlamıyor. İlk sürümde ek olarak zıpkın ve en fazla bir basit pasif donanım; crew, pet, gem, core, castle, trophy, skill ekranları gizli. Çalışan kayıtlar/mekanikler silinmez.
- Mühimmat: normal gülle + pahalı güçlendirilmiş gülle, zıpkın stoğu ayrı. Ücretsiz/düşük etkili acil normal atış veya limanda ücretsiz asgari stok önerisi; **ilk tercih limanda yalnız minimum 10 normal gülle ve 5 zıpkına tamamlayan başlangıç yardımını** uygulamaktır. Ticari değeri/loot exploit yaratmayacak kural authority'de doğrulanır (yardım stoğu satılamaz veya ayrı izlenir). Normal ve güçlendirilmiş mühimmat seçimi savaşta yapılabilir; cooldown sıfırlanmaz. İlk sürümde element matrisi menüsü yok.
- Tek para: altın; loot malzemesi para değildir. Liman pazarında alış/satış fiyatı, stok, miktar ve toplam; sabit temel fiyat + mevcut PRG05 fiyat hesaplaması. Mal taşıma için sade adet/kapasite; zorunlu ağırlık hesaplama menüsü yok. Üretim/skill ağaçları sonraya.
- Batma: gemi sahipliği ve donanım kaybolmaz; güvenli limanda düşük hull ile tekrar doğuş, kurtarma/temel tamir ile tekrar savaşa girebilir. İlk tercih ganimetin yalnız batıştan beri bankalanmamış ticaret malı kısmını kaybetmek değil, **sabit sınırlı tamir maliyeti ve son sefer ganimetinin korunması**; para yetersizse asgari ücretsiz tamir. Bu seçim ilk testte ayarlanır. Offline pause simülasyonu durdurur; LAN menü simülasyonu durdurmaz.
- Normal NPC ve geçici raid birbirinden ayrı; sanal oyuncu NPC, kalıcı filo ve dinamik bölge sahibi UI'sı hiç yapılmaz. İlk mini raid: açık deniz olay bildirimi, haritada konum, 2–4 üye, ödül, sonlanma. Otomatik görev oluşumu ve katkı gösterimi, normal liman görevinden ayrı sekme. Raid'in kendisi tek encounter sahibi; görev görünümü ayrı authority sonucu tüketir, ikinci loot üretmez.

**Navigasyon:** Ana menü → kayıt/yeni oyun → deniz HUD. HUD'dan Harita, Envanter, Görevler, Duraklat. Liman menziline girince Liman düğmesi → Tersane / Donanım / Cephane / Ticaret / Tamir / Kontratlar. Bu ekranlar aynı liman modal kabuğunda sekmeler; ayrı ana menü sayfaları değil. Harita ve journal denizde erişilir. Gemi satın alımı ve ekipman yalnız limanda; savaşta yalnız hedef, hareket, silah ve mühimmat. LAN ekranı ana menü ve duraklat menüsünde aynı bileşen. Geri düğmesi önce modalı, sonra pause'u kapatır; Android sistem geri düğmesi aynı yolu izler.

#### B. Mobil wireframe sözleşmesi (1280×720 logical landscape)

Safe rect içindeki oranlar başlangıç yerleşimidir; fontScale 1.3 ve küçük ekranlarda yatay taşma yok. 48 logical birim minimum hedef, gerektiğinde gerçek dp ile doğrula. Tema: koyu denizci/eskimiş metal, kontrollü altın, okunur metin ve ikon; dekorasyon dokunma alanını küçültmez. Önce düşük detay prototip, sonra ortak art direction. Renk tek başına state anlatmaz.

```text
DENİZ HUD
┌ Hull / aktif gemi ─────────────────── Bölge / harita / menü ┐
│ görev / raid bildirimi                                    │
│                                                           │
│                 OYUN DÜNYASI                              │
│                 seçili hedef halkası                      │
│                                                           │
│ dur / merkezle       hedef hull + menzil      top / zıpkın  │
│ çanta / görev          seçili mühimmat      ateş + reload  │
└─────────────────── safe area ─────────────────────────────┘

LİMAN (bütün mağazalar için tek kabuk)
┌ geri | liman adı | altın | gemi hull ──────────── kapat ┐
│ Tersane | Donanım | Cephane | Ticaret | Tamir | Kontrat  │
│ ┌ Liste / grid (scroll) ┐ ┌ Seçilen ürün/gemi ───────┐ │
│ │ görsel, ad, fiyat     │ │ görsel + statlar         │ │
│ │ sahip / stok         │ │ mevcut → yeni farkı      │ │
│ │ …                    │ │ adet − [1] + / toplam    │ │
│ └──────────────────────┘ │ [SATIN AL] [SAT/TAK]      │ │
│                          └ feedback / hata ──────────┘ │
└───────────────────────────────────────────────────────┘

HARİTA / GÖREV / ENVANTER
┌ geri | ekran başlığı ─────────────────────── kapat ┐
│ harita veya filtre/listesi │ detay / hedef / ödül   │
│                            │ [İZLE / ROTA / KULLAN]  │
└────────────────────────────────────────────────────┘
```

HUD üzerinde sol üstte oyuncu hull, üst sağda menü/minimap; alt sağda en büyük Ateş düğmesi, yanındaki zıpkın hedef uygunsa etkin. Top/zıpkın seçili hedefe göre bağlamsal tek ana butonda birleştirilebilir; yanlış hedef seçilince neden göster. Reload progress ve sayı; ateş sonucu kısa toast/floating number, ekranı kaplayan popup yok. Hedef halkası boyut/zoom uyumlu, UI paneli tap'i world input'a geçirmez. HUD küçük gemi üzerinde kocaman metin etiketleri bırakmaz. Harita: mevcut sektör zoom/pan, komşu sektör grafiği, liman ve raid marker; rota düğmesi gerçek navigation isteği, teleport değil. Envanter 3 filtre: donanım, cephane, ticaret/loot; satma yalnız limanda. Görev journal: normal kontratlar + dinamik raid; seçilen tek tracked objective HUD'da, haritada konum. Tersane karşılaştırması aynı stat birimleri, fark ve satın alma maliyeti; satır seçmek satın almaz. Pahalı gemi alımı ve gemi değiştirme tek onay dialogu; sık kullanılan cephane/loot işlemleri için her defasında modal onay yok.

#### C. Koddan doğrulanmış sistem/işlem envanteri

| Alan | Gerçek kaynak ve mevcut sözleşme | İlk sürüm boşluğu / sorumlu |
|---|---|---|
| Gemi | src/data/definitions/ship_definition.gd: display_name, visual_profile_id, faction_id, weapon_ids, base_hull_hp; iki kayıt ship.foundation_player / ship.vs02_practice. src/data/movement/ship_placeholder_profile.tres tek hareket profili. | PLAY-05/06: altı gerçek hull definition + hareket profile ref + fiyat/kapasite/ownership/aktif gemi; güvenli gemi değişimi, save/LAN. Görsel test seçicisi satın alma sistemi değildir. |
| Top | WeaponDefinition: base_damage, range_meters, min_range_meters, reload_seconds, accuracy, crit, broadside, penetration. weapon.vs01_practice_cannon tek pilot. | PLAY-03 + PLAY-06: üç top profili, item→weapon ref, batarya kapasitesi ve adet etkisi, combat/motor rebind; UI salt read-model. |
| Mühimmat | ammo.core_round → item.core_round; ammo.core_ember → item.core_ember. CombatAuthority.register_ammo/mount_ammo/transact select_ammo. HarpoonProfile ayrı. | PLAY-03/06: çok ürünlü fiyat/stok, aktif stok HUD, boş stok kurtarma, zıpkın pazarı. |
| Ticaret | InventoryState.execute_transaction(actor, transaction_id, operation, payload); Prg05EconomyState.quote(owner, market) → item, stock, buy, sell, disposition. OP economy_market_buy/sell payload tam olarak market_id, quantity. Sonuç accepted, reason, operation, quantity, unit_price, balance, stock. | PLAY-05: mevcut Bootstrap sadece market.haven.salvage ve anchor.haven_center/128 radius kabul ediyor. Çok ürünlü liman kataloğu ve per-product/port access guard; LAN aynı kontrol. Fiyat/değer UI tarafından yazılmaz. |
| Donanım / çanta | InventoryState quantities_snapshot/equipment_snapshot/stat_value; inventory_equip {slot,item_id}; inventory_unequip {slot}; inventory_transfer {source_container,target_container,item_id,quantity}. ProgressionPanel sinyalleri var. | PLAY-06: gemi-instance bazlı sahiplik ve batarya item adetleri mevcut slot sistemine bağlanmalı. UI'da ileri progression gizli, eski save korunur. |
| Savaş/onarım | CombatAuthority.fire/harpoon/transact; hull_damaged, ship_sunk, monster_defeated, wreck_destroyed; intent(kind,id); result accepted, success, reason, sequence_id, amount. repair_hull mevcut item/tick onarımı; Bootstrap 20 hull/180 tick pilot. | PLAY-03/05: limanda altın karşılığı tamir ve batma/kurtarma atomik iş akışı; HUD snapshot/animasyon ve sound. Mevcut saha repair ile ikinci hull truth kurulmaz. |
| Ganimet | LootAuthority ve WorldObjectAuthority; mevcut gemi sunk → drop/claim, chest/wreck; tek inventory. | PLAY-04/05: gerçek canavar spawn/loot, bütünleşik pickup, tekrar spawn/claim, coin grant idempotent. |
| Görev | Prg04QuestState + InventoryState quest_journal_snapshot. quest_accept / quest_turn_in payload quest_id,npc_id; journal row status,title,description,objectives (current/required/target_id), reward_preview, remaining_ticks. QuestJournalPanel mevcut. Bootstrap bounty.foundation.practice (80 altın) ve convoy bridge. | PLAY-04/07: production journal, gerçek kontratlar, geçici raid objective/ödül adaptörü, altın ödülü tek ledger. Statik NPC turn-in işlemi raid auto-claim ile karıştırılmaz. |
| NPC/raid | FleetCoordinator register_fleet, formation_commands, mark_member_status, snapshot; AI role profiles trader/escort/raider, WorldSpawnDirector, CombatAuthority. | PLAY-04: normal NPC population, geçici encounter ayrı lifecycle; filo koordinatörü shared service. Simulated player yok. |
| Harita/liman | sector.foundation → sector.outer_reach → sector.safe_haven; Deep Haven askıda. SectorGraph, SectorMapOverlay; Ashen Haven safe_zone ve liman market anchor. | PLAY-02/05: birinci liman tamamla, ikinci liman gerekiyorsa aynı surface graph üzerinde authored anchor; Deep Haven'i açma. |
| Görsel | src/presentation/ship/visual_pilot.gd, pilot_atlases, pilot_water.gdshader, Bootstrap; SC01/02/03/04/06/08 ve M01/M02 stage kanıtı. | PLAY-02/03: atlas→gerçek definition, mount, gerçek spawn, deniz/ada/efekt, üretim standardı. |
| LAN/save | ProductionLanHost, SessionHost/Client, HostTransactionLedger, lan_guest.gd, SaveService; market pilot ve guest currency mevcut. | PLAY-09: yeni gemi, batarya, raid, quest ve liman işlemlerini authenticated actor + host snapshot ile genişlet; reconnect ve migration. |

**Önemli:** src/presentation/bootstrap.tscn hâlâ test temelli BoatMarker/InputBlocker ile kuruluyor. Güncel Bootstrap market panelini runtime ekliyor; gerçek ana menü/tersane veya tüm progression ekranları bağlanmış sayılmaz. Görev panellerinin varlığı production ekranı anlamına gelmez. Ticaret ledger üst sınırı mevcut 128 transaction; uzun testte kapasite davranışı ve güvenli evict/replay politikası incelenmeli, tekrar ödül güvenliği gevşetilmemeli.

#### D. UI adapter sözleşmesi v1 (önerilen presentation DTO, mevcut wire protocol değil)

UI tüm state'i detached snapshot üzerinden okur. UI/backend paralel işlerinde bir ortak adapter kullanılır; payload alan isimleri aşağıdaki mock sözleşmede sabit. Gerçek mevcut komutları dönüştüren adapter backend doğrulamasını atlamaz. Stable ID biçimi, nullable ve sayısal birimler korunur; price/hull/cooldown gibi alanların sahibi domain.

| Snapshot grubu | Alanlar (type) |
|---|---|
| Session | mode:string offline/host/guest, connection:string, owner_id:string, paused:bool, save_state:string, revision:int |
| Player | entity_id:string, active_ship_id:string, ship_def_id:string, hull:float, max_hull:float, speed:float world units/s, balance:int, sector_id:string, in_port:bool, port_id:string/null |
| Combat | target_id:string/null, target_class:string/null, hull/max_hull:float, distance:float, can_fire:bool, reason:string, reload_remaining_s:float, reload_total_s:float, ammo_id:string, ammo_qty:int, harpoon_qty:int, can_harpoon:bool |
| Ship catalog row | ship_def_id:string, name:string, visual_id:string, price:int, hull:float, speed:float, turn_deg_s:float, cannon_capacity:int, owned:bool, active:bool, available:bool, reason:string |
| Owned ship row | ship_instance_id:string, ship_def_id:string, hull:float, max_hull:float, cannon_item_id:string/null, cannon_count:int, equipment_ids:array[string] |
| Product row | market_id:string, port_id:string, item_id:string, category:string cannon/ammo/harpoon/cargo/equipment, name:string, icon_id:string, stock:int, owned_qty:int, buy:int, sell:int/null, available:bool, reason:string, stat_preview:object |
| Inventory row | item_id:string, name:string, category:string, qty:int, equipped_qty:int, icon_id:string, sell_value:int/null |
| Port | port_id:string, name:string, sector_id:string, in_range:bool, services:array[string], repair_quote:int, repairable_hull:float |
| Quest row | quest_id:string, status:string, title:string, description:string, objectives:array, reward_preview:object, sector_ids:array[string], remaining_ticks:int (-1 no timer); raid_id:string/null for adapter-only raid view |
| Raid row | raid_id:string, sector_id:string, position:{x:float,y:float}, status:string announced/active/completed/expired, total:int, remaining:int, reward_gold:int, expires_tick:int/null, tracked:bool |
| Map | sector_id:string, nodes:array, gates:array, port_markers:array, raid_markers:array, player_position:{x:float,y:float}, route:array |

Intent envelope for UI: operation:string, request_id:string, payload:object. Adapter resolves actor from local owner or authenticated LAN session; no actor/faction/balance/price supplied by UI. Response: request_id, accepted:bool, reason:string, operation:string, snapshot_revision:int; optional detached result, refreshed snapshot. Combat result success differs from accepted (accepted miss is valid). Pending mutation disables same action until response; timeout retry with identical ID/payload; different user intent fresh ID. UI ignores stale snapshots. Existing protocol stays unchanged until adapter lane verifies mapping.

| UI operation | Payload | Status |
|---|---|---|
| economy_market_buy / economy_market_sell | {market_id,quantity} | Existing, port+market access adapter generalized |
| inventory_equip / inventory_unequip | {slot,item_id} / {slot} | Existing, ship-specific binding needs extension |
| ship_purchase | {port_id,ship_def_id} | NEW proposed; atomic debit + ownership + persistence, not automatic activate |
| ship_activate | {port_id,ship_instance_id} | NEW; in port, not combat, transfer active hull/profile/battery safely |
| battery_set | {port_id,ship_instance_id,cannon_item_id,count} | NEW; all-or-nothing inventory/equip, no duplicate |
| select_ammo / fire_weapon / fire_harpoon | {ammo_id} / {target_id} / {target_id} | adapter maps to CombatAuthority existing command format, not new authority |
| port_repair | {port_id,ship_instance_id} | NEW; full available repair quote, recheck current funds/hull, atomic debit and hull |
| quest_accept / quest_turn_in | {quest_id,npc_id} | Existing |
| raid_track / quest_track | {raid_id} / {quest_id} | Presentation only; reward never client |
| raid_reward | no client reward command | Authority auto settlement once on eligible completion; contribution shared co-op rule below |
| loot_claim / navigate / stop / map_gate | {drop_id} / {x,y} / {} / {gate_id} | Adapter to existing gameplay paths |
| save / host / join / reconnect | existing save/network adapter | no duplicate save truth |

Error presentation: insufficient_stock_or_funds → “Altın veya stok yetersiz”; market_full_or_overflow → “Pazarın alım kapasitesi dolu”; inventory_rejected/equip_rejected → “Kapasite veya donanım uyumsuz”; hostile_market → “Bu liman ticarete kapalı”; transaction_conflict → “İşlem çakıştı, yenile”; transaction_ledger_full → “İşlem kaydı dolu, tekrar denemeden önce kaydı kontrol et”; invalid_npc_interaction → “Görev verenin menziline gir”; quest_not_completable → “Hedefleri tamamla”. NEW UI normalized reasons: out_of_range, combat_locked, insufficient_funds, already_owned, incompatible, insufficient_stock, disconnected, save_failed. Adapter açıkça eşler; bilinmeyen hata “İşlem tamamlanmadı” + teknik log; accepted=false asla başarı toast'u değil. Boş/loading/reconnect/disabled durumları mock'ta ayrı fixture.

#### E. İlk içerik matrisi ve mock fixture

Gerçek pilot (koddan): ship.foundation_player hull 100, ship.vs02_practice hull 75; tek placeholder hareket profili speed 180, turn 72 deg/s. weapon.vs01_practice_cannon base_damage 25, 35–360 range, reload 1.25 s; round scale 1.0, ember 1.15 + scorched; harpoon.core02_debug 18 damage, 320 range, reload 1.25 s; monster.core02_practice hull 120; bounty 80. Bunlar denge hedefi değildir.

Aşağıdaki `draft.*` kimlikler UI mock içindir; production kaydı değildir. İsimler geçici etiket, mevcut gemi görsel rehberindeki özgün isimler finalde kullanılır.

| Mock gemi / visual | Altın | Hull | Hız | Dönüş °/s | Top kapasitesi |
|---|---:|---:|---:|---:|---:|
| draft.ship.sc01 / SC01 (başlangıç) | 0 | 100 | 180 | 72 | 2 |
| draft.ship.sc02 / SC02 | 300 | 130 | 185 | 68 | 3 |
| draft.ship.sc03 / SC03 | 420 | 180 | 145 | 52 | 3 |
| draft.ship.sc04 / SC04 | 550 | 160 | 200 | 76 | 4 |
| draft.ship.sc06 / SC06 | 850 | 230 | 165 | 52 | 5 |
| draft.ship.sc08 / SC08 | 1300 | 320 | 125 | 40 | 6 |

| Mock ürün | Alış / satış altın | Etki |
|---|---:|---|
| draft.cannon.light | 35 / 17 | 10 damage/top, 300 range, 1.4s |
| draft.cannon.standard | 85 / 42 | 16 damage/top, 360 range, 1.8s |
| draft.cannon.heavy | 160 / 80 | 26 damage/top, 390 range, 2.5s |
| item.core_round | 1 / 0 | normal gülle |
| item.core_ember | 4 / 2 | güçlendirilmiş gülle |
| item.core02_harpoon | 2 / 1 | zıpkın stoğu |
| item.vs03_salvage_scrap | 8 / 4 | loot/ticaret |
| draft.cargo.supplies | 15 / 8 | ticaret malı |
| draft.cargo.spice | 30 / 18 | ticaret malı |

Rakamlar yalnız mock: gerçek PRG05 quote min sell=1 olduğundan mock normal gülle satış 0 = “satış yok”, yeni ürün kuralı gerekir. Maliyet hesapları authority quote üzerinden; UI toplam = quote×adet yalnız tahmin, final actual result gösterilir. Top başına mühimmat tüketimi, salvo hasarı ve reload dengesini PLAY-03 doğrular. Örnek başlangıç 120 altın + 40 normal gülle + 15 zıpkın; ilk kazanılabilir SC02 300 altın. Mini raid önerisi toplam 150 altın, iki normal kontrat 60–80, monster 20–40. Solo/iki oyuncu katkı ve ekonomi testinden sonra rakamlar kesinleşir; loot ve kontrat toplamı ilk gemi alımını gereksiz grind'a dönüştürmemeli.

**Fixture set (UI lane için elle oluşturulabilir deterministic veri):**
- F01 deniz: player SC01 hull 72/100, gold 120, sector.foundation; enemy ship hull 40/75, 180 distance, can_fire=true, reload 0.4/1.4, round 40, harpoon 15; F02 yanlış hedef monster, can_fire=false, can_harpoon=true; F03 out_of_range ve sıfır stok.
- F04 tersane: SC01 owned/active, diğerleri yukarıdaki matris; gold 120 → SC02 disabled; F05 gold 400 → SC02 enabled; accepted sonrası gold 100, SC02 owned not active; activate sonrası SC01 hull 72 saklı, SC02 hull 130. Retry aynı request_id: aynı sonuç, bakiye tekrar düşmez.
- F06 mağaza: port safe_haven, market mock round stock 80, owned 40, buy 1, sell null; 20 adet alım → gold 100, stock 60, owned 60; F07 quantity 81 → reject; F08 out-of-range → panel kapanır; F09 disconnect → pending, reconnect aynı ID.
- F10 donanım: SC01 capacity 2, light count 2, envanter standard 1; standard count 3 reject; count 1 success. Preview eski/yeni salvo ve cooldown; unused light iade.
- F11 tamir: SC01 hull 72/100, quote 28 (mock 1 altın/hull), gold 120; accepted → 100/100, gold 92. F12 gold 0: acil minimum hull yardımı yalnız ihtiyaç halinde; tamir bedava full hull değildir.
- F13 normal quest available/active/completable/completed; kill progress 0/2→2/2, turn-in sonucu bir kez; F14 raid active total 3 remaining 2, reward 150; remaining 0 → complete, 150 toplam raid ödülü yalnız bir event. F15 raid expired, reward 0, marker temizlenir. F16 empty inventory/journal, F17 loading, F18 save_failed, F19 guest read-only/reconnect.

#### F. Dünya/raid ve görevlerin ilk oynanış içeriği

Önerilen ilk akış: başlangıç güvenli limanı → 1 kısa seyir/loot kontratı → korsan savaş kontratı → canavar avı → ilk tamir/cephane/ticaret → yeni gemi satın alma → mini raid bildirimi. Serbest seyir her zaman mümkün; kontratlar tutorial kılavuzu, zorunlu seviye kilidi değil. İlk üretim üç surface sektör ve iki liman hedefi; ikinci liman henüz hazır değil, birinci limanla akış test edilebilir. Yeni canavar tanımı M01/M02 görseline göre territory/charge veya circle/flee basit profil; normal NPC popülasyonu tüccar/raider/escort. Raid trigger, eligibility, timeout ve cleanup normal population cap'ten bağımsız encounter cap ile çalışır. İlk öneri aynı aktif bölgede tek raid; güvenli alan dışı spawn, erişilebilir su. Ödül toplamı host tarafından katkı sahibi oyunculara dağıtılır (solo tamamı; co-op eşit katkı için eşit, kalan yuvarlama stable owner sırası; minimum anlamlı katkı eşiği testle belirlenir), yeniden bağlanma duplicate ödeme yapmaz. Normal loot ve raid bonusu açıkça ayrı kalem. Raid sonlanırsa canlı üyeler ve görev marker'ı temizlenir, kayıt/yükleme aynı encounter ID ile devam eder. Kalıcı sandbox oyuncu ekonomisi yok.

#### G. UI/uygulama paralel teslim sırası ve kontrol

UI sahibi: yalnız presentation ekranı, ortak theme ve mock adapter; domain, save, network dosyası değişmez. Ekonomi sahibi: ship ownership, gemi/top/cephane market ve tamir; mevcut InventoryState/Prg05 üzerinden. Savaş sahibi: top bataryası, target, ammo, VFX event. NPC/raid sahibi: spawn/lifecycle, existing FleetCoordinator, quest/loot adapter. Asset sahibi: altı gemi + iki canavar + ada/deniz, görsel ve collider; UI için ikon/thumbnail export. LAN sahibi: authenticated commands/read-model parity. Bootstrap composition, registry, save migration ve shared adapter tek entegrasyon sahibi; diğer paketler çakışmasız bileşen geliştirir.

UI lane önce F01–F19 ile çalışır; hiçbir fiyat/stat hardcode production kabulü değildir. Her ekran contract mock ve gerçek adapter smoke, keyboard/back/touch, resize, safe-area, empty/error/pending, no input leakage; Godot frame capture 1280×720 ve dar viewport. UI art tasarımının kullanıcı görsel onayı ayrı. Backend lane valid/reject/atomic/retry/save/load/host-guest testleri, gerçek üretim sahnesi; birleşik kabulden önce fixture adapter kaldırılır veya debug-only kalır. İlk kullanıcı tasarım onayı alınmadan fiyatlar, gemi kapasitesi, ücretsiz kurtarma ve HUD kontrol tercihleri final kabul sayılmaz.

**Asset listesi UI:** onaylı SC01/02/03/04/06/08 atlaslarından thumbnail, M01/M02 target portrait, top (3), mühimmat (2), zıpkın, loot/salvage ve mal (2), altın, tamir, map/port/raid/quest, hedef/hull/reload, bağlantı/ayar ve geri ikonları; buton/sekme/panel ortak theme. Ses: top, impact, batış, zıpkın, pickup, UI kabul/hata; yalnız lisans doğrulanmış veya özgün. HUD animasyonları basit; gereksiz çoklu katman/shader yok. UI ikonlarının ilk mock'u placeholder olabilir. Asset üretimi yeni gemi çeşitliliği için bekletilmez.

**PLAY-00 tasarım kontrolü:** ekran akışları, mevcut vs yeni işlemler, mock içerik, üç dünya popülasyonunun ayrımı, paralel sahiplik ve hata durumları bu bölümde kayıtlı. Kullanıcı kabulü ve gerçek fixture/UI kodu henüz yok. PLAY-01 bağımsız sürdürülür; PLAY-02 envanter/QA bağımsız; UI ve domain implementasyonları ilgili sözleşme kabulü sonrası başlatılır.

## 3. Paralel yürütme — kritik yol ve sahiplik

İlk iş PLAY-00 iken bağımsız mevcut asset envanteri/QA ve PLAY-01 hareket replay iyileştirmeleri devam edebilir; arayüz implementasyonu ilgili PLAY-00 sözleşmesi doğrulanmadan başlamaz. Sözleşme ekran grubu bazında kabul edildikçe ilgili UI işinin başlaması mümkündür; bütün grupların bitmesi beklenmez.

| Paket | İş ve teslim | Bağımlılık / sahiplik |
|---|---|---|
| PLAY-00 / Sözleşme | Yukarıdaki sistem/ekran kapsamı, içerik veri matrisi, UI mock sözleşmeleri, kullanıcı tasarım kabulü | İlk görev; ortak API/şema için tek yazıcı |
| PLAY-01 / Helm | Mevcut hareket hataları, dönüş/rota, input ve kamera; fizik replay | Bağımsız; ShipMotor/navigasyon/input, yalnız kendi alanı |
| PLAY-02 / Dünya ve asset | Onaylı gemi ve canavar sprite/mount/pivot, ada/kıyı collision, deniz shader, harita ve wake; kaynak çözünürlüğü politikası, profil | Bağımsız asset hazırlığı; presentation/asset importer; UI ikon gereksinimi PLAY-00 |
| PLAY-03 / Savaş ve VFX | Top/zıpkın, reload ve hit; onaylı demo VFX (atış, iz, isabet, hasar/batış), audio, ucuz mobil alternatif; mevcut CombatAuthority | Savaş görünümü asset ile sözleşmeye bağlı; authority alanı ayrı |
| PLAY-04 / Dünya NPC ve mini raid | Normal NPC ve canavar gerçek gameplay, ayrı küçük korsan raid lifecycle, görev tetikleyici, filo koordinasyonu, ödül ve save/reconnect | Mevcut AI/filo/spawn; raid görev/loot sözleşmesi PLAY-00; PLAY-03 authority reuse |
| PLAY-05/06/07 / Ekonomi ve progression | Gemi/top/mühimmat satın alma, takma/seçme, basit market/loot/tamir, görev, tek para ve kayıt; mevcut PRG API'leri | PLAY-00 sözleşmesi; economy/inventory/quest domain, yeni parallel truth yok |
| UI / POL-01 ilk sürüm | Gerçek Godot mobil ekranları, komponentler, navigasyon, HUD, liman/pazar/donanım/görev/map/LAN; mock üzerinden erken çalıştır, adapter ile gerçek veriye bağla | PLAY-00 ilgili ekran sözleşmesi; presentation UI; domain dosyaları değiştirilmez |
| PLAY-09 / LAN | Aynı offline komutlar, host/guest UI bağlama, raid ve market/loot/gemi değişimi parity, discovery/IP, reconnect, save/drift | NET/PRG mevcut temel; sözleşme sabitlenince erken başlar; birleşik doğrulama gameplay hazır olunca |
| PLAY-08 / Entegrasyon ve test | Tek production sahnesi, bütün UI ve gameplay bağlama, gerçek 15/30–60 dk döngü, otomatik oyuncular, video ve cihaz testi | Bütün ilk sürüm paketleri; tek entegrasyon sahibi; ileri içerik beklenmez |
| PLAY-10 / İleri sandbox | Ayrı kalıcı simulated-player population, filo ekonomisi/hakimiyet, daha geniş içerik; denizaltı/büyük raid ayrıca değerlendirilir | PLAY-08/09 kabulü sonrası; ilk sürüm için geliştirme yok |

**Dalga 1:** PLAY-00 + PLAY-01 + PLAY-02 asset hazırlığı. **Dalga 2:** PLAY-00 ekran gruplarının kabulüyle UI, PLAY-03, PLAY-04, PLAY-05/06/07, LAN adapter ve kalan görseller paralel. Her lane mevcut kodu yeniden kullanır. **Dalga 3:** PLAY-08/09 bütünleşik APK, tam test, hataları düzelt/yeniden test. Ayrı sohbetler açılması gerekiyorsa bu iş paketleri brif olarak kullanılır; bu belge sohbetlerin açıldığı ya da çalıştığı anlamına gelmez.

Yalnız gerçek bağımlılık durdurur. Her lane güncel main HEAD, kendi dosya/sınırları ve ilgili sözleşme sürümünü kontrol eder; ortak Bootstrap, project.godot, registry/manifest, save ve network şemasının tek entegrasyon yazıcısı vardır. Başkalarının aynı dosyasını paralel değiştirme; gerekirse çakışmayan adapter/presenter ve testler üzerinden çalış. Sözleşme değişikliği önce sahip tarafından onaylanıp kayıt edilir; ilgili UI/backend yeniden doğrulanır. Mevcut main-only sınırı korunur, yeni dal/PR politikası oluşturulmaz. Kanıt ve bağımlılıklar mevcut kanonik görev/SESSION_HANDOFF/GOREV_RAPORU kayıtlarına işlenir; mükerrer görev veya rapor sistemi yok.

## 4. İlk sürüm teslim kapısı

- Hazır SC01/02/03/04/06/08 ve M01/M02 paketleri 2026-11-26 checkpoint'te stage edildi. Canavarlar görsel önizleme; gerçek spawn/AI henüz kabul edilmedi. Güncel onaylı gemi/canavar/ada/VFX envanteri repo kaynaklarından doğrulanır; eksik yükleme veya lisans ayrı iş, tüm sanat kataloğu beklenmez. Onaylı sprite çözünürlük standardı üretim rehberinden alınır. Mevcut normal map/baked lighting/efekt deneylerinden yalnız onaylı, mobilde ölçülmüş ucuz seçenek; onaylanmamış demo production kabulü sayılmaz. Godot hazır çözüm/extension araştırmasından sadece ihtiyaç olan ve lisans+uyumluluk+export kontrolü geçen bileşen kullanılır.
- Başlangıç içeriği önerisi: 6+ hazır gemi, 2+ canavar, 3 bölge, 2 liman, 5–8 kısa görev/kontrat, tekrar edilebilir mini raid, offline + 2 fiziksel cihaz LAN; 1–4 oyuncu ölçek hedefi testle kesinleşir. Hazır içerik yeterliyse yeni asset üretimi kritik yol değildir.
- Otomatik oyuncu senaryoları gerçek production sahnesinde: açılış → seyir → top/zıpkın avı → ganimet → pazar → gemi/top/mühimmat satın al → ekipman/onarım → raid → ödül → save/reload; başarısızlık ve tekrar işlemleri, ölüm/respawn, yanlış hedef/menzil, stok/bakiye, iki oyuncu aynı hedef/loot, reconnect/late join ve host save. Yeni özellikler için normal/raid popülasyon ayrımı, raid cleanup/reward tekliği ve LAN parity. Ekonomi uzun simülasyonda gelir/masraf/softlock, hasar/kaçış/AI çeşitliliği ve oyuncunun ilk yükseltmeye erişimi ölçülür.
- Görsel kanıt: gerçek Godot frame capture veya replay video, gemi dönüş/pivot/heading, savaş efektleri, hasar/batış, canavar, UI küçük ekran okunurluğu; düşük FPS örnekleri ve ayrı gerçek cihaz performans kanıtı. Android düşük/orta donanımda frame pacing, CPU/GPU, bellek, termal, dokunmatik, pause/resume; hedef 60 FPS, 30 FPS fallback. İki fiziksel cihaz LAN oturumunda drift ve bağlantı testi; gerçek cihaz testi yoksa not_run.
- Mevcut FND/VS/CORE/AI/NET/PRG regresyonlarını koru; exact SHA CI, export, artifact readback. Unit test sayısı eğlence kanıtı değildir. Her küçük değişiklikte kullanıcıya APK kurdurma; konsolide APK ile 15 dakikalık ilk döngü ve 30–60 dakikalık gerçek oyun kabulü. PLAY-01 hareket hissi ve Android performansı halen not_run; PRG-05 fiziksel LAN kapısı açık; PRG-06 pilot askıda. Teknik geçmiş SESSION_HANDOFF ve GOREV_RAPORU'nda korunur.
- İlk sürüm tamamlanmadan ileri sanal oyuncu NPC, dinamik bölge savaşı veya denizaltı geliştirmesi açılmaz. İlk sürümde yalnız küçük geçici raid vardır, ADV büyük raid framework'ünün tamamlanması önkoşul değildir.

### Ada üretim standardı — 2026-11-26 (kullanıcı kararı, bağımsız görsel lane)

**Yeni bağlayıcı kural: N ada çıktısı = N benzersiz, ayrı geometri referansı.** Örneğin beş ada için beş tekil PNG; modelin toplu bir geometri atlasından kendi seçimini yapması artık kullanılmaz. Her çıktıyı belirli referans numarası/seed ile bire bir eşleştir; aynı geometriyi başka ada için yeniden kullanma. Yeni ada gerektiğinde motorla yeni seed üret, adayları silüet, kıyı, yükseklik ve jeoloji çeşitliliği açısından seç. Seed farkı tek başına yeterli değildir. Geometri referansının silüeti, kıyı akışı, yükselti ve fiziksel oranları korunur; yüzeyler ve bitki örtüsü özgün yorumlanır. Önceki seride 5 ayrı sonuç alınsa da ikinci beşlide üçü aynı kütleye benzedi; toplu atlas seçimini bırakma gerekçesi budur.

**Araç ve üretim zinciri (gerçek kullanılan kaynak):**
- [fabio-t/terrain-generator v0.3.1](https://github.com/fabio-t/terrain-generator/releases/tag/v0.3.1), Rust CLI, Apache-2.0. Sohbete yüklenen Linux x86_64 statik paket: `terrain-generator-v0.3.1-x86_64-unknown-linux-musl.tar.gz`; yerel SHA-256 `6d6afe771430c28506f83a7e58a3f0c89e7811db4bf8740db770df3a9deb3c68`. Motorun kendi OpenSimplex/fraktal arazi, düzensiz ada maskesi ve damlacık tabanlı hidrolik erozyonu kullanılır; görsel üretim modeli ile heightmap icat edilmez.
- Düşük maliyetli aday taraması: 384×384 heightmap; seed, frequency, coast-noise, sea-level, octaves, persistence, droplets gibi seçenekleri değiştir. İlk deneyde 60 adaydan 10 seçildi. Seçilenler için aynı seed ve makro ayarlarla native 1536×1536 16-bit yükseklik üret. Son doğrulanabilir paket 6 octave, persistence 0.48, yüksek yoğunlukta 720.000 damlacık kullanır. Ayarlar yeni adaya göre değiştirilebilir.
- Makro kıyıyı korumak için mevcut render.py: 384² kaynağın bicubic yükseltilmiş tabanına 1536² gerçek motor çıktısının band-pass yükseklik kalıntısı (gain 0.55, sigma 1.25 hücre, kıyıya yakın taper) eklenir; ana bağlı kara kütlesi seçilir. Bu bir PNG upscale değildir. Son paketin manifestindeki coast-mask IoU 0.9614–0.9947 aralığındadır; tamamen aynı kıyı garantisi değildir. Gerekirse daha iyi erozyon/mesh yoğunluğu ayarla, yalnız PNG boyutunu büyütme.
- Python/Pillow, NumPy, SciPy ve Numba ile yükseklik alanı üçgenlenip depth-buffer ve interpolasyonla gerçek ortografik arazi renderı alınır. Kamera yataya göre 55°, azimut 35°, roll 0; sol üst aydınlatma. Deniz seviyesinin altında kalan kısımlar kesilir. Eğim, yükseklik ve kıyı uzaklığı ile kum/bej, kaya/gri, toprak/kahverengi, çayır/yeşil ve fundalık renkleri belirlenir. Kum bütün kıyıyı kesintisiz çerçevelemez. Tekil ref 1536×1536 şeffaf PNG, toplu inceleme panosu 3072×3072; bunlar referanstır, final sprite/runtime mesh değildir.
- Mevcut küçük ada denemelerinin geometri genişlikleri 55–120 m, relief 4–15 m. Yeni küçük adalarda yaklaşık 40–120 m tasarım aralığı; gerçek oyun world-unit ölçek eşlemesi ayrıca yapılır. Büyük ada ölçeği veya ağaç yoğunluğu otomatik kopyalanmaz.

**Dosya envanteri (sohbet artefaktları; henüz bu Git deposuna yüklenmiş sayılmaz):**
- `SeaCraft_terrain_detail_set.zip` — güncel ana kaynak paketi; SHA-256 `215c3e91f0f0e20c8b172b672c4a1128a4b01ed8560db6c62bb027de25791550`. İçinde `references/IS-##_seed###.png` (10 ayrı 1536² ref), `macro_384/`, `native_1536/`, `refined_heightmaps/`, `manifest.json`, `render.py`. Paket CRC kontrolü başarılı. Render betiğinde eski çalışma ortamına ait sabit /mnt/data yolları vardır; yeni ortamda paket içi klasörlere uyarlanması gerekir. Mevcut seed sırası: 102, 100, 110, 113, 114, 129, 128, 135, 147, 154. Bu referans numaraları final sanat asset ID'leriyle doğrulanmış bir eşleme değildir.
- `SeaCraft_terrain_detail_55.png` — 3072² toplu QA/seçim atlası, GPT Image'a üretim referansı olarak artık verilmez. `SeaCraft_terrain_detail_comparison.png` — arazi detay karşılaştırması. Eski `SeaCraft_10_ada_motor_v031.zip`, `SeaCraft_terrain_HD_set.zip` ve ilgili atlaslar tarihsel deneylerdir.
- `atlas_de_texturas_naturais_costeiras_envelhecidas.png` — güncel ada çevre malzeme atlası (1254²). Yalnız renk, malzeme ailesi ve sanat dili rehberi; hücreleri/tekstürleri birebir kopyalatma. `127422.png` — ilk ağaçsız ada kalite örneği (1254² RGBA); yalnız sanat/okunurluk referansı, şekil şablonu değil. Gemi ve canavar atlasları doğrudan ada dokusu olarak kullanılmaz.

**GPT Image üretim protokolü:**
1. N ayrı geometriyi hazırla ve yükle (Reference 1…N); her Output 1…N için yalnız eş numaralı geometri, diğer adaların geometrisi kullanılmaz. Sonra ortak çevre malzeme atlası (Reference N+1), gerekiyorsa kabul edilen ada kalite örneği (Reference N+2). Beş ada için beş geometri + ortak atlas + opsiyonel kalite örneği. Modelin seçim yapması yerine eşleme promptta açık yazılır; karışırsa tekli üretime dön.
2. SeaCraft: antik, sert, tuz/rüzgâr aşındırmış Kuzey Atlantik esintili Lovecraft deniz dünyası; handcrafted stylized realism, doğal hacim, zengin fakat ölçülü renk/kontrast, mobil ölçekte okunaklı yüzey. Her ada farklı jeoloji ve ekosistem; kum, toprak, çayır, fundalık ve kayanın dağılımı doğal ve değişken. Küçük açık deniz adaları kural olarak ağaçsız; ot, liken, yosun, funda, bodur çalı. Daha büyük adalarda yalnız korunaklı ve toprak koşulları uygun iç bölgelerde ağaç; sahil dibine dekoratif çam koyma.
3. Her çıktı tek tamamlanmış 1:1 kare şeffaf PNG; bütün ada ve küçük güvenlik marjı, 55° ortografik, sol üst ışık. Kaya, kum, toprak, bitkiler tek bütünleşik baked sprite; görsel katmanlar/ayrı runtime prop montajı yok. Su, sığ su, dalga, köpük, yansıma, dış gölge, yapı/liman/karakter yok; deniz ve kıyı VFX kodla ayrı üretilir. N çıktı ayrı dosya, kolaj veya sprite sheet değil.
4. QA: referans/çıktı eşlemesi, silüet tekrarı, gerçekçi kara-deniz sınırı, doğal ölçek/ekoloji, mobil okunurluk, mikro doku/hücresel kabartı kusuru, alpha saçakları ve görsel tutarlılık. Negatif görsel ref denemesi başarılı olmadı; klasik frekans filtreleri plastikleşme yarattı; bunlar varsayılan üretim adımı değildir. Görsel kabul, dosya/alpha kontrolü, collision uyumu ve gerçek Android entegrasyonu ayrı kapılar.
5. Final kaynak PNG + ada ID, benzersiz seed, motor sürümü, geometri ref adı/hash, üretim ayarları, malzeme ref sürümü ve prompt eşlemesi saklanır. Görselden bağımsız land/shore mask ve kıyı collision polygonu teknik veri olarak çıkarılabilir; final sprite ile örtüşme test edilir. Normal doğal adalar yalnız gemi hareketini engelleyen dekoratif kara kütlesidir; karaya çıkma, hasat veya yapı etkileşimi yok. Mevcut liman/outpost sistemlerinin sözleşmesini değiştirme.

**Kapsam:** Bu kayıt üretim yöntemi revizyonudur; runtime kodu, collision entegrasyonu, asset yükleme ve PLAY-02 cihaz kabulü tamamlanmış değildir. PLAY-01 aktif kalır.


---

# Tarihsel teknik görev kataloğu (referans, yürütme sırası değildir)


> Plan revizyon girdisi: main @ 02f0571c762f8ab4c7893227e153e1570dd68627  
> Hedef motor: Godot 4.7  
> Platform: Android + masaüstü  
> Ağ: tamamen offline oynanabilir, isteğe bağlı LAN, host-authoritative  
> Görsel yön: 2D/2.5D 3/4 top-down, ultra-realistic dark maritime Lovecraftian  
> Bu belge planlama çıktısıdır. Kodlama, addon kurulumu ve asset üretimi içermez.

## 0. Planlama ilkeleri

Bu sıra MEKANIK_KATALOGU.md, ICERIK_KATALOGU.md, GODOT_HAZIR_COZUMLER.md, HAZIR_ASSET_ARASTIRMASI.md ve GEMI_GORSEL_TASARIM_VE_SPRITE_PLANI.md birlikte okunarak oluşturulmuştur. 22 Kasım 2026 revizyonu, 767 kayda genişleyen resmî forum içerik araştırmasını ve seçilen GDQuest tabanlı 2D deniz yönünü plana işler; görev sırasını değiştirmez.

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
- Deniz sunumu tamamen 2D CanvasItem kalır. T31 için seçilen referans GDQuest `godot-shaders` içindeki **2D water in top-down view** yaklaşımıdır; yalnız uygun MIT shader/kod yaklaşımı uyarlanır, demo sanat varlıkları alınmaz. Pruva/borda köpüğü, kıç türbülansı, hız ve dönüşe bağlı kıvrılan V-wake ile birkaç saniyede dağılan iz SeaCraft'a özel 2D sistemdir; 3D ocean/FFT/buoyancy kapsam dışıdır.
- Resmî Seafight EN/TR forumundaki sayı, görsel ve görev akışları **tasarım/veri şeması referansıdır**; SeaCraft'ın final denge değerleri, isimleri ve görselleri özgün kalır. Quest araştırmasındaki başlangıç/bitiş NPC'si, hedef türü, harita/elde-etme koşulu, süre ve ödül alanları PRG-04 şemasına taşınır.
- Güncel ICERIK_KATALOGU **767** somut kayıt içerir. Katalog arketip, stat aralığı, objective biçimi ve içerik çeşitliliği kaynağıdır; telifli isim/görsel birebir taşınmaz.

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

## PRG-01 — Inventory, equipment, crew, pet/companion ve preset\n\n**Durum: TAMAMLANDI — exact kod SHA `a3344909e489adc93800f6591238eb7102561542`, CI run `45015026436`, artifact ID `14750439866`; fiziksel Android cihaz `not_run`.**

**Amaç:** Loot’u gerçek build sistemine dönüştürmek.

**Mekanik katalog ID’leri:** M-016, M-017, M-018, M-019, M-020, M-052.

**Bağımlılıklar:** NET-04.

**BUILT_IN / RECOMMENDED_ADDON:** T22 RECOMMENDED_ADDON A11 GLoot yalnız grid/weight/multi-container ihtiyacı doğrulanırsa; T23 BUILT_IN item/resource DB.

**Sistemler:** InventoryState, stack/slot transaction, weapon/structure/sail/figurehead/crew/trainer/pet slotları, extension modifiers, ship/pet gem ve socket progression, preset, companion slot.

**Görsel/asset bağımlılığı:** Item ikonları placeholder olabilir; gerçek icon seti polish/content aşamasında.

**Android gereksinimi:** Drag/drop’a bağımlı olmayan touch alternatifleri; büyük hit targets.

**LAN gereksinimi:** Equip/transfer transaction host doğrular; istemci GLoot nesnesi replike edilmez.

**Kabul kriterleri:** Slot type/weight/quantity kuralları atomik; preset savaş/safe-state kuralını ihlal edemez; equipment/crew/pet/gem statları tek modifier pipeline'dan geçer ve kaynak forum değerleri SeaCraft final dengesi olarak doğrudan kopyalanmaz.

**GitHub Actions doğrulaması:** Equip compatibility ve kategori/slot şema doğrulaması; transfer rollback; stack boundaries; gem/socket progression; preset restrictions; duplicate transaction.

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

**Amaç:** Data-driven görevler, bounty/escort/salvage/trade/capture/damage/collect objective’leri ve ödül ledger’ı kurmak; resmî forum araştırmasında görülen görev zinciri alanlarını SeaCraft'a özgü veri modeline dönüştürmek.

**Mekanik katalog ID’leri:** M-031, M-032.

**Bağımlılıklar:** PRG-03.

**BUILT_IN / RECOMMENDED_ADDON:** T21 CUSTOM_REQUIRED quest model; T25 A12 Dialogue Manager 4 RECOMMENDED_ADDON yalnız dallı yazarlık büyürse.

**Sistemler:** QuestDefinition, QuestInstance, objective event bus, reward ledger, NPC interaction authority, journal view model; start/turn-in NPC ID, chain prerequisite, region/map constraint, target/acquisition rule, optional time limit, reward bundle ve daily/raid/Atlantis tür etiketleri.

**Görsel/asset bağımlılığı:** Portre/diyalog sanatı zorunlu değil.

**Android gereksinimi:** Journal/diyalog touch ve fontScale 1.3.

**LAN gereksinimi:** Party share policy açık; completion/reward host doğrular.

**Kabul kriterleri:** Kill/damage/capture/collect/acquire ve süreli objective eventleri stable ID ile işler; quest chain prerequisite ve region kısıtı doğrulanır; reward bir kez; save/load quest progress korunur; invalid remote completion reddedilir.

**GitHub Actions doğrulaması:** Objective type matrisi (kill/damage/capture/collect/acquire/timed); chain/region prerequisite; reward idempotency; save/load; host spoof rejection.

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

**Tarihsel teknik kapı:** Faction/economy persistence ve host transaction testleri. Güncel PRG-06 başlama kapısı PLAY-08/09 kullanıcı kabulüdür.

## PRG-06 — Surface/submarine katmanı ve içerik genişletme altyapısı

**Amaç:** Atlantis referansını SeaCraft’a ayrı content mode olarak uyarlamak; mevcut çekirdeği çoğaltmadan surface/sub mode tag’i eklemek.

**Mekanik katalog ID’leri:** M-049, M-050, M-051, M-060.

**Bağımlılıklar:** PRG-05.

**BUILT_IN / RECOMMENDED_ADDON:** T18 shared combat profiles; T19 sector layers; T21 progression gates; T22/T23 inventory/data; T27 progression.

**Sistemler:** mode tag, submarine tier/loadout, launcher + torpedo/breach profile, submarine gem/socket progression, auto-fire intent, sub sector/Deep Haven geçişi, shared progression bridge.

**Görsel/asset bağımlılığı:** Submarine production art ayrı lane; placeholder ile sistem doğrulanabilir.

**Android gereksinimi:** Yeni layer memory/texture budget aşmamalı.

**LAN gereksinimi:** Mode transition ve combat host-authoritative.

**Kabul kriterleri:** Surface ve sub aynı entity/save/network çekirdeğini kullanır; launcher/torpedo/breach ve submarine gem kuralları veri odaklı ayrı profillerdir; forumdaki exact Atlantis değerleri yalnız referans olup SeaCraft dengesi bağımsızdır.

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

**BUILT_IN / RECOMMENDED_ADDON:** T31 RECOMMENDED_REFERENCE + CUSTOM_REQUIRED: GDQuest `godot-shaders` **2D water in top-down view** CanvasItem yaklaşımı; A13 yalnız shader/kod referansı, demo sanatı kullanılmaz. T33 audio/localization. Hazır asset raporundaki lisanslı/CC0 kaynaklar yalnız gereken boşluklarda.

**Sistemler:** visual profile resolver, 8-direction AtlasTexture mapping, pivot/socket binding, 2D water surface shader, ship-water interaction emitter/mask sistemi, pruva ve borda köpüğü, kıç türbülansı, hız/dönüşe bağlı kıvrılan V-wake, birkaç saniyede dağılan trail, cannon/hit/fire/smoke, sinking presentation, audio buses.

**Görsel/asset bağımlılığı:** İlk zorunlu production kabul: SC-02, SC-03 ve SC-08 pilotları. Ardından minimum set. SC-14 S boss için; tam 15 gemi bu görevin ilk alt kapısını engellemez.

**Android gereksinimi:** Texture residency, water shader fill-rate/overdraw, trail-mask çözünürlük ve yaşam süresi bütçesi, mip/filter testi, alpha fringe, low-quality water/VFX mode.

**LAN gereksinimi:** Görseller local presentation; gerçek heading/combat/intent host state’inden gelir.

**Kabul kriterleri:** 4×2 N,NE,E,SE/S,SW,W,NW atlas mapping doğru; pivot ≤1 final px; socket/occlusion yönleri doğru; GDQuest tabanlı su shader'ı Godot 4.7.2 Compatibility'de parse/render eder; wake hız ve dönüşle tutarlı kıvrılır, köpük katmanları doğru gemi bölgelerinden çıkar ve iz bounded sürede söner; VFX gameplay hitbox/physics değiştirmez; 3D/FFT ocean yoktur.

**GitHub Actions doğrulaması:** Asset path/atlas dimension validation; missing socket/profile checks; water shader parse/import smoke; wake parameter/range ve bounded trail-lifetime contract testleri; audio reference completeness.

**Gerçek cihaz doğrulaması:** Android Compatibility’de pilot üç gemi 360° dönüş, socket, bow/side/stern foam, kıvrılan V-wake, trail decay, water shimmer/overdraw ve yoğun filo testi.

**Sonraki görevi engelleyen kapı:** Pilot üç gemi teknik art kapısını geçmeden geniş sprite üretimi production-ready sayılmaz.

## POL-03 — Android/performance optimizasyonu ve soak

**Amaç:** AI, world, LAN, VFX ve UI’ı gerçek mobil host bütçesine indirmek.

**Mekanik katalog ID’leri:** M-001, M-003, M-047, M-056.

**Bağımlılıklar:** POL-02.

**BUILT_IN / RECOMMENDED_ADDON:** T14 AI LOD; T15 spatial hash; T16 pooling yalnız profiler gerekçesiyle; T29 mobile; T32 profiler; T33 Android export.

**Sistemler:** quality tiers, AI/path budgets, snapshot budgets, VFX cap, water shader/wake quality tierleri, trail resolution/lifetime ve eşzamanlı wake bütçesi, optional pools, texture/audio budget, load-time telemetry.

**Görsel/asset bağımlılığı:** Minimum sprite/VFX setinin gerçek dosyaları ölçülür.

**Android gereksinimi:** Ana kapsam; thermal throttling ve uzun oturum.

**LAN gereksinimi:** Android host/client throughput ve reconnect soak.

**Kabul kriterleri:** Hedef cihaz sınıfında tanımlanmış frame/memory/network ve water/VFX fill-rate bütçeleri aşılırsa trail çözünürlüğü/yaşam süresi, wake yoğunluğu ve içerik yoğunluğu kalite katmanıyla düşebilir; gameplay authority korunur.

**GitHub Actions doğrulaması:** Performance regression için deterministic entity-count benchmark; headless soak; export artifact size budget; leak-like growth checks mümkün olduğu ölçüde.

**Gerçek cihaz doğrulaması:** 30–60 dk offline soak, 30–60 dk LAN host soak, background/resume, thermal, battery, memory, Wi-Fi jitter.

**Sonraki görevi engelleyen kapı:** Gerçek cihaz budget ölçümü olmadan final content fill yoğunluğu kilitlenmez.

## POL-04 — İçerik doldurma, dengeleme ve final offline/LAN acceptance

**Amaç:** ICERIK_KATALOGU ve mekanik katalog kapsamasını veri odaklı içerikle doldurmak; canlı servis bağımlılığı yaratmadan final kabul matrisi oluşturmak.

**Mekanik katalog ID’leri:** M-035, M-054, M-057, M-060; ayrıca M-001…M-060 kapsama denetimi.

**Bağımlılıklar:** POL-03.

**BUILT_IN / RECOMMENDED_ADDON:** T17 seed; T21 quest; T23 data registry; T26 economy; T27 progression; T28 loot; T32 test/profiling; T33 localization/audio.

**Sistemler:** content packs, özgün balance tables, source/reference metadata, equipment/crew/pet/gem veri paketleri, quest-chain content packs, region escalation, local challenge rotations, validation reports, offline/LAN acceptance suite.

**Görsel/asset bağımlılığı:** Minimum ship set önce; tam 15 gemi ve ileri boss/monster içerikleri katmanlı olarak doldurulur. Hazır assetlerin lisans kaydı dosya-bazlı tutulur.

**Android gereksinimi:** İçerik hacmi arttıkça APK size, memory ve load time bütçesi tekrar ölçülür.

**LAN gereksinimi:** Aynı content hash zorunlu; mismatch join reddi.

**Kabul kriterleri:** M-001…M-060 her biri ya implemented/adapted ya da açıkça out-of-scope adaptation olarak izlenir; 767 kayıtlı araştırma girdisi source metadata ile izlenir ve SeaCraft'a özgü içerik/balance paketlerine dönüştürülür, forumdaki exact ad/değer/görsel doğrudan production içeriği sayılmaz; offline internet yokken tam oynanabilir; LAN host-authoritative acceptance suite geçer.

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
| A13 GDQuest Godot Shaders | RECOMMENDED_REFERENCE | POL-02 | `2D water in top-down view` shader/kod yaklaşımı; MIT kod tarafı uyarlanabilir, demo sanat varlıkları alınmaz; Godot 4.7.2 Compatibility + Android cihaz doğrulaması zorunlu |
| A14 GUT | RECOMMENDED_ADDON | FND-01 | Headless Godot 4.7 CI; release export’a dahil edilmez |
| A01 LANServerBroadcast | OPTIONAL, varsayılan değil | NET-04 | PacketPeerUDP özel çözüm yetersizse ve 4.7/Android doğrulanırsa |
| A02 netfox | OPTIONAL, varsayılan değil | NET-02 sonrası ölçüm | Yalnız ölçülen interpolation/prediction ihtiyacı varsa |
| A05 LimboAI | OPTIONAL alternatif | AI-01 sonrası | Beehave + custom FSM yetersizse; Android GDExtension yükleme kanıtı |
| A04 Godot SQLite | OPTIONAL | CORE-04 sonrası ölçüm | JSON persistence ölçeği gerçekten yetersizse |

# 5. TARİHSEL IMPLEMENTATION ORDER (geçersiz yürütme sırası)

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

Bu plan M-001’den M-060’a kadar mekanik kataloğunun tamamını en az bir görev paketine bağlar. AI-01…AI-30 maddeleri ise VS-02 ve AI-01…AI-04 görevlerinde uygulanabilir alt davranışlar olarak izlenir. İçerik kataloğunun güncel **767** somut kaydı, ilk vertical slice’ın ön koşulu değildir; resmî forumdan gelen exact değer/görseller doğrudan SeaCraft içeriğine kopyalanmadan, schema ve denge referansı olarak POL-04’e kadar veri paketleri halinde kademeli işlenir.

En kritik sıra kapısı şudur:

**FND-06 save → VS-04 offline vertical slice → AI-04 ölçeklenebilir authoritative dünya → NET-03 aynı vertical slice LAN parity → progression/economy → raid/boss → final UI/art → Android/performance → content fill.**
