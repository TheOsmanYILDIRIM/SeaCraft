# SeaCraft — Canavar Sprite Üretim Rehberi

Kanonik tasarım fişleri: [CANAVAR_GORSEL_TASARIM_VE_SPRITE_PLANI.md](CANAVAR_GORSEL_TASARIM_VE_SPRITE_PLANI.md). Ortak sanat ve güncel gemi üretim yöntemi: [GEMI_GORSEL_TASARIM_VE_SPRITE_PLANI.md](GEMI_GORSEL_TASARIM_VE_SPRITE_PLANI.md), [GEMI_SPRITE_URETIM_REHBERI.md](GEMI_SPRITE_URETIM_REHBERI.md). Bu dosya planlanan canavar uyarlamasıdır; mevcut gemi kodunun organik türlerde çalıştığı doğrulanmamıştır.

## 1. Önce kimlik, sonra ölçülü 3D proxy

1. Mxx fişinden L/B, dünya L, su üstü/sualtı, uzuv sayısı ve tarafları, renk, B/A/P seçilir. Tek türün top plan, iki profil, ön/arka konsepti; parça numaraları, su düzlemi, ağırlık merkezi ve eklem/soket işaretleri. İlk üretim sıfırdan Create dili; eklenmemiş resme referans verme.
2. Tür ailesine uygun kaba Three.js/3D proxy: balık/yılan, kabuklu, vatoz, kafadanbacaklı, uzun boyunlu; aynı fiziksel parçalar ve rig kökü. Basit tek biçimli proxy başka anatomiyi zorlamaz. 55° ortografik, 0° roll, 45° ekran yönleri; ölçek ve üst-sol ışık sabit. B nötr eklem pozu tüm yönlerde aynı. A/P için aynı proxy üzerinde poz farkı.
3. İki kare radial rehber: renksiz/dokulu yalnız kamera, yerleşim ve ölçek; renkli tanısal yalnız ön/arka, sol/sağ, eklem ve su düzlemi sürekliliği. Renkler gerçek tasarıma taşınmaz. Üçüncü kaynak organik SeaCraft malzeme/ışık referansı; gemi tahtası/yelkeni değil. Dördüncü varsa türün onaylı kimlik konsepti/NE hero; ek referans yalnız eksik anatomik detay. Proxy ve organik renk örneği henüz üretilmedi.
4. Sekiz nesne birbirinden kopuk, tam kare tuvali olabildiğince doldurur; başlar merkeze bakar. M02 gibi asimetrik, M08 gibi radyal türde ön eksen açıkça kilitlenir. M08 kol uçları yön tayin etmez. Yerleşim örneği tür anatomisini belirlemez. 3D proxy'de temas/padding ve yön eşlemesi doğrulanır.

## 2. Kopyalanabilir GPT Image üretim promptu

Aşağıdaki İngilizce şablonda [ ] alanları kanonik tür fişiyle doldurulur. Yalnız gerçekten eklenen referans satırları bırakılır. Kullanıcı üç bağımsız görselden birini seçer; üç ayrı istek/çıktı, üçlü kolaj değildir.

> ABSOLUTE OUTPUT REQUIREMENT: STRICT 1:1 SQUARE IMAGE, width equals height. Create THREE independent alternative images of an EIGHT-DIRECTION RADIAL SPRITE SHEET for SeaCraft, one complete square sheet per image, never a three-panel collage.
>
> Subject: [Mxx, original creature name, ecological role]. Exactly eight views of one physically identical creature in [B neutral / A named attack key pose / P named phase pose]. [Precise anatomy, length-to-width ratio, exact limb/fin/eye/plate count, left/right asymmetry, silhouette anchors]. Lock all anatomy, body length, joint roots and markings across the eight headings. [Surface: show only anatomically correct visible body above the fixed waterline / underwater: full body, no water surface baked in].
>
> References, when attached: 1) uncolored 8-direction 3D guide for camera, framing and spacing ONLY; 2) color-coded 3D guide for directional anatomy, fixed landmarks and left/right continuity ONLY; 3) organic SeaCraft material reference for wet skin, scales, shell, bone, muted pigment and lighting ONLY; 4) approved identity concept/NE hero for the exact creature. Do not copy diagnostic colors, unrelated guide anatomy or ship materials.
>
> Fixed true orthographic camera, 55 degrees above horizontal, zero roll, eight projected 45-degree headings. All anatomical heads/forward axes point toward a large empty center. Consistent physical scale, natural foreshortening, fixed cold broad upper-left world light. No separate per-view fit, zoom, perspective or mirror.
>
> [Detailed muted material palette and three to five silhouette identifiers]. Dark nautical photorealism with restrained cosmic horror; readable volumes, realistic biological joints and wet surface texture, no cartoon, plastic or neon. Eight isolated complete objects, ample transparent clearance, no touching, cropping or overlap. True RGBA where supported. No painted checkerboard, no sea, foam, spray, wake, shadows outside the body, fog, bubbles, glow halo, UI, text or labels. [Species-specific negatives]. No changing anatomy, extra limbs or eyes, missing tail, reversed scars or changing pose.
>
> Deliver THREE separate alternatives, each exactly eight views on ONE STRICT 1:1 SQUARE IMAGE. Width equals height.

