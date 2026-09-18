%% =========================================================
%%  KKU_FrekansiKarsilastir.m
%%  Kırıkkale Üniversitesi – 700 MHz / 2.6 GHz / 28 GHz
%%  Kapsama ve Sinyal Gücü Karşılaştırması
%%
%%  ITU-R M.2412 önerilerine göre üç farklı frekans bandı
%%  kampüs ortamında karşılaştırılmaktadır.
%% =========================================================

clear; clc; close all;

fprintf('╔══════════════════════════════════════════════════════════╗\n');
fprintf('║   KKÜ – Frekans Bandı Karşılaştırması                   ║\n');
fprintf('║   700 MHz (4G) | 2.6 GHz (LTE/5G) | 28 GHz (5G mmWave) ║\n');
fprintf('╚══════════════════════════════════════════════════════════╝\n\n');

viewer = siteviewer(Buildings='map.osm', Basemap='openstreetmap');

%% ── Frekans Senaryoları ─────────────────────────────────────────────────
freqBands = struct( ...
    'isim',   {'700MHz_4G',  '2600MHz_LTE5G', '28GHz_5GmmWave'}, ...
    'freq',   {700e6,         2.6e9,            28e9}, ...
    'guc_W',  {4.0,           2.0,              0.5}, ...
    'maxR',   {1500,          1000,             300}, ...
    'renk',   {[0.2 0.7 0.2], [0.1 0.4 0.8],   [0.8 0.2 0.2]});

%% ── Alıcılar (gerçek OSM konumları) ────────────────────────────────────
rxData = {
    'Kutuphane',     39.880190, 33.447136;
    'VeterinerFak',  39.884138, 33.441904;
    'KapaliSpor',    39.884008, 33.446022;
    'KYK_Yurt',      39.873928, 33.455910;
    'MYO_Yemekhane', 39.873590, 33.451916;
    'DisHekimlik',   39.871157, 33.454775;
};

rx = rxsite.empty;
for k = 1:size(rxData,1)
    rx(k) = rxsite(Name=rxData{k,1}, Latitude=rxData{k,2}, ...
                   Longitude=rxData{k,3}, AntennaHeight=1.5);
end

%% ── Verici Koordinatı (sabit) ───────────────────────────────────────────
tx_lat = 39.879439; tx_lon = 33.445946; tx_h = 18;

%% ── Simülasyon Döngüsü ──────────────────────────────────────────────────
ss_all = zeros(numel(freqBands), numel(rx));

fprintf('%-18s', 'Alıcı \\ Frekans');
for f = 1:numel(freqBands)
    fprintf('%16s', freqBands(f).isim);
end
fprintf('\n%s\n', repmat('-', 1, 18+16*3));

for f = 1:numel(freqBands)
    tx = txsite( ...
        Name                 = sprintf('TX-%s', freqBands(f).isim), ...
        Latitude             = tx_lat, ...
        Longitude            = tx_lon, ...
        AntennaHeight        = tx_h, ...
        TransmitterFrequency = freqBands(f).freq, ...
        TransmitterPower     = freqBands(f).guc_W);

    rtpm = propagationModel('raytracing', ...
        Method='sbr', MaxNumReflections=2, MaxNumDiffractions=1, ...
        BuildingsMaterial='concrete', TerrainMaterial='concrete');

    for k = 1:numel(rx)
        ss_all(f,k) = sigstrength(rx(k), tx, rtpm);
    end
end

% Tabloyu yazdır
for k = 1:numel(rx)
    fprintf('%-18s', rx(k).Name);
    for f = 1:numel(freqBands)
        fprintf('%14.1f dBm', ss_all(f,k));
    end
    fprintf('\n');
end

%% ── Her Frekans İçin Kapsama Haritası ──────────────────────────────────
for f = 1:numel(freqBands)
    tx = txsite( ...
        Name                 = sprintf('TX-%s', freqBands(f).isim), ...
        Latitude             = tx_lat, ...
        Longitude            = tx_lon, ...
        AntennaHeight        = tx_h, ...
        TransmitterFrequency = freqBands(f).freq, ...
        TransmitterPower     = freqBands(f).guc_W);

    rtpm = propagationModel('raytracing', ...
        Method='sbr', MaxNumReflections=2, MaxNumDiffractions=1, ...
        BuildingsMaterial='concrete', TerrainMaterial='concrete');

    clearMap(viewer);
    show(tx, 'ShowAntennaHeight', true);
    for k = 1:numel(rx); show(rx(k)); end

    coverage(tx, rtpm, ...
        SignalStrengths = -120:5, ...
        MaxRange        = freqBands(f).maxR, ...
        Resolution      = 5, ...
        Transparency    = 0.5);

    title(sprintf('KKÜ Kapsama – %s (P=%.1fW, MaxR=%dm)', ...
        freqBands(f).isim, freqBands(f).guc_W, freqBands(f).maxR));
    fprintf('[✓] %s kapsama haritası tamamlandı.\n', freqBands(f).isim);
    pause(1);
end

%% ── Karşılaştırma Grafikleri ────────────────────────────────────────────
figure('Name', 'Frekans Karşılaştırması', 'Position', [50 50 1000 520]);

subplot(1,2,1);
bar(ss_all', 'grouped');
legend({freqBands.isim}, 'Location', 'best', 'Interpreter', 'none');
xticks(1:numel(rx)); xticklabels({rx.Name}); xtickangle(22);
ylabel('Sinyal Gücü (dBm)'); xlabel('Alıcı');
title({'KKÜ – Frekans Karşılaştırması (Tüm RX)', 'Beton | 2 Yansıma | 1 Kırınım'});
grid on; box on;
yline(-100, '--r', '-100 dBm Eşik', 'LabelHorizontalAlignment', 'left');

subplot(1,2,2);
freqMHz = [700, 2600, 28000];
% Ortalama sinyal gücü
meanSS = mean(ss_all, 2);
plot(freqMHz, meanSS, '-o', 'LineWidth', 2.5, 'MarkerSize', 9, ...
     'Color', [0.15 0.4 0.75], 'MarkerFaceColor', [0.9 0.5 0.1]);
set(gca, 'XScale', 'log');
xticks(freqMHz); xticklabels({'700 MHz', '2.6 GHz', '28 GHz'});
ylabel('Ortalama Sinyal Gücü (dBm)'); xlabel('Frekans');
title({'Frekans vs Ortalama Alınan Güç', '(6 RX noktası ortalaması)'});
grid on; box on;
ylim([min(meanSS)-10, max(meanSS)+5]);

sgtitle('KKÜ Kampüsü – Frekans Bandı Analizi', 'FontSize', 13, 'FontWeight', 'bold');

fprintf('\n[✓] Frekans karşılaştırması tamamlandı.\n\n');
