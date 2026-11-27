# SeaCraft — Gemi Görsel Tasarımı ve Sprite Üretim Planı

**Kanonik karar · SOHBET-04 · Godot 4.7 · 2D/2.5D · Android ve masaüstü, offline + LAN.** İncelenen `main` snapshot’ı: `1f82426f80f68d1f46464bfe15628fd9b439fff5`; brif başlangıcı `a852f1ab644c0625ae4770dbce122ff4d1cf592d` doğrulanmış ata. Bu dosya tasarım ve üretim sözleşmesidir; görsel, kod veya çalışan Godot uygulaması değildir.

## 1. Kaynaklar ve roster kararı

- [ICERIK_KATALOGU.md](ICERIK_KATALOGU.md): 12 Gold ve 33 Elite tasarımı, açık uçlu A–Z event arşivi ve NPC/Admiral/boss grupları bir **çeşitlilik sinyali**; tasarım satırı başına gemi yok. C-0062 tüccar, C-0061 Admiral tetiklenmesi ve C-0070 hayalet boss örneği. Adları, armaları, gövde/kumaş renklerini, görselleri veya dengeyi aktarma. Kamera türü ve içerik çeşitliliği dışında Seafight referansı prompt girdisi değildir.
- [MEKANIK_KATALOGU.md](MEKANIK_KATALOGU.md): AI-02–05 ve AI-23–24 devriye, keşif, konvoy, eskort ve komuta ayrımını; AI-08/10/12/14 menzil, onarım, boarding, boss fazını gerekçelendirir. Açık deniz oyuncu/NPC filoları aynı fiziksel gövde havuzunu kullanabilir. Elite bir ilerleme rütbesidir (SC-08 varyantı), Admiral görsel olarak ayrı komuta gövdesidir.
- [HAZIR_ASSET_ARASTIRMASI.md](HAZIR_ASSET_ARASTIRMASI.md): A-07 yönlü ayrı render ve katman düzeni için yöntem referansı; A-01/02 piksel sanatı bu fotogerçekçi üretimin kaynak gövdesi değil. Üçüncü taraf varlığı bu teslimde kullanılmaz. Deniz canavarları, sualtı gemileri, petler, kaleler ve kıyı dekoru kapsam dışı.
- [GODOT_HAZIR_COZUMLER.md](GODOT_HAZIR_COZUMLER.md): T30 sabit Camera2D, T31 ayrı su/foam/wake ve T33 Android Compatibility ilk test adayı. Yön ve efekt sunumu istemcide; gerçek baş açısı, çarpışma ve gameplay yetkili simülasyonda. Sprite paketi ağ/çevrimiçi servis gerektirmez.

**15 temel gövde.** Önemli roller yalnız recolor ile ayrılmaz. Minimum: oyuncu sloop’u, keşif, ticaret, korsan, eskort, ağır, destek ve raid boss. Tam: bunlara devriye, interceptor, artillery, boarding, lider, Admiral ve event hayaleti eklenir. Minimumda dışarıda kalan bir rol, başka gövdeyi boyayıp varmış gibi gösterilmez. Boss ve hayalet farklı siluet/karşılaşmadır; event eşyası, rütbe ve faction ayrı gövde sayılmaz.

## 2. MASTER ART DIRECTION

**Fotogerçekçi karanlık denizcilik, kontrollü kozmik korku.** Kasvetli ve insanı küçük gösteren bir dünyada savaş/tuz/ıslaklık izi taşıyan gemiler. Islak geniş damarlı ahşap, gerçek su hattında seyrek tuz/yosun, oksitli demir/bronz, ıslak lifli halat, ağır kirli keten. Dövülmüş metalde çukur ve akıntı izi; küçük deformasyon fiziksel taşıyıcıya uyar. Tekinsizlik: ıslak fosil, tanımsız oyma, gömülü kemik, alışılmadık metal parça. Cursed/boss’ta mafsala kaynaşmış kaburga, siyah yosun, barnacle/mercan ve çok sınırlı soluk ışık kullanılabilir; serbest tentacle yığını, neon, gösterişli high-fantasy yok.

**Kamera:** Ortografik paralel projeksiyon, yatay düzlemden **55°**, roll **0°**. Aynı kamera; sadece gemi yaw yapar. Pruva–kıç su hattı ekseni ekran yönünü belirler, direk ucu belirlemez. N ekran yukarı, E sağ; sektörler 45°. N/S’de borda örtülebilir; ekstra kamera eğimiyle görünür yapılmaz. Blok projeksiyonu: ekran +x sağ, +y aşağı; zemin y izdüşümü `sin(55°) × y`, yükseklik yukarı `cos(55°) × z`. Yön kılavuzu için hedef ekran açısı φ, +x’ten saat yönünde ölçüldüğünde yatay blok yaw’ı `atan2(sin φ / sin 55°, cos φ)`; böylece çapraz okuma tam ekran 45° kalır. E/W tam su hattı uzunluğu kalibrasyonudur; N/S doğal önden kısalır.

**Işık:** CD/ayna üretiminde yatay simetrik, geniş diffüz soğuk ışık; ayrı sekiz render yönteminde üst-sol/NW plan yönünden sabit geniş soğuk ana ışık, yaklaşık 60° yükseklik; yumuşak diffüz fırtına öncesi gökyüzü dolgu, kontrollü ıslak specular; kaynak gemiyle dönmez. Temas/AO yalnız yüzey üzerinde; gemi dışı gölge, yansıma, köpük, duman, sis, glow ve su sprite’a gömülmez. Güverte, borda, yelken farklı değer kütleleri; kömür siyahı kontrastı tamamen yutmasın. Kontur çizme; değer ve hacim ile kenar tarif et.

**Renk/yoğunluk:** Kömür, koyu eskimiş kahve, soğuk gri, navy, kirli mavi-yeşil, mat bronz, zeytin, kemik, kül. Boğuk amber, kurumuş kan kırmızısı, hastalıklı teal/yeşil ve morumsu siyah yalnız vurgu; vurgu yaklaşık en çok dolu alanın %3’ü, emissive %0,5’i. Önce gövde ve arma kütlesi, sonra port/işlev, sonra perçin ve lif. İnce halat mobilde kaynar/titreşirse ayrıntıyı azalt, ana silueti değil. Karanlık/sis atmosferi oyun sahnesine aittir; sprite çevresi boş ve true RGBA.

**Mobil kapı:** 1× referansta en küçük E/W gövde 60 px, %75 zoom’da 45 px. Her fişteki 3–5 ayıraçlar gri ton ve üç farklı deniz değeri üzerinde okunmalı. Pilotun ilk üç gövdesini iki değerlendirici, rastgele N/E/NE/SW görünümlerinde en az 3/4 doğru tanımalı; sonra yeni gövdeyi en yakın siluet komşusuyla aynı teste sok. Arma rengi ve UI kapalıyken rol okunur; tekstür değil hacim düzeltilir.

## 3. Gövde fişleri

L/B, ıslak gövdenin pruva–kıç boyu / azami enidir; civadra, yelken ve dış aksesuar hariç. Güverte sayısı ambar/hizmet katı dahil. Port adedi fiziksel açıklık adedidir; GPU görünüşünde örtülen port doğal olarak görünmez ve görsel adet oyun DPS’si değildir.

### SC-02 · Kül Dikişi — Başlangıç sloop’u

**Rol ve esin:** Oyuncu başlangıcı, kurye NPC; gaff sloop. **Gövde:** L/B 4,0:1; Dar iğ gövde, alçak borda; az kalkık kama pruva, yuvarlak kısa ayna kıç. **Güverte, direk ve yelken:** 1 açık; 1 direk; kıça açılan yamuk gaff ana yelken ve dar tek flok. **Batarya ve görünür açıklıklar:** 0 batarya/0 port; açık güvertede 2 küçük top/borda.

**Ana siluet / mobil ayıraçlar:** tek yamuk yelken, ince flok, kama burun, kısa yuvarlak kıç. **Palet, yüzey ve kumaş:** ıslak koyu meşe, mat demir halkalar, kül grisi yamalı keten. **Bayrak ve faction alanı:** direk tepesinde çatal flama, kıçta mühür pedi. **Süs/baş figürü:** az; aşınmış kemik bodoslama kaması, heykel yok.

