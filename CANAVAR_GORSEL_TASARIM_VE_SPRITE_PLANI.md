# SeaCraft — Canavar Görsel Tasarımı ve Sprite Üretim Planı

**Tasarım ve üretim sözleşmesi · 2026-11-24 · Godot 4.7.2 · 2D/2.5D · Android/masaüstü · offline + LAN.** Kaynak snapshot: `201f90f3445e01a8f963f7241c498138c9f70d67`. Bu belge asset üretimi, kod entegrasyonu veya cihaz kabulü değildir. Tüm satırlar başlangıçta **planlandı**; M01–M15 özgün önerilen tasarım ID'leridir, mevcut runtime stable ID değildir.

**Bağlayıcı sadeleştirme (2026-11-24):** Her canavar gemiler gibi tek nötr, bütünleşik statik modelden 8 yön × 1 kare ve 1 atlas alır. Saldırı, yüzme, bekleme, hasar, ölüm ve boss fazı için ilave sprite/poz veya parça katmanı üretilmez. Kodla yapılabilen görsel hareket ve efektler serbesttir; özel boss istisnası ancak yeni açık kullanıcı onayıyla.

## 1. Kaynaklar, kapsam ve roster kararı

- [Gemi görsel planı](GEMI_GORSEL_TASARIM_VE_SPRITE_PLANI.md) ortak 55° ortografik kamera, dünya ölçeği, yön sırası ve karanlık denizcilik sanat sözleşmesidir. [Gemi üretim rehberi](GEMI_SPRITE_URETIM_REHBERI.md) 24 Kasım tarihli radial/üç alternatif/QA/12 dosya kurallarını içerir. Canavar uyarlaması: [CANAVAR_SPRITE_URETIM_REHBERI.md](CANAVAR_SPRITE_URETIM_REHBERI.md).
- [ICERIK_KATALOGU.md](ICERIK_KATALOGU.md) C-0164–0225, C-0248–0249, C-0683 farklı biyom, harpoon ve sualtı içeriklerinin çeşitlilik sinyalidir. Dış oyunun adları, sayıları, görselleri, desenleri ve statları kopyalanmaz; her kaynak satırına bir canavar gerekmez. C-0217/0223 enkazı canlı roster dışında.
- [MEKANIK_KATALOGU.md](MEKANIK_KATALOGU.md) M-014, M-057, M-060, AI-13/15: harpoon, bölge, direnç, territory, flee/charge/circle/pack/nest/boss. Buradaki **M01** görsel ID'leri katalogdaki **M-001** mekanik ID'leri değildir.
- [HAZIR_ASSET_ARASTIRMASI.md](HAZIR_ASSET_ARASTIRMASI.md) A-16 yalnız koşullu rig/proxy yöntem referansı; lisans teyidi olmadan asset kullanılmaz. [GELISTIRME_GOREV_PLANI.md](GELISTIRME_GOREV_PLANI.md) CORE-02 ve PLAY sırası korunur. Mevcut `monster.core02_practice` geçici test hedefi; M01'e otomatik eşleme yapılmaz.
- 15 özgün temel anatomi: 8 minimum yüzey, 4 ek yüzey, 3 ileri derinlik/sualtı. Minimum roster bir tasarım paketi, hepsini şimdi oyuna ekleme talimatı değildir. PLAY-01 ve PLAY-08/09 önceliklerini değiştirme; ileri boss/sualtı runtime üretimi ilgili kapıya kadar bekler. Pet, gemi boss'u, enkaz, çevre objesi, loot ikonu ve AI/stat kodu kapsam dışı.

## 2. MASTER ART DIRECTION

Fotogerçekçi karanlık denizcilik, ölçülü kozmik korku; gerçek deniz biyolojisinden özgün anatomi. Islak mat deri, yarı saydam ince yüzgeç kenarı, kıvrımlı pul, kalkerli kabuk, tuzlu yara izi, fosil kemik, seyrek parazit; biyolojik eklemler ve yük taşıyan kütle. Ahşap/keten gemi malzemesi yerine organik materyal. Koyu lacivert, kül, yosun yeşili, füme gri, soğuk kemik; boğuk pas/amber/koyu kırmızı vurgu yaklaşık ≤%3, emissive ≤%0,5. Neon, çizgi film, plastik, rastgele göz/uzuv, gereksiz diken, gemi parçalarıyla birleşmiş anatomi yok. Kara silüet okunur, kontrast su üzerinde kaybolmaz.

