# SESSION HANDOFF — SOHBET-31 / SeaCraft NET-04

> Bu kayıt 2026-11-22 tarihinde kullanıcının açık “yeni sohbete devret, hiçbir şeyi eksik bırakma” talebiyle oluşturuldu.
> Yeni sohbet bu dosyayı **başlangıç bağlamı** olarak kullanmalı; fakat her zaman uzak `main` HEAD'i yeniden doğrulamalı.
> Ayrıntılı NET-04 uygulama sözleşmesinin kanonik kaynağı `AKTIF_GOREV.md` dosyasıdır. Bu devir kaydı o briefin yerine geçmez; mevcut gerçek durumu, kanıt zincirini ve devam noktasını sabitler.

## 1. Kullanıcı çalışma biçimi

- Türkçe ve kısa sonuç ver.
- Gerçek proje işinde plan/ilk commit/workflow başlatmakla yetinme; uygula → doğrula → hata varsa düzelt → yeniden doğrula → exact sonucu teslim et.
- Aynı işi sürdürmek için kullanıcıdan tekrar “devam et” isteme.
- Kullanıcı uzun worker promptlarını sohbette görmek istemiyor.
- Uzun görev briefi yalnız `AKTIF_GOREV.md` içinde tutulur.
- Ayrıntılı görev sonucu yalnız tek kanonik `GOREV_RAPORU.md` dosyasına yazılır; yeni sonuç dosyaları açılmaz.
- Sohbette yalnız kısa worker promptu / kısa kapanış sonucu verilir.
- Branch/PR açma; SeaCraft için hedef yalnız `main`.
- Başka sohbetin veya paralel işin değişikliklerini ezme.
- Test veya güvenlik kontrollerini sırf CI yeşil olsun diye kaldırma/zayıflatma.
- Gerçek cihaz çalışmadıysa `not_run`; CI'ı fiziksel Android testi gibi gösterme.
- WAVE 6 progression/content görevlerine NET-04 kapanmadan başlama.

## 2. Zorunlu başlangıç sırası

Yeni sohbet gerçek işe başlamadan:

1. `skills://plugins/termux-toolkit/osman-operating-system/skill.md`
2. Gerekirse `github-safe-operations`, `production-verification`, `avenox-brain`
3. `TheOsmanYILDIRIM/SeaCraft/main` güncel HEAD
4. `AKTIF_GOREV.md`
5. bu `SESSION_HANDOFF.md`
6. `GOREV_RAPORU.md`
7. `GELISTIRME_GOREV_PLANI.md` NET-04
8. `README.md` NET-03/NET-04
9. Avenox Beyin mevcut NET-04 taskı

okunmalı.

Bu dosyanın oluşturulduğu anda repo root'ta daha önce `SESSION_HANDOFF.md`, `TASKS.md` veya `AGENTS.md` yoktu.

## 3. Repo ve doğrulanmış güncel nokta

Repo: `TheOsmanYILDIRIM/SeaCraft`  
Dal: `main`  
Godot: `4.7.2-stable`

Bu handoff hazırlanırken doğrulanmış HEAD:

`76228c99e9c5b214bf8191a78aec9da63f8d0f22`

Commit:

`ci: harden NET-03 real-process long transit budget`

Tree:

`1e0de6b8ec474208a567b35cadd054be4f9d0ee9`

NET-04 brief hazırlama commit'i:

`6524b03ed472aec4ff0aa60403770052673d08b8`

Mevcut HEAD bu brief commit'inden **50 commit ileride**. Bu 50 commitin tamamı NET-04 değildir; paralel sprite/look-pipeline değişiklikleri de vardır. Dolayısıyla reset/rebase/force veya “NET-04 öncesine dön” yaklaşımı kesinlikle kullanılmamalı.

## 4. Genel proje ilerlemesi

NET-03 kapanışı dahil doğrulanmış tamamlanan plan görevleri:

- FND-01..FND-06
- VS-01..VS-04
- CORE-01..CORE-04
- AI-01..AI-04
- NET-01
- NET-02
- NET-03

