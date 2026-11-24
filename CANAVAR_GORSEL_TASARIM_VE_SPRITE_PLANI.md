# SeaCraft — Canavar Görsel Tasarımı ve Sprite Üretim Planı

**Tasarım ve üretim sözleşmesi · 2026-11-24 · Godot 4.7.2 · 2D/2.5D · Android/masaüstü · offline + LAN.** Kaynak snapshot: `201f90f3445e01a8f963f7241c498138c9f70d67`. Bu belge asset üretimi, kod entegrasyonu veya cihaz kabulü değildir. Tüm satırlar başlangıçta **planlandı**; M01–M15 özgün önerilen tasarım ID'leridir, mevcut runtime stable ID değildir.

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

Boy L: nötr B pozunda burun–kuyruk uçları veya radyal/çok uzuvlu türde sabit ön–arka eksen üzerindeki anatomik ayak izi. L/B en geniş doğal gövde/uzuv ayak izine oran; dik boy ayrıca kılavuzda tutulur. Varyant yeni anatomi değildir. A ve P ek pozları aynı kimliği ve pivotu korur.

### M01 · Tuz Dişi — Küçük kıyı avcısı
Rol: erken harpoon, sürü/kaçış; kıyı ve açık deniz. L/B 3,2:1. Tek baş, iki küçük yan yüzgeç, tek kısa sırt yüzgeci, çatallı kuyruk; alçak su hattı. Ayıraç: kama baş, iki diş çıkıntısı, tek üçgen sırt, çatal kuyruk. Füme mavi deri, kemik diş, az tuz lekesi. Sabit: 1 sırt, 2 yan, çatal kuyruk; varyant: küçük yara/pul tonu. Negatif: uzun yılan boynu, ikinci sırt, bacak yok. B: dengeli yüzüş; kaçış runtime.

### M02 · Kabuk Kıskaç — Zırhlı resif canavarı
Rol: territory/charge ve zırh telegraph; kayalık kıyı. L/B 0,9:1; oval kalkerli kabuk, tam 2 kıskaç ve 8 yürüme uzvu (dördü her taraf, occlusion doğal), sol kıskaç %20 daha iri. Ayıraç: asimetrik iki kıskaç, kubbe, yelpaze bacaklar. Koyu taş grisi, paslı kahve eklem, kemik kabuk çizgisi. Sabit: sol büyük kıskaç; varyant: kabuk aşınması. Negatif: ekstra uzuv, simetrik kıskaç, neon yok. A: sol kıskaç kaldırılmış, diğer eklemler aynı; taban merkezi sabit.

### M03 · Kör Palamut — Hızlı orta avcı
Rol: dairesel yüzüş ve kısa kaçış; açık deniz. L/B 4,5:1; uzun iğ gövde, iki eğik göğüs yüzgeci, tek geriye yatık sırt yüzgeci, dik hilal kuyruk; dar kör göz çukuru. Ayıraç: uzun burun, hilal kuyruk, eğik sırt. Koyu zeytin-gri pul, açık kül yan çizgi. Sabit: hilal kuyruk, iğ ekseni; varyant: yan çizgi tonu. Negatif: M01 gibi kısa çatal kuyruk, iri çene, ek sırt yüzgeci yok. B: nötr; sprint izi runtime.

### M04 · Dip Kamçısı — Deniz yılanı
Rol: pursuit/circle, menzilli sıçrama; açık deniz ve tropik. L/B 3,4:1 nötr sabit S eğrisi; bir dar baş, uzun tek omurga, iki kısa baş arkası kanatçık, ince terminal kuyruk. Ayıraç: iki doğal eğri, sivri burun, çift küçük kanatçık. Füme yeşil pul, seyrek kemik sırt plakası (5 adet). Sabit: 5 plaka, eğrinin anatomik tarafı; varyant: pul lekesi. Negatif: halkaya sarılma, kopuk kuyruk, ikinci baş yok. A: baş öne uzanır, orta gövde pivotu ve uzunluk korunur.

### M05 · Kara Sırt — Büyük balina tipi otçul/territory
Rol: ağır yavaş hedef, bölge savunması; açık/soğuk deniz. L/B 2,8:1; geniş küt baş, iki iri göğüs paleti, tek küçük arka sırt, yatay iki loblu kuyruk. Ayıraç: fıçı sırt, geniş alın, yatay kuyruk, tek küçük sırt. Kömür deri, donuk açık yara izleri. Sabit: iki palet, yatay kuyruk; varyant: yara yerleri yalnız yeni konseptte sabitlenir. Negatif: balık dik kuyruk, boynuz, fıskiye sprite içinde yok. B: su hattında nötr; nefes/splash ayrı.