**Varyant:** flama, yelken tonu ve mühür. **Sabit:** tek direk/flok, kısa ayna ve açık top yerleri; ayrıca pivot, su hattı ve silah soketleri. **Negatif:** iki direk, kutu kıç veya kapalı silah portu yok.

### SC-03 · Tuz Ambarı — Ticaret fluytu

**Rol ve esin:** Tüccar, kaçakçı NPC; oyuncu kargo; Hollanda fluytu. **Gövde:** L/B 3,0:1; Geniş ambar karnı, içe kapanan borda; yuvarlak baş, armut kıç. **Güverte, direk ve yelken:** 2: iş+ambar; 3 kısa direk; ilk ikisinde birer kısa enli kare, kıçta kısa latin. **Batarya ve görünür açıklıklar:** 0 batarya/0 port; tek merkez kargo kapağı silah değildir.

**Ana siluet / mobil ayıraçlar:** armut kıç, alçak üç direk, iri merkez kapak, portsuz borda. **Palet, yüzey ve kumaş:** tuzlu kahverengi meşe, paslı demir, kirli bej bez; ıslak koyu yük örtüsü. **Bayrak ve faction alanı:** mizana üstünde düz flama, kapak yanında lonca damgası. **Süs/baş figürü:** az; sığ oyma baş baklası, baş figürü yok.

**Varyant:** sandık, örtü tonu, lonca damgası ve flama. **Sabit:** armut kıç, kapak, üç kısa direk, portsuz borda; ayrıca pivot, su hattı ve silah soketleri. **Negatif:** savaş galerisi, yüksek kale veya komuta sehpası yok.

### SC-08 · Demir Mezar — Ağır hat gemisi

**Rol ve esin:** Ağır NPC, geç oyun oyuncu tankı; perçinli Elite varyant; iki bataryalı hat gemisi. **Gövde:** L/B 3,6:1; Derin dik geniş gövde; küt takviyeli baş, geniş düz kutu kıç. **Güverte, direk ve yelken:** 3: açık+iki batarya; 3 direk; önde/ortada ikişer kare, kıçta bir kare ve yarım gaff. **Batarya ve görünür açıklıklar:** 2 batarya; üstte 7 altta 8 düzenli dikdörtgen port/borda.

**Ana siluet / mobil ayıraçlar:** çift port hattı, kutu kıç, demir burun, geniş kare arma bloğu. **Palet, yüzey ve kumaş:** kömür meşesi, çukur paslı ferforje, bronz perçin, kül gri ağır bez. **Bayrak ve faction alanı:** ana direk tepesi, düz kıç aynasında birlik mührü. **Süs/baş figürü:** orta; fosil kaburga baş postasına gömülü.

**Varyant:** düz plaka, şerit, flama ve mühür; Elite’te en az iki modül. **Sabit:** 7+8 port, üç direk, küt baş ve düz ayna; ayrıca pivot, su hattı ve silah soketleri. **Negatif:** komuta fener çifti, üçüncü batarya veya çan yok.

### SC-01 · Sis İğnesi — Keşif filikası

**Rol ve esin:** Oyuncu keşif, liman habercisi, konvoy öncü NPC; açık lugger filikası. **Gövde:** L/B 4,4:1; Çok alçak açık çift uçlu kabuk; ince dik baş ve sivri kıç, açık dümen. **Güverte, direk ve yelken:** 1 açık taban; 1 kısa direk, eğik sırıkta tek lug yelken; flok yok. **Batarya ve görünür açıklıklar:** 0 batarya/0 port/top; görünür kürek oturağı.

**Ana siluet / mobil ayıraçlar:** iki sivri uç, tek eğik bez, çıplak oturak, açık palalı dümen. **Palet, yüzey ve kumaş:** ıslak koyu ceviz, kararmış çivi, üç dikişli soluk kemik tonu yelken. **Bayrak ve faction alanı:** direkte ip flaması, bez üst üçte birinde işaret pedi. **Süs/baş figürü:** çok az; üç aşınmış çizik, figür yok.

**Varyant:** ip flaması, küçük işaret. **Sabit:** çift uç, lug, oturak ve dümen; ayrıca pivot, su hattı ve silah soketleri. **Negatif:** flok, top, kapalı güverte veya yüksek kıç yok.

### SC-04 · Yarık Çene — Korsan brig’i

**Rol ve esin:** Raider NPC; oyuncu korsan yükseltmesi; brig. **Gövde:** L/B 4,1:1; Eğimli orta ince borda; kesik kama pruva; tek kıç basamağı ve kısa tırnaklı ayna. **Güverte, direk ve yelken:** 2: açık+batarya; 2 direk; önde iki kare, arkada bir kare ve ince gaff. **Batarya ve görünür açıklıklar:** 1 batarya, çatlak kapaklı 5 port/borda.

**Ana siluet / mobil ayıraçlar:** iki kare arma bloğu, kama baş, tırnaklı kıç, açık basamak. **Palet, yüzey ve kumaş:** kurumlu koyu meşe, çukur demir, zeytin gri ağır bez ve tek kirli açık yama. **Bayrak ve faction alanı:** arka direk flaması, kıç aynasında çentik mühür. **Süs/baş figürü:** az; fosil çene pruvasına gömülü.

**Varyant:** bağlı ganimet, flama, trim ve yelken tonu. **Sabit:** 2 direk, 5 port, kama baş ve tırnaklı ayna; ayrıca pivot, su hattı ve silah soketleri. **Negatif:** boarding tablaları, parlak kafatası veya çift batarya yok.

### SC-06 · Perçin Hattı — Eskort korveti

**Rol ve esin:** Konvoy koruması NPC; oyuncu savunma; kısa korvet. **Gövde:** L/B 3,8:1; Tok düz omuzlu gövde, kısa yükseltilmiş baş, geniş düz ayna ve su hattı tamponu. **Güverte, direk ve yelken:** 2: açık+batarya; 2 direk; önde iki dar kare, arkada yüksek gaff ve küçük üst kare. **Batarya ve görünür açıklıklar:** 1 batarya, eş aralıklı 6 kare port/borda.

**Ana siluet / mobil ayıraçlar:** çift paralel borda rayı, düz ayna, düzenli port ritmi, yüksek gaff. **Palet, yüzey ve kumaş:** koyu ıslak meşe, cüruflu gri demir, dar füme mavi gri ağır bez. **Bayrak ve faction alanı:** arka direkte çatal flama, baş plakasında arma. **Süs/baş figürü:** az; basık bronz kalkan, canlı baş figürü yok.

**Varyant:** flama, kalkan pedi, cıvatalı plaka aksesuarı. **Sabit:** çift ray, 6 port, düz ayna ve 2 direk; ayrıca pivot, su hattı ve silah soketleri. **Negatif:** korsan tırnakları, üçüncü direk, sehpa veya büyük ambar kapağı yok.

### SC-11 · Dikiş Feneri — Onarım tender’ı

**Rol ve esin:** Saha onarım NPC’si, oyuncu destek; tersane hoy’u ve kurtarma mavnası. **Gövde:** L/B 2,75:1; Geniş sığ omuz; yuvarlak burun; düz açık iş platformu kıç. **Güverte, direk ve yelken:** 2: iş+ambar; 2 direk; önde kare, arkada yarım kısa gaff; ortada A vinci. **Batarya ve görünür açıklıklar:** 0 batarya/0 port; 1 açık savunma topu başta.

**Ana siluet / mobil ayıraçlar:** A vinci, portsuz borda, açık kıç, enine tahta demeti. **Palet, yüzey ve kumaş:** yağlı küllü meşe, yeşillenmiş bronz makara, soluk zeytin bez ve ıslak çuval. **Bayrak ve faction alanı:** ön direk tepesi, vinç tabanında tersane damgası. **Süs/baş figürü:** az; tek kapalı boğuk amber fener, baş figürü yok.

**Varyant:** tamir yükü, fener, flama ve trim. **Sabit:** A vinci, portsuz borda, düz kıç ve 2 direk; ayrıca pivot, su hattı ve silah soketleri. **Negatif:** kanca sırası, tamir halesi veya üçüncü direk yok.

### SC-14 · Dip Çanı — Lanetli raid sancak gemisi