**Kamera:** Gemilerle aynı sabit paralel ortografik projeksiyon, yataydan 55°, roll 0°. Ekranda N yukarı, E sağ. Sekiz ekran yönü; 3D yaw hedefi +x'ten saat yönlü ekran açısı φ için atan2(sin φ / sin 55°, cos φ). Yalnız canlı/proxy yaw döner; kamera, ışık ve ölçek sabit. Ana ışık dünya üst-sol/NW, yaklaşık 60° yükseklik, soğuk geniş kaynak ve yumuşak dolgu. Karşı taraf aynalanmaz. Canavarın başı veya sabit anatomik ön ekseni yönü tanımlar; kuyruğun/kolun kıvrımı yön değildir. E/W kalibrasyonu, N/S doğal foreshortening.

**Yüzey:** Sadece su üstü görünür anatomi + su hattında doğru kesişim; kesilmiş su altı gövdesi sahnede ayrı sunulabilir. Su, köpük, gölge, yansıma, sis, kan bulutu, saldırı halkası ve wake sprite'a gömülmez. Sualtı rosterında bütün gövde görünür; z derinliği ve ışık kaybı runtime, gövde gerçek RGBA. Gövde üstündeki yerel AO serbest.

**Mobil kapı:** En küçük yön ekseni E/W 48 px, %75 zoom 36 px; farklı görünüşler aynı ölçekte. Üç ayrı deniz rengi ve gri ton, 1× ve %75 zoom. İki gözlemci rastgele N/E/NE/SW örneklerinde ilk üç türü en az 3/4 doğru tanır; sonrakiler en yakın siluet komşusuyla karşılaştırılır. Göz rengi değil kütle ve uzuvlar ayırt edici olmalı.

## 3. Tür fişleri

Boy L: tek nötr pozda burun–kuyruk uçları veya radyal/çok uzuvlu türde sabit ön–arka eksen üzerindeki anatomik ayak izi. L/B en geniş doğal gövde/uzuv ayak izine oran; dik boy ayrıca kılavuzda tutulur. Varyant yeni anatomi değildir. Tüm yönler aynı nötr anatomi ve pivotu korur.

### M01 · Tuz Dişi — Küçük kıyı avcısı
Rol: erken harpoon, sürü/kaçış; kıyı ve açık deniz. L/B 3,2:1. Tek baş, iki küçük yan yüzgeç, tek kısa sırt yüzgeci, çatallı kuyruk; alçak su hattı. Ayıraç: kama baş, iki diş çıkıntısı, tek üçgen sırt, çatal kuyruk. Füme mavi deri, kemik diş, az tuz lekesi. Sabit: 1 sırt, 2 yan, çatal kuyruk; varyant: küçük yara/pul tonu. Negatif: uzun yılan boynu, ikinci sırt, bacak yok. Nötr dengeli yüzüş; kaçış runtime.

### M02 · Kabuk Kıskaç — Zırhlı resif canavarı
Rol: territory/charge ve zırh telegraph; kayalık kıyı. L/B 0,9:1; oval kalkerli kabuk, tam 2 kıskaç ve 8 yürüme uzvu (dördü her taraf, occlusion doğal), sol kıskaç %20 daha iri. Ayıraç: asimetrik iki kıskaç, kubbe, yelpaze bacaklar. Koyu taş grisi, paslı kahve eklem, kemik kabuk çizgisi. Sabit: sol büyük kıskaç; varyant: kabuk aşınması. Negatif: ekstra uzuv, simetrik kıskaç, neon yok. Kıskaçlar nötr sabit; hücum tüm sprite'ın kodla hareketi ve efektle gösterilir.