### M06 · Yosun Kalkanı — Resif kabuklusu
Rol: pasif/defansif ağır av, resif. L/B 1,45:1; geniş basık altıgen kabuk, dört palet, küçük yuvarlak baş, kısa tek kuyruk. Ayıraç: basık zırh, dört kanat, kısa baş. Koyu yosun yeşili/kalker gri, kabuk üzerinde sınırlı tortu. Sabit: 4 palet ve altıgen kabuk; varyant: yosun yoğunluğu. Negatif: kıskaç, yükselen taş ada, 8 bacak yok. B: yatay; kabuğa çekilme ayrı poz gerekirse sonra.

### M07 · Kül Vatozu — Alan tehditçisi
Rol: geniş süzülme ve elemental uyarı; sıcak/volkanik yüzey. L/B 0,95:1; tek baklava disk, iki geniş yan kanat, iki kısa ön lob, tek ince arka kamçı. Ayıraç: yassı kanat hattı, iki ön lob, uzun kamçı. Bazalt gri deri, boğuk pas kenar; parlama yok. Sabit: tek kamçı, disk geometrisi; varyant: kenar tonu. Negatif: manta yerine kuş kanadı, çoklu kuyruk, ateş kaplama yok. A: iki disk ucu yukarı bükülür; efekt ayrı.

### M08 · Boğuk Pençe — Yüzey kraken boss'u
Rol: büyük karşılaşma/territory, saldırı fazı; açık deniz. L/B 1,15:1 nötr uzuv yayılımı; tek armut manto, iki göz, tam 8 kol; ön-arka eksen göz çifti ve manto ucu ile kilitli. Ayıraç: iri manto, sekiz ayrı kol kökü, önde iki kalın kol, düşük arka yay. Islak morumsu kömür, küllü vantuz, çok az soluk yeşil. Sabit: 8 kol, iki göz, sağ ön kolda üç iz; varyant: ton, yara decal. Negatif: dokuzuncu kol, kopuk tentacle, gemi, su spirali yok. A: iki ön kol kalkar; P: ağır yara/faz, aynı 8 kol ve manto, yeni uzuv yok.

### M09 · Buz Çenesi — Kutup pusucusu
Rol: buz kıyısı/charge. L/B 3,0:1; geniş yassı baş, iki belirgin çene dişi, çift yan palet, tek kısa yatay kuyruk ve üç sırt çıkıntısı. Ayıraç: küt yassı kafa, iki diş, üç kısa çıkıntı. Füme mavi deri, kemik çıkıntı, lokal don. Sabit: üç çıkıntı ve yatay kuyruk. Varyant: don lekesi. Negatif: buz kristali halesi veya M05 fıçı sırtı yok. B.

### M10 · Kor Omurga — Volkanik zırhlı balık
Rol: sıcak biyom/dirençli territory. L/B 2,6:1; ağır baş plakası, 6 sırt plakası, çift kalın yan yüzgeç, yuvarlak dik kuyruk. Ayıraç: altı ayrı plakalı sırt, baş kalkanı, tok arka. Kömür-bazalt, boğuk turuncu-kahve çatlak pigment; alev yok. Sabit: 6 plaka. Varyant: pas tonu. Negatif: lav ışığı, kıskaç, yılan gövdesi yok. B.

### M11 · Sis Gagası — Yüzey kanatlı avcı
Rol: tropik/sisli kıyı, hızlı baskın; suya yakın yüzüş, uçuş runtime kapsamı dışı. L/B 1,65:1; iki dar geriye eğimli yüzgeç, tek kemiksi gaga, düz gövde, iki loblu kısa kuyruk. Ayıraç: gaga, geriye eğik dar yüzgeç çifti, iki lob. Koyu lacivert, kemik gaga, mat kahve benek. Sabit: iki yüzgeç, gaga; varyant: benek tonu. Negatif: tüy, kuş ayağı, M07 baklava disk yok. B.

