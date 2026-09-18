%% =========================================================
%%  KKÜ_RayTracing_Ana.m
%%  Kırıkkale Üniversitesi Kampüsü – Ana Ray Tracing Simülasyonu
%%
%%  Koordinatlar gerçek OSM verisinden (map.osm) alınmıştır:
%%    Bounds: 39.8703–39.8877 N, 33.4379–33.4577 E
%%
%%  VERİCİ (TX):  Rektörlük binası çatısı
%%    → Kampüs merkezinde, yüksek konum, tüm yönlere açık
%%    → lat=39.879439, lon=33.445946, h=18m
%%
%%  ALICILAR (RX): 6 gerçek kampüs noktası (OSM bina merkezleri)
%%    RX1 – Kütüphane      (TX'e yakın, açık alan)
%%    RX2 – Veteriner Fak. (kuzey-batı, uzak, NLOS)
%%    RX3 – Kapalı Spor S. (kuzey, orta mesafe)
%%    RX4 – KYK Yurdu      (güney-doğu, engelli)
%%    RX5 – MYO Yemekhane  (güney, uzak)
%%    RX6 – Diş Hekimliği  (güney-doğu, en uzak)
%%
%%  GEREKSİNİM: map.osm bu scriptle aynı klasörde olmalı.
%%  TOOLBOX: Communications Toolbox + Antenna Toolbox
%% =========================================================

clear; clc; close all;

fprintf('╔══════════════════════════════════════════════════════════╗\n');
fprintf('║   KKÜ Kampüsü – Ray Tracing Simülasyonu                 ║\n');
fprintf('║   Gerçek OSM Verisi  |  2.6 GHz  |  SBR Yöntemi        ║\n');
fprintf('╚══════════════════════════════════════════════════════════╝\n\n');

%% ── 1. HARİTA ───────────────────────────────────────────────────────────
osmFile = 'map.osm';
if ~exist(osmFile, 'file')
    error('map.osm bulunamadı! Lütfen bu scriptle aynı klasöre koyun.');
end

viewer = siteviewer(Buildings=osmFile, Basemap='openstreetmap');
fprintf('[1] Harita yüklendi: %s\n', osmFile);
fprintf('    Kapsama: 39.8703–39.8877 K, 33.4379–33.4577 D\n\n');

%% ── 2. VERİCİ ANTEN (TX) ───────────────────────────────────────────────
%
%  SEÇIM GEREKÇESİ: Rektörlük binası
%  • Kampüsün coğrafi merkezine en yakın büyük bina (merkez: ~39.8779, 33.4483)
%  • Çevresi açık, doğu-batı-kuzey-güney tüm yönlere görüş hattı
%  • Binalar arası en iyi yükseltiden dağılım sağlar
%  • Gerçek koordinat (OSM): lat=39.879439, lon=33.445946
%  • Anten yüksekliği: 18m (bina ~4 kat + çatı montajı)
%  • Frekans: 2.6 GHz (LTE Band 7 / 5G NR n41 – Türkiye'de yaygın)
%  • Güç: 2W (33 dBm) – kampüs küçük hücre senaryosu
%
tx = txsite( ...
    Name                   = 'TX – Rektörlük Çatısı', ...
    Latitude               = 39.879439, ...
    Longitude              = 33.445946, ...
    AntennaHeight          = 18, ...
    TransmitterFrequency   = 2.6e9, ...
    TransmitterPower       = 2.0);

fprintf('[2] Verici Anten (TX):\n');
fprintf('    Bina    : Rektörlük\n');
fprintf('    Konum   : %.6f K, %.6f D\n', tx.Latitude, tx.Longitude);
fprintf('    Yükseklik: %.0f m\n', tx.AntennaHeight);
fprintf('    Frekans : %.1f GHz\n', tx.TransmitterFrequency/1e9);
fprintf('    Güç     : %.0f W (%.0f dBm)\n\n', ...
    tx.TransmitterPower, 10*log10(tx.TransmitterPower*1000));

%% ── 3. ALICI ANTENLER (RX) ─────────────────────────────────────────────
%
%  Koordinatlar doğrudan map.osm bina merkezlerinden alınmıştır.
%  Her alıcı farklı bir kanal koşulunu temsil eder:
%   LOS  = Line of Sight (doğrudan görüş hattı)
%   NLOS = Non Line of Sight (engelli)
%
rxData = {
%   İsim                        Lat         Lon        Yükseklik  Açıklama
    'RX1-Kutuphane',            39.880190,  33.447136, 1.5,       'LOS - Kütüphane (yakın, açık alan)';
    'RX2-VeterinerFak',         39.884138,  33.441904, 1.5,       'NLOS - Veteriner Fakültesi (kuzey, ~660m)';
    'RX3-KapaliSporSalonu',     39.884008,  33.446022, 1.5,       'NLOS - Kapalı Spor Salonu (kuzey, ~520m)';
    'RX4-KYK_Yurt',             39.873928,  33.455910, 1.5,       'NLOS - KYK Yurdu (güney-doğu, ~1000m)';
    'RX5-MYO_Yemekhane',        39.873590,  33.451916, 1.5,       'NLOS - MYO Yemekhane (güney, ~680m)';
    'RX6-DisHekimligiFak',      39.871157,  33.454775, 1.5,       'NLOS - Diş Hekimliği (en uzak, ~960m)';
};

rx = rxsite.empty;
for k = 1:size(rxData, 1)
    rx(k) = rxsite( ...
        Name          = rxData{k,1}, ...
        Latitude      = rxData{k,2}, ...
        Longitude     = rxData{k,3}, ...
        AntennaHeight = rxData{k,4});
end

fprintf('[3] Alıcı Antenler (%d nokta):\n', numel(rx));
fprintf('    %-28s  %10s  %11s  %s\n', 'Ad', 'Enlem', 'Boylam', 'Açıklama');
fprintf('    %s\n', repmat('-', 1, 80));
for k = 1:numel(rx)
    fprintf('    %-28s  %10.6f  %11.6f  %s\n', ...
        rx(k).Name, rx(k).Latitude, rx(k).Longitude, rxData{k,5});
end
fprintf('\n');

%% ── 4. YAYILIM MODELLERİ ───────────────────────────────────────────────
%
%  Model (a): PEC – Mükemmel İletken yüzey (teorik üst sınır)
%  Model (b): Beton – Gerçekçi kampüs bina malzemesi (ITU-R P.2040)
%
rtpm_pec = propagationModel('raytracing', ...
    Method             = 'sbr', ...
    MaxNumReflections  = 2, ...
    MaxNumDiffractions = 1, ...
    BuildingsMaterial  = 'PEC', ...
    TerrainMaterial    = 'PEC');

rtpm_beton = propagationModel('raytracing', ...
    Method             = 'sbr', ...
    MaxNumReflections  = 2, ...
    MaxNumDiffractions = 1, ...
    BuildingsMaterial  = 'concrete', ...
    TerrainMaterial    = 'concrete');

fprintf('[4] Yayılım modelleri tanımlandı (SBR, 2 yansıma, 1 kırınım).\n\n');

%% ── 5. LOS ANALİZİ (Görüş Hattı) ──────────────────────────────────────
fprintf('[5] LOS analizi çiziliyor...\n');
clearMap(viewer);
show(tx, 'ShowAntennaHeight', true);
for k = 1:numel(rx); show(rx(k)); end
for k = 1:numel(rx)
    los(tx, rx(k));
end
title('KKÜ Kampüsü – LOS Analizi (Rektörlük TX)');
pause(0.5);

%% ── 6. RAY TRACING GÖRSELLEŞTİRMESİ ───────────────────────────────────
fprintf('[6] Ray tracing görselleştirmesi (beton model)...\n');
clearMap(viewer);
show(tx, 'ShowAntennaHeight', true);
for k = 1:numel(rx); show(rx(k)); end
raytrace(tx, rx, rtpm_beton);
title('KKÜ Kampüsü – Ray Tracing (Beton Malzeme, 2.6 GHz)');
pause(0.5);

%% ── 7. SİNYAL GÜCÜ KARŞILAŞTIRMASI ────────────────────────────────────
fprintf('[7] Sinyal gücü hesaplanıyor...\n\n');

ss_pec   = zeros(1, numel(rx));
ss_beton = zeros(1, numel(rx));
dist_m   = zeros(1, numel(rx));

for k = 1:numel(rx)
    ss_pec(k)   = sigstrength(rx(k), tx, rtpm_pec);
    ss_beton(k) = sigstrength(rx(k), tx, rtpm_beton);
    dist_m(k)   = distance(tx.Latitude, tx.Longitude, ...
                           rx(k).Latitude, rx(k).Longitude) * 111320;
end

fprintf('    %-28s  %6s  %10s  %10s  %8s\n', ...
    'Alıcı', 'Mes(m)', 'PEC(dBm)', 'Beton(dBm)', 'Fark(dB)');
fprintf('    %s\n', repmat('-',1,70));
for k = 1:numel(rx)
    fprintf('    %-28s  %6.0f  %10.2f  %10.2f  %8.2f\n', ...
        rx(k).Name, dist_m(k), ss_pec(k), ss_beton(k), ss_pec(k)-ss_beton(k));
end
fprintf('\n');

%% ── 8. KAPSAMA HARİTASI ─────────────────────────────────────────────────
fprintf('[8] Kapsama haritası oluşturuluyor (tüm kampüs)...\n');
clearMap(viewer);
show(tx, 'ShowAntennaHeight', true);

coverage(tx, rtpm_beton, ...
    SignalStrengths = -120:5, ...
    MaxRange        = 1200, ...
    Resolution      = 5, ...
    Transparency    = 0.5);

title({'KKÜ Kampüsü Kapsama Haritası', ...
       'TX: Rektörlük (18m) | 2.6 GHz | Beton Malzeme'});

%% ── 9. KARŞILAŞTIRMA GRAFİĞİ ───────────────────────────────────────────
figure('Name', 'Sinyal Gücü Karşılaştırması', 'Position', [50 50 900 500]);

rxLabels = strrep({rx.Name}, 'RX', 'RX');
x = 1:numel(rx);

bar(x-0.2, ss_pec,   0.35, 'FaceColor', [0.2 0.5 0.8], 'DisplayName', 'PEC (İdeal)');
hold on;
bar(x+0.2, ss_beton, 0.35, 'FaceColor', [0.8 0.3 0.2], 'DisplayName', 'Beton (Gerçekçi)');
hold off;

legend('Location', 'northeast');
xticks(x);
xticklabels({rx.Name});
xtickangle(25);
ylabel('Alınan Sinyal Gücü (dBm)');
xlabel('Alıcı Noktası');
title({'KKÜ Kampüsü – PEC vs Beton Malzeme Karşılaştırması', ...
       'TX: Rektörlük | 2.6 GHz | SBR (2 yans., 1 kırın.)'});
grid on; box on;
yline(-100, '--r', 'Alım Eşiği (-100 dBm)', 'LabelHorizontalAlignment', 'left');

% Değerleri ekle
for k = 1:numel(rx)
    text(k-0.2, ss_pec(k)+0.8,   sprintf('%.1f', ss_pec(k)), ...
         'HorizontalAlignment','center','FontSize',7.5);
    text(k+0.2, ss_beton(k)+0.8, sprintf('%.1f', ss_beton(k)), ...
         'HorizontalAlignment','center','FontSize',7.5);
end

fprintf('[✓] Ana simülasyon tamamlandı.\n\n');
fprintf('Sıradaki adımlar:\n');
fprintf('  >> KKU_KanalModeli.m          – Kanal profili ve gecikme analizi\n');
fprintf('  >> KKU_FrekansiKarsilastir.m  – 700MHz / 2.6GHz / 28GHz\n');
fprintf('  >> KKU_LinkButcesi.m          – Malzeme ve hava koşulları\n');
fprintf('  >> KKU_CokVerici.m            – 3 TX ile tam kapsama\n\n');