### M03 · Kör Palamut — Hızlı orta avcı
Rol: dairesel yüzüş ve kısa kaçış; açık deniz. L/B 4,5:1; uzun iğ gövde, iki eğik göğüs yüzgeci, tek geriye yatık sırt yüzgeci, dik hilal kuyruk; dar kör göz çukuru. Ayıraç: uzun burun, hilal kuyruk, eğik sırt. Koyu zeytin-gri pul, açık kül yan çizgi. Sabit: hilal kuyruk, iğ ekseni; varyant: yan çizgi tonu. Negatif: M01 gibi kısa çatal kuyruk, iri çene, ek sırt yüzgeci yok. Nötr; sprint izi runtime.

### M04 · Dip Kamçısı — Deniz yılanı
Rol: pursuit/circle, menzilli sıçrama; açık deniz ve tropik. L/B 3,4:1 nötr sabit S eğrisi; bir dar baş, uzun tek omurga, iki kısa baş arkası kanatçık, ince terminal kuyruk. Ayıraç: iki doğal eğri, sivri burun, çift küçük kanatçık. Füme yeşil pul, seyrek kemik sırt plakası (5 adet). Sabit: 5 plaka, eğrinin anatomik tarafı; varyant: pul lekesi. Negatif: halkaya sarılma, kopuk kuyruk, ikinci baş yok. Tek sabit S eğrisi; hücum tüm sprite'ın kodla hareketiyle gösterilir.

### M05 · Kara Sırt — Büyük balina tipi otçul/territory
Rol: ağır yavaş hedef, bölge savunması; açık/soğuk deniz. L/B 2,8:1; geniş küt baş, iki iri göğüs paleti, tek küçük arka sırt, yatay iki loblu kuyruk. Ayıraç: fıçı sırt, geniş alın, yatay kuyruk, tek küçük sırt. Kömür deri, donuk açık yara izleri. Sabit: iki palet, yatay kuyruk; varyant: yara yerleri yalnız yeni konseptte sabitlenir. Negatif: balık dik kuyruk, boynuz, fıskiye sprite içinde yok. Su hattında nötr; nefes/splash ayrı.

### M06 · Yosun Kalkanı — Resif kabuklusu
Rol: pasif/defansif ağır av, resif. L/B 1,45:1; geniş basık altıgen kabuk, dört palet, küçük yuvarlak baş, kısa tek kuyruk. Ayıraç: basık zırh, dört kanat, kısa baş. Koyu yosun yeşili/kalker gri, kabuk üzerinde sınırlı tortu. Sabit: 4 palet ve altıgen kabuk; varyant: yosun yoğunluğu. Negatif: kıskaç, yükselen taş ada, 8 bacak yok. Yatay sabit gövde; savunma durumu renk/efekt ile gösterilir.

### M07 · Kül Vatozu — Alan tehditçisi
Rol: geniş süzülme ve elemental uyarı; sıcak/volkanik yüzey. L/B 0,95:1; tek baklava disk, iki geniş yan kanat, iki kısa ön lob, tek ince arka kamçı. Ayıraç: yassı kanat hattı, iki ön lob, uzun kamçı. Bazalt gri deri, boğuk pas kenar; parlama yok. Sabit: tek kamçı, disk geometrisi; varyant: kenar tonu. Negatif: manta yerine kuş kanadı, çoklu kuyruk, ateş kaplama yok. Disk nötr sabit; alan saldırısı ayrı runtime efekt.

### M08 · Boğuk Pençe — Yüzey kraken boss'u
Rol: büyük karşılaşma/territory, saldırı fazı; açık deniz. L/B 1,15:1 nötr uzuv yayılımı; tek armut manto, iki göz, tam 8 kol; ön-arka eksen göz çifti ve manto ucu ile kilitli. Ayıraç: iri manto, sekiz ayrı kol kökü, önde iki kalın kol, düşük arka yay. Islak morumsu kömür, küllü vantuz, çok az soluk yeşil. Sabit: 8 kol, iki göz, sağ ön kolda üç iz; varyant: ton, yara decal. Negatif: dokuzuncu kol, kopuk tentacle, gemi, su spirali yok. Sekiz kol tek nötr birleşik sprite'ta sabit; saldırı/faz kodlu hareket, renk ve ayrı telegraph ile gösterilir.