### M12 · Çan Boyun — Uzun boyunlu leviathan
Rol: ağır yüzey bölge tehdidi, geç oyun. L/B 2,2:1; bir uzun dik boyun ve küçük baş, dört palet, iri oval gövde, tek ince kuyruk. Ayıraç: kavisli uzun boyun, 4 palet, oval gövde. Koyu arduvaz, kemik boyun çıkıntıları (3). Sabit: 4 palet, 3 çıkıntı. Varyant: boyun lekesi. Negatif: iki boyun, yılan gibi gövdesiz biçim yok. A: boyun öne eğilir; su hattındaki gövde sabit.

### M13 · Kör Kandil — Derinlik pusu balığı
Rol: ileri sualtı hedefi; karanlık derinlik. L/B 2,1:1; tek iri baş/çene, tek alın uzantısı, çift küçük yan yüzgeç, tek sırt ve dar kuyruk. Ayıraç: çene, tek kandil ucu, ince arka. Kömür-siyah, donuk kemik diş, soluk amber nokta (ayrı emissive gerekirse). Sabit: 1 kandil, 2 yan. Varyant: ton. Negatif: ışık halesi, su kabarcığı veya iki kandil yok. B; tam gövde.

### M14 · Derin Yelkovan — Sualtı kalamarı
Rol: ileri sualtı takip/sürü. L/B 2,9:1; torpido manto, iki üçgen arka yüzgeç, 8 kısa kol + 2 uzun yakalama uzvu. Ayıraç: uzun manto, iki arka üçgen, iki uzun uç. Füme kahverengi/soğuk mor, soluk vantuz. Sabit: 8+2 uzuv. Varyant: pigment. Negatif: M08 yuvarlak manto, 8 eş uzun kol yok. B; tam gövde.

### M15 · Çukur Tacı — Derinlik leviathan boss'u
Rol: ileri sualtı çok fazlı boss. L/B 2,4:1; geniş kama çene, uzun kalın tek omurga, 2 iri göğüs paleti, 2 küçük arka palet, 5 kaburga plakası/borda ve tek yarıklı kuyruk. Ayıraç: çene boşluğu, çift palet çifti, 5+5 plaka. Koyu taş grisi/kemik, ölçülü hastalıklı teal pigment. Sabit: 4 palet, 10 plaka, sağ ilk plaka çentikli. Varyant: yara/ton. Negatif: göz yığını, tentacle, gemi enkazı, ışık bulutu yok. A: çene açılır; P: zırhta yarık, plakalar ve ana eklemler korunur. Tam gövde.

## 4. Ölçek ve tek yön standardı

SC-01 gemi E/W 60 dünya birimi = 60 final px (referans 1,00); canavar L değeri aynı dünyada ölçülür. Her tür kendi nötr pozunda aynı projeksiyon ölçeğine sahip; baş/kıç görüntüsü doğal kısalır. Çok uzuvlu türde B genişliği/eklem işaretleri ayrıca ölçülür; A/P uzuv uçları hareket edebilir ama gövde ölçeği değişmez. Her tür için gerçek metre eşdeğeri yalnız sanat referansıdır (60 birim ≈ 12 m); hitbox veya hasar ölçüsü değildir.

| ID | Birincil rol | L/B | E/W nötr L px | Relative L/60 | Final C | Paket |
|---|---|---:|---:|---:|---:|---|
| M01 | Küçük kıyı avcısı | 3,2 | 48 | 0,80 | 160 | Minimum |
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

C ilk bütçedir, 8 px padding sığmazsa tüm poz/yönlerde aynı üst sınıfa geç; tek yönde fit yasak. M02/M07 için genişlik ayrıca kılavuzdan kalibre edilir. M08/M15 pozları yüksekse tam atlas bütçesi yeniden hesaplanır; kırpılmaz.

## 5. Hücre, alfa, pivot ve Godot