**Rol ve esin:** Çok fazlı boss, oyuncu kullanmaz; dört direkli ağır kalyon ve enkaz. **Gövde:** L/B 3,25:1; Merdiven omuzlu dev gövde; çatal çene baş; kemik kemerli yüksek kırık kıç. **Güverte, direk ve yelken:** 4: açık+iki batarya+alt enkaz; 4 direk; ilk ikisinde birer dik kare, ortada geniş kare, kıçta yarım gaff. **Batarya ve görünür açıklıklar:** 2 batarya, üstte 6 altta 7 port/borda, ayrıca baş çatalında 2 kuşatma ağzı.

**Ana siluet / mobil ayıraçlar:** dört direk, ters çan boşluğu, çatallı gözsüz çene, merdiven kıç. **Palet, yüzey ve kumaş:** siyah yosunlu meşe, kemikle kaynaşmış demir, morumsu siyah ağır bez; yüzeye sınırlı teal damar. **Bayrak ve faction alanı:** arka direk dibinde parçalı bez, kıç kemerinde kesik işaret. **Süs/baş figürü:** yoğun kümeli; organik çatal kaburga, çan çerçevesi, serbest tentacle yok.

**Varyant:** faz işareti, yüzeyde kül decal; faction yok. **Sabit:** dört direk, 6+7 port, çene, çan ve kıç kemeri; ayrıca pivot, su hattı ve silah soketleri. **Negatif:** neon, kafa/uzuv kalabalığı veya uçan parçalar yok.

### SC-05 · Kör Mühür — Devriye kuteri

**Rol ve esin:** Faction devriye/gümrük NPC, oyuncu kontrat; silahlı cutter. **Gövde:** L/B 3,5:1; Orta genişlik ve yüksek küpeşte; küt dik baş; çentikli kısa kıç aynası. **Güverte, direk ve yelken:** 2: açık+sığ batarya; 1 yüksek direk; uzun gaff, küçük üst kare ve çift flok. **Batarya ve görünür açıklıklar:** 1 batarya, 3 iri kare port/borda.

**Ana siluet / mobil ayıraçlar:** tek yüksek direk, çift flok, üç açıklık, küt baş. **Palet, yüzey ve kumaş:** tuzlu koyu meşe, ferforje, soluk navy gaff ve kirli gri floklar. **Bayrak ve faction alanı:** direk tepesi uzun flama, iki baş plakası işaret pedi. **Süs/baş figürü:** az; kör bronz vizör biçimli plaka.

**Varyant:** flama, mühür, borda şeridi ve yelken tonu. **Sabit:** tek direk, çift flok, 3 port ve küt pruva; ayrıca pivot, su hattı ve silah soketleri. **Negatif:** sloop yuvarlak kıç, interceptor gagası, konvoy sehpası yok.

### SC-07 · Akıntı Bıçağı — Hızlı interceptor

**Rol ve esin:** Takip NPC’si, oyuncu hız uzmanı; Baltimore clipper/schooner. **Gövde:** L/B 5,2:1; Çok uzun ince alçak gövde; bıçak gaga pruva, dar aşağı eğimli kıç. **Güverte, direk ve yelken:** 1 açık; 2 geriye eğik direk; çift keskin üçgen yelken ve alçak tek flok. **Batarya ve görünür açıklıklar:** 0 batarya/0 port; başta iki açık takip topu, borda topu yok.

**Ana siluet / mobil ayıraçlar:** 5,2:1 iğ hattı, iki eğik direk, uzun gaga, alçak kıç. **Palet, yüzey ve kumaş:** nemli ceviz, mat demir kılavuz, gergin zeytin gri keten. **Bayrak ve faction alanı:** arka tepede iğne flama, kıç iç bordada işaret. **Süs/baş figürü:** çok az; demir baş dudağı, figür yok.

**Varyant:** flama, işaret ve kapalı küçük trim. **Sabit:** gaga, eğik direkler, üçgen yelken ve takip topu yuvası; ayrıca pivot, su hattı ve silah soketleri. **Negatif:** kare yelken, yüksek borda, geniş kargo ve gaff yok.

### SC-09 · Kör Havan — Uzak menzil topçu gemisi

**Rol ve esin:** Kuşatma NPC’si; oyuncu menzil uzmanı; bomb ketch. **Gövde:** L/B 3,15:1; Kısa geniş karın; yay gibi düşey omuzlu baş; basık kemer kıç. **Güverte, direk ve yelken:** 2: açık+cephanelik; 2 direk orta-kıçta; bir küçük kare ve bir alçak latin. **Batarya ve görünür açıklıklar:** 0 batarya/0 port; baş kuyusunda 2 merkezi havan, kıçta iki açık döner savunma topu.

**Ana siluet / mobil ayıraçlar:** iki iri havan ağzı, boş ön güverte, tok yay baş, kıça toplanmış arma. **Palet, yüzey ve kumaş:** ıslak karaağaç, oksitli bronz, dar füme keten. **Bayrak ve faction alanı:** mizana kısa flama, havan taşıyıcıları arası damga. **Süs/baş figürü:** az; iki döküm halka, baş figürü yok.

**Varyant:** flama, damga, küçük cephane aksesuarı. **Sabit:** iki havan, boş baş, kıç arma ve geniş karın; ayrıca pivot, su hattı ve silah soketleri. **Negatif:** yan ağır batarya, uzun takip burnu, vinç yok.

### SC-10 · Kanca Ağzı — Boarding kadırgası

**Rol ve esin:** Boarder NPC, oyuncu yakın baskın; galiot/küçük kadırga. **Gövde:** L/B 4,6:1; Uzun yassı taban ve geniş omuz; kesik mahmuz pruva; yükseltilmiş dar platform kıç. **Güverte, direk ve yelken:** 1 açık; 2 kısa direk; iki farklı alçak latin, çift borda yürüyüş tablası. **Batarya ve görünür açıklıklar:** 0 batarya/0 port; başta 1 açık top; borda başına 3 kapalı kanca yuvası top değildir.

**Ana siluet / mobil ayıraçlar:** çift yanal tabla, mahmuz, iki kısa latin ve kıç platformu. **Palet, yüzey ve kumaş:** kararmış meşe, oksitli demir kıskaç, füme bordo-gri üçgen bez. **Bayrak ve faction alanı:** arka direk altı kısa flama, iç tabla kabartması. **Süs/baş figürü:** az-orta; mahmuz üzerine fosil plaka.

**Varyant:** sabit yuvaya ağ/halat, flama ve işaret. **Sabit:** iki tabla, mahmuz, 2 latin ve 3 kanca yuvası/borda; ayrıca pivot, su hattı ve silah soketleri. **Negatif:** uzun kürek ormanı, havan, A vinci veya kare arma yok.

### SC-12 · Kervan Kandili — Silahlı konvoy lideri

**Rol ve esin:** Konvoy lideri NPC, oyuncu kontrat; silahlı ticari kalyon. **Gövde:** L/B 3,25:1; Geniş yük karnı; tek düşük baş kale; kademeli yüksek köprü kıç üzerinde açık sinyal sehpası. **Güverte, direk ve yelken:** 3: açık+batarya+ambar; 3 direk; iki geniş kare ve büyük latin mizana. **Batarya ve görünür açıklıklar:** 1 batarya, 4 port/borda; iki dar yük kapağı.

**Ana siluet / mobil ayıraçlar:** sinyal sehpası, iki kapak, yüksek arka köprü, dört küçük port. **Palet, yüzey ve kumaş:** tuzlu koyu meşe, bronz çerçeve, kirli bone bez, küçük amber lamba. **Bayrak ve faction alanı:** sehpa üzerinde iki sinyal dili, kıç aynasında lonca işareti. **Süs/baş figürü:** orta; pruvasında gömülü yön taşı.

**Varyant:** sinyal kumaşı, mühür ve küçük kargo. **Sabit:** sehpa, iki kapak, 4 port ve arka köprü; ayrıca pivot, su hattı ve silah soketleri. **Negatif:** fluyt armut kıçı, ikiz amiral ışığı ve çift batarya yok.

### SC-13 · Kara Mihver — Admiral komuta fırkateyni