For first concept with no attached reference: ask directly for one square identity/concept image with consistent top, side, front and back studies, no reference/edit language. For one-direction correction: use only attached approved identity, target proxy and approved neighbor; request one square image of that exact heading and pose, same camera/scale/light. It replaces only the rejected direction; original source preserved.

## 3. Yön sırası ve görsel kapı

Radial merkez üstündeki nesne içe bakıyorsa S, sağ üst SW, sağ W, sağ alt NW, alt N, sol alt NE, sol E, sol üst SE. Son atlas sırası **N NE E SE / S SW W NW**. Üretim tek yön fallback sırası NE → E → W → N → S → SE → SW → NW. Baş yönünü gerçek anatomiden kontrol et; radial sektör sadece ipucudur.

Kullanıcının seçtiği radialı büyüt: 8/8 nesne, aynı tür, aynı uzuv adedi ve tarafı, aynı poz, aynı kamera, temas yok. Ayrı A/P pozları B kimliğini korur. Uygun değilse yalnız sorunlu yönü üret veya bütün pano yeniden; temas eden nesneyi wedge kesimiyle yamama.

## 4. Ekstraksiyon ve kaynak çözünürlüğü

- Orijinal radial PNG değişmeden arşivlenir. Mevcut `tools/sprite_radial_extract.py radial.png raw/ --facing inward` aracı yalnız 8 ayrı alfa bileşeni ve doğru baş eşlemesi doğrulandığında kullanılabilir; araç gemi için yazılmıştır. İnce ayrık kol, kopuk alfa veya birbirine değen nesnelerde yanlış parçalama riskini kontrol et. Türde yetersizse 8 nesnenin parça gruplarını açıkça tanıyan organik maske/ayırıcı geliştirilir ve test edilir; rastgele sabit kutu kesimi yok.
- 8 ayrılmış gerçek PNG'nin dolu piksel genişliği/yüksekliği, ince diş, yüzgeç ve vantuz kenarları gözle/ölçümle doğrulanır. Final hücre büyüklüğü kaynak detayının kanıtı değil. Yetersizse açıkça **AI upscale gerekli** bildir; kullanıcı harici kaliteli AI ile ayrı sekiz yönü yükseltir. Bu pipeline kendiliğinden AI upscale uygulamaz. Yalnız interpolasyonla yeni detay kazanıldığı söylenmez. En-boy oranı korunur; atlası sonradan upscale etme.

## 5. Ölçek, merkezleme ve organik renk

- 1024² master, gerçek anatomik kök (512,512); final hücre merkezine aynı dönüşüm. L/E-W ölçeği ve L/B genişlik, iki/üç eklem ve su kesişimi kılavuzdan; görüntünün bbox ortası, kuyruk ucu veya kıskaçtan pivot çıkarma. B/A/P ortak gövde ölçüsü. N/S foreshortening, asimetrik sağ/sol, doğal A/P hareketi korunur. Kareye x/y ayrı ölçek yok.
- `tools/sprite_normalize.py` gemiye özgü hull/support-anchor ve pair-lock varsayımlarına sahip. Canavara körlemesine uygulanmaz. Şeffaflık, renk ve paketleme genel bölümleri yeniden kullanılabilir; anatomik landmark normalize/organik anchor profili için önce M01–03'te test gerekir. Mevcut gemi davranışı değiştirilmez. Kullanıcının elle verdiği JSON pivot/ölçek son kararıdır; yeni crop'ta yeniden QA.
- Geminin N Lab/LUT ve `tools/seacraft_showlook.py --stage v3` gemi wood/sail/metal sınıflarını kullanır. Canavarda aynı karanlık dünya kontrastı, fakat deri/pul/kabuk/kemik/yüzgeç/emissive sınıfları ayrı. Organik N veya onaylı tür masterı referans; malzeme renklerini gemi tahtasına dönüştürme. Ortak film eğrisi ancak örnek ve öncesi/sonrası kabulüyle; alfa, anatomi ve doku geometriye dokunmaz. Referans olmayan organik LUT uydurma. Organik profil henüz uygulanmadı.
- Gri ton ve koyu/açık deniz üstünde önce/sonra karşılaştır. M01–03 geçmeden kalan türlerde otomasyon yok.

