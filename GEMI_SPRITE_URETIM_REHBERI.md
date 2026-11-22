# SeaCraft Gemi Sprite Üretim Rehberi

Bu belge, `GEMI_GORSEL_TASARIM_VE_SPRITE_PLANI.md` içindeki kanonik kuralları değiştirmez. Amaç, SC-02 · Kül Dikişi pilot üretiminde fiilen çalışan görsel üretim hattını ve tekrar edilmemesi gereken hataları operasyonel bir rehber olarak kaydetmektir.

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
- no mirroring
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

Tüm GPT Image üretim isteklerinde **ABSOLUTE OUTPUT REQUIREMENT = STRICT 1:1 SQUARE IMAGE** yazılır. Bu kural master/hero, tek yön sprite, concept/reference ve 8-yön radial referans panosu için aynıdır. Genişlik ve yükseklik eşit olmalıdır. 4×2 final atlas gibi kare olmayan paketler GPT Image içinde üretilmez; ayrı kod/normalizasyon aşamasında monte edilir.

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