**Rol ve esin:** Bölge Admiral ve eskort komutanı NPC; büyük komuta fırkateyni. **Gövde:** L/B 4,25:1; Uzun belirgin dar bel; yukarı kıvrılmış mahmuz; iki kapalı fenerli çift teras kıç. **Güverte, direk ve yelken:** 3: açık+batarya+alt depo; 3 uzun direk; önde/ortada ikişer dar kare, kıçta uzun gaff ve küçük üst kare. **Batarya ve görünür açıklıklar:** 1 batarya, tek hatta 10 küçük port/borda.

**Ana siluet / mobil ayıraçlar:** ikiz fener, çift teras, ince arma piramidi, tek uzun port hattı. **Palet, yüzey ve kumaş:** charcoal meşe, bronz fener kafesi, kül mavi bez ve fırtına grisi yamalar. **Bayrak ve faction alanı:** ana tepede çatal komuta flaması, terasta kalkan paneli. **Süs/baş figürü:** orta; örtülü göz kabartmalı bronz baş bloğu.

**Varyant:** komuta flaması, amblem, fener tonu ve trim. **Sabit:** ikiz fener, çift teras, 10 port, uzun üç direk; ayrıca pivot, su hattı ve silah soketleri. **Negatif:** çift batarya, organik çan, yük sehpası veya dördüncü direk yok.

### SC-15 · Solgun Omurga — Hayalet ve legendary enkaz

**Rol ve esin:** Lanetli açık deniz NPC ve özel event; oyuncu skin’i değil; terk edilmiş barque. **Gövde:** L/B 3,9:1; İnce belde dışa açık kaburgalar; yarık dar baş; iskele ucu çökmüş yarım ayna kıç. **Güverte, direk ve yelken:** 2: çökmüş açık+yarı açık batarya; 3 direk, 2 ayakta+1 ana direk kırığı; önde parçalı kare, kıçta kesik latin. **Batarya ve görünür açıklıklar:** 1 yıkık batarya; 4 port iskeleti/borda, iskelede ikisi kapalı; 1 açık kırık top.

**Ana siluet / mobil ayıraçlar:** kırık orta direk, iki kopuk bez, yarım kıç, üç dışa açık kaburga. **Palet, yüzey ve kumaş:** su emmiş morumsu siyah kereste, çürük demir, solgun bez ve siyah yosun. **Bayrak ve faction alanı:** kıç direği kökünde yırtık bez, ilk sağlam kaburgada çizik. **Süs/baş figürü:** orta; yarım spiral fosil ve tek çok soluk teal damar.

**Varyant:** çizik, don ve kurum decal. **Sabit:** kıç asimetrisi, iki sağlam ve bir kırık direk, 3 kaburga; ayrıca pivot, su hattı ve silah soketleri. **Negatif:** saydam gövde, hava sisi, çan veya aynalama yok.

## 4. Ölçek ve tek yön standardı

**Sekiz onaylı oyun yönü; simetrik gemilerde 5 özgün + 3 yatay yansıma (CD, 2026-11-26).** Yeni base gövdelerde pruva–kıç eksenine göre iskele/sancak simetrisi varsayılandır; pruva ile kıç aynı değildir. Beş özgün görünüşten E↔W, NE↔NW, SE↔SW çiftlerinin eksik üyeleri yatay yansıma ile tamamlanır; N ve S bağımsızdır. Simetrik güverte, arma, yelken eğrisi, top/aksesuar ve yumuşak iki taraflı ışık gerekir. Okunur yazı, tek taraflı hasar, asimetrik kargo veya SC-15'in kanonik çökmüş kıçı gibi kimlik öğeleri aynalanmaz; böyle durumlarda ilgili yönler ayrı üretilir veya kullanıcı onayıyla tasarım revize edilir. Eski onaylı sekiz yönlü kaynaklar korunur. Atlas her durumda dışarıda 8 yön olarak monte edilir.

**Hareket 360°**, görsel sektör N=0°, NE=45°, E=90°, SE=135°, S=180°, SW=225°, W=270°, NW=315°. En yakın sektör, ±22,5° sınır; titreşim için mevcut sektörden çıkışta 3° görsel histerezis. Yön atlasını gerçek açıda tekrar döndürme veya iki görüntüyü crossfade etme. Wake, mermi, gerçek atış ve fizik sprite açısına kilitlenmez.

**Dünya boyu:** SC-01 L=1,00; E/W taban **60 dünya birimi = 60 ekran px (1× referans)**. Tablodaki göreli boy ×60, 1× oturumda E/W su hattı boyu; en ≈ L/LB. Sanat referansı 1,00 için yaklaşık 12 m, 4,10 için 49,2 m; denge veya isabet ölçüsü değildir. Çarpışma ayrı su hattı planından. Bir gemide aynı ortak px/dünya oranı; yönler/hasar için ayrı “fit” yok. Baş/kıçta doğal projeksiyon kısalmasını koru.

### Efektif sprite çözünürlüğü — zorunlu kabul kapısı (M01 dersi)

Dünya boyu, 1× ekranda gösterilen boy, kaynak nesne çözünürlüğü, final görünür gövde çözünürlüğü ve şeffaf hücre boyutu farklı ölçülerdir. Dünya boyu tablosu fizik/sunum oranını korur; final PNG'nin piksel yoğunluğunu sınırlamaz. **160 px veya 224 px doku hedefi, hücre etiketi değil görünür ana gövde/hull uzunluğu hedefidir.** Eski hücre sınıflarının sayısal değeri (160/224/320/384 px) yeni üretimde başlangıç gövde çözünürlüğü hedefidir; paketleme hücresi sonradan hesaplanır. M01 örneğinde 48 dünya birimi korunur; E/W görünür gövde 160 px hedeflenir, 224×224 hücre ve 896×448 atlas kullanılır. 160×160 hücre içinde 48 px gövde bu hedef için reddedilir.

- Her yeni asset için önce hedef gerçek E/W gövde/hull piksel uzunluğu belirle. E/W anatomik uçları ölç; diğer yönlerin doğal projeksiyon kısalmasını koru. Alfa≥128 bbox genişlik/yükseklik ve gerçek landmark uzunluğunu ayrı raporla; kopuk piksel veya direk yüksekliğini gövde uzunluğu sayma.
- Kaynak nesneleri gerçek alfa sınırından ayır, gereksiz boşluğu kaldır; yüksek çözünürlüklü temiz master'ı koru. Manuel hizalama JSON'u varsa onaylı göreli yön ölçeği ve pivot ofsetleri korunur. Son paketleme için sekiz yöne tek ortak uniform katsayı ve aynı pivot dönüşümü uygula; yön başına yeniden fit, x/y ayrı stretch veya merkez sıfırlama yok.
- Final hücreyi hedef gövde yoğunluğundan SONRA seç: tüm yönlerin ortak pivot etrafındaki alfa>0 sınırları + dört kenarda en az 8 px alpha-0. Gerekirse tüm seti daha büyük ortak hücreye geçir; hedefi sessizce küçültme. Gemi hasar/maskeleri varsa aynı dönüşüm ve hücre. Dünya boyunu korumak için runtime sunum ölçeği = dünya gövde uzunluğu / final referans gövde px; pivot-relative socket'lere de aynı dönüşüm uygulanır. Fizik/hitbox değişmez.
- Hedef E/W uzunluğu ±%3 ve diğer yönlerin kılavuz projeksiyon oranları kontrol edilir; final bbox, kaynak gerçek detay yoğunluğu, padding, atlas hücre eşitliği ve dönüş QA ölçülmeden teslim yok. Kaynak yetersizse kullanıcıya AI upscale gerekli bildir; interpolasyon veya boş tuval büyütme yeni detay değildir.
- HTML'de düşük çözünürlüklü (örn. 256²) gömülü önizleme serbest; aynı sanal 1024 koordinatı ve aynı çerçeve dönüşümü korunur. JSON final yüksek çözünürlüklü kaynaklara uygulanır; preview PNG final kaynak değildir. Final GIF final PNG'lerden, ayrı HD GIF temiz yüksek çözünürlüklü hizalanmış kaynaklardan yapılır. HD incelemede tüm karelere ortak sıkı güvenli tuval kullanılır; dev boş canvas yasak.
- Manifestte dünya uzunluğu, target_body_px, measured_body_px_per_direction, source_bbox_per_direction, final_bbox_per_direction, effective_fill_ratio (bbox genişlik/hücre, yükseklik/hücre), cell_px, atlas_px, ortak katsayı, pivot, runtime_world_per_texel ve varsa upgrade_reason kaydedilir. Güncel dört dosyalı atlas-only ZIP standardı geçerlidir. Eski paketler bu kapı yeniden ölçülmeden geçmiş sayılmaz.