- N=0°, NE=45°, E=90°, SE=135°, S=180°, SW=225°, W=270°, NW=315°; 4×2 atlas üst N NE E SE / alt S SW W NW. Sprite görünüşü en yakın sektör ±22,5°, 3° histerezis; hareket 360°. Yönler arasında gerçek fizik rotasyonu ile sprite rotasyonunu karıştırma.
- 1024² normalize yön master, 2048² konsept arşivi hedefi; ham üretim çözünürlüğü değildir. 160²/224²/320²/384² final hücre → 640×320/896×448/1280×640/1536×768 atlas. 8 bit sRGB straight RGBA, kenarlarda ≥8 px gerçek alpha-0; premultiplied filtrele ve straight döndür. Kenar halo/komşu piksel/ince uzuv testi.
- Pivot B/A/P ve bütün yönlerde **aynı anatomik referans**: yüzeyde gövdenin ağırlık merkezinin su düzlemine izdüşümü (yılanda sabit orta omurga; kabukluda kabuk merkezi; krakende manto tabanı); sualtında ana gövdenin hareket kökü. Normalize (512,512), final (C/2,C/2). Bbox merkezi değil; 3D referans, eklem, göz ve su düzlemi işaretleriyle kilitle. Tolerans ≤1 final px pivot, nötr L ±%3, ana landmark ±2 final px ve yön ±2°; uzuv adedi/tarafı sıfır tolerans.
- Socket fişi: ağız/çene, sol/sağ saldırı noktası, harpoon hit gösterimi, wake kökü, loot görseli ve varsa zayıf nokta; görünürlük ve occlusion yön/poz bazlı. Simülasyon hitbox'ı ayrı, resimden türetilmez.
- Godot sunumda AtlasTexture, filter_clip, repeat kapalı, merkez pivot, lineer filtre, ilk lossless/mip kapalı; B/A/P ayrı set, A frame zinciri değil. 384² ×8 RGBA8 atlas ~4,5 MiB; GPU belleği PNG boyutu değildir. Marker LOD, çoklu canavar + gemi + su/VFX Android profili ayrı kabul. Stable ID/HP/loot/harpoon/AI host authority değişmez; sunum eşlemesi ileride registry üzerinden açıkça tasarlanır.

## 6. Animasyon, faz, varyant

B=base nötr sekiz yön. A=saldırı için bir ek sekiz yönlü anatomik anahtar poz. P=boss fazı için bir ek sekiz yönlü yapısal durum. A tek başına tam animasyon değil: anticipation, active, recovery zamanları authoritative gameplay event'ine göre sunulur; B→A→B sert siluet deformasyonu kabul edilemezse ek onaylı ara poz gerekir ve bütçe revize edilir. P bir faz değişimidir, HP yüzdesine rastgele bağlanmaz.

Basit yüzüş: 0,5–1° görsel rocking, ≤1 px heave; wake/splash/hit/harpoon/telegraph ayrı runtime efekt. Yılan/kalamar yüzüşü için 3D rig veya ek pose sheet ileride ayrı doğrulanır; düz sprite'ın esnetilmesiyle uzuvlar kaydırılmaz. Boss kolları her yönde aynı numaralı köke bağlı; çene pozunda baş ölçeği değişmez. Yaralanma küçük decal/flash; P dışında yeni gövde gerektirmez. Görsel varyant yalnız pigment, yerel yara/decal, biyom kaplaması; 15 anatomiyi recolor ile ikame etme. Harpoon hedefleri ile wreck ve ship target class ayrımı korunur.

## 7. SPRITE PRODUCTION MATRIX

Her satır 1 konsept + 8 B; ek poz başına 8 yön. A/P yalnız belirtilen satırlarda. Minimum ve tam hesap **kabul edilmiş varlıklar**, üç radial aday/ret/upscale/QA ara çıktıları dahil değildir.

| ID | C | 4×2 atlas | Minimum poz | Tam poz | Tam render | Tam concept dahil | Min concept dahil |
|---|---:|---|---|---|---:|---:|---:|
| M01 | 160 | 640×320 | B | B | 8 | 9 | 9 |
| M02 | 160 | 640×320 | B+A | B+A | 16 | 17 | 17 |
| M03 | 160 | 640×320 | B | B | 8 | 9 | 9 |
| M04 | 224 | 896×448 | B | B+A | 16 | 17 | 9 |
| M05 | 224 | 896×448 | B | B | 8 | 9 | 9 |
| M06 | 160 | 640×320 | B | B | 8 | 9 | 9 |
| M07 | 224 | 896×448 | B | B+A | 16 | 17 | 9 |
| M08 | 384 | 1536×768 | B+A | B+A+P | 24 | 25 | 17 |
| M09 | 224 | 896×448 | — | B | 8 | 9 | 0 |
| M10 | 224 | 896×448 | — | B | 8 | 9 | 0 |
| M11 | 224 | 896×448 | — | B | 8 | 9 | 0 |
| M12 | 320 | 1280×640 | — | B+A | 16 | 17 | 0 |
| M13 | 160 | 640×320 | — | B | 8 | 9 | 0 |
| M14 | 224 | 896×448 | — | B | 8 | 9 | 0 |
| M15 | 384 | 1536×768 | — | B+A+P | 24 | 25 | 0 |
| **Toplam** | | | **10 set** | **23 set** | **184** | **199** | **88** |