Toplam: **21/35**.

NET-04 henüz tamamlanmadı. NET-04 kapanırsa ilerleme **22/35** olur.

## 5. NET-03 kesin kapanış kanıtı

NET-03 exact kod SHA:

`f0cd18727870d6d49b961c758e49660e53770479`

Başarılı Actions:

- run `44966391971`
- run #174
- conclusion: `success`

Test:

- GUT `325/325`
- NET-03 `9/9`
- orphan `0`
- gerçek ayrı process: 1 host + 1 client
- full vertical slice + combat disconnect
- semantic digest:
  `2c9cea2fb6cad5e2ca5226d7a1f6e30fb944f594413c2572943ca04a31d22693`

Doğrulanan NET-03 davranışı:

- remote move host ShipMotor
- remote target CombatAuthority
- remote fire host-derived actor/heading
- client outcome mutation reddi
- host-only AI
- client AI decision count 0
- AI zinciri `PATROL → ALERT → RETREAT → REPAIR → RESUME`
- 5 accepted fire
- 1 sunk
- 1 drop
- 1 claim
- 2 salvage
- duplicate sequence / duplicate claim ikinci ödül üretmedi
- combat sırasında disconnect sonrası host state/AI/loot ledger korundu

NET-03 artifact:

- ID `14731951086`
- ad `SeaCraft-NET03-f0cd18727870d6d49b961c758e49660e53770479`
- ZIP SHA256 `3c8fe99b0946fe46bf8d829093cc84f1d9ae60a3a97cfbd9aa04b49fde864e1d`
- APK SHA256 `486f06f23087df366ef4c539e32b2d7b90b8b9bceea7c1ba60b1cfc88206dd25`
- Linux executable SHA256 `1a291d3d15e4180b60b0af96cf6458f11fe143636d76575ddf1e23d1a3f24f2e`
- Linux PCK SHA256 `f47d44ca43cd4649415520c188f7df70c4baa3e7dca8f135e45fa9d19043c97f`

NET-03 Beyin:

- task `tasks/seacraft-net03-vertical-slice-lan-parity-20261122.md`
- status `done`
- revision `2`
- receipt `receipts/17cca67ee6a7f677f93d10f87d190fb5424d6208d89e65a5e8d439e01680ae25.md`
- Beyin close commit `9454df4cba6eacd02e824ca62e39b4d5e2f0b00c`
- fiziksel Android Wi-Fi: `not_run`

`GOREV_RAPORU.md` içinde `## SOHBET-30 — SeaCraft NET-03 — Vertical Slice LAN Parity` bölümü vardır.

## 6. Aktif görev: NET-04

Exact sohbet etiketi:

`[SOHBET-31 | SeaCraft NET-04 — Discovery, Reconnect, Late Join ve LAN Transaction Hardening]`

Kanonik tam brief:

`AKTIF_GOREV.md`

Plan bölümü:

`GELISTIRME_GOREV_PLANI.md > NET-04 — Discovery, reconnect, late join ve LAN transaction hardening`

Planın ana kapıları:

- PacketPeerUDP discovery
- discovery/game ENet port ayrımı
- bounded beacon / TTL / rate limit
- reconnect token + session mapping
- late-join baseline
- transaction IDs / duplicate reward koruması
- parser fuzz
- protocol mismatch
- Android 17 / target SDK 37 / ACCESS_LOCAL_NETWORK
- real discovery + reconnect + late join + lost-ACK process senaryosu
- NET-03/02/01 + AI/CORE/VS regressionları
- export + artifact readback
- Beyin strict kapanışı
- WAVE 6 başlamaz

## 7. NET-04 kodu gerçekten repo içinde

README artık bir `## NET-04 LAN hardening` bölümü içeriyor; ancak bu **doğrulanmış kapanış değildir**.

Brief commit `6524b03...` ile güncel HEAD arasındaki NET-04 üretim değişiklikleri arasında şunlar var:

Yeni:

- `src/network/host_transaction_ledger.gd`
- `src/network/lan_discovery_client.gd`
- `src/network/lan_discovery_host.gd`
- `src/network/lan_discovery_protocol.gd`
- `src/network/lan_permission_gate.gd`
- `tests/unit/test_net04_lan_hardening.gd`
- `tools/ci/run_net04_process_integration.sh`
- `tools/ci/verify_net04_suite.py`
- `tools/net04/client_a.gd`
- `tools/net04/client_b.gd`
- `tools/net04/host_fixture.gd`
- `tools/net04/process_harness.gd`
- `tools/net04/process_harness.tscn`

NET-04 nedeniyle değişen ana production dosyaları:

- `src/network/network_entity_registry.gd`
- `src/network/network_replication_peer.gd`
- `src/network/session_client.gd`
- `src/network/session_host.gd`
- `src/network/session_protocol.gd`
- `src/network/session_rpc_bridge.gd`
- `.github/workflows/ci.yml`
- `export_presets.cfg`
- `README.md`

NET-03 harness üzerinde de NET-04 CI regresyon güvenilirliği için değişiklik var:

- `tools/net03/client_driver.gd`
- `tools/net03/host_fixture.gd`
- `tests/unit/test_net03_vertical_slice.gd`

## 8. NET-04 mevcut implementasyon sözleşmeleri

Güncel kod/README'e göre implementasyon şu yönde:

- network protocol version: **3**
- UDP discovery ENet gameplay socketinden ayrı
- beacon max 512 byte UTF-8 JSON
- beacon cadence 500 ms
- client TTL 2500 ms
- visible session cap 16
- discovery listing authority değildir; ENet handshake yine zorunlu
- manual IPv4 korunur
- host başına `session.*` identity
- reconnect grace 30000 ms
- reconnect token entropy 128 bit
- resume aynı player mapping ve sequence continuity hedefler
- başarılı resume token rotate eder
- late join/reconnect READY öncesi reliable baseline alır
- baseline snapshot/event watermark taşır
- claimed loot current baseline'da geri gelmez
- `pickup_loot` transaction ID ile idempotent retry sözleşmesine geçirilmiştir
- `HostTransactionLedger` bounded snapshot/restore taşır
- Android export target SDK 37 hedeflenmiştir
- INTERNET korunur
- ACCESS_LOCAL_NETWORK eklenmiştir
- permission gate yalnız açık LAN aksiyonunda devreye girer
- offline boot socket/permission/reconnect açmamalıdır
- host migration / relay / NAT punch / account auth / encryption kapsam dışıdır

Bunların unit-test seviyesinde çoğu doğrulanmış olsa da full real-process + export/artifact kapanışı henüz yoktur.

## 9. NET-04 unit/GUT kanıtı

Latest run `44972652533`, exact SHA `76228c99...` üzerinde:

- Scripts: `23`
- Tests: `338`
- Passing Tests: `338`
- Asserts: `28007`
- `All tests passed!`
- NET-04: `13/13`

Geçen NET-04 markerları:

- `NET04_DISCOVERY_PROTOCOL_OK`
- `NET04_DISCOVERY_FUZZ_OK count=2000 seed=20261122`
- `NET04_DISCOVERY_TTL_OK ttl_ms=2500 max_visible=16`
- `NET04_RECONNECT_TOKEN_OK entropy_bits=128`
- `NET04_RECONNECT_SEQUENCE_OK grace_ms=30000`
- `NET04_LATE_JOIN_BASELINE_OK entities=1 watermarks=1`
- `NET04_BASELINE_RECONCILE_OK same_sequence=1`
- `NET04_TRANSACTION_IDEMPOTENCY_OK cached=1 conflict=1`
- `NET04_TRANSACTION_PERSISTENCE_OK entries=1`
- `NET04_PERMISSION_FALLBACK_OK permission=android.permission.ACCESS_LOCAL_NETWORK`
- `NET04_OFFLINE_BOOT_OK manual_ipv4=1 discovery_autostart=0`
- `NET04_NETWORK_BOUNDARY_OK`
- `NET04_PROTOCOL_MISMATCH_OK version=3`

