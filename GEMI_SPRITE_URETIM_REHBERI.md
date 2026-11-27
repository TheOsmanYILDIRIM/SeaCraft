# SeaCraft Gemi Sprite Üretim Rehberi

Bu belge, `GEMI_GORSEL_TASARIM_VE_SPRITE_PLANI.md` içindeki kanonik kuralları değiştirmez. Amaç, SC-02 · Kül Dikişi pilot üretiminde fiilen çalışan görsel üretim hattını ve tekrar edilmemesi gereken hataları operasyonel bir rehber olarak kaydetmektir.

**Güncel üretim ve prompt varsayılanı: [§22 Gemiye özel parametrik Ship Builder](#22-gemiye-özel-parametrik-ship-builder--2026-11-27-güncel-varsayılan).** Önceki tek yön ve ortak proxy yöntemleri tarihsel/istisnai kurtarma yöntemleridir.

## 1. Başlangıç: önce kimlik, sonra çok yönlü kamera referansı

Her gemide ilk iş tek bir güzel görsel üretmek değil, **aynı fiziksel geminin kimliğini kilitlemek** olmalıdır.

Sıra:

1. Master kimlik / concept:
   - gövde oranı ve siluet
   - pruva/kıç biçimi
   - direk ve yelken düzeni
   - top/port konumları
   - güverte yerleşimi
   - asimetrik tamir/hasar izleri
   - malzeme, renk, kurum, yaşlanma ve motif
2. Kamera/proxy referansı:
   - küçük ve basit bir 3D gemi modeli kullanılabilir
   - model oyun varlığı değildir; yalnız kamera ve yön referansıdır
   - model **sabit tutulur**, yönler için yalnız kamera geminin etrafında döndürülür
   - node/actor transformlarıyla parçaları ayrı ayrı döndürmek yasaktır; SC-02’de gövde biçimi bu yüzden bozuldu
3. Bir sonraki gemilerde tek yönlü referans üretmek yerine başlangıçta **çok yönlü referans seti** çıkar:
   - N, NE, E, SE, S, SW, W, NW
   - aynı model
   - aynı kamera yüksekliği
   - aynı ortografik projeksiyon
   - aynı framing/ölçek
   - aynı materyal
   - aynı ışık
   - yalnız azimut 45° değişir
4. Arşiv için hem 8 ayrı yön PNG hem de tek contact-sheet üret. AI'ya hedef yön için ilgili tekil referansı ver; contact-sheet kalite kontrol içindir.

### Kamera kuralı

- TRUE ORTHOGRAPHIC / PARALLEL PROJECTION
- perspektif kamera yok
- kaçış noktası yok
- yakın ve uzak parçalar aynı ölçek
- kamera eğimi sabit
- roll = 0
- gemi yalnız yaw ekseninde dönmüş gibi görünmeli

SC-02 pilotunda “ortografik gibi” görünen ama kıçı büyütüp pruvası küçülen çıktılar reddedildi.

## 2. Her yön için üç referans kullan

Her yeni yön isteğinde üç referans rolü açıkça ayrılmalıdır:

### Referans 1 — MASTER IDENTITY

Yalnız geminin gerçek kimliği için:

- gövde oranı
- yelken biçimi
- tamir/hasar işaretleri
- top ve güverte yerleşimi
- malzeme ve renk
- asimetri

### Referans 2 — TARGET CAMERA / ORIENTATION

Yalnız hedef yön ve kamera için:

- N / NE / E / SE / S / SW / W / NW
- kamera yüksekliği
- ortografik projeksiyon
- güverte/borda görünürlük oranı
- fiziksel örtüşme

Proxy modelin tasarımını kopyalama.

### Referans 3 — ADJACENT APPROVED SPRITE

Bir önceki onaylı komşu yön:

- aynı fiziksel gemi devamlılığı
- yelken/arma devamlılığı
- güverte nesneleri
- tamir işaretleri
- genel malzeme/ışık dili

Örnek:
- NE üretirken N
- E üretirken NE
- SE üretirken E
- S üretirken SE
- SW üretirken S
- W üretirken SW
- NW üretirken W

Bir önceki yön **tek referans değildir**; master + hedef kamera ref + komşu yön birlikte kullanılır.

## 3. Promptların sabit omurgası

Her yön promptunda açıkça bulunmalı:

- “Create a brand-new image”
- hedef yön:
  - bow points exactly ...
  - stern points exactly ...
  - previous approved direction → target = exactly 45° yaw
- TRUE ORTHOGRAPHIC / PARALLEL PROJECTION
- no perspective camera
- no vanishing point
- same camera elevation
- same apparent world scale
- same deck-to-hull-side balance
- same physical vessel
- no mirroring (yalnız ayrı render/asimetrik istisna; CD simetrik gemilerde 3 yatay yansıma uygulanır)
- no redesign
- true transparent RGBA background

### Yelken ve gizli yüzey devamlılığı

AI tek bir açıdan geminin görünmeyen yüzlerini güvenilir biçimde bilemez. Prompt içinde fiziksel devamlılık ayrıca tarif edilmelidir.

Yelken:

- gerçek ince kumaş yüzeydir, billboard değildir
- sabit spar/boom/yard ve halat noktalarına bağlıdır
- açı değiştikçe yüzey doğal olarak daralır
- arka yüz görünürse aynı kumaşın arka yüzüdür
- büyük/small yama aynı fiziksel kumaş bölgesinde kalır
- yama görünür kalsın diye başka tarafa taşınmaz
- karşı yüz görülüyorsa ekrandaki görünümü doğal olarak tersleşebilir

Gövde:

- asimetrik onarımlar gerçek iskele/sancak tarafında sabittir
- görünmeyen taraftaki işaret görünmez olabilir
- görünür tutmak için karşı bordaya kopyalanmaz

Güverte:

- direk tabanı, toplar, ızgaralar, variller, halatlar, kabin ve fener sabit fiziksel noktalardadır
- kompozisyon uğruna yeniden dizilmez

## 4. Üretim yön sırası ve kabul kapısı

Kanonik planın üretim sırası korunur:

`concept → NE → E → W → N → S → SE → SW → NW`

Pratik iterasyonda komşu yön devamlılığı için saat yönünde seri üretim de kullanılabilir; ancak final atlas sırası değişmez:

`N, NE, E, SE / S, SW, W, NW`

Her yön şu kontroller geçmeden onaylanmaz:

- yön doğru mu?
- gerçekten ortografik mi?
- ana gövde oranı değişmiş mi?
- direk/yelken sayısı ve bağlantısı aynı mı?
- asimetrik tamirler doğru tarafta mı?
- top/güverte düzeni aynı mı?
- renk/ışık kabul edilmiş komşu yönle uyumlu mu?
- alfa gerçek mi?
- kırpılmış halat/fener/bowsprit var mı?

## 5. Boyut normalizasyonu: bbox eşitleme yapma

SC-02’de ilk yanlış yöntem, her yönün alfa bounding-box'unu aynı dış boyuta zorlamaktı. Bu yöntem **yanlıştır**.

Sebep: ortografik kamerada geminin ekrandaki uzunluğu yöne göre doğal olarak kısalır. N/S görünüşünü E/W kadar uzatmak gerçek dünya ölçeğini bozar.

Kanonik kural:

- aynı gemide tek px/dünya ölçeği vardır
- yön başına ayrı “fit” yoktur
- doğal projeksiyon kısalması korunur
- final master 1024×1024 RGBA
- SC-02 final oyun hücresi 160×160
- pivot master'da (512,512)

55° kamera kontrolü için beklenen yaklaşık ekran uzunluk oranları:

- E/W = 1.000
- NE/SE/SW/NW ≈ 0.914
- N/S ≈ 0.819

Formül:

```text
diagonal_ratio = sqrt(0.5 + 0.5 * sin(55°)^2)
north_south_ratio = sin(55°)
```

Bu oranlar **bağımsız resize hedefi değil**, aynı dünya ölçeğinin projeksiyon kontrolüdür.

AI kaynakları farklı boyutta geldiyse:

1. güvenilir E/W su hattı uzunluğunu dünya ölçeği referansı yap
2. diğer yönlerde gövde/su hattı eksenini ölç
3. beklenen projeksiyon oranına göre tek global dünya ölçeğine getir
4. tüm alfa bbox'unu eşitleme
5. yelken/halat uçlarını “gemi uzunluğu” ölçüsüne katma

## 6. Merkezleme ve pivot: alfa bbox merkezi kullanma

SC-02’de toplam alfa şeklinin merkezi kullanıldığında yelken ve arma, gemiyi hücre içinde kaydırdı.

Kanonik pivot:

**su hattındaki orta gemi kirişinin merkez çizgisiyle kesişimi**

Master'da:
`pivot = (512,512)`

Bu nedenle:

- full-alpha bbox midpoint kullanma
- yelken/arma ağırlık merkezini kullanma
- trim edilmiş sprite merkezine göre hizalama yapma

AI çıktısında gerçek su hattı/pivot ölçüsü yoksa geçici otomatik yaklaşım:

1. alfa içinden gövde ağırlıklı maske çıkar
2. açık renk yelken ve ince arma çizgilerini merkez hesabından mümkün olduğunca dışarıda bırak
3. geminin heading ekseninde pruva–kıç **gövde** uçlarını bul
4. bu eksenin orta noktasını ve borda orta çizgisini proxy pivot kabul et
5. proxy pivotu (512,512)'ye yerleştir
6. contact-sheet ve dönüş GIF'inde görsel sıçrama varsa elle doğrula

SC-02’de son düzeltmede gövde odaklı merkezleme kullanıldı; sonraki gemilerde concept aşamasında pivot işaretlenirse bu tahmine gerek kalmaz.

## 7. Renk/ışık normalizasyonu: N yönünü LUT hedefi yap

SC-02’nin son üretilen yönleri giderek daha parlak ve sıcak çıktı. Basit RGB gain yeterli olmadı.

Çalışan yöntem:

**N yönü = canonical color/look reference**

Diğer 7 yön N'e LUT-benzeri renk transferi ile eşitlenir.

### Uygulanan renk hattı

1. yalnız alpha içindeki gemi piksellerini işle
2. sRGB → Lab dönüştür
3. L kanalında luminance quantile eğrisini N yönüne eşle
4. Lab a/b kromatik dağılımını N'e taşı:
   - kaynak a/b medyanı
   - kaynak covariance
   - whitening
   - N covariance ile recolor
5. renk transferini tam %100 basmak yerine yerel texture/ışık mikro kontrastını koruyacak blend uygula
6. alpha-0 alanların RGB'sini sıfırla
7. sonuçları contact-sheet üzerinde aynı nötr arka planda karşılaştır

SC-02’de yaklaşık %90+ LUT blend, basit RGB kanal çarpanından belirgin daha tutarlı sonuç verdi.

Kontrol için yalnız ortalama RGB kullanma. En az:

- median/quantile luminance
- Lab a/b merkezi
- highlight/shadow dağılımı

N'e yakınlaştırılmalıdır.

## 8. Alfa, padding ve final paket

Her yön master:

- 1024×1024
- straight RGBA
- dış alan alpha 0
- deniz/gölge/stüdyo fonu yok
- kırpılmış arma yok

Final kalite kontrol:

1. şeffaf PNG'leri gri zeminde contact-sheet yap
2. siyah zeminde halo testi
3. açık zeminde fringe testi
4. N→NE→E→SE→S→SW→W→NW döngülü GIF/video yap
5. dönüşte:
   - ölçek pompalanıyor mu?
   - pivot sıçrıyor mu?
   - renk/parlaklık atlıyor mu?
   - yelken taraf değiştiriyor mu?
   - gemi gövdesi morph ediyor mu?
   kontrol et

GIF önizleme için şeffaf palet güvenilir değildir; istemciye göre siyahlaşabilir. Kontrol GIF'ini nötr gri fonda üret, gerçek oyun varlıklarını ise şeffaf PNG olarak sakla.

## 9. SC-02 pilotundan çıkarılan tekrar-etme kuralları

- Tek yön kamera referansı üretip sonra diğerlerini tahmin etme; en başta 8 yön proxy referansı çıkar.
- Modeli yön için transform etme; modeli sabit bırak, kamerayı orbit ettir.
- Actor/node'lara ayrı transform uygulamak gövdeyi bozabilir.
- “Orthographic-looking” çıktıyı kabul etme; yakın/uzak ölçek farkını kontrol et.
- Her yönü aynı bbox'a fit etme.
- Tam alfa merkezine göre pivotlama yapma.
- Basit RGB gain ile renk eşitlemeyi final çözüm sayma; canonical yön LUT hedefi kullan.
- Her yeni yön için master + target camera ref + adjacent approved sprite üçlüsünü kullan.
- Gizli yelken/arka yüz/karşı borda detaylarını promptta fiziksel olarak açıkla.
- 8 yön bittikten sonra normalizasyonu toplu yap:
  1. dünya ölçeği
  2. pivot
  3. renk/LUT
  4. alfa
  5. contact-sheet
  6. dönüş önizlemesi
- Final onay, tek kare güzelliğiyle değil sekiz karenin **aynı fiziksel gemi** gibi dönmesiyle verilir.

## 10. Önerilen sonraki gemi akışı

```text
A. master concept + pivot/waterline işareti
B. aynı 3D proxy'den 8 ortografik kamera referansı
C. ilk kabul yönü / hero
D. her yeni yön: master + hedef proxy ref + komşu onaylı sprite
E. 8 yön tamamlanınca aynı dünya ölçeğine normalize
F. gerçek pivotu (512,512)'ye hizala
G. canonical N look'a Lab/LUT match
H. alfa/padding kontrolü
I. contact-sheet + rotation preview
J. final 4×2 atlas ve Android düşük-zoom kontrolü
```

Bu hat, SC-02 pilotunda yaşanan kamera, ölçek, renk ve merkezleme tekrarlarını azaltmak için sonraki tüm gemilerde varsayılan üretim prosedürüdür.


## 11. Mobil manuel hizalama aracı — isteğe bağlı QA/debug

Kanonik üretim akışı artık manuel hizalama gerektirmez. `tools/sprite_normalize.py` içindeki su/gövde support-anchor sistemi varsayılan final hizalamayı üretir. Mobil manuel araç yalnız görsel QA, hata ayıklama veya olağan dışı bir gemide birkaç piksellik residual ince ayar gerektiğinde kullanılır:

`tools/sprite_manual_aligner_template.html`

Araç tek dosyalık, internetsiz çalışan bir HTML'dir. Kullanım:

1. 8 adet 1024×1024 şeffaf PNG'yi **N, NE, E, SE, S, SW, W, NW** sırasıyla seç.
2. Büyük önizlemede tek parmakla seçili frame'i X/Y kaydır.
3. İki parmak pinch ile yalnız gerektiğinde scale düzelt.
4. **Play** ile dönüşü sürekli izle; konumsal sıçramayı tek kare yerine döngü içinde değerlendir.
5. **Ghost** ile önceki yönü düşük alfa referans olarak göster.
6. Ayarları JSON olarak indir; böylece manuel karar tekrar üretilebilir.
7. Atlas düğmesiyle 4×2 master atlası dışa aktar.

Kullanım kuralı:

- otomatik support-anchor = varsayılan final hizalama
- rotation/contact-sheet = zorunlu görsel QA
- manuel HTML = yalnız isteğe bağlı residual düzeltme/debug
- kaydedilen JSON = yalnız manuel araca gerçekten başvurulduysa yeniden üretilebilir düzeltme kaydı
- PNG'lerdeki ölçek ve LUT işlemleri HTML'e girmeden önce tamamlanmış olmalı

SC-02 manuel pilot tarihsel bir ara adımdır. SC-03 doğrulamasından sonra normal üretimde her gemi için manuel işaretleme veya manuel X/Y/scale ayarı zorunlu değildir.


## 12. Kanonik otomatik normalizasyon aracı

Bundan sonra boyut, dünya ölçeği, otomatik pivot/anchor, 180° karşı-yön eşleme, alfa çıkarma ve N yönüne LUT/Lab renk eşitleme için her gemide yeniden Python kodu yazılmaz.

Tek kanonik araç:

`tools/sprite_normalize.py`

Bu araç normal üretimde **final normalize paketi** üretir. Manuel HTML aşaması zorunlu değildir.

Örnek:

```bash
python tools/sprite_normalize.py raw/ normalized/ \
  --camera-elevation 55 \
  --broadside-px 790 \
  --anchor-x 512 \
  --anchor-y 560 \
  --padding 24 \
  --color-ref N \
  --gif-fps 6
```

Gerekli Python paketleri:

```text
pillow
numpy
opencv-python
scikit-image
```

Araç şu işlemleri tek akışta yapar:

1. Gerçek alfa varsa onu kullanır; opak stüdyo arka planında GrabCut ile foreground çıkarır.
2. Yelken/arma bbox'ını dünya ölçeği sanmaz; gövde-ağırlıklı yapısal maske üzerinden yön ekseni ölçer.
3. 55° ortografik kamera için doğal projeksiyon oranlarını korur:
   - E/W = 1.000
   - çaprazlar ≈ 0.914
   - N/S ≈ 0.819
4. Gövde ekseninden otomatik anchor çıkarır ve ortak pivot çevresine yerleştirir.
5. N↔S, NE↔SW, E↔W, SE↔NW karşıt yön çiftlerinin görsel footprint'ini kontrol eder/eşler.
6. N yönünü varsayılan canonical renk hedefi kabul edip diğer yönlere luminance quantile + Lab a/b covariance tabanlı LUT-benzeri transfer uygular.
7. **No-crop safety fit** uygular. Ölçek/pivot sonucu içerik 1024 tuvalden taşacaksa piksel kesmez; ilgili frame'i güvenli padding içine uniform küçültür ve oranı `normalization_report.json` içine yazar.
8. Şunları otomatik üretir:
   - 8 şeffaf normalize PNG
   - `contactsheet.png`
   - `rotation.gif`
   - `normalized_png.zip`
   - `normalization_report.json`

### Zorunlu sıra

```text
Ham 8 yön
→ tools/sprite_normalize.py
→ contact sheet / rotation GIF kontrolü
→ final PNG paketi / atlas
```

Yalnız QA'da belirgin residual sıçrama görülürse isteğe bağlı olarak `tools/sprite_manual_aligner_template.html` açılır. Bu istisna normal üretim bağımlılığı değildir.

**Kural:** Normalizasyon/LUT/pivot için sohbet içinde her seferinde yeni ad-hoc script yazma. Önce bu kanonik aracı kullan. Araçta eksik veya hata bulunursa yeni geçici script üretmek yerine bu dosyayı düzelt, aynı test setinde yeniden doğrula ve rehberi güncel tut.

SC-03 sırasında tespit edilen kritik hata: normalize edilmiş kareler 1024×1024 olsa bile negatif compositing offset alfa içeriğini tuval dışında bırakabiliyordu. Kare dosya olmak tek başına kırpılmadığı anlamına gelmez. Bu nedenle `compose_no_crop()` güvenlik kapısı kanonik aracın zorunlu parçasıdır.

## 13. Manuel hizalama template'i — isteğe bağlı tek QA aracı

Manuel müdahale gerekirse kullanılacak tek HTML:

`tools/sprite_manual_aligner_template.html`

Bu dosya gemiye özel görsel gömmez. Her gemide normalize edilmiş 8 PNG kullanıcı tarafından yüklenir.

Template kuralları:

- kaynak PNG'ye bbox trim/crop uygulamaz;
- kaynak görselin tam doğal dikdörtgenini ve aspect ratio'sunu korur;
- yalnız X/Y ve uniform scale transformu uygular;
- frame başına %50–150 boyut düzeltme sağlar;
- iki parmak pinch ile scale ayarı sağlar;
- animasyon hızını 1–24 FPS arasında anlık değiştirir;
- Ghost ile önceki frame'i gösterir;
- ayarları `sprite_manual_alignment.json` olarak kaydeder/geri yükler;
- final 4×2 atlas dışa aktarır;
- kaynak alfa ekran kenarına değiyorsa `KAYNAK KENARA DEĞİYOR` uyarısı verir. Bu uyarı HTML'in kırptığı anlamına gelmez; PNG'nin kendisinin daha önce kesilmiş olabileceğini bildirir.

**Kural:** Normal üretimde HTML açmak zorunlu değildir. Manuel QA gerekirse gemiden gemiye yeni HTML üretme; yalnız bu tek template'i kullan/geliştir ve GitHub'daki dosyayı güncelle.


## 14. Su temaslı destek anchor sistemi

SC-03 manuel hizalama testi, yalnız alpha centroid veya direk/yelken ağırlıklı merkez hesabının yeterli olmadığını gösterdi. Gemiler insan karakterlerindeki “ayak” mantığına benzer biçimde **denize oturan gövde destek yüzeyi** üzerinden hizalanmalıdır.

Kanonik normalizer artık varsayılan olarak şu yöntemi kullanır:

1. yelken, ince arma ve direk etkisini azaltmak için yoğun ahşap/gövde maskesi çıkarır;
2. gövdenin geniş taşıyıcı kısmındaki yatay kesitlerden X destek merkezini hesaplar;
3. yoğun gövde kütlesinden Y destek merkezini hesaplar;
4. N/S, NE/SW, E/W, SE/NW karşı yönlerini aynı fiziksel aile olarak ele alır;
5. gövde heading-span ölçüsünden teorik 55° projeksiyon oranına göre scale tahmini yapar;
6. karşı yön çiftlerinin scale tahminini birlikte yumuşatır;
7. SC-03 manuel QA verisinden çıkarılmış küçük **aile bazlı residual** düzeltmeleri %100 değil, yumuşatılmış ağırlıkla uygular;
8. son kompozisyonda yine `compose_no_crop()` güvenlik kapısı çalışır.

Bu yaklaşım tek tek frame değerlerini ezberlemez. Amaç insan gözüyle yapılan hizalamaya yaklaşırken her yönün doğal projeksiyon farkını ve küçük model morflarını tolere etmektir.

SC-03 test setinde elde edilen doğrulama:
- X/Y düzeltme bileşen RMSE: yaklaşık **8.6 px**
- scale RMSE: yaklaşık **0.0157** (yaklaşık %1.6)
- karşı yönlerde küçük insan ayarı farkları bilerek tamamen ezberlenmedi
- N/S, NE/SW, E/W, SE/NW fiziksel çiftleri yumuşatılmış ortak scale ile tutuldu

Bu nedenle kanonik final kabul sırası:

`sprite_normalize.py → rotation/contact-sheet kontrolü → final PNG paketi / atlas`

SC-03 üzerinde ayrıca boy/en ekseni ve elle landmark işaretleme deneyleri yapıldı. Bunlar veri analizinde yararlı olsa da görsel sonucu support-anchor yönteminden güvenilir biçimde daha iyi yapmadı ve manuel iş yükü ekledi; bu nedenle varsayılan üretim hattına alınmadı.

**Kural:** direk tepesi, yelken bbox'ı veya full-alpha merkezi final anchor değildir. Ana anchor gövdenin denize oturan yoğun destek yapısıdır. Manuel landmark/JSON normal üretim girdisi değildir.


## 15. GPT Image prompt ve 1:1 kare çıktı kuralı

Tüm GPT Image üretim isteklerinde **ABSOLUTE OUTPUT REQUIREMENT = STRICT 1:1 SQUARE IMAGE** yazılır. Bu kural master/hero, tek yön sprite, concept/reference ve 5-yön CD / 8-yön radial referans panosu için aynıdır. Genişlik ve yükseklik eşit olmalıdır. 4×2 final atlas gibi kare olmayan paketler GPT Image içinde üretilmez; ayrı kod/normalizasyon aşamasında monte edilir.

İlk master/hero görseli **sıfırdan üretim** olarak istenir. İlk promptta “attached reference”, “same vessel as attached”, “edit”, “modify”, “use reference 1/2” gibi düzenleme çağrıştıran dil kullanılmaz. Önce gemi doğrudan tarif edilerek tek 1:1 master üretilir. Referans kullanan dil yalnız ikinci ve sonraki aşamalarda, gerçekten görsel referans eklendiğinde kullanılır.

İlk master promptunun zorunlu iskeleti:

- ilk cümlede `Create ... in a STRICT 1:1 SQUARE FORMAT.`
- tüm gemi kare içine rahatça sığmalı; direk, yelken, pruva, kıç ve arma kırpılmamalı;
- fiziksel gövde, direk/yelken, port ve malzeme kimliği açık tarif edilmeli;
- ortografik/yüksek açı yaklaşık 55° belirtilmeli;
- düz koyu mavi-gri stüdyo fonu;
- deniz/su/wake/sis/duman/yazı/UI/frame yok;
- prompt sonunda tekrar `ABSOLUTE OUTPUT REQUIREMENT: 1:1 SQUARE IMAGE. Width and height must be identical.` denmeli.

8-yön radial referans aşamasında iki referans kullanılır: gemi kimliği için onaylı tekli master ve yalnız yerleşim/kamera düzeni için kodla hazırlanmış radial pano örneği. Radial pano da **strict 1:1 square** üretilir. Örnek panodaki gemi tasarımı kopyalanmaz.

**Kural:** GPT Image üretim promptlarında 1:1 kare şartı hiçbir aşamada varsayılmaz; prompt içinde açıkça iki kez yazılır.


## 16. Ortak SeaCraft renk / LUT hattı

Yeni kanonik araç:

\`tools/seacraft_showlook.py\`

Bu araç geminin geometrisini, alfa kanalını, canvas boyutunu veya yerleşimini değiştirmez. Yalnız normalize edilmiş 8 yönün ortak renk/ton görünümünü üretir. Girdi klasörü \`N.png, NE.png, E.png, SE.png, S.png, SW.png, W.png, NW.png\` dosyalarını aynı canvas boyutunda içermelidir.

Kanonik sıra:

\`\`\`text
gövde/pivot ve yön normalizasyonu
→ gemi içi yön renk eşitlemesi (sprite_normalize.py içindeki canonical N Lab/LUT)
→ tools/seacraft_showlook.py --stage v3
→ final PNG / atlas
\`\`\`

Manuel hizalama kullanılmışsa X/Y/scale düzeltmesi bu sıranın geometrik kısmında kalır; ortak show-look geometrik hizalamayı tekrar değiştirmez.

Araçta SC-01 look-development sırasında kullanılan üç aşama korunur:

- **v1 · Global Theme LUT:** bütün gemi setinden tek Lab luminance quantile + a/b covariance profili çıkarıp stil referansındaki gemi foreground'una eşler. Tarihsel ilk ortak görünüm denemesidir.
- **v2 · Material-aware:** yelken, ahşap, metal/koyu donanım ve diğer bölgeleri ayrı Lab profilleriyle eşler. Tek global transferin malzeme renklerini birbirine sürüklemesini azaltır.
- **v3 · ShowLook — varsayılan:** v2 mantığını daha kontrollü katsayılarla uygular; ardından filmic ton eğrisi, hafif soğuk gölge, kontrollü sıcak ahşap orta ton ve kirli-krem yelken sınırı ekler. Son olarak yalnız global finishing katmanını taşıyan hafif bir 33³ \`.cube\` üretir.

**Önemli:** v3'te üretilen \`.cube\` dosyası tek başına tam v3 değildir. Asıl ortak görünüm material-aware Python aşamasıdır; cube yalnız taşınabilir son show-look katmanıdır.

Örnekler:

\`\`\`bash
python tools/seacraft_showlook.py normalized/ style_reference.png out_v1/ --stage v1
python tools/seacraft_showlook.py normalized/ style_reference.png out_v2/ --stage v2
python tools/seacraft_showlook.py normalized/ style_reference.png out_v3/ --stage v3 --cube-size 33
\`\`\`

Her çalıştırma yön PNG'lerine ek olarak \`contactsheet_<stage>.png\`, seçili yönde before/after \`comparison_<direction>_<stage>.png\`, \`profile_<stage>.json\` ve \`validation.json\` üretir. v3 ayrıca \`SeaCraft_ShowLook_v3_33.cube\` üretir.

Bağımlılıklar mevcut sprite normalizer ile aynıdır:

\`\`\`text
pillow
numpy
opencv-python
scikit-image
\`\`\`

Doğrulama kuralı: bütün final yönler aynı canvas boyutunda RGBA kalmalı ve alfa içeriği dört kenara taşmamalıdır. SC-01 doğrulama setinde v1, v2 ve v3'ün üçünde de 8/8 kare aynı canvas, RGBA ve edge-alpha=0 olarak geçti; v3 33³ cube çıktısı da üretildi.

**Üretim kararı:** yeni gemilerde ortak tema için varsayılan \`v3\`; v1/v2 yalnız geriye dönük karşılaştırma ve look-development teşhisi için korunur. Stil referansı ayrı girdidir; araç referans görselini repoya gömmek zorunda değildir.


## 17. Eski 8-yön radial pano ekstraksiyonu (CD için §21)

8 yönün tek kare radial panoda üretildiği durumda kesim için artık sohbet içinde gemiye özel kod yazılmaz.

Kanonik ekstraktör:

`tools/sprite_radial_extract.py`

### Radial pano kesim kuralı

Şeffaf radial panoda final yönler **sabit kare, sabit sektör veya komşuluk bbox'ı ile kesilmez**. Bu yöntemler komşu geminin flama, halat, top namlusu veya başka alfa parçalarını yanlış frame'e sızdırabilir.

Varsayılan yöntem:

1. panodaki gerçek alpha üzerinden connected-component analizi yap;
2. alanı en büyük 8 fiziksel objeyi seç;
3. her objeyi pano merkezine göre centroid açısıyla N/NE/E/SE/S/SW/W/NW slotuna ata;
4. yalnız o component'e ait pikselleri koru;
5. objenin kendi alpha bbox'ını şeffaf padding ile çıkar;
6. ekstraksiyon contact-sheet'ini gözle doğrula;
7. bundan sonra kanonik normalizer'a geç.

Pruvalar radial panoda merkezden dışarı bakıyorsa:

```bash
python tools/sprite_radial_extract.py radial.png raw/ --facing outward
```

Pruvalar merkeze bakıyorsa yalnız yön isimlemesi terslenir:

```bash
python tools/sprite_radial_extract.py radial.png raw/ --facing inward
```

**Yasak:** Aynı işi yapmak için her gemide yeni Python kesim kodu yazmak, 45° wedge'i final maske olarak kullanmak veya sabit dikdörtgen crop'u obje ekstraksiyonu sanmak.

### Bundan sonraki zorunlu sıra

```text
Onaylı radial pano
→ tools/sprite_radial_extract.py
→ extraction_contactsheet görsel QA
→ tools/sprite_normalize.py
→ normalize contactsheet + rotation.gif QA
→ tools/seacraft_showlook.py --stage v3
→ final PNG / 4×2 atlas / FINAL rotation GIF
```

`sprite_normalize.py` içindeki support-anchor, dünya ölçeği, pair-lock, no-crop ve N-LUT mantığı yeniden yazılmaz. Bir hata bulunursa geçici gemi scripti yerine kanonik araç düzeltilir ve bu rehber aynı commit'te güncellenir.

### Final GIF kuralı

Normalizer'ın ürettiği `rotation.gif`, **ShowLook öncesi hizalama/ölçek QA** kanıtıdır. Teslim edilen dönüş GIF'i mutlaka ShowLook uygulanmış final 8 PNG'den yeniden üretilir. Böylece kullanıcı GIF'te oyuna girecek gerçek renk/parlaklık sonucunu görür.

### Kir / doku yoğunluğu kuralı

ShowLook katmanı yeni kir, benek, çizik, sharpen, clarity veya local-contrast dokusu üretmez. Kaynak üretim zaten aşırı kirli veya tekrarlı grunge ise bu sorun üretim/material referansında çözülür. Renk düzeltmesi kaynak dokuyu gereğinden sert gösteriyorsa gemiye özel ad-hoc grade yazılmaz; ham → normalize → ShowLook karşılaştırılır ve gerekiyorsa **kanonik `tools/seacraft_showlook.py`** global olarak düzeltilip rehber güncellenir.

Git geçmişi rehberin her revizyonunu saklar; bu dosya kanonik operasyon kitabıdır ve pipeline değiştiği her commit'te güncel tutulur.

## 18. Final pivot kabulü ve minimal teslim ZIP standardı

Normalize aracının otomatik anchor sonucu **nihai gerçek kabul değildir**; rotation QA sonucudur. Her gemide final teslimden önce şu kapı zorunludur:

1. master pivot hedefi `(512,512)` olarak doğrulanır;
2. final hücrede aynı pivot tam hücre merkezine taşınır: `(C/2,C/2)`;
3. N→NE→E→SE→S→SW→W→NW rotation önizlemesinde gövde merkezinin sıçramadığı görsel olarak doğrulanır;
4. support-anchor sonucu belirgin pivot sıçraması üretiyorsa gemiye özel ad-hoc hizalama scripti yazılmaz; aynı kanonik `sprite_normalize.py` bu gemide `--no-support-anchor` ile yeniden çalıştırılır ve iki sonuç rotation QA ile karşılaştırılır;
5. yalnız doğrulanmış hizalama final pakete girer.

**Kural:** support-anchor varsayılan otomatik adaydır; rotation/contact-sheet QA onu veto edebilir. Final kabul ölçütü, sekiz yönün aynı fiziksel dönme noktasına oturmasıdır.

### Final ZIP sözleşmesi

Kullanıcıya verilen final gemi ZIP'i yalnız şu teslim dosyalarını içerir:

- 8 final yön PNG: `N, NE, E, SE, S, SW, W, NW`
- 1 final 4×2 atlas PNG
- 1 final rotation GIF
- 1 `manifest.json`
- 1 **orijinal üretim kaynağı** (radial pano / tekil ana kaynak PNG; kayıpsız, yeniden işlenmemiş)

Toplam standart içerik: **12 dosya**.

`manifest.json` en az şunları kaydeder:

- gemi ID/adı
- final hücre boyutu
- atlas boyutu ve yön sırası
- master pivot ve final pivot
- kullanılan normalize modu
- ShowLook sürümü
- minimum şeffaf padding
- edge-alpha doğrulaması

Final ZIP'e **girmez**:

- radial extraction ara PNG/ZIP'leri
- extraction contact-sheet/report
- normalize ara ZIP'i/report/contact-sheet
- ShowLook comparison görselleri
- LUT/`.cube` dosyaları
- profile/validation ara JSON'ları
- çalışma klasörleri
- debug veya manuel hizalama dosyaları

Bu ara çıktılar QA sırasında tutulabilir ancak kullanıcıya teslim edilen final ZIP'in parçası değildir.

### Final küçültme kuralı

1024 master doğrudan sabit hücreye küçültülmez. Önce gerçek gövde hedefi ve ortak katsayı, sonra tüm yönlere yeterli hücre hesaplanır. Pivot merkezde, padding ≥8 px; hedefi düşüren otomatik fit final kabul değildir.

### Efektif sprite çözünürlüğü — zorunlu kabul kapısı (M01 dersi)

Dünya boyu, 1× ekranda gösterilen boy, kaynak nesne çözünürlüğü, final görünür gövde çözünürlüğü ve şeffaf hücre boyutu farklı ölçülerdir. Dünya boyu tablosu fizik/sunum oranını korur; final PNG'nin piksel yoğunluğunu sınırlamaz. **160 px veya 224 px doku hedefi, hücre etiketi değil görünür ana gövde/hull uzunluğu hedefidir.** Eski hücre sınıflarının sayısal değeri (160/224/320/384 px) yeni üretimde başlangıç gövde çözünürlüğü hedefidir; paketleme hücresi sonradan hesaplanır. M01 örneğinde 48 dünya birimi korunur; E/W görünür gövde 160 px hedeflenir, 224×224 hücre ve 896×448 atlas kullanılır. 160×160 hücre içinde 48 px gövde bu hedef için reddedilir.

- Her yeni asset için önce hedef gerçek E/W gövde/hull piksel uzunluğu belirle. E/W anatomik uçları ölç; diğer yönlerin doğal projeksiyon kısalmasını koru. Alfa≥128 bbox genişlik/yükseklik ve gerçek landmark uzunluğunu ayrı raporla; kopuk piksel veya direk yüksekliğini gövde uzunluğu sayma.
- Kaynak nesneleri gerçek alfa sınırından ayır, gereksiz boşluğu kaldır; yüksek çözünürlüklü temiz master'ı koru. Manuel hizalama JSON'u varsa onaylı göreli yön ölçeği ve pivot ofsetleri korunur. Son paketleme için sekiz yöne tek ortak uniform katsayı ve aynı pivot dönüşümü uygula; yön başına yeniden fit, x/y ayrı stretch veya merkez sıfırlama yok.
- Final hücreyi hedef gövde yoğunluğundan SONRA seç: tüm yönlerin ortak pivot etrafındaki alfa>0 sınırları + dört kenarda en az 8 px alpha-0. Gerekirse tüm seti daha büyük ortak hücreye geçir; hedefi sessizce küçültme. Gemi hasar/maskeleri varsa aynı dönüşüm ve hücre. Dünya boyunu korumak için runtime sunum ölçeği = dünya gövde uzunluğu / final referans gövde px; pivot-relative socket'lere de aynı dönüşüm uygulanır. Fizik/hitbox değişmez.
- Hedef E/W uzunluğu ±%3 ve diğer yönlerin kılavuz projeksiyon oranları kontrol edilir; final bbox, kaynak gerçek detay yoğunluğu, padding, atlas hücre eşitliği ve dönüş QA ölçülmeden teslim yok. Kaynak yetersizse kullanıcıya AI upscale gerekli bildir; interpolasyon veya boş tuval büyütme yeni detay değildir.
- HTML'de düşük çözünürlüklü (örn. 256²) gömülü önizleme serbest; aynı sanal 1024 koordinatı ve aynı çerçeve dönüşümü korunur. JSON final yüksek çözünürlüklü kaynaklara uygulanır; preview PNG final kaynak değildir. Final GIF final PNG'lerden, ayrı HD GIF temiz yüksek çözünürlüklü hizalanmış kaynaklardan yapılır. HD incelemede tüm karelere ortak sıkı güvenli tuval kullanılır; dev boş canvas yasak.
- Manifestte dünya uzunluğu, target_body_px, measured_body_px_per_direction, source_bbox_per_direction, final_bbox_per_direction, effective_fill_ratio (bbox genişlik/hücre, yükseklik/hücre), cell_px, atlas_px, ortak katsayı, pivot, runtime_world_per_texel ve varsa upgrade_reason kaydedilir. 12 dosya ZIP standardı değişmez. Eski paketler bu kapı yeniden ölçülmeden geçmiş sayılmaz.



**Kural:** final paket üretimi de kanonik hattın parçasıdır. Her gemide farklı ZIP yapısı veya fazladan debug dosyaları üretme.



## 19. Kaynak çözünürlük kapısı ve AI upscale bildirimi

8 yönün tek bir radial üretim görselinden çıkarıldığı gemilerde, final hücre boyutu uygun olsa bile her tekil gemiye düşen **gerçek kaynak piksel yoğunluğu** yetersiz kalabilir. Normalizasyon sırasında büyütmek yalnız mevcut pikselleri yeniden örnekler; kaybolmuş ince detay üretmez.

Bu nedenle ekstraksiyon sonrasında, normalizasyon/ShowLook/final küçültmeden **önce** kaynak çözünürlük görsel QA kapısı vardır:

- gövde kaplama çizgileri, arma, yelken kenarları ve küçük donanım yeterince netse pipeline normal devam eder;
- tekil yönler belirgin biçimde yumuşak, pikselli veya ayrıntı fakiri ise süreç durdurulmaz ancak kullanıcıya açıkça **“AI upscale gerekli”** denir;
- ChatGPT/kanonik pipeline kendi başına AI upscale uygulamaz;
- kullanıcı kaliteli haricî AI upscaler ile 8 ayrılmış yönü yükseltir ve yükseltilmiş yönleri geri verir;
- upscale, mümkünse **8 yön ayrıldıktan sonra; pivot/ölçek normalizasyonu, ShowLook ve final atlas üretiminden önce** yapılır;
- final 4×2 atlası veya zaten küçültülmüş oyun hücrelerini sonradan upscale etmek üretim yöntemi değildir;
- upscale gerekmiyorsa gereksiz yere önerilmez.

**Kural:** Kaynak çözünürlüğü yetersiz görüldüğünde kalite kaybını sessizce resize ile gizleme. Kullanıcıya açıkça `AI upscale gerekli` uyarısı ver ve upscale edilmiş kaynak gelene kadar özgün ayrıntı kazanılmış gibi davranma.

## 20. GLB'den ortak 8-yön kamera/geometri referansı + modüler yelkenler (2026-11-23)

SC-02/SC-03 üretiminde kullanılan ortak GLB modeli `sample_2026-11-22T165909.224.glb` **oyun gemisi değildir**; yalnızca ortografik kamera, yön ve gövde süreklilik referansıdır. İki ayrı pano hazırlanır: **normal/dokulu** (8 yönün kamera/boş merkez/radial yerleşimi) ve **renkli tanısal** (pruva-kıç, iki borda, arma alanının farklı yönlerde aynı fiziksel yapı olması). Renkli örneğin paleti, gerçek gemiye taşınmaz. Modelin tek birleşik mesh olması nedeniyle renk sınırları yaklaşık konumsal ayrımdır, özgün parça ID verisi değildir.

Doğrulanmış yeniden üretim: GLB'nin gömülü dokusu + geometrisi; glTF Y-up → Z-up dönüşümü; sabit 55° ortografik kamera, sekiz 45° yön, 1280² pano, %90 dünya ölçeği ve alfa-temas denetimi. Python + NumPy/Pillow/Trimesh/Numba CPU rasterizer ile aynı girdilerden iki çalıştırmada byte düzeyinde aynı çıktı ve **8/8 ayrı alfa bileşeni** ölçüldü. Orijinal tarihî pano ile piksel eşitliği iddia edilmez. *Önce repoya yüklenmiş* `SeaCraft_SC03_RefKod_Model_Ciktilar_Dokumantasyon.zip` ilk renderer taslağını içerdiğinden tekrar üretim kodu için güvenilir referans olarak kullanılmamalı; düzeltilmiş yerel teslim `SeaCraft_3D_Referans_Ve_Gemi_Pipeline_DOGRULANMIS.zip` ile değiştirilmelidir (bu ikinci ZIP SeaCraft/main'de mevcut; 2026-11-26 kontrolü).

**Bağımsız renksiz 2×2 clay arma modülleri:** SQ-1=tek kare, SQ-2=çift kare, GF-1=gaff, JB-1=flok, LT-1=latin. Bir gemi için birleşik arma renderı zorunlu değil; ihtiyaç listesi belirlenir ve yalnız eksik modül üretilir. SC-03 reçetesi **ön SQ-1 + ana SQ-1 + kıç LT-1**; kısa-geniş tüccar oranları promptla uyarlanır, otomatik SQ-1B açılmaz. Bu arma modülleri gemi-özel nihai sprite değildir.

**Doğrudan 8-yön radial üretimde referans sırası:** (1) renksiz kamera referansı, (2) renkli süreklilik referansı, (3) *ayrı* SeaCraft texture atlası, (4+) gerekli arma modülleri. Gemi geometrisi kanonik SC fişinden gelir; ortak GLB gemisinin gövdesi kopyalanmaz. Radial panoda temas varsa kesimle yama yapma, üretimi tekrar et. Devamı **`sprite_radial_extract.py` → kaynak çözünürlük kapısı → `sprite_normalize.py` (N Lab/LUT) → `seacraft_showlook.py --stage v3` → HTML manuel JSON QA → final 8 yön / 4×2 atlas / GIF / manifest / orijinal kaynak**. SC-03 final hücre 224², atlas 896×448; 12 dosyalık oyun ZIP'i, GLB/referans geliştirme arşivinden ayrıdır. Runtime'da sekiz yön atlası ve ±10° görsel Sprite2D geçişi kullanılabilir; gerçek gemi rotası ile dalga yalpası ayrı tutulur; GIF gerçek Godot entegrasyonu değildir.

## 2026-11-24 — SC-01 / SC-04 ve yeni sprite kalite kararları

> Bu kayıt görsel üretim kararları içindir; oyun içi entegrasyon/cihaz testi kanıtı değildir. M-01 ve M-02 dosyaları kullanıcı tarafından ayrıca aktarılmıştır, burada tekrar yüklenmez.

### Onaylanan yeni arma modülleri
- LG-1 lug: dört köşeli yelken, eğik üst seren, tek kısa direk, alt bumba yok. GF-1 ile karıştırma. SC-01 Sis İğnesi tek LG-1'li, dar çift uçlu, açık kokpitli keşif filikasıdır. Onaylı 2×2 gri referansın beyaz kenar saçakları finalde görünmemeli.
- SQG-1: arka direk için TEK direğe bağlı üstte enine SQ-1 kare yelken ve altta kıça doğru boyuna uzanan GF-1 gaff/spanker; farklı sail plane, yaklaşık dik. Gaff'ın üstünde eğik pik, altında kıça uzanan bumba vardır. İki ayrı referans üçüncü direk gibi yorumlandığından birleşik 2×2 referans onaylandı. Ön/arka görünümde kare yelken geniş, yan görünümde gaff geniş görünmelidir.
- SC-04 Yarık Çene: sadece iki direk ve dört yelken. Ön SQ-2 iki kare, arka SQG-1 bir kare + bir gaff. Üç direkli ilk çıktı reddedildi; iki sonraki seçenekten ikinci radial görüntü seçildi. SC04_FINAL_MANUAL_ALIGNED_GITHUB_UPLOAD.zip SeaCraft/main'de.
- SC-01 Sis İğnesi: SW yönü ilk hizalamada eksikti; sağlam kaynaktan kurtarılarak çapraz yönlere göre düzeltildi. SC01_FINAL_MANUAL_ALIGNED_GITHUB_UPLOAD.zip SeaCraft/main'de.

### Kalıcı görsel QA ve çözünürlük kararları
- Yeni simetrik gemilerde §21 CD beş görünüşlü 1:1 kare çıktı varsayılandır. Üç ayrı varyant istendiğinde tam üç bağımsız resim üret, kolaj değil; kullanıcı seçimi/onayı olmadan final pipeline'a geçme. SC-11 tek CD pilotu kullanıcı tarafından kabul edildi.
- Esas ölçü PNG canvas çözünürlüğü değil, nesnenin alfa bounding box genişlik/yüksekliğidir. 256×256 tuvalde örneğin 75×127 dolu piksel kalite kaybıdır; 1024×1024 boş çalışma tuvali yeni detay üretmez.
- Radial orijinal korunur. Her yön gerçek nesne sınırına göre ve şeffaf payla ayrılır. Tekil AI upscale gerektiğinde her yönün gerçek detay ve anatomisi ayrı kontrol edilir. Sabit kareye hem x hem y ölçekleyerek nesneyi ezmek yasak; en-boy oranı korunur.
- Kullanıcı elle hizalama yaptıysa eski JSON merkez/ölçek referansıdır; yeni crop/upscale sonuçlarıyla dünya pivotu korunur ama şekil yeniden doğrulanır. CD simetrik gövdelerde üç eksik yön yatay yansıma ile tamamlanır; asimetrik nesneyi geometrik olarak doğrulamadan aynalama final kabul sayılmaz.
- HTML'de hangi gerçek tekil PNG'lerin gömüldüğü ve dolu piksel alanları kontrol edilir; küçük preview/test canvas görsellerini upscale master diye sunma. Mobilde 8/8 yükleme ve JSON dışa aktarımı doğrulanır.
- Oyun paketi 8 RGBA PNG, 4×2 atlas, dönüş GIF'i, manifest ve dokunulmamış radial kaynak = 12 dosya. Gerçek AI-upscale master ile interpolasyon veya boş canvas büyütmesini birbirinden açıkça ayır. Godot/Android entegrasyonu ayrı kanıttır.


## 2026-11-25 — Runtime pruva/yön doğrulaması

- Final dosya adları/atlas hücre sırası tek başına yön doğruluğu değildir. Gerçek pruva ve dümen/kıç işaretlerini 8 yönlü oyun ölçeği panosunda incele. SC-01 (dümen), SC-04 (yarık pruva) güncel final paketleri etiketlerine göre 180° ters; kaynak arşivleri korunur, runtime staging bu iki kesin paket için 4 hücre kaydırarak N–NE–E–SE–S–SW–W–NW düzenine getirir. Yeni arşiv geldiğinde yön kapısını yeniden incele; kör düzeltme uygulama.
- Sprite yönü en yakın gerçek atlas hücresi + yalnız kalan ±22,5° görsel açı ile simülasyon heading'ine eşlenir; simülasyon ve görsel dönüş ayrı kalır. Ara rota noktaları durma hedefi değil geçiş noktasıdır. Cihaz kurulumu öncesi gerçek Godot fizik örneklerinden rota/hız/heading replay GIF'i ve tüm atlasların yön panosu kullanılır; gerçek cihaz final kabulü ayrı kalır.


## 21. CD beş görünüşlü simetrik gemi üretimi — 2026-11-26 (yerleşim/işleme; güncel referans ve prompt §22)

Bu bölüm eski sekiz özgün render, aynalama yasağı ve zorunlu concept/hero sırası ile çelişen yerlerde yeni simetrik base gemiler için önceliklidir. Asimetrik kanonik hasar, boss/enkaz, okunur amblem, tek taraflı ekipman veya farklı borda kimliği zorunluysa ayrı görünüş üret; karakteristiği sessizce silme. Eski kabul edilmiş paketler korunur.

### Kaynak pano / referanslar

- Gerçek 55° ortografik, sıfır roll, 45° dünya heading adımları, STRICT 1:1 square başta ve sonda; beş özgün görünüş aynı fiziksel gemi ve ortak ölçekte. CD silüet odaklı radial yerleşimde ortak odak korunur, uzaklıklar değişebilir; gemiler temas etmez ve kırpılmaz. Iskele/sancak simetrisi, iki yan için yumuşak dengeli ışık; pruva-kıç simetrisi değil. Flama, yazı, hasar, yelken eğrisi ve güverte donanımı yansımaya uygun olmalı.
- Tarihsel proxy yöntemi (güncel varsayılan değildir; §22): (1) `CD_normal_2048.png` normal 3D kamera/yerleşim, (2) `CD_colored_2048.png` renk kodlu geometri, (3) `SeaCraft_texture_atlas_source.png` ayrı malzeme atlası, (4+) kanonik gemi fişinin SQ/GF/JB/LT arma modülleri. İlk iki referansta proxy gemi kimliğini ve tanısal renkleri kopyalama. Texture atlası değişmedi; runtime atlası da 4×2 kaldı.
- CD referans geliştirme arşivi `SeaCraft_CD_5Yon_Referans.zip` (yerel teslim; GitHub'da henüz mevcut değil): 1280²/2048² normal ve renkli, şeffaf 2048² sürümler, `generate_cd.py`, `CD_report.json`. Girdi: repo kökündeki `SeaCraft_3D_Referans_Ve_Gemi_Pipeline_DOGRULANMIS.zip`. Kullanım: `python generate_cd.py original.zip output_directory`. Python NumPy/SciPy/Pillow/Trimesh/Numba. Raporun yerleşim pozisyonları N,NW,E,SW,S; oyun heading'i tersidir. Örnek GLB'de aynı boy eski panoya göre 1.7888× doğrusal ölçek, sıfır alfa çakışması ve 2048²'de 23.7 px en küçük maske aralığı ölçüldü; bu her yeni gemide garanti değildir.

| CD konumu | Gerçek pruva yönü / oyun PNG | Türetilen yön |
|---|---|---|
| Üst orta | S | — |
| Üst sol | SE | SW (yatay ayna) |
| Sağ orta | W | E (yatay ayna) |
| Alt sol | NE | NW (yatay ayna) |
| Alt orta | N | — |

Konum adı ile oyun heading adını karıştırma; her kaynakta pruva/dümen üzerinden doğrula. Yansıma daima yataydır; 180° görüntü dönüşü veya N/S yansıtma yapılmaz. Alternatif yerleşimlerde her yansıma çiftinin tek üyesi ve N/S zorunludur.

### İşleme ve manuel düzeltme

1. Kaynak alfa bileşenlerinden tam beş bağımsız nesneyi ayır; yönleri pruvaya göre eşle, eksik üç yönü yatay yansıt ve sekiz RGBA elde et. Mevcut `tools/sprite_radial_extract.py` sekiz bileşen bekler; CD desteği kanonik araçta henüz yok. CD için sekizli ekstraktörü kör çalıştırma; yeni kalıcı araç değişikliği yapılırsa CD ve eski sekizli fixture testleri zorunlu. Temas/eksik arma varsa yeniden üret, kopuk parçayı komşuya sızdırma.
2. Kaynak çözünürlüğü ve anatomiyi kontrol et; gereken durumda AI upscale uyarısı. Ortak dünya ölçeği ve su hattı pivotu, N Lab/LUT ve ShowLook v3 korunur. Kullanıcı onaylı manuel ayarlar varsa geometri yeniden otomatik normalize edilmez; son renk işlemi geometriyi değiştirmez.
3. Manuel HTML'de x/y/scale yanında `beam` = geminin projekte pruva-kıç eksenine dik yerel en düzeltmesi; canvas X stretch değildir. Sadece kullanıcı kontrolünde, ölçülü geometri düzeltmesi. `warp` eski fırça işlemleri; `pins` Puppet Warp kaynak/ hedef noktaları (`x,y,tx,ty,r,fixed`). Sabit noktalar korunacak bölgelerde, hareketli noktalar pruva gibi hedefte; yumuşak etki alanı. Zoom/pan yalnız görüntüleme, sprite transformu değil. Özgün yüksek çözünürlüklü kaynaktan yeniden örnekle, deformasyon birikimli bulanıklık/katlanma yapmamalı. JSON'da eski alanlar ve yeni pinler saklanır, final export aynı dönüşümü kullanır. Bu özellikler SC-11 yerel HTML pilotunda denenmiştir; repo `tools/sprite_manual_aligner_template.html` bu modları §23 itibarıyla içerir. Tarayıcı testi ile gerçek Android performans kabulü ayrı tutulur.
4. Kullanıcının son JSON'u final kabul girdisidir; sekiz yönü tek ortak katsayıyla, (512,512) master pivotunu C/2'ye taşıyarak paketle. Pruva/kıç, yerel en, gövde ölçeği, dönme sıçraması, kırpılma, yansıma kaynaklı fener/arma detayları, alfa kenarı ve atlas hücre eşitliği kontrol edilir. Önizleme zoom'u veya preview çözünürlüğü final geometriye yazılmaz. Son GIF final ShowLook PNG'lerden.
5. 12 dosya ZIP değişmez: 8 RGBA, 4×2 atlas N NE E SE / S SW W NW, final GIF, manifest, dokunulmamış beşli radial kaynak. Manifestte kaynak görünüş ve yansıma eşlemesi, manuel düzeltme yöntemi, kaynak/son bbox, ortak ölçek, gerçek gövde hedefi, pivot, padding ve ölçüm sınırları bulunur. Ara JSON/HTML/debug final ZIP'e eklenmez.

### SC-11 Dikiş Feneri — doğrulanmış paket örneği

`SC11_FINAL_MANUAL_ALIGNED_GITHUB_UPLOAD.zip` SeaCraft/main'de, blob `9ed1f91504eb3c94e9cadf586897f6431e857795` (yerel ZIP ile aynı Git blob; SHA-256 `0fdd43c420aa96b7c4b36186790774cbd2dcca566b39011d0ec11b1bca40cc22`). 1254² beşli kaynak, 5+3 (E/NW/SW yansıma), NE/NW yerel en, NW dört Puppet Warp noktası ve manuel hizalama kabulü. ShowLook v3, SC-03 E stil örneği; 288² final hücre / 1152×576 atlas, E/W yaklaşık 223/225 px gövde (224 hedef), 16 px min alfa-0 pay, 144/144 final pivot, 102 dünya uzunluğu. ZIP 12 dosya ve CRC kontrolü geçti; AI upscale uygulanmadı. Çapraz landmark oranları bağımsız ölçülmedi, yeni N-LUT uygulanmadı (pilot manifesti), Godot/Android kabulü yok. Bu pilot yeni yöntem için görsel örnektir, tüm gemilerde otomatik başarı garantisi değildir.

## 22. Gemiye özel parametrik Ship Builder — 2026-11-27 (güncel varsayılan)

**Bu bölüm §1–4, §10, §15, §20 ve §21'deki eski proxy/ref ve prompt sırasıyla çeliştiğinde önceliklidir.** §21'in yön eşlemesi, kaynak ekstraksiyonu, simetri istisnası, çözünürlük/pivot/renk ve 12 dosyalık teslim kuralları korunur. Eski onaylı oyun paketleri değiştirilmez.

### Referans üretimi ve yükleme

- Tek parametrik Three.js gövde motoru; 6 pruva + 6 kıç profili, 21 arma, bağımsız top portları, 18 dekorasyon modülü, 15 düzenlenebilir gemi reçetesi. Gemiye özel gövde/arma/donanım montajı aynı fiziksel modelden render edilir. Bunlar **oyun içi 3D modeller değil**, GPT Image için geometrik kılavuzlardır. Reçeteyi kanonik gemi fişine göre kontrol et, gerekirse düzenle ve JSON sakla. SC-15 ve tek taraflı montajlar için sekiz bağımsız yön.
- Ship Builder v0.5 kaynak ve çevrimdışı HTML arşivi: `SeaCraft_ShipBuilder_v0.5_SOURCE.zip` (repo köküne kullanıcı yüklemesi bekleniyor; henüz GitHub'da doğrulanmadı). SHA-256 `d88b4d1be9be84e66377827760f86266cc17f01a676ca987e69549c5932a8257`. Arşivi aç, `SeaCraft_ShipBuilder_v05/offline.html` çalıştır. Kaynak modülleri, Three.js MIT lisansı, worker, testler ve SC-02 pilotu içeride; tekrar üretim README'de. Üretilmiş filo GLB/PNG'leri arşiv boyutunu azaltmak için çıkarıldı (SC-02 PNG'leri korunur). Android gerçek cihaz testi yapılmadı. V0.5 önizleme Web Worker'da, final referans 2048²; renkli/renksiz aynı yerleşim.
- **Varsayılan yalnız iki görsel:** (1) gemiye özel renksiz CD (`clay.png` veya HTML'den renksiz PNG), fiziksel yapı/kamera/yerleşim için; (2) orijinal `SeaCraft_texture_atlas_source.png`, malzeme ve sanat dili için. Renk kodlu CD **zorunlu değildir**; yalnız karmaşık/asimetrik geometride parça veya yön karışıklığı görülürse üçüncü yardımcı ref olarak eklenir ve promptta doğru numarası belirtilir; tanısal renkler sanata geçmez. Arma artık birleşik modelde olduğundan ayrı yelken görselleri ve başka geminin proxy'si varsayılan olarak yüklenmez.
- Tek istek, tek kare, simetrik gemide 5 yön (üst sol SE, üst orta S, sağ orta W, alt sol NE, alt orta N); 55° true orthographic, zero roll, ortak fiziksel ölçek, içe bakan pruvalar, temassız ve kırpılmamış silüetler. Asimetride 8 yönü açıkça iste, yansıtma yapma.
- Önce bir çıktı üret. Başarılıysa gereksiz varyant isteme. 3D kılavuzun sade render estetiği kopyalanmaz; geometri korunarak gerçekçi ahşap işçiliği, bez ve metal detayları sanat aşamasında eklenir.

### Prompt yazma ilkeleri

NPC sınıfı yaşayan dünyanın parçasıdır, rastgele jenerik tekne veya benzersiz boss değildir. Önce kısa, inandırıcı kullanım geçmişi (işlev, bakım, onarım); sonra uzaktan ve küçük parçada dahi tanınan **2–3 güçlü imza**: siluet/baş-kıç, borda renk şeridi, yelken yaması, işlevsel ekipman gibi. İmza gemi fişine uygun olmalı; sıradan sınıf aynı haritada 10–20 kez görüldüğünde abartılı veya yapay görünmemeli. Diğer ayrıntılar doğal işlevden gelsin; gereksiz süs, karmaşık halat, aşırı hasar, gürültülü mini detay ve yeni siluet parçaları ekleme. Boss/legendary gemilerin kanonik özel unsurlarını ise koru. Referansın belirlediği geometriyi uzun promptla yeniden tasarlatma; yalnız kimlik, kritik sayılar, negatif kısıtlar ve QA koşullarını yaz. Renkli referans eklenmediyse promptta ondan söz etme.

### Kullanıma hazır İngilizce SC-02 örneği (iki referans)

```text
SC-02 — KÜL DİKİŞİ / ASH STITCH
Create ONE premium production-quality five-view ship sprite sheet for SeaCraft, a dark maritime game with realistic handcrafted nautical artwork.
STRICT 1:1 SQUARE IMAGE.

SHIP IDENTITY
Ash Stitch is a small agile coastal sloop used by independent sailors, couriers and inexperienced captains. Practical harbor shipwrights rebuild these vessels with salvaged timber, repaired sails and reliable old iron fittings. Lived-in, maintained and seaworthy; a recognizable recurring ship class, not a unique legendary vessel or extravagant fantasy ship. Balance individuality and simplicity so many copies can coexist naturally.

VISUAL SIGNATURE
A distinctive wedge-shaped bow with integrated dark iron repair reinforcement; a narrow faded ash-blue stripe on both broadsides; a modest ash-gray stitched repair patch on both faces of the gaff mainsail. Prioritize readable silhouettes and material masses over excessive miniature details.

REFERENCE 1 — SHIP-SPECIFIC NEUTRAL 3D CD GUIDE
Authoritative physical hull proportions, sail configuration, equipment arrangement, orthographic camera and five-view composition. Refine its simplified surfaces into believable wooden ship construction, preserving the structure and silhouette. Do not copy its simplified render style.
REFERENCE 2 — ORIGINAL SEACRAFT MATERIAL ATLAS
Authoritative wood, metal, sailcloth, rope, texture density, palette, brightness and surface finish.

PHYSICAL STRUCTURE
One slender low wooden hull, exactly one mast, one four-sided aft gaff mainsail, one narrow triangular forward jib, four exposed deck cannons in two symmetric broadside pairs. Modest functional deck equipment as in the reference. No enclosed gun deck or cannon ports. Preserve gaff, boom and jib geometry; restrained functional rigging. No flag fabric; masthead ready for a separate animated pennant.

ART DIRECTION
Aged dark oak, weathered linen, oxidized iron, subtle ash-blue accents and believable craftsmanship. Balanced neutral illumination, natural material brightness and subtle contact shadows consistent with the atlas. Avoid exaggerated ambient occlusion, weathering, gloss, clutter, excessive ropes and oversized ornaments. Recognizable at small gameplay scale.

FIVE-VIEW CONSISTENCY
Exactly five views of ONE physical vessel: upper left SE, upper middle S, middle right W, lower left NE, lower middle N. Fixed true orthographic camera, 55-degree elevation, zero roll, same physical scale. Only heading changes. Identical geometry, equipment, materials and visual signatures; natural occlusion. Bilateral symmetry suitable for horizontal mirroring. Maximize sprite size without touching or clipping.

OUTPUT
Transparent RGBA background; five complete isolated sprites; no water, wake, foam, external shadows, scenery, text, labels, flag fabric, additional ships, random equipment, exaggerated fantasy, low-poly style, normal or depth maps.
STRICT 1:1 SQUARE IMAGE.

REFERENCE UPLOAD ORDER
1. SC-02 neutral 3D CD guide.
2. Original SeaCraft material atlas.
```

### İlk SC-02 pilotunun kanıtı ve kabul sınırı

Kullanıcı tek GPT Image üretiminde renkli CD vermeden başarılı görsel elde etti ve görsel sonucu beğendi. Kaynak `127644.png`, 1254×1254 RGBA, SHA-256 `8ff45ad0a102510dd74e755da3904730ead84e6d74d8f84fd64a1ca9774704ed`; kaynak arşivinde `pilot/SC-02_GPT_Image_first_pass.png`. Alfa>127 ile beş büyük bağımsız bileşen, yaklaşık %28,08 doluluk; küçük kopuk alfa pikselleri mevcut. Tek direk/gaff/flok, açık dört top düzeni, mavi şerit, onarım yaması, pruva ve kıç okunabilir. Yama ayrıntısında küçük farklar ve N/S tam-alfa bbox yükseklikleri 564/641 px; bbox tek başına su hattı ölçeği kanıtı değildir. Ortak gövde uzunluğu, pivot, alfa kenarı, küçük oyun ölçeği ve 8 yön dönüş QA henüz geçilmedi. Önce ölç; gerekiyorsa düzelt; sırf eski işlem hattı var diye otomatik büyütme, beam/warp, N-LUT veya ShowLook uygulama. Renk ve boyut zaten kabul sınırındaysa geometriyi/renkleri koruyarak normalizasyon/montaj yap; kaynak çözünürlüğü yetersizse mevcut upscale kapısı geçerlidir. Görsel kaynak beğenisi final oyun paketi kabulü değildir. Mevcut onaylı SC-02 ZIP korunur.


## 23. Sprite hizalama + montaj ve canlı efekt kontrolü — 2026-11-27

**Kanonik araç:** [tools/sprite_manual_aligner_template.html](tools/sprite_manual_aligner_template.html). Tek dosya, çevrimdışı, harici bağımlılık yok. Önceki 8 PNG / yön / x-y-scale / ghost / dönüş / JSON / atlas işlevleri korunur; SC-11 yerel pilotunun bağımsız viewport zoom/pan, yerel beam, fırça warp ve Puppet Warp yetenekleri taşındı. Yeni gemi için kaynaklar aynı 1024 master koordinat sisteminde hazırlanır, tek dünya ölçeği korunur. Her gemi için bağımsız fit yapılmaz. Yeni üretimde kullanıcıya 8 kaynak PNG gömülü aynı şablon verilebilir; generik repo şablonu gemi PNG'si içermez.

### Montaj iş akışı

- Montaj ve hizalama sekmeleri aynı tuvali kullanır. Önce kaynakları yükle, yönü seç, gerektiğinde hizala. Montaj sekmesinde varsayılan Seç/taşı modudur. Mevcut noktayı tutup sürükle; boş alanda görünüm kaydırılır, iki parmakla yakınlaştırılır. Yeni parça yalnız tür seçilip + Ekle'ye basıldığında oluşturulur; gereken noktalar tamamlanınca otomatik seç/taşı moduna dönülür. Nokta türleri: **top namlusu** iki nokta (ağız, görsel ateş yönü); **flama/sancak** iki nokta (montaj, kumaşın yönü ve uzunluğu); **yelken** dört köşe (üst sol, üst sağ, alt sağ, alt sol), üçgen flok için üç köşe (tepe ve taban köşeleri); pruva, kıç, yangın, tamir, pivot ve su hattı tek nokta. Parça ID'sini yönler arasında sabit tut; iskele/sancak kimliklerini doğrula. Örtülü top görünürmüş gibi işaretlenmez; gizli olarak kaydet veya ilgili görünüşte atla.
- Parça listesi: ID düzenleme, gizle/göster, Tek nokta veya Tüm parça modunda doğrudan sürükleme (maske köşeleri de taşınabilir), silme, istenirse karşı yön yansıtma. Ayna işlemi yalnız gerçek simetrik kaynaklarda; N/S ayrı, asimetrik gemide otomatik ayna kullanılmaz. Ayna geometrisinin ve top taraflarının gerçek kaynak üzerinde gözle QA'sı zorunlu.
- Şeffaf arma PNG yükle; aynı resim her tanımlı yüzeye UV eşlemesiyle uyarlanır. Yelken maske + ile seçili yelken üzerinde dört köşeli dışlama alanı ekle (halat, direk vb.); mevcut luminans/alfa otomatik maskesi yalnız sezgiseldir. Flama/sancak ve yelken arması bağımsız, flama için 60, yelken için 24 fazlı önbellekli preview; seçili parçanın arma boyutu ve kumaş rengi ayrı. PNG dosyası kullanıcı tarafından seçilir, JSON içine gömülmez. Top testinde tek seçili veya tüm görünür namlulara namlu parlaması/duman/mermi görseli; pruva/kıç ve diğer efektler yerleşim göstergesi. Noktalar ve efektler bağımsız kapatılabilir.
- Arayüz Montaj / Hizalama / Dosya olarak ayrılır; arma ve maske ayrıntıları katlanır. Dönüş kontrolü her sekmede erişilebilir, 6–60 yön FPS seçeneği ve canlı efekt FPS göstergesi vardır. Nokta sürüklemede render requestAnimationFrame ile birleştirilir, ana tuval/arka plan gereksiz yeniden çizilmez; sürüklenen yelkenin pahalı UV cache güncellemesi bırakınca yapılır. Mobil boyutlu Chromium'da tek nokta ve tüm parça taşıma, dokunmatik sürükleme, ekleme sonrası seç/taşı, JSON ve sekme testleri geçti; efekt çizimi yaklaşık 60 FPS ölçüldü. Bu fiziksel cihaz performansı veya 60 FPS garantisi değildir. Animasyon overlay canvas'ta; ana sprite/warp canvas'ı hareketli efekt için yeniden çizilmez. UV katmanı değişiklikte hazırlanır, tekrar çizimde hazır faz seçilir. Runtime için öneri ortak gemi sınıfı × arma cache/atlası veya shader; bu HTML önizleme motoru Godot'a entegre değildir. Tarayıcıda gerçek PNG yükleme, 8 yön, animasyon/ana tuval ayrımı, manuel maske, ayna, eski JSON, pin kaynak↔hedef dönüşümü ve 4096×2048 ana atlas dışa aktarımı test edildi. Test fiziksel Android/Godot performansı değildir. Tam gemi/halat derinlik örtüşmesi ve fizik kumaş simülasyonu yok.

### JSON sözleşmesi ve teslim

- Normal `sprite_manual_alignment.json` eski `fps, frames` alanlarını korur; ek `mounts` nesnesi aynı kayıtla taşınır. Ayrı `sprite_mounts.json` da çıkar/geri yüklenir.
- `schema: seacraft-mounts-v1`, `space: source-local-1024-centered`, `aligned_space: cell-1024-top-left`. `frames[N|NE|E|SE|S|SW|W|NW]` bir parça dizisidir. Her parçada `id, kind, p, hidden, mirror, size, color, masks, aligned, aligned_masks`. `p` kaynak, `aligned` son hücre koordinatlarıdır; x/y/scale, yerel beam ve ters warp/pin alanından hesaplanır. Yön oku için ikinci nokta kullanılır; son hücre C ise koordinatı C/1024 ile dönüştür. Kaynak PNG seti ve yön etiketleriyle bağlıdır. Kullanıcı JSON'u final onay girdisi; son hizalama/warp sonrasında JSON'u yeniden çıkar. Yeni gemi sprite kaynağı değişirse eski koordinatları doğrulamadan kullanma.
- Ana atlas efektleri ve işaretleri içermez. Eski oyun ZIP'i/atlas düzeni değiştirilmez; montaj JSON'u ek geliştirme/entegrasyon girdisi olarak ayrı tutulur. Runtime tüketicisi ve paket sözleşmesi uyarlaması ayrı bir iş. Kullanıcı SC-02 için başlangıç işaretlerini görsel olarak doğrulamalı; görünmeyen yelken yüzeyleri için arma çizilmez. Bu karar mevcut PLAY-01 veya Godot dosyalarını değiştirmez.
