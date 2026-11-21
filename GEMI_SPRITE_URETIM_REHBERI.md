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


## 11. Mobil manuel hizalama aracı

Otomatik pivot/anchor hizalama iyi bir ilk tahmin üretir; ancak final kabulte birkaç piksellik yönler-arası hareket insan gözüyle hâlâ fark edilebilir. Bu nedenle final üretim kapısında mobil manuel hizalama aracı kullanılır:

`tools/sprite_manual_aligner_template.html`

Araç tek dosyalık, internetsiz çalışan bir HTML'dir. Kullanım:

1. 8 adet 1024×1024 şeffaf PNG'yi **N, NE, E, SE, S, SW, W, NW** sırasıyla seç.
2. Büyük önizlemede tek parmakla seçili frame'i X/Y kaydır.
3. İki parmak pinch ile yalnız gerektiğinde scale düzelt.
4. **Play** ile dönüşü sürekli izle; konumsal sıçramayı tek kare yerine döngü içinde değerlendir.
5. **Ghost** ile önceki yönü düşük alfa referans olarak göster.
6. Ayarları JSON olarak indir; böylece manuel karar tekrar üretilebilir.
7. Atlas düğmesiyle 4×2 master atlası dışa aktar.

Final merkezleme kuralı:

- otomatik anchor = başlangıç tahmini
- manuel HTML hizalama = final görsel kabul kapısı
- kaydedilen JSON = yeniden üretilebilir düzeltme kaydı
- PNG'lerdeki ölçek ve LUT işlemleri HTML'e girmeden önce tamamlanmış olmalı
- mümkünse scale = 1 bırakılır; araç esas olarak X/Y pivot ince ayarı içindir

SC-02 pilotunda final kabul edilen manuel kayıt, otomatik hizalamanın üzerine frame bazlı X/Y düzeltmeleri uyguladı. Bu nedenle sonraki gemilerde de final paketlemeden önce aynı araçla bir tam 360° dönüş kontrolü yapılmalıdır.