## 5. Hücre, alfa ve Godot 4.7

| 4 sütun × 2 satır | 0 | 1 | 2 | 3 |
|---|---|---|---|---|
| Satır 0 | N | NE | E | SE |
| Satır 1 | S | SW | W | NW |

4×2, standardı tek gridde tutar ve 8×1’e göre en uzun kenarı yarıya indirir. Her onaylı yön/base/H/S **1024×1024 normalize master RGBA PNG**; bu ham model çıktısı boyutunun garantisi değildir. Ortografik konsept/ref **2048²** arşiv. İlk paketleme bütçeleri gövdeye göre **160²/224²/320²/384²**, atlaslar **640×320/896×448/1280×640/1536×768**. Her gövde kendi sınıfında; >0 alfa sınırı padding’e girerse tek kareyi küçültme, kılavuzu ve gerekirse tüm gövde hücre sınıfını düzelt.

**Alfa:** 8 bit/kanal, sRGB straight RGBA PNG; dış alan alpha 0, kumaş opak, alfa yalnız doğal kenar ve deliklerde, hayalet gövde de opak. Final hücrenin dört kenarında en az **8 px** gerçek alpha-0 padding (komşular arası ≥16 px). Alfa>0 bbox clipping, alfa≥128 bbox siluet ölçümü için yön başına kayıt; trim veya bbox orta noktasına göre hizalama yok. Premultiplied uzayda filtrele, straight RGBA dön; 2 px yakın RGB edge bleed yalnız alpha-0 bölgede. Gri/siyah üstüne compositing ile matte, halo, beyaz fringe, kopuk piksel ve kırpılmış donanım kontrolü. Deniz, gökyüzü, iz, gölge, sis, yazı ve modelin boyadığı dama deseni yasak.

**Pivot ve socket:** Su hattındaki orta gemi kirişinin merkez çizgisiyle kesişimi; her final hücrede `(C/2,C/2)`, master’da `(512,512)`. Pruva/kıç, gerçek iskele/sancak top ağzı ve yönü, fener, arma/flama, hasar slotu, boarding ve wake kökü pivot-relative; uzak/yakın occlusion işareti. Düzeltme toleransı pivot ≤1 final px, su hattı uçları kılavuzdan ±%3, mast tepe/omuz noktaları 2 px, hedef yön ±2°; mast/port kimliği toleransı sıfır. H/S’de kopan soketi devre dışı bırak; sağlam soketi kırık donanıma taşıma.