### M09 · Buz Çenesi — Kutup pusucusu
Rol: buz kıyısı/charge. L/B 3,0:1; geniş yassı baş, iki belirgin çene dişi, çift yan palet, tek kısa yatay kuyruk ve üç sırt çıkıntısı. Ayıraç: küt yassı kafa, iki diş, üç kısa çıkıntı. Füme mavi deri, kemik çıkıntı, lokal don. Sabit: üç çıkıntı ve yatay kuyruk. Varyant: don lekesi. Negatif: buz kristali halesi veya M05 fıçı sırtı yok. Nötr.

### M10 · Kor Omurga — Volkanik zırhlı balık
Rol: sıcak biyom/dirençli territory. L/B 2,6:1; ağır baş plakası, 6 sırt plakası, çift kalın yan yüzgeç, yuvarlak dik kuyruk. Ayıraç: altı ayrı plakalı sırt, baş kalkanı, tok arka. Kömür-bazalt, boğuk turuncu-kahve çatlak pigment; alev yok. Sabit: 6 plaka. Varyant: pas tonu. Negatif: lav ışığı, kıskaç, yılan gövdesi yok. Nötr.

### M11 · Sis Gagası — Yüzey kanatlı avcı
Rol: tropik/sisli kıyı, hızlı baskın; suya yakın yüzüş, uçuş runtime kapsamı dışı. L/B 1,65:1; iki dar geriye eğimli yüzgeç, tek kemiksi gaga, düz gövde, iki loblu kısa kuyruk. Ayıraç: gaga, geriye eğik dar yüzgeç çifti, iki lob. Koyu lacivert, kemik gaga, mat kahve benek. Sabit: iki yüzgeç, gaga; varyant: benek tonu. Negatif: tüy, kuş ayağı, M07 baklava disk yok. Nötr.

### M12 · Çan Boyun — Uzun boyunlu leviathan
Rol: ağır yüzey bölge tehdidi, geç oyun. L/B 2,2:1; bir uzun dik boyun ve küçük baş, dört palet, iri oval gövde, tek ince kuyruk. Ayıraç: kavisli uzun boyun, 4 palet, oval gövde. Koyu arduvaz, kemik boyun çıkıntıları (3). Sabit: 4 palet, 3 çıkıntı. Varyant: boyun lekesi. Negatif: iki boyun, yılan gibi gövdesiz biçim yok. Boyun nötr sabit; hücumda yalnız tüm sprite hareketi ve efekt.

### M13 · Kör Kandil — Derinlik pusu balığı
Rol: ileri sualtı hedefi; karanlık derinlik. L/B 2,1:1; tek iri baş/çene, tek alın uzantısı, çift küçük yan yüzgeç, tek sırt ve dar kuyruk. Ayıraç: çene, tek kandil ucu, ince arka. Kömür-siyah, donuk kemik diş, soluk amber nokta (ayrı emissive gerekirse). Sabit: 1 kandil, 2 yan. Varyant: ton. Negatif: ışık halesi, su kabarcığı veya iki kandil yok. Nötr tam gövde.

### M14 · Derin Yelkovan — Sualtı kalamarı
Rol: ileri sualtı takip/sürü. L/B 2,9:1; torpido manto, iki üçgen arka yüzgeç, 8 kısa kol + 2 uzun yakalama uzvu. Ayıraç: uzun manto, iki arka üçgen, iki uzun uç. Füme kahverengi/soğuk mor, soluk vantuz. Sabit: 8+2 uzuv. Varyant: pigment. Negatif: M08 yuvarlak manto, 8 eş uzun kol yok. Nötr tam gövde.