| Kalem | Minimum | Tam (minimum dahil) |
|---|---:|---:|
| Temel anatomi/konsept | 8 | 15 |
| Base yön | 64 | 120 |
| A yön | 16 | 48 |
| P yön | 0 | 16 |
| Kabul edilen yön master/render | 80 | 184 |
| Konsept dahil kabul görseli | 88 | 199 |
| Oyun gövde atlası | 10 | 23 |
| Ortak efekt atlası üst bütçesi (gemi ortakları yeniden kullanılır) | 2 | 3 |
| En çok oyun atlası | 12 | 26 |

Ortak efekt A: splash/wake/harpoon/hit (mevcut gemi atlası uygunsa tekrar üretme); B: ısırık/alan uyarısı/loot decal; tam C: derinlik/boss telegraph/faz. Atlas başına ilk ≤1024². Sayılar tam animasyon ara kareleri içermez; yeni ihtiyaç matrisi açıkça günceller.

## 8. GPT IMAGE PRODUCTION ORDER

İlk üç **M01 → M02 → M03** için konsept, nötr anatomi ve sekiz yön birlikte kilitlenir; her biri görsel/mobile kapısını geçmeden sonraki benzer türlere çıkılmaz. Minimum: M01, M02 B/A, M03, M04, M05, M06, M07, M08 B/A. Tam: M09–M12, M13–M15 ve matris A/P ekleri. B onaylanmadan A/P üretme. İleri runtime içerikleri PLAY kapısına kadar bekler; görsel plan hazırlığı mevcut geliştirme işini değiştirmez.

Her sette kare 1:1, ayrı üç radial seçenek, kullanıcı seçimi, kesim, gerçek kaynak çözünürlüğü kapısı, anatomi-temelli hizalama, organik renk, manuel QA, 4×2 atlas ve 12 dosya standardı uygulanır. Sorunlu yön aynı konsept + hedef 3D yön ile ayrı yeniden üretilir; ayna yok. Ayrıntılı adımlar ve kopyalanabilir prompt: [CANAVAR_SPRITE_URETIM_REHBERI.md](CANAVAR_SPRITE_URETIM_REHBERI.md).

## 9. Üretim takip ve kabul

| ID | Konsept | B | A | P | ZIP | Runtime/cihaz |
|---|---|---|---|---|---|---|
| M01 | Planlandı | Planlandı | — | — | Yok | not_run |
| M02 | Planlandı | Planlandı | Planlandı | — | Yok | not_run |
| M03 | Planlandı | Planlandı | — | — | Yok | not_run |
| M04 | Planlandı | Planlandı | Planlandı | — | Yok | not_run |
| M05 | Planlandı | Planlandı | — | — | Yok | not_run |
| M06 | Planlandı | Planlandı | — | — | Yok | not_run |
| M07 | Planlandı | Planlandı | Planlandı | — | Yok | not_run |
| M08 | Planlandı | Planlandı | Planlandı | Planlandı | Yok | not_run |
| M09 | Planlandı | Planlandı | — | — | Yok | not_run |
| M10 | Planlandı | Planlandı | — | — | Yok | not_run |
| M11 | Planlandı | Planlandı | — | — | Yok | not_run |
| M12 | Planlandı | Planlandı | Planlandı | — | Yok | not_run |
| M13 | Planlandı | Planlandı | — | — | Yok | not_run |
| M14 | Planlandı | Planlandı | — | — | Yok | not_run |
| M15 | Planlandı | Planlandı | Planlandı | Planlandı | Yok | not_run |

Her kabul satırına gerçek kaynak, seçilen varyant, revizyon, atlas/ZIP SHA, görüntü QA ve runtime/device kanıtı ayrı yazılır. Oyun test hedefinin varlığı asset kabulü değildir. Bu belgenin oluşturulması roster, rehber ve bütçe tasarımını tamamlar; tek bir sprite bile üretilmiş sayılmaz.
