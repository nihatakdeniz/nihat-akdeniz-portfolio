%% =========================================================
%%  KKU_Baslangic.m
%%  Kırıkkale Üniversitesi – Başlangıç Testi ve Konum Haritası
%%
%%  BU SCRIPTİ İLK ÇALIŞTIRIN:
%%   1. Toolbox kontrolü
%%   2. map.osm kontrolü ve harita yükleme
%%   3. Tüm TX/RX konumlarını haritada göster
%%   4. Freespace referans hesabı
%%   5. Çalıştırma sırası rehberi
%% =========================================================

clear; clc; close all;

fprintf('╔══════════════════════════════════════════════════════════╗\n');
fprintf('║   KKÜ Ray Tracing – Başlangıç Testi                     ║\n');
fprintf('╚══════════════════════════════════════════════════════════╝\n\n');

%% ── 1. TOOLBOX KONTROLÜ ─────────────────────────────────────────────────
fprintf('── Toolbox Kontrolü ──\n');
allOK = true;
try
    pm = propagationModel('freespace');
    fprintf('  [✓] Communications Toolbox – mevcut\n');
catch
    fprintf('  [✗] Communications Toolbox – EKSİK! Lütfen yükleyin.\n');
    allOK = false;
end
try
    ts = txsite('Latitude',39,'Longitude',33,'TransmitterFrequency',1e9);
    fprintf('  [✓] Antenna Toolbox – mevcut\n');
catch
    fprintf('  [✗] Antenna Toolbox – EKSİK! Lütfen yükleyin.\n');
    allOK = false;
end

%% ── 2. OSM DOSYASI KONTROLÜ ─────────────────────────────────────────────
fprintf('\n── OSM Dosyası Kontrolü ──\n');
if exist('map.osm','file')
    d = dir('map.osm');
    fprintf('  [✓] map.osm bulundu (%.1f KB)\n', d.bytes/1024);
    fprintf('      Kapsama: 39.8703–39.8877 K, 33.4379–33.4577 D\n');
    fprintf('      İçerik : KKÜ Şehitler Kampüsü + çevre\n');
    osmOK = true;
else
    fprintf('  [✗] map.osm bu klasörde bulunamadı!\n');
    fprintf('      Dosyayı .m scriptleriyle aynı klasöre koyun.\n');
    osmOK = false;
    allOK = false;
end

if ~allOK
    fprintf('\n[!] Eksiklikler giderilmeden simülasyon çalışmaz.\n');
    return;
end

%% ── 3. HARİTA VE KONUMLAR ───────────────────────────────────────────────
fprintf('\n── Harita Yükleniyor ──\n');
viewer = siteviewer(Buildings='map.osm', Basemap='openstreetmap');
fprintf('  [✓] Site Viewer açıldı.\n');

% ── VERİCİ (TX) ──────────────────────────────────────────────────────────
tx = txsite( ...
    Name='TX1-Rektorluk (Ana TX)', ...
    Latitude=39.879439, Longitude=33.445946, ...
    AntennaHeight=18, TransmitterFrequency=2.6e9, TransmitterPower=2.0);

% ── ALICILAR (RX) ─────────────────────────────────────────────────────────
rxDef = {
%   Kısa İsim             Lat          Lon          Açıklama
    'RX1-Kutuphane',      39.880190,   33.447136,   'Kütüphane (yakın, LOS olabilir)';
    'RX2-VeterinerFak',   39.884138,   33.441904,   'Veteriner Fak. (~660m, NLOS)';
    'RX3-KapaliSpor',     39.884008,   33.446022,   'Kapalı Spor Salonu (~520m)';
    'RX4-KYK_Yurt',       39.873928,   33.455910,   'KYK Yurt (~1000m, NLOS)';
    'RX5-MYO_Yemekhane',  39.873590,   33.451916,   'MYO Yemekhane (~680m)';
    'RX6-DisHekimlik',    39.871157,   33.454775,   'Diş Hekimliği (~960m, en uzak)';
};

rx = rxsite.empty;
for k = 1:size(rxDef,1)
    rx(k) = rxsite(Name=rxDef{k,1}, Latitude=rxDef{k,2}, ...
                   Longitude=rxDef{k,3}, AntennaHeight=1.5);
end

% Haritada göster
show(tx, 'ShowAntennaHeight', true);
for k = 1:numel(rx); show(rx(k)); end

title('KKÜ Kampüsü – TX/RX Anten Konumları (OSM Verisi)');
fprintf('  [✓] TX ve %d RX noktası haritada gösterildi.\n', numel(rx));

%% ── 4. KONUM TABLOSU ────────────────────────────────────────────────────
fprintf('\n── Anten Konumları (OSM Verisi) ──\n');
fprintf('  %-30s  %10s  %11s  %6s  %s\n', 'Anten', 'Enlem', 'Boylam', 'H(m)', 'Açıklama');
fprintf('  %s\n', repmat('-',1,80));
fprintf('  %-30s  %10.6f  %11.6f  %6d  %s\n', tx.Name, ...
    tx.Latitude, tx.Longitude, tx.AntennaHeight, ...
    'VERİCİ – Rektörlük çatısı, kampüs merkezi');
for k = 1:numel(rx)
    fprintf('  %-30s  %10.6f  %11.6f  %6.1f  %s\n', rx(k).Name, ...
        rx(k).Latitude, rx(k).Longitude, rx(k).AntennaHeight, rxDef{k,4});
end

%% ── 5. MESAFE TABLOSU ───────────────────────────────────────────────────
fprintf('\n── TX-RX Mesafeleri ──\n');
for k = 1:numel(rx)
    d = distance(tx.Latitude,tx.Longitude,rx(k).Latitude,rx(k).Longitude)*111320;
    fprintf('  TX → %-30s : %7.1f m\n', rx(k).Name, d);
end

%% ── 6. FREESPACE REFERANS HESABI ────────────────────────────────────────
fprintf('\n── Freespace Referans (Teorik Üst Sınır) ──\n');
pm_fs = propagationModel('freespace');
fprintf('  %-30s  %10s  %12s\n', 'Alıcı', 'Mes(m)', 'SS_FS(dBm)');
fprintf('  %s\n', repmat('-',1,56));
for k = 1:numel(rx)
    d   = distance(tx.Latitude,tx.Longitude,rx(k).Latitude,rx(k).Longitude)*111320;
    ss  = sigstrength(rx(k), tx, pm_fs);
    fprintf('  %-30s  %10.1f  %12.2f\n', rx(k).Name, d, ss);
end

%% ── 7. ÇALIŞTIRMA SIRASI ────────────────────────────────────────────────
fprintf('\n╔══════════════════════════════════════════════════════════╗\n');
fprintf('║  ✓ SİSTEM HAZIR – Simülasyonları sırayla çalıştırın:    ║\n');
fprintf('╠══════════════════════════════════════════════════════════╣\n');
fprintf('║  1. KKU_RayTracing_Ana.m          Ana ray tracing        ║\n');
fprintf('║  2. KKU_KanalModeli.m             Kanal profili + PDP    ║\n');
fprintf('║  3. KKU_FrekansiKarsilastir.m     700M/2.6G/28G          ║\n');
fprintf('║  4. KKU_LinkButcesi.m             Malzeme + hava         ║\n');
fprintf('║  5. KKU_CokVerici.m               3 TX optimal kapsama   ║\n');
fprintf('╚══════════════════════════════════════════════════════════╝\n\n');