### M15 · Çukur Tacı — Derinlik leviathan boss'u
Rol: ileri sualtı çok fazlı boss. L/B 2,4:1; geniş kama çene, uzun kalın tek omurga, 2 iri göğüs paleti, 2 küçük arka palet, 5 kaburga plakası/borda ve tek yarıklı kuyruk. Ayıraç: çene boşluğu, çift palet çifti, 5+5 plaka. Koyu taş grisi/kemik, ölçülü hastalıklı teal pigment. Sabit: 4 palet, 10 plaka, sağ ilk plaka çentikli. Varyant: yara/ton. Negatif: göz yığını, tentacle, gemi enkazı, ışık bulutu yok. Çene ve plakalar nötr sabit; saldırı/faz renk, hareket ve ayrı efekt ile gösterilir. Tam gövde.

## 4. Ölçek ve tek yön standardı

SC-01 gemi E/W 60 dünya birimi = 60 ekran px (1× referans) (referans 1,00); canavar L değeri aynı dünyada ölçülür. Her tür kendi nötr pozunda aynı projeksiyon ölçeğine sahip; baş/kıç görüntüsü doğal kısalır. Çok uzuvlu türde genişlik/eklem işaretleri ayrıca ölçülür; bütün yönlerde anatomi ve gövde ölçeği değişmez. Her tür için gerçek metre eşdeğeri yalnız sanat referansıdır (60 birim ≈ 12 m); hitbox veya hasar ölçüsü değildir.

| ID | Birincil rol | L/B | E/W dünya L (1× ekran px) | Relative L/60 | Başlangıç gövde hedefi / hücre bütçesi | Paket |
|---|---|---:|---:|---:|---:|---|
| M01 | Küçük kıyı avcısı | 3,2 | 48 | 0,80 | 160 / 224 | Minimum |
| M02 | Zırhlı resif | 0,9 | 66 | 1,10 | 160 | Minimum |
| M03 | Hızlı açık deniz | 4,5 | 72 | 1,20 | 160 | Minimum |
| M04 | Deniz yılanı | 3,4 | 120 | 2,00 | 224 | Minimum |
| M05 | Ağır balina tipi | 2,8 | 132 | 2,20 | 224 | Minimum |
| M06 | Resif kabuklusu | 1,45 | 84 | 1,40 | 160 | Minimum |
| M07 | Alan tehdidi | 0,95 | 108 | 1,80 | 224 | Minimum |
| M08 | Yüzey boss | 1,15 | 246 | 4,10 | 384 | Minimum |
| M09 | Kutup pusu | 3,0 | 108 | 1,80 | 224 | Tam |
| M10 | Volkanik zırh | 2,6 | 126 | 2,10 | 224 | Tam |
| M11 | Sisli kıyı baskın | 1,65 | 90 | 1,50 | 224 | Tam |
| M12 | Uzun boyun | 2,2 | 180 | 3,00 | 320 | Tam |
| M13 | Sualtı pusu | 2,1 | 72 | 1,20 | 160 | Tam/ileri |
| M14 | Sualtı takip | 2,9 | 144 | 2,40 | 224 | Tam/ileri |
| M15 | Sualtı boss | 2,4 | 270 | 4,50 | 384 | Tam/ileri |

C ilk bütçedir, 8 px padding sığmazsa tüm yönlerde aynı üst sınıfa geç; tek yönde fit yasak. M02/M07 için genişlik ayrıca kılavuzdan kalibre edilir. M08/M15 nötr anatomisi yüksekse tam atlas bütçesi yeniden hesaplanır; kırpılmaz.

### Efektif sprite çözünürlüğü — zorunlu kabul kapısı (M01 dersi)

Dünya boyu, 1× ekranda gösterilen boy, kaynak nesne çözünürlüğü, final görünür gövde çözünürlüğü ve şeffaf hücre boyutu farklı ölçülerdir. Dünya boyu tablosu fizik/sunum oranını korur; final PNG'nin piksel yoğunluğunu sınırlamaz. **160 px veya 224 px doku hedefi, hücre etiketi değil görünür ana gövde/hull uzunluğu hedefidir.** Eski hücre sınıflarının sayısal değeri (160/224/320/384 px) yeni üretimde başlangıç gövde çözünürlüğü hedefidir; paketleme hücresi sonradan hesaplanır. M01 örneğinde 48 dünya birimi korunur; E/W görünür gövde 160 px hedeflenir, 224×224 hücre ve 896×448 atlas kullanılır. 160×160 hücre içinde 48 px gövde bu hedef için reddedilir.