**Motor:** `AtlasTexture.region=(col×C,row×C,C,C)`, `margin=0`, `filter_clip=true`, repeat kapalı, centered ve offset sıfır. Statik gövdede Sprite2D; SpriteFrames gerekirse sekiz ayrı **tek karelik** N…NW animasyonu, loop kapalı; yön seti animasyon zinciri değildir. Lineer filtre, başlangıçta mip kapalı ve lossless; cihazda shimmer olursa korumalı mip/export testi. Atlas RGB/RGBA verisi, maskeler ve ataçlar dışındaki tekil master’lar oyuna girmez. 1536×768 RGBA8 taban yaklaşık 4,5 MiB (mip/ek kaynak hariç), PNG dosya boyutu GPU belleği değildir. Android Compatibility’de çok gemi + su + VFX ile texture residency, overdraw, tam dönüş ve socket testi; uzakta marker LOD. [AtlasTexture](https://docs.godotengine.org/en/4.7/classes/class_atlastexture.html) · [SpriteFrames](https://docs.godotengine.org/en/4.7/classes/class_spriteframes.html).

## 6. Animasyon ve hasar

Çizim: su → wake/foam ve temas gölgesi → örtülecek uzak VFX → gövde → yakın aksesuar/decal → yerel namlu/kanca/ateş/duman → UI. Runtime efektleri ana sprite’a basma. Yakın soketler küçük rocking’i takip eder, dünya dumanı etmez. Sadece ana yön görünümü statiktir.

| Görsel | Ana sheet? | Ayrı yöntem |
|---|---|---|
| Idle sailing | Yalnız statik 8 yön | Hız ve izle hareket hissi, ek gövde karesi yok. |
| Hafif rocking | Hayır | Görsel pivotta 0,5–1° ve en çok 1 px heave; uzakta kapat; fizik etkilenmez. |
| Sail movement | Hayır | Varsayılan statik; maskeli gemilerde lokal düşük genlikli shader, dış siluet/halatlar sabit. |
| Wake | Hayır | Kıçtan ortak atlas izi, hız ve gerçek yönle uzat. |
| Water foam | Hayır | Baş ve borda temasına ayrı küçük birleşen/doku; durunca söndür. |
| Cannon fire | Hayır | Namludan ayrı mermi/iz; gameplay açısı 360°. |
| Cannon recoil | Hayır | Açık/top parçasına 1–2 px kısa runtime öteleme; diğerlerinde dumanla ima. |
| Muzzle flash | Hayır | 1–3 kare ortak VFX; delik katmanına göre occlusion. |
| Hit reaction | Hayır | Yerel shader kararması ve kısa kıymık/splash; gövde sıçramaz. |
| Smoke | Hayır | Düşük alfa kısa döngü/partikül; filo üstünde spawn bütçesi. |
| Fire | Hayır | Ayrı muted amber VFX, uygun gövde/güverte bölgelerinden otomatik; elle slot zorunlu değil; halo yok. |
| Damaged state | Hayır | Decal/maske, yalnız SC-08 ve SC-14 için tam pakette ayrı H atlası. |
| Sinking | Hayır | Su hattı maskesi, lokal eğim, enkaz; seçili 3 türde ayrıca S atlası. |
| Repair effect | Hayır | Gövde merkezi çevresinde ayrı VFX; özel tamir soketi isteğe bağlı. |
| Boarding state | Hayır | Kanca uçları arasında runtime halat, varsa tabla overlay, gövde tekrar çizilmez. |
| Buff/debuff | Hayır | Yüzeyde maske/decal ve küçük biçim kodlu simge; sadece renge güvenme. |
| Shadow | Hayır | Su hattı merkezli yumuşak parametrik gölge. |

| Hasar durumu | Karar |
|---|---|
| Pristine | Ana sprite; bakım/tuz izi kalır, savaş hasarı yok. |
| Lightly damaged | Kurum, kıymık, yelken içi delik ve çizik decal; yeni sprite yok. |
| Heavily damaged | Normalde 2–3 bölgesel decal, iç yelken maskesi. Tam pakette **SC-08 H:** düşmüş ön arma desteği, üst iskele bataryasında iki kırık açıklık; **SC-14 H:** iskele çene dişi kopuk, çan sehpası çökmüş. Her biri 8 onaylı poz. Minimumda boss fazı overlay telegraph ile, ayrı siluet S son fazında. |
| Burning | Yangın+duman+kurum, yeni gövde yok. |
| Sinking | **SC-14 S** minimum/tam: devrilmiş çan ve çatlak arka kemer. Tamda **SC-08 S:** baş su çizginin altında kabul edilir, kırık arka sancak direği kökü kalır; **SC-15 S:** çıplak omurga, çöken kıç. Her set 8 yön; su boyanmaz. Ekranda su hattı maskelemesi, küçük eğim, debris/köpük ve çekilme uygula. Diğer gemiler base/H + runtime batış; fade tek başına kullanılmaz. |

## 7. Faction ve varyant

**Minimum 3 profil:** Bağımsız (gri çatal flama + çizik halka; SC-01/02/04; SC-04 ganimet ve yırtık flama alt düzeni), Ambar Birliği (kirli bone düz flama + çift ambar çizgisi; SC-03/11), Kıyı Nöbeti (navy yarık flama + perçin şeridi; SC-06/08). **Tam 5 profil:** bunlara Kül Hanedanı (kurşun-amber şerit, kapalı fener ve ters çentik; devriye/Admiral alternatifi), Dip Yeminlileri (kül yeşili kısa flama, kesik mühür ve yüzeyde corruption; insan faction’ı, SC-15’in yerine geçmez) eklenir. Her varyantta iki bağımsız görsel işaret (ör. flama biçimi+kabartma veya yük düzeni); yalnız renk değişimi rol ayırmaz.

**Matristeki maskeler:** Her işaretli gövde için tek 8 yönlü RGB veri atlası, base hücre ve pivotu; R=yelken içi, G=trim/plaka, B=borda şeridi, lineer import; ana gövde alfa ayrı. SC-08 Elite aynı gemi: cıvatalı plaka, flama/mühür değişikliği, yeni port yok. H/S’ye modül taşırken yalnız sağlam socket/decal çalışır; H/S için ek maske bütçesi yok. Maskesiz gemide yelken recolor yok; işaret ve aksesuar soketi kullan. Sancak/iskele amblem pozisyonu ve occlusion yön fişinde; yazı aynalanmaz. Flama ve amblem ortak atlas, yön bazlı quad/montaj; boya bütün gövdeye uygulanmaz.

**Modüler sınır:** Yelken tonu, flama, amblem, local trim/şerit, deck cargo, kapalı fener ve armor plating; yalnız sabit yuva ve bbox içinde. Corruption, frost, fire, cursed izleri overlay/shader; hitbox’ı ve askerî görsel işlevi değiştirme. Figurehead aynı hacimli gömülü parçaysa tasarım varyantı olabilir; bu üretim paketinde ayrı baş figürü sprite’ı yok. Yeni baş silueti, yeni direk/arma geometrisi, batarya mimarisi, kargo omzu, komuta sehpası, havan kuyusu, boarding platformu, vinç veya boss çanı değişiyorsa ayrı gövde. Fişteki izin aynı gövde renderından modüler üretim içindir.

## 8. GPT Image hattı

**Zorunlu çıktı kuralı:** GPT Image ile üretilen her master, hero, concept/reference, tek yön ve 5-yön CD / 8-yön radial pano **STRICT 1:1 SQUARE IMAGE** olmalıdır. Width = height şartı promptun başında ve sonunda açıkça yazılır. Kare olmayan 4×2 atlaslar GPT Image içinde üretilmez; harici kodla monte edilir.

**İlk master promptu düzenleme değildir:** İlk gemi masterında henüz görsel referans yoksa `attached reference`, `same vessel as attached`, `edit`, `modify` veya benzeri referans/düzenleme dili kullanma. Doğrudan `Create ... in a STRICT 1:1 SQUARE FORMAT.` ile sıfırdan üretim iste. Referans dili yalnız gerçek referans görseli eklendiği sonraki aşamalarda kullanılır.

| Yaklaşım | Karar |
|---|---|
| Tek istekle 5 yön CD sheet | Yeni simetrik base gövdelerde varsayılan: gerçek 3D kılavuz, içe bakan pruvalar ve silüet odaklı kompakt yerleşim. Tek karede 8 ayrı görünüş asimetrik/istisnai gövdeler için seçenek; süreklilik QA zorunlu. |
| Tek master → ayrı yön renderı | Nihai aşamada evet; yalnız tek açı gizli bordayı tanımlamaz, ortografik kılavuzla kilitle. |
| Önce 4 yön → kalanlar | Tek başına yeterli değil; N/S ayrı olduğu için 5 özgün görünüş gerekir. 5+3 yatay yansıma yalnız simetri ve dönüş QA ile kabul edilir. |
| Orthographic concept → yönler → atlas | İstisnai kurtarma hattı; yeni varsayılan gemiye özel parametrik CD → tek GPT Image pano → harici montaj. |

1. Kanonik gemi fişi ve parametrik 3D referans zorunlu; **ayrı concept sheet yalnız gerektiğinde**: top plan, iskele/sancak profil, baş/kıç; L/B, su hattı/pivot, ayrı numaralı mast-kumaş-port/soket listesi, asimetri, renk ve trim. GPT Image konsepti ölçü kılavuzu olarak önerir; çizgi/ölçü elle düzeltilir. Aynı kamera altında sekiz projeksiyon bloğu bu kılavuzdan hazırlanır; gerekirse kaba 3D proxy yalnız referans, oyun varlığı değil.
2. Simetrik gemilerde kanonik kimlik + gemiye özel birleşik renksiz parametrik CD + orijinal malzeme atlasıyla doğrudan tek beş görünüşlü kare kaynak üret. Renk kodlu CD yalnız ihtiyaçta yardımcı referanstır; ayrı arma görselleri varsayılan değildir. Güncel Ship Builder ve prompt sözleşmesi [üretim rehberi §22](GEMI_SPRITE_URETIM_REHBERI.md#22-gemiye-özel-parametrik-ship-builder--2026-11-27-güncel-varsayılan). Tekil concept/NE hero gerektiğinde yardımcıdır, zorunlu ikinci üretim değildir. Asimetrik istisnada ayrı sekiz yön yöntemi kullanılabilir. E/W port ve uzunluk; N/S pruva/kıç kütlesi; çaprazlarda yelken occlusion kontrol edilir. Farklı mast sayısı, bez kesiti, port, kamera veya tarafa yanlış düşen kargoda geçersiz kaynak düzeltilir. Sabit metre/px ilişkisi; hücreye ayrı fit yok. H/S ancak ana sekiz oyun yönü geçince türetilir.
3. Modelin gerçek alfa desteği varsa şeffaf PNG iste; yoksa düz tek renk matte üstünde tek gemi, dış işlemle temiz alfa. Boyanmış dama/pus gerçek alfa değildir. Kenardaki halat/metal/delikler matte testinden geçer, kırpılmış parça kabul edilmez. Source çözünürlüğü normalize edilir; montaj, yön sırası ve padding harici yapılır. Modelin poz ölçüsünü veya sürümün şeffaflık özelliğini varsayma. [OpenAI Image generation kılavuzu](https://developers.openai.com/api/docs/guides/image-generation).
4. Sırayla concept fizik/ölçü, NE malzeme, iki borda parça kimliği, baş/kıç düşey okuma, tam atlas, alfa/pivot/soket, 360° önizleme ve Android düşük zoom. Çalışma kaydında model/ayar, revizyon, referansın kaynağı ve haklar; dosya kimliği ör. `SC-02_base_NE.png`, `SC-02_base_atlas.png`. Dilim (minimum/tam) paketinden bağımsız aynı varlık adı ve cell standardı.

**Tarihsel tek yön promptu (istisna):**

> One isolated SeaCraft vessel, [ship ID/class], same vessel as attached orthographic reference and NE hero. Lock [L/B, waterline and bow/stern], [exact deck and mast IDs], [sail shapes, cloth and attachment points], [port/starboard port and weapon layout], [fixed silhouette and asymmetry]. Rotate ship in yaw only to [target heading and blockout]. Orthographic, 55° above horizontal, roll zero, fixed upper-left broad cold light. Real wet timber, aged rope, oxidized metal, heavy muted sailcloth, [muted palette and restrained eerie motif]. Match [waterline pivot, calibrated E/W length, attachment landmarks]. Render one full object, isolated, true transparent RGBA when supported. No sea, sky, halo, haze, foam, wake, cast shadow, grid, text, extra masts or ports. Natural occlusion. State [base/H/S]: only [approved structural delta]; follow [ship-specific negative constraints].

Yeni varsayılan genel prompt ve montaj sözleşmesi [üretim rehberi §24](GEMI_SPRITE_URETIM_REHBERI.md). Fişten rol ve sabit geometriler, yelken/port sayıları ve biçimleri, taraf kimliği, palet, motif, özel negatifler; matristen boy ve hücre; concept’ten kayıt noktası alınır. “Aynı seed” ölçü kontrolünün yerine geçmez.

## 9. Üretim hesabı

| Kalem | Minimum | Tam (minimum dahil) |
|---|---:|---:|
| Temel gövde | 8 | 15 |
| Ana yön/gövde | 8 | 8 |
| Ana render | 64 | 120 |
| Orthographic concept/ref | 8 | 15 |
| Ek NE hero (ana render içinde) | 0 | 0 |
| Ek H renderı | 0 | 16 |
| Ek S renderı | 8 | 24 |
| Toplam oyun gövde renderı | 72 | 160 |
| Concept dahil özgün kabul görseli | 80 | 175 |
| Faction profili | 3 | 5 |
| Faction kontrol atlası | 5 | 7 |
| Ortak VFX/aksesuar atlası | 2 | 3 |
| Oyun gövde atlası (base + H + S) | 9 | 20 |
| **Gerçek oyun PNG / atlas toplamı** | **16** | **30** |
| Arşiv PNG (tekil gövde master’ları + concept) | 80 | 175 |
| **Oyun + arşiv gerçek PNG toplamı** | **96** | **205** |

Minimum gövde atlasları 8 temel + SC-14 S; tam 15 temel + 2 H + 3 S. **Ortak A**: wake, foam, splash, namlu, hit, duman, ateş, debris/kurum. **Ortak B**: flama/arma, kargo/fener, kanca, repair ve buff/debuff işaretleri. **Tam C**: frost/corruption, boss telegraph, ikinci kırık/yırtık seti. Atlas başına ilk bütçe ≤1024²; gölge, halat ve mikro animasyon parametrik, ek PNG değil. 5/7 kontrol atlası elle maskelenir; yeni gövde renderı sayılmaz. Counts kabul edilen iş: reddedilen deneme, ham ara adım, proxy ve katmanlı çalışma dosyaları hariç. Faction profilleri bağımsız sheet değil.

## MASTER SHIP ROSTER

| ID · Gemi | Birincil rol | Ayırt edici kimlik | Relative scale | E/W 1× px / dünya birimi | Paket |
|---|---|---|---:|---:|---|
| SC-01 · Sis İğnesi | Keşif filikası | iki sivri uç, tek eğik bez, çıplak oturak, açık palalı dümen | 1.00 | 60 | Minimum + tam |
| SC-02 · Kül Dikişi | Başlangıç sloop’u | tek yamuk yelken, ince flok, kama burun, kısa yuvarlak kıç | 1.20 | 72 | Minimum + tam |
| SC-03 · Tuz Ambarı | Ticaret fluytu | armut kıç, alçak üç direk, iri merkez kapak, portsuz borda | 1.90 | 114 | Minimum + tam |
| SC-04 · Yarık Çene | Korsan brig’i | iki kare arma bloğu, kama baş, tırnaklı kıç, açık basamak | 1.75 | 105 | Minimum + tam |
| SC-05 · Kör Mühür | Devriye kuteri | tek yüksek direk, çift flok, üç açıklık, küt baş | 1.55 | 93 | Tam |
| SC-06 · Perçin Hattı | Eskort korveti | çift paralel borda rayı, düz ayna, düzenli port ritmi, yüksek gaff | 1.95 | 117 | Minimum + tam |
| SC-07 · Akıntı Bıçağı | Hızlı interceptor | 5,2:1 iğ hattı, iki eğik direk, uzun gaga, alçak kıç | 1.85 | 111 | Tam |
| SC-08 · Demir Mezar | Ağır hat gemisi | çift port hattı, kutu kıç, demir burun, geniş kare arma bloğu | 2.90 | 174 | Minimum + tam |
| SC-09 · Kör Havan | Uzak menzil topçu gemisi | iki iri havan ağzı, boş ön güverte, tok yay baş, kıça toplanmış arma | 2.10 | 126 | Tam |
| SC-10 · Kanca Ağzı | Boarding kadırgası | çift yanal tabla, mahmuz, iki kısa latin ve kıç platformu | 2.05 | 123 | Tam |
| SC-11 · Dikiş Feneri | Onarım tender’ı | A vinci, portsuz borda, açık kıç, enine tahta demeti | 1.70 | 102 | Minimum + tam |
| SC-12 · Kervan Kandili | Silahlı konvoy lideri | sinyal sehpası, iki kapak, yüksek arka köprü, dört küçük port | 2.45 | 147 | Tam |
| SC-13 · Kara Mihver | Admiral komuta fırkateyni | ikiz fener, çift teras, ince arma piramidi, tek uzun port hattı | 3.25 | 195 | Tam |
| SC-14 · Dip Çanı | Lanetli raid sancak gemisi | dört direk, ters çan boşluğu, çatallı gözsüz çene, merdiven kıç | 4.10 | 246 | Minimum + tam |
| SC-15 · Solgun Omurga | Hayalet ve legendary enkaz | kırık orta direk, iki kopuk bez, yarım kıç, üç dışa açık kaburga | 2.65 | 159 | Tam |

## SPRITE PRODUCTION MATRIX

8 px iç padding ve 4×2 aynı yön sırası. H ve S de 8 yön ve ana hücre ölçüsünde. Toplamlar concept dâhil kabul görselidir; maskeler ve ortak efekt atlasları ayrı muhasebedir. Ana yön adedi final oyun karelerini sayar; CD ile özgün render adedi beşe iner.

| Gemi | Ana yön | Source / kare | Başlangıç hücre bütçesi | Başlangıç 4×2 sheet px | Tam ekler | Tam gövde renderı | Tam concept dahil | Minimum concept dahil |
|---|---:|---|---|---|---|---:|---:|---:|
| SC-02 · Kül Dikişi | 8 | 1024×1024 | 160×160 | 640×320 | 1 ref + 1 maske atlası | 8 | 9 | 9 |
| SC-03 · Tuz Ambarı | 8 | 1024×1024 | 224×224 | 896×448 | 1 ref + 1 maske atlası | 8 | 9 | 9 |
| SC-08 · Demir Mezar | 8 | 1024×1024 | 320×320 | 1280×640 | 1 ref + 8 H + 8 S + 1 maske atlası | 24 | 25 | 9 |
| SC-01 · Sis İğnesi | 8 | 1024×1024 | 160×160 | 640×320 | 1 ref | 8 | 9 | 9 |
| SC-04 · Yarık Çene | 8 | 1024×1024 | 224×224 | 896×448 | 1 ref + 1 maske atlası | 8 | 9 | 9 |
| SC-06 · Perçin Hattı | 8 | 1024×1024 | 224×224 | 896×448 | 1 ref | 8 | 9 | 9 |
| SC-11 · Dikiş Feneri | 8 (5+3) | 1024×1024 | 224 px gövde → 288×288 hücre | 1152×576 | 1 ref + 1 maske atlası | 8 | 9 | 9 |
| SC-14 · Dip Çanı | 8 | 1024×1024 | 384×384 | 1536×768 | 1 ref + 8 H + 8 S | 24 | 25 | 17 |
| SC-05 · Kör Mühür | 8 | 1024×1024 | 224×224 | 896×448 | 1 ref + 1 maske atlası | 8 | 9 | 0 |
| SC-07 · Akıntı Bıçağı | 8 | 1024×1024 | 224×224 | 896×448 | 1 ref | 8 | 9 | 0 |
| SC-09 · Kör Havan | 8 | 1024×1024 | 224×224 | 896×448 | 1 ref | 8 | 9 | 0 |
| SC-10 · Kanca Ağzı | 8 | 1024×1024 | 224×224 | 896×448 | 1 ref | 8 | 9 | 0 |
| SC-12 · Kervan Kandili | 8 | 1024×1024 | 320×320 | 1280×640 | 1 ref | 8 | 9 | 0 |
| SC-13 · Kara Mihver | 8 | 1024×1024 | 320×320 | 1280×640 | 1 ref + 1 maske atlası | 8 | 9 | 0 |
| SC-15 · Solgun Omurga | 8 | 1024×1024 | 320×320 | 1280×640 | 1 ref + 8 S | 16 | 17 | 0 |
| **Toplam** | **120** | | | | **15 ref + 16 H + 24 S + 7 maske** | **160** | **175** | **80** |

## GPT IMAGE PRODUCTION ORDER

**2026-11-27 güncel üretim önceliği:** SC-14 Dip Çanı raid boss üretimi askıda; raid oynanışı yokken erken surface gemilerine öncelik ver. Mevcut SC-01/02/03/04/06/08/11 kaynak paketleri korunur. Sonraki eksik normal gemiler SC-05 (devriye), SC-07 (takip), ardından ihtiyaca göre SC-12 (konvoy), SC-09 (havan) ve SC-10 (boarding); özel mekanik gerektiren gemiler ilgili oynanış ihtiyacına bağlı. SC-13/14/15 ileri içeriktir. Roster kapsamı ve PLAY yürütme sırası değişmez.

Aşağıdaki tarihsel roster sırası kapsam ve tasarım fişlerini gösterir; güncel öncelik yukarıdadır. Mevcut kabul edilmiş paketler tekrar üretilmez. Yeni simetrik base gövdelerde **CD 5 özgün görünüş → 5 yön hizalama/montaj ve canlı efekt QA → 3 otomatik yatay yansıma → 8 yön QA → final paket + ayrı montaj JSON**; asimetrik istisnada concept/NE hero ve ayrı sekiz yön kullanılabilir. Atlas sırası değişmez: **N, NE, E, SE / S, SW, W, NW**. Minimum/tam kapsamı ve oyun geliştirme kabul kapıları ayrıdır.

| Sıra | Gemi | Önce concept/NE’de kilitlenecek şekil | 8-yön teslim kapısı |
|---:|---|---|---|
| 1 | SC-02 · Kül Dikişi | tek direk/flok, kısa ayna ve açık top yerleri | Minimum base; base sonrası maske |
| 2 | SC-03 · Tuz Ambarı | armut kıç, kapak, üç kısa direk, portsuz borda | Minimum base; base sonrası maske |
| 3 | SC-08 · Demir Mezar | 7+8 port, üç direk, küt baş ve düz ayna | Minimum base → tam H ve S; base sonrası maske |
| 4 | SC-01 · Sis İğnesi | çift uç, lug, oturak ve dümen | Minimum base |
| 5 | SC-04 · Yarık Çene | 2 direk, 5 port, kama baş ve tırnaklı ayna | Minimum base; base sonrası maske |
| 6 | SC-06 · Perçin Hattı | çift ray, 6 port, düz ayna ve 2 direk | Minimum base |
| 7 | SC-11 · Dikiş Feneri | A vinci, portsuz borda, düz kıç ve 2 direk | Minimum base; base sonrası maske |
| 8 | SC-14 · Dip Çanı | dört direk, 6+7 port, çene, çan ve kıç kemeri | Minimum base → minimum S; tam H |
| 9 | SC-05 · Kör Mühür | tek direk, çift flok, 3 port ve küt pruva | Tam base; base sonrası maske |
| 10 | SC-07 · Akıntı Bıçağı | gaga, eğik direkler, üçgen yelken ve takip topu yuvası | Tam base |
| 11 | SC-09 · Kör Havan | iki havan, boş baş, kıç arma ve geniş karın | Tam base |
| 12 | SC-10 · Kanca Ağzı | iki tabla, mahmuz, 2 latin ve 3 kanca yuvası/borda | Tam base |
| 13 | SC-12 · Kervan Kandili | sehpa, iki kapak, 4 port ve arka köprü | Tam base |
| 14 | SC-13 · Kara Mihver | ikiz fener, çift teras, 10 port, uzun üç direk | Tam base; base sonrası maske |
| 15 | SC-15 · Solgun Omurga | kıç asimetrisi, iki sağlam ve bir kırık direk, 3 kaburga | Tam base → tam S |


## 2026-11-26 — CD kaynak yerleşimi ve SC-11 pilotu

- Kare 1:1, 55° gerçek ortografik kamera, sıfır roll, 45° dünya heading farkları; beş görünüşün pruvaları ortak odak bölgesine bakar. Radial konumlar üst-orta, üst-sol, sağ-orta, alt-sol, alt-orta; ortak ölçek, değişken radyal uzaklık ve güvenli alfa aralığı. Yerleşim etiketi yön değildir: üst-orta=S, üst-sol=SE, sağ-orta=W, alt-sol=NE, alt-orta=N (gerçek pruva yönü). Yatay yansıma ile E, NW, SW tamamlanır. Her yeni kaynakta bu eşleme görsel olarak yeniden doğrulanır.
- Tarihsel pilot: normal ve renk kodlu CD kılavuzları mevcut GLB'den kodla üretilir; yeni varsayılan için aşağıdaki 2026-11-27 kararına bak. Ayrı SeaCraft malzeme/texture atlası ve modüler arma kütüphanesi aynen kullanılır; CD değişikliği kaynak pano yerleşimidir, runtime 4×2 formatını değiştirmez. Ayrıntılı operasyon: [Gemi üretim rehberi](GEMI_SPRITE_URETIM_REHBERI.md).
- SC-11 kullanıcı manuel hizalama ve Puppet Warp pilotu: [final kaynak ZIP](SC11_FINAL_MANUAL_ALIGNED_GITHUB_UPLOAD.zip), 288² hücre, 1152×576 atlas, E/W 223/225 px yaklaşık gövde ölçüsü, 16 px minimum alfa-0 pay, 102 dünya birimi. 5 özgün + E/NW/SW türetilmiş; NW yerel nokta düzeltmesi. 12 dosya, ShowLook v3. Kaynak paket GitHub'da doğrulandı; Godot/Android entegrasyonu ve çapraz landmark projeksiyon ölçümleri henüz doğrulanmadı.

## 2026-11-27 — Gemiye özel parametrik referans ve NPC sanat kimliği

- Tek parametrik Ship Builder ile gövde, arma, port ve donanım aynı fiziksel modelde birleştirilir; 15 gemi bağımsız mesh değil düzenlenebilir reçetedir. 3D yalnız referans; runtime 2D kalır. İki görsel varsayılan: renksiz gemiye özel CD + orijinal malzeme atlası. Renkli CD yalnız gerektiğinde; ortak yanlış gövde/ayrı arma görselleri zorunlu değil. İlk SC-02 tek üretim kullanıcı tarafından görsel olarak beğenildi; final sprite QA ayrıdır. NPC sınıfları için kısa işlevsel geçmiş, 2–3 okunaklı imza, doğal ve ölçülü ayrıntı; yaygın sınıfı boss gibi benzersizleştirme. Kanonik gemi fişleri ve eski onaylı oyun paketleri korunur. Ayrıntı ve hazır iki referanslı SC-02 promptu: [üretim rehberi §22](GEMI_SPRITE_URETIM_REHBERI.md#22-gemiye-özel-parametrik-ship-builder--2026-11-27-güncel-varsayılan).

## 2026-11-27 — Dinamik arma ve montaj kabulü (güncel)

- [Kanonik üretim rehberi §24](GEMI_SPRITE_URETIM_REHBERI.md) ve [HTML v6](tools/sprite_manual_aligner_template.html): beş özgün yönde hizalama ve montaj; diğer üçü otomatik yansır. Asimetrik gemilerde sekiz bağımsız yön. Her yeni gemide top ağız/yön, ön/arka efekt katmanı, uygun bayrak/flama noktaları, görünür yelken UV yüzeyleri, gerekiyorsa örtüşme maskeleri, baş/kıç su hattı canlı önizlemede kontrol edilir. Yangın/hasar/tamir için elle ayrı nokta zorunlu değildir. Dört dosyalı atlas-only ana sprite ZIP'i kullanılır; montaj JSON ayrı üretim girdisidir.
- GPT Image ana sprite'ına faction arması, sancak/flama kumaşı veya efekt basılmaz; mast ve bağlantı yüzeyleri hazır, kumaş nötr. Kalıcı sınıf imzası (ör. SC-02 kül grisi onarım yaması ve mavi şerit) kalır. Flama ince, sancak daha geniş ve genelde kıçta, yelken arması bağımsız UV katman. Düz şeffaf PNG, tüm uygun şablonlarda tekrar kullanılabilir. Öncelik mobil performans ve modülerlik; runtime paylaşılan cache/atlas veya GPU shader, her kare yeniden hesaplama yok.
- SC-02 kullanıcı montajı tamamlandı: [62 montajlı son JSON](SC02_montaj_guncel.json), GUN-61 SE/SW arka katman. Onaylı koordinatlar yeniden elle düzenlenmez. Eski runtime ZIP'i değiştirilmedi; yeni runtime entegrasyonu ve cihaz kabulü ayrı.

- Güncel paket standardı: `seacraft-atlas-only-v1` — 4×2 RGBA atlas, final dönüş GIF'i, manifest ve orijinal kaynak PNG. Ayrı sekiz yön PNG'si ZIP'te mükerrer saklanmaz; gerektiğinde atlas hücreleri kayıpsız ayrılır. Montaj JSON'u ayrı sidecar; eski paketler geçerli. Ayrıntı: üretim rehberi §18/§24G.