Dolayısıyla unit/pure-contract tarafı yeşildir. Kapanışı engelleyen kısım gerçek process/regression zinciridir.

## 10. CI başarısızlık zinciri — kritik devir bilgisi

NET-04 üzerinde çok sayıda correction commit/run oluştu. Eski hata sınıflarını yeniden araştırıp aynı denemeleri tekrarlama.

Önemli runlar:

- `44969924758` — SHA `8bc690ab1a06c6e3bae87c6c9a10c3ae37a04160` — failure
- `44970165376` — SHA `f3338a53b724baff00c609180a493ccff5fd9566` — cancelled
- `44970217652` — SHA `339ce951c29fe16f41a7a5c4a6833203adfde13a` — cancelled
- `44970309230` — SHA `f7eed7b20a8a247ff2303f113cdace5b9291964b` — failure
- `44970473753` — SHA `e0f259e7302683dd64f498c8243194d0af91508b` — failure
- `44970636932` — SHA `9d68119b13787fbaefea5a9dbb52ce134719ef21` — failure
- `44970821152` — SHA `c15d22b1cbebc095ef2a6ef8404f626bc0cd9833` — failure
- `44971088280` — SHA `4d5ee8bebdac134aced919566f20049c607eaef5` — failure; GUT + NET01 + NET02 + NET03 geçti, NET04 real process adımında durdu
- `44971602502` — SHA `c5413a84ce3fd77f63c3507073b28d8d66ef16db` — failure
- `44971781694` — SHA `93710d75b64ee2386f93db0ddff131bb7a637710` — failure
- `44972053272` — SHA `34857e336eed09a89e27372f48d5548747c288cf` — failure
- `44972238605` — SHA `888f0cd56f02f67f454674776b97cc2eb0d5b06b` — failure
- `44972652533` — SHA `76228c99e9c5b214bf8191a78aec9da63f8d0f22` — failure

Önemli correction başlıkları arasında:

- `fix process harness child wait ownership`
- `fix reconnect token test parse error`
- `preserve baseline header until completion signal`
- `preserve first and resumed gameplay sequence after baseline`
- `do not consume gameplay sequence for baseline readiness ack`
- `restore gameplay intent sequence advancement`
- `reconcile existing mirrors from authoritative baseline`
- `make baseline authoritative over pre-handshake spawns`
- `verify baseline reconciliation regression`
- `surface late-join process failure diagnostics`
- `report late-join state on process failure`
- `harden NET-03 real-process long transit budget`

vardır.

## 11. En değerli ara kanıt: SHA 34857e...

Run `44972053272`, SHA:

`34857e336eed09a89e27372f48d5548747c288cf`

şunu kanıtladı:

- GUT 338/338 yeşil
- NET-01 gerçek process yeşil
- NET-02 gerçek process yeşil
- NET-03 gerçek vertical-slice process **yeşil**
- NET-03 verifier **yeşil**
- NET-04 unit testleri yeşil
- sonra `NET-04 real UDP discovery reconnect late-join and lost-ACK transaction integration` adımı failure verdi

O runın NET-04 shell script'i child process loglarını yeterince yüzeye çıkarmadığı için exact child root-cause logu CI ana logunda görünmedi.

Bundan sonra şu diagnostic commitler eklendi:

- `846319ff44fc59669b8548522266e4ae703688fc` — `net04: surface late-join process failure diagnostics`
- `888f0cd56f02f67f454674776b97cc2eb0d5b06b` — `net04: report late-join state on process failure`

Ancak bu runlardan itibaren NET-04 stepine gelmeden NET-03 process zamanlama problemi ortaya çıktı.

## 12. Şu anki exact blocker

En güncel run:

`44972652533`

Exact SHA:

`76228c99e9c5b214bf8191a78aec9da63f8d0f22`

Conclusion:

`failure`

Geçen adımlar:

- setup/import/parse
- headless boot
- GUT full suite 338/338
- NET-01 process + verifier
- NET-02 process + verifier

Takılan adım:

`NET-03 real host and client vertical-slice parity and combat disconnect`

Exact hata:

Client:

`ERROR: NET03_PROCESS_FAILURE: client stage timeout: authoritative arrival`

Host:

`ERROR: NET03_PROCESS_FAILURE: host authoritative movement did not arrive`

Öncesinde client markerları çıkmış:

- `NET03_CLIENT_READY case=full player=entity.player`
- `NET03_REMOTE_MOVE_OK`
- `NET03_REMOTE_TARGET_OK`
- `NET03_REMOTE_FIRE_OK`
- `NET03_AI_PARITY_OK client_decisions=0`
- `NET03_COMBAT_REPLICATION_OK`

Yani NET-03 uzun “authoritative arrival” geçişinde bekleme/varış güvenilirliği bozuluyor.

### Çok önemli teşhis sınırı

`34857e...` ile current `76228c...` arasında yalnız **3 commit** vardır ve production network dosyası değişmemiştir.

Bu aralıkta değişen dosyalar yalnız:

- `tools/ci/run_net04_process_integration.sh`
- `tools/net03/host_fixture.gd`
- `tools/net04/client_b.gd`

Dolayısıyla son NET-03 kırılması için production protocol regression kanıtı yoktur; en güçlü mevcut kanıt **NET-03 harness/timing reliability** sorunudur.

Ama bunu “kesin flake” deyip sadece rerun etme. Root cause'u harness akışı / movement arrival assertion / timeout bütçesi üzerinden düzelt ve tekrar exact commit CI çalıştır.

Latest commit `76228c99...` zaten `tools/net03/host_fixture.gd` içinde “long transit budget” düzeltmesi denedi, fakat yeterli olmadı.

## 13. NET-04 gerçek process için sonraki nokta

Önce NET-03 regression tekrar güvenilir yeşil olmalı.

Sonra NET-04 process adımına yeniden ulaş.

NET-04 process kanonik hedefi:

- 1 host
- client A
- client B late join
- real UDP PacketPeerUDP discovery
- A discovery ile host bulur
- A baseline sonrası READY
- world ilerler
- loot transaction T bir kez commit olur
- ACK kaybolmadan/sonra transport kopuş senaryosu
- B late join current baseline
- claimed loot geri gelmez
- A same session/token ile resume
- same player mapping
- fresh baseline
- transaction T retry → cached result, ikinci reward yok
- old/malformed token reject
- malformed discovery packet burst ENet sessionı bozmaz
- clean shutdown
- TTL expiry

Diagnostic commitler late-join failure state'ini artık loglamalı. NET-03 düzeldikten sonra elde edilen yeni NET-04 process logunu esas al; eski tahminle kod yazma.

## 14. NET-04 henüz tamamlanmayan kapanış parçaları

Şu anda:

- NET-04 real process: **not passed**
- NET-04 verifier: son runlarda step'e ulaşmadı / skipped
- Android target 37 export: **son exact run için not_run**
- Linux export: **son exact run için not_run**
- Artifact: **yok**
- Artifact authenticated readback: **yok**
- fiziksel Android 17 permission allow/deny/revoke: **not_run**
- same-Wi-Fi desktop↔Android: **not_run**
- background→foreground reconnect: **not_run**
- `GOREV_RAPORU.md` NET-04 bölümü: **yok**
- Beyin NET-04 strict close: **yok**
- WAVE 6: **başlanmamalı**

NET-04 tamamlandı deneme.

## 15. Avenox Beyin NET-04 durumu

Tek mevcut kanonik task:

`tasks/seacraft-net04-lan-hardening-20261122.md`

Beyin main'de görülen durum:

- id: `seacraft-net04-lan-hardening-20261122`
- status: `blocked`
- revision: `1`

Bu task, kod başlamadan önce “Godot 4.7.2 + Android SDK37/Gradle validation environment” blockerı ile açılmıştı.