- Her yeni asset için önce hedef gerçek E/W gövde/hull piksel uzunluğu belirle. E/W anatomik uçları ölç; diğer yönlerin doğal projeksiyon kısalmasını koru. Alfa≥128 bbox genişlik/yükseklik ve gerçek landmark uzunluğunu ayrı raporla; kopuk piksel veya direk yüksekliğini gövde uzunluğu sayma.
- Kaynak nesneleri gerçek alfa sınırından ayır, gereksiz boşluğu kaldır; yüksek çözünürlüklü temiz master'ı koru. Manuel hizalama JSON'u varsa onaylı göreli yön ölçeği ve pivot ofsetleri korunur. Son paketleme için sekiz yöne tek ortak uniform katsayı ve aynı pivot dönüşümü uygula; yön başına yeniden fit, x/y ayrı stretch veya merkez sıfırlama yok.
- Final hücreyi hedef gövde yoğunluğundan SONRA seç: tüm yönlerin ortak pivot etrafındaki alfa>0 sınırları + dört kenarda en az 8 px alpha-0. Gerekirse tüm seti daha büyük ortak hücreye geçir; hedefi sessizce küçültme. Gemi hasar/maskeleri varsa aynı dönüşüm ve hücre. Dünya boyunu korumak için runtime sunum ölçeği = dünya gövde uzunluğu / final referans gövde px; pivot-relative socket'lere de aynı dönüşüm uygulanır. Fizik/hitbox değişmez.
- Hedef E/W uzunluğu ±%3 ve diğer yönlerin kılavuz projeksiyon oranları kontrol edilir; final bbox, kaynak gerçek detay yoğunluğu, padding, atlas hücre eşitliği ve dönüş QA ölçülmeden teslim yok. Kaynak yetersizse kullanıcıya AI upscale gerekli bildir; interpolasyon veya boş tuval büyütme yeni detay değildir.
- HTML'de düşük çözünürlüklü (örn. 256²) gömülü önizleme serbest; aynı sanal 1024 koordinatı ve aynı çerçeve dönüşümü korunur. JSON final yüksek çözünürlüklü kaynaklara uygulanır; preview PNG final kaynak değildir. Final GIF final PNG'lerden, ayrı HD GIF temiz yüksek çözünürlüklü hizalanmış kaynaklardan yapılır. HD incelemede tüm karelere ortak sıkı güvenli tuval kullanılır; dev boş canvas yasak.
- Manifestte dünya uzunluğu, target_body_px, measured_body_px_per_direction, source_bbox_per_direction, final_bbox_per_direction, effective_fill_ratio (bbox genişlik/hücre, yükseklik/hücre), cell_px, atlas_px, ortak katsayı, pivot, runtime_world_per_texel ve varsa upgrade_reason kaydedilir. 12 dosya ZIP standardı değişmez. Eski paketler bu kapı yeniden ölçülmeden geçmiş sayılmaz.

## 5. Hücre, alfa, pivot ve Godot