## 6. Mobil manuel hizalama, alfa ve final QA

Gemi `tools/sprite_manual_aligner_template.html` 8 yön gömülü manuel QA için başlangıçtır; türün gerçek anchor/ölçüsü ve B/A/P etiketi ile kullanılabilirliği önce doğrulanmalı. 8 gerçek PNG yüklenir; preview küçük canvas değil. `sprite_manual_alignment.json` export/import doğrulanır. Kullanıcının manuel hizalaması varsa uygulanır ve sonuç yeniden açılır. Tüm yönler için alfa>0 bbox, alfa≥128 kütle, pivot, L ve landmark raporu. Final 8 px alpha-0 padding; komşu alfa yok. Açık/gri/koyu matte üzerinde fringe yok. RGBA düz alfa.

Final GIF: gemi standardındaki 21 FPS yön geçiş önizlemesi; sekiz gerçek yön, gerekiyorsa yalnız görsel ±10° küçük dönüş yaklaşımı ve 7 FPS detay QA. Canavar deformasyonu ayrı poz gerektirir; GIF'i yüzüş/saldırı animasyonu veya gerçek Godot testi diye sunma. B/A/P arasında kontrol önizlemesi ayrıca QA dosyası olabilir, final ZIP'e girmez.

## 7. Final ZIP standardı (poz başına 12 dosya)

`M01_TUZ_DISI_B_FINAL_GITHUB_UPLOAD.zip` örnek isim; A/P ayrı pakette. İçerik tam 12 dosya: `M01_B_N.png`, `M01_B_NE.png`, `M01_B_E.png`, `M01_B_SE.png`, `M01_B_S.png`, `M01_B_SW.png`, `M01_B_W.png`, `M01_B_NW.png`, `M01_B_atlas.png`, `M01_B_rotation.gif`, `manifest.json`, `M01_B_original.png` (dokunulmamış radial kaynak). Bir yön ayrı yeniden üretilirse kaynak provenance ve SHA manifestte belirtilir, ek orijinal düzeltme kaynakları ayrı arşivde korunur; final ZIP 12 dosya olarak kalır.

Manifest minimum alanları: schema_version, asset_id, pose, direction_order, source_sha256, corrected_direction_sources (varsa), master_px, cell_px, atlas_px, pivot_px, world_length, width_ratio, surface_mode, landmark/sockets (yön/poz bazlı), per_direction bbox/sha256, alpha_padding, color_profile/version, user_selection/revision, QA sonuçları. Sprite/atlas/GIF SHA, orijinal kaynak SHA, atlas hücrelerinin tekil PNG'lerle piksel eşitliği, 8 yön/12 dosya ve ZIP CRC doğrulaması. Kayıpsız orijinal kaynak korunur. Ara crop, model, LUT, HTML, JSON hizalama, contact sheet, debug ZIP finalde yok; gerektiğinde ayrı QA arşivi.

## 8. Godot ve Android kabulü

- Görsel paket teslimi = tasarım kimliği + QA + ZIP readback. Oyun entegrasyonu ayrı: Mxx ile runtime stable monster ID eşlemesi, atlas bölgeleri, hit/loot socketleri, doğru hedef tag, B/A/P state event sunumu; simülasyon ve network DTO değişmez. Cannon/harpoon sınıf doğrulaması, territory ve loot authority korunur. VFX yönü gerçek oyun açısına bağlı, sprite sektörüne değil.
- Gerçek cihazda küçük hedef touch seçimi, %75 zoom siluet, gemiyle yan yana ölçek, çoklu canavar + su/efekt, sprite jitter, atlas bleed, 360° yön geçişi ve saldırı telegraph okunabilirliği; mobil performans ve LAN parity ilgili aşamada. Çalıştırılmamış test not_run. İleri sualtı ve boss içeriklerini PLAY kapılarından önce runtime'a zorla ekleme.
- Başlangıç durumu: bu rehber tasarım sözleşmesi; organik proxy, normalizer/renk profili, canavar PNG/ZIP, Godot entegrasyonu ve Android kabulü henüz yok. İlk iş M01–M03 tasarım/üretim pilotu; sonraki işlerden önce ilgili kullanıcı seçimi ve kalite kapısı.