**Bu blocker metni artık güncel repo gerçeğini temsil etmiyor:** Godot CI çalışıyor ve NET-04 kodu repo içinde. Taskı silme veya yeni task açma. Aynı kanonik task kapanışta resmî Avenox DirectSync yolu ile doğru exact evidence kullanılarak revizyonlanmalıdır.

Ara CI failure'ları için yeni receipt/task yaratma.

Kapanışta yalnız:

- exact successful code SHA
- successful Actions
- test/process evidence
- export
- artifact readback
- Android status
- tek done revision
- tek receipt

ile kapat.

## 16. GOREV_RAPORU.md durumu

`GOREV_RAPORU.md` en son doğrulanmış kapanış olarak NET-03'ü içeriyor.

Henüz şu bölüm yok:

`## SOHBET-31 — SeaCraft NET-04 — Discovery, Reconnect, Late Join ve LAN Transaction Hardening`

NET-04 gerçekten kapanana kadar ekleme.

Kapanınca geçmişi koruyarak aynı dosyaya tek NET-04 bölümü ekle. Ayrı rapor dosyası oluşturma.

## 17. Paralel / ilgisiz değişiklikleri koru

NET-04 brief commit'i ile current HEAD arasında paralel sprite/look pipeline işi de girdi.

Compare'da NET-04 dışı görülen örnekler:

- `GEMI_SPRITE_URETIM_REHBERI.md`
- `SC01_SIS_IGNESI_GITHUB_UPLOAD.zip`
- `tools/seacraft_showlook.py`

Bunları NET-04 düzeltmesi yaparken silme, revert etme veya eski tree ile ezme.

Her yazmadan önce current HEAD'i yeniden oku ve CAS/expected SHA kullan.

## 18. Mimari kırmızı çizgiler

Korunacak:

- simulation/data/persistence network bağımsızlığı
- network API yalnız `src/network/**` tarafında
- client outcome mutation yok
- actor identity peer→player host mappingden
- host authority truth source
- stable IDs / bounded primitive DTO
- protocol/content compatibility handshake
- offline boot network-free
- Beehave manual/detached scheduler sınırı
- no client lockstep truth
- no host migration
- no internet relay
- no NAT punch
- no cloud lobby/account auth
- reconnect token discovery beacon/log içinde yok
- physical Android evidence CI diye gösterilmez

## 19. Kapanış için exact yapılacaklar

Yeni sohbet, kullanıcının tekrar “devam” demesini beklemeden:

1. current HEAD'i yeniden doğrula
2. latest NET-03 real-process failureı kök nedeninden düzelt
3. full exact CI çalıştır
4. başarısızsa tüm ilgili logları aç, correction yap ve yeniden çalıştır
5. NET-04 real process markerlarını gerçek process üzerinden geçir
6. NET-04 verifier geçir
7. tüm eski NET/AI/CORE/VS regressionları geçir
8. orphan=0 doğrula
9. Android targetSdk 37 + INTERNET + ACCESS_LOCAL_NETWORK export/readback doğrula
10. Linux export + boot doğrula
11. `SeaCraft-NET04-<exact SHA>` artifact oluştur
12. authenticated artifact readback + COMMIT_SHA + SHA256SUMS doğrula
13. fiziksel cihaz yoksa açık `not_run`
14. mevcut Beyin NET-04 taskını duplicate yaratmadan strict done/receipt ile kapat
15. `GOREV_RAPORU.md` içine tek NET-04 kapanış bölümü yaz ve geri oku
16. WAVE 6'ya başlama
17. ancak bütün bunlar geçerse NET-04 done ve proje 22/35

## 20. Yeni sohbet için kısa başlangıç komutu

Yeni sohbet uzun brief üretmesin. Bu komut yeterli:

`TheOsmanYILDIRIM/SeaCraft/main üzerindeki SESSION_HANDOFF.md ve AKTIF_GOREV.md dosyalarını oku. SOHBET-31 / NET-04 işini son doğrulanmış noktadan doğrudan sürdür. Önce güncel HEAD ve latest Actions'ı doğrula; açık failureı düzelt, CI/export/artifact/Beyin/report kapanışına kadar durma. WAVE 6'ya başlama.`