- N=0°, NE=45°, E=90°, SE=135°, S=180°, SW=225°, W=270°, NW=315°; 4×2 atlas üst N NE E SE / alt S SW W NW. Sprite görünüşü en yakın sektör ±22,5°, 3° histerezis; hareket 360°. Yönler arasında gerçek fizik rotasyonu ile sprite rotasyonunu karıştırma.
- 1024² normalize yön master, 2048² konsept arşivi hedefi; ham üretim çözünürlüğü değildir. 160²/224²/320²/384² final hücre → 640×320/896×448/1280×640/1536×768 atlas. 8 bit sRGB straight RGBA, kenarlarda ≥8 px gerçek alpha-0; premultiplied filtrele ve straight döndür. Kenar halo/komşu piksel/ince uzuv testi.
- Pivot bütün yönlerde **aynı anatomik referans**: yüzeyde gövdenin ağırlık merkezinin su düzlemine izdüşümü (yılanda sabit orta omurga; kabukluda kabuk merkezi; krakende manto tabanı); sualtında ana gövdenin hareket kökü. Normalize (512,512), final (C/2,C/2). Bbox merkezi değil; 3D referans, eklem, göz ve su düzlemi işaretleriyle kilitle. Tolerans ≤1 final px pivot, hedef doku L ±%3, ana landmark ±2 final px ve yön ±2°; uzuv adedi/tarafı sıfır tolerans.
- Socket fişi: ağız/çene, sol/sağ saldırı noktası, harpoon hit gösterimi, wake kökü, loot görseli ve varsa zayıf nokta; görünürlük ve occlusion yön bazlı. Simülasyon hitbox'ı ayrı, resimden türetilmez.
- Godot sunumda AtlasTexture, filter_clip, repeat kapalı, merkez pivot, lineer filtre, ilk lossless/mip kapalı; tek 4×2 yön atlası, her yön için bir statik kare; animasyon frame zinciri yok. 384² ×8 RGBA8 atlas ~4,5 MiB; GPU belleği PNG boyutu değildir. Marker LOD, çoklu canavar + gemi + su/VFX Android profili ayrı kabul. Stable ID/HP/loot/harpoon/AI host authority değişmez; sunum eşlemesi ileride registry üzerinden açıkça tasarlanır.

## 6. Statik sprite ve kod tabanlı animasyon

**8 yön × tek kare.** Canavarın bütün anatomisi tek RGBA sprite'tır; yüzgeç, kuyruk, kol, çene, göz, kabuk ayrı katmanlara ayrılmaz. Yüzme/idle, saldırı, yaralanma, ölüm, dalma veya boss fazı için ek poz, frame seti, rig veya sprite sheet üretilmez. Kraken dahil istisnasız ilk üretim standardıdır.

- Yüzüş: gerçek 360° hareket, yön seçimi, 0,5–1° görsel rocking, ≤1 px heave; su izi ve köpük ayrı runtime efekt.
- Hücum: authoritative anticipation/active/recovery olayına göre bütün sprite'ta küçük geri çekilme/öne atılma ve dönüş, gerekirse kısa görsel ölçek/pulse; menzil ve isabet alanı değişmez. Isırma veya kol savurma için yeni anatomi resmi gerekmez; ses, su sıçraması ve telegraph ile anlatılır.
- Hasar/faz: modulate/flash, shader, ortak decal ve parçacık; ölüm: sönme, batma/mask, küçük dönüş ve splash. Dalma: maskeleme, renk ve alfa, gerçek derinlik durumundan ayrı sunum. Bunlar önerilen kod efektleridir, uygulanmış değildir.
- İleri deformasyon veya rig, ayrı uzuv, el çizimi ara kare veya ek boss atlası temel kapsam dışıdır. Sadece açık kullanıcı onayı ile istisna ve ayrı bütçe oluşturulabilir.
- Pigment/decal varyantı ayrı anatomi sayılmaz; ortak efektler yeniden kullanılır. Simülasyon hitbox, HP, target class, loot, cooldown ve LAN authority değişmez.

## 7. SPRITE PRODUCTION MATRIX

Her satır 1 konsept + 8 nötr statik yön + 1 atlas; başka poz veya katman yok. Kabul edilmiş varlıklar sayılır; üç radial aday/ret/upscale/QA ara çıktıları hariç.

| ID | C | 4×2 atlas | Tam yön PNG | Tam atlas | Tam concept dahil | Min concept dahil |
|---|---:|---|---:|---:|---:|---:|
| M01 | 224 | 896×448 | 8 | 1 | 9 | 9 |
| M02 | 160 | 640×320 | 8 | 1 | 9 | 9 |
| M03 | 160 | 640×320 | 8 | 1 | 9 | 9 |
| M04 | 224 | 896×448 | 8 | 1 | 9 | 9 |
| M05 | 224 | 896×448 | 8 | 1 | 9 | 9 |
| M06 | 160 | 640×320 | 8 | 1 | 9 | 9 |
| M07 | 224 | 896×448 | 8 | 1 | 9 | 9 |
| M08 | 384 | 1536×768 | 8 | 1 | 9 | 9 |
| M09 | 224 | 896×448 | 8 | 1 | 9 | 0 |
| M10 | 224 | 896×448 | 8 | 1 | 9 | 0 |
| M11 | 224 | 896×448 | 8 | 1 | 9 | 0 |
| M12 | 320 | 1280×640 | 8 | 1 | 9 | 0 |
| M13 | 160 | 640×320 | 8 | 1 | 9 | 0 |
| M14 | 224 | 896×448 | 8 | 1 | 9 | 0 |
| M15 | 384 | 1536×768 | 8 | 1 | 9 | 0 |
| **Toplam** | | | **120** | **15** | **135** | **72** |

| Kalem | Minimum | Tam (minimum dahil) |
|---|---:|---:|
| Temel anatomi/konsept | 8 | 15 |
| Statik yön PNG | 64 | 120 |
| Ek animasyon/faz sprite'ı | 0 | 0 |
| Konsept dahil kabul görseli | 72 | 135 |
| Canavar gövde atlası | 8 | 15 |
| Final ZIP (tür başına bir) | 8 | 15 |

Ortak su, harpoon, hit ve telegraph VFX gemi hattından ve runtime kodundan yeniden kullanılır; canavar başına yeni efekt atlası zorunlu değildir. 12 dosyalık paket standardı değişmez (8 PNG, atlas, dönüş GIF, manifest, orijinal kaynak).

## 8. GPT IMAGE PRODUCTION ORDER

İlk üç **M01 → M02 → M03** için konsept, nötr anatomi ve sekiz yön birlikte kilitlenir; her biri görsel/mobile kapısını geçmeden sonraki benzer türlere çıkılmaz. Minimum: M01–M08, tam: M09–M15 eklenir. Her tür için yalnız bir nötr sekiz yön seti üretilir. İleri runtime içerikleri PLAY kapısına kadar bekler; görsel plan hazırlığı mevcut geliştirme işini değiştirmez.

Her sette kare 1:1, ayrı üç radial seçenek, kullanıcı seçimi, kesim, gerçek kaynak çözünürlüğü kapısı, anatomi-temelli hizalama, organik renk, manuel QA, 4×2 atlas ve 12 dosya standardı uygulanır. Sorunlu yön aynı konsept + hedef 3D yön ile ayrı yeniden üretilir; ayna yok. Ayrıntılı adımlar ve kopyalanabilir prompt: [CANAVAR_SPRITE_URETIM_REHBERI.md](CANAVAR_SPRITE_URETIM_REHBERI.md).

## 9. Üretim takip ve kabul

| ID | Konsept | Statik 8 yön | ZIP | Runtime/cihaz |
|---|---|---|---|---|
| M01 | Planlandı | Planlandı | Yok | not_run |
| M02 | Planlandı | Planlandı | Yok | not_run |
| M03 | Planlandı | Planlandı | Yok | not_run |
| M04 | Planlandı | Planlandı | Yok | not_run |
| M05 | Planlandı | Planlandı | Yok | not_run |
| M06 | Planlandı | Planlandı | Yok | not_run |
| M07 | Planlandı | Planlandı | Yok | not_run |
| M08 | Planlandı | Planlandı | Yok | not_run |
| M09 | Planlandı | Planlandı | Yok | not_run |
| M10 | Planlandı | Planlandı | Yok | not_run |
| M11 | Planlandı | Planlandı | Yok | not_run |
| M12 | Planlandı | Planlandı | Yok | not_run |
| M13 | Planlandı | Planlandı | Yok | not_run |
| M14 | Planlandı | Planlandı | Yok | not_run |
| M15 | Planlandı | Planlandı | Yok | not_run |

Her kabul satırına gerçek kaynak, seçilen varyant, revizyon, atlas/ZIP SHA, görüntü QA ve runtime/device kanıtı ayrı yazılır. Oyun test hedefinin varlığı asset kabulü değildir. Bu belgenin oluşturulması roster, rehber ve bütçe tasarımını tamamlar; tek bir sprite bile üretilmiş sayılmaz.
