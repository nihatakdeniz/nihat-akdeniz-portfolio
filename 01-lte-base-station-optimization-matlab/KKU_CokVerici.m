%% =========================================================
%%  KKU_CokVerici.m
%%  Kırıkkale Üniversitesi – 3 Baz İstasyonu ile Tam Kapsama
%%
%%  TX konumları OSM verisiyle optimize edilmiştir:
%%   TX1: Rektörlük (merkez)
%%   TX2: Veteriner Fakültesi (kuzey-batı)
%%   TX3: KYK Yurt (güney-doğu)
%%  → Bu üçlü kampüsün her köşesini kapsayacak şekilde seçilmiştir.
%% =========================================================

clear; clc; close all;

fprintf('╔══════════════════════════════════════════════════════════╗\n');
fprintf('║   KKÜ – 3 Baz İstasyonu / Optimal Kapsama               ║\n');
fprintf('╚══════════════════════════════════════════════════════════╝\n\n');

viewer = siteviewer(Buildings='map.osm', Basemap='openstreetmap');

%% ── 3 Verici Anten ──────────────────────────────────────────────────────
%
%  TX1 – Rektörlük çatısı (h=18m)
%    Kampüs merkezi. Kütüphane, BESYO ve çevre binaları kapsar.
%
%  TX2 – Veteriner Fakültesi çatısı (h=15m)
%    Kuzey-batı köşe. Kapalı Spor Salonu ve kuzeybatı alanı kapsar.
%
%  TX3 – KYK Yurt bölgesi su kulesi/yüksek noktası (h=20m)
%    Güney-doğu köşe. Diş Hekimliği, MYO ve yurt binaları kapsar.
%
txData = {
%   İsim                Lat          Lon          h(m) Güç(W) Renk
    'TX1-Rektorluk',    39.879439,   33.445946,   18,  2.0,   [0.8 0.2 0.2];
    'TX2-VeterinerFak', 39.884138,   33.441904,   15,  1.5,   [0.2 0.6 0.2];
    'TX3-KYK_Yurt',     39.873928,   33.455910,   20,  1.5,   [0.2 0.2 0.8];
};

tx = txsite.empty;
for t = 1:size(txData,1)
    tx(t) = txsite( ...
        Name                 = txData{t,1}, ...
        Latitude             = txData{t,2}, ...
        Longitude            = txData{t,3}, ...
        AntennaHeight        = txData{t,4}, ...
        TransmitterFrequency = 2.6e9, ...
        TransmitterPower     = txData{t,5});
end

fprintf('[TX] Baz İstasyonları:\n');
for t = 1:numel(tx)
    fprintf('  %s: (%.6f, %.6f), h=%dm, P=%.1fW\n', ...
        tx(t).Name, tx(t).Latitude, tx(t).Longitude, ...
        tx(t).AntennaHeight, tx(t).TransmitterPower);
end

%% ── Alıcılar ────────────────────────────────────────────────────────────
rxData = {
    'Kutuphane',          39.880190, 33.447136;
    'VeterinerFak_Giris', 39.884000, 33.442000;
    'KapaliSpor',         39.884008, 33.446022;
    'KYK_Yurt_Merkez',    39.873928, 33.455910;
    'MYO_Yemekhane',      39.873590, 33.451916;
    'DisHekimlik',        39.871157, 33.454775;
    'BilgisayarLab',      39.873314, 33.449692;
    'BESYO',              39.880439, 33.446810;
    'MerkYemekhane',      39.881750, 33.449658;
};

rx = rxsite.empty;
for k = 1:size(rxData,1)
    rx(k) = rxsite(Name=rxData{k,1}, Latitude=rxData{k,2}, ...
                   Longitude=rxData{k,3}, AntennaHeight=1.5);
end
nRX = numel(rx);

fprintf('\n[RX] %d alıcı tanımlandı.\n\n', nRX);

%% ── Yayılım Modeli ──────────────────────────────────────────────────────
rtpm = propagationModel('raytracing', Method='sbr', ...
    MaxNumReflections=2, MaxNumDiffractions=1, ...
    BuildingsMaterial='concrete', TerrainMaterial='concrete');

%% ── Tüm TX Kapsama Haritaları ───────────────────────────────────────────
fprintf('[1] Kapsama haritaları oluşturuluyor...\n');
clearMap(viewer);
for t = 1:numel(tx)
    show(tx(t), 'ShowAntennaHeight', true);
end
for k = 1:nRX; show(rx(k)); end

for t = 1:numel(tx)
    coverage(tx(t), rtpm, ...
        SignalStrengths=-120:5, MaxRange=1200, Resolution=5, Transparency=0.4);
    pause(0.3);
end
title('KKÜ – 3 Baz İstasyonu Kapsama Haritası (Beton, 2.6 GHz)');

%% ── Sinyal Gücü Matrisi: Her TX → Her RX ───────────────────────────────
fprintf('\n[2] Sinyal gücü matrisi hesaplanıyor...\n');
ss_matrix = zeros(numel(tx), nRX);

for t = 1:numel(tx)
    for k = 1:nRX
        ss_matrix(t,k) = sigstrength(rx(k), tx(t), rtpm);
    end
end

%% ── Best-Server Analizi ─────────────────────────────────────────────────
fprintf('\n[3] Best-Server Analizi:\n');
fprintf('%-22s  %14s  %8s  %10s\n', 'Alıcı', 'En İyi TX', 'dBm', 'Kazanç(dB)');
fprintf('%s\n', repmat('-',1,60));

bestTX_idx = zeros(1, nRX);
for k = 1:nRX
    [maxSS, best] = max(ss_matrix(:,k));
    [minSS, ~]    = min(ss_matrix(:,k));
    bestTX_idx(k) = best;
    fprintf('%-22s  %14s  %8.1f  %+10.1f\n', ...
        rx(k).Name, tx(best).Name, maxSS, maxSS-minSS);
end

%% ── Ray Tracing: Her TX → Tüm RX ───────────────────────────────────────
fprintf('\n[4] Işın çizimleri...\n');
clearMap(viewer);
for t = 1:numel(tx); show(tx(t), 'ShowAntennaHeight', true); end
for k = 1:nRX; show(rx(k)); end

for t = 1:numel(tx)
    raytrace(tx(t), rx, rtpm);
    pause(0.3);
end
title('KKÜ – 3 TX Ray Tracing (Beton, 2 Yansıma)');

%% ── Grafikler ───────────────────────────────────────────────────────────
figure('Name','Çok Vericili Analiz','Position',[50 50 1050 650]);

subplot(2,2,[1 2]);
hm = heatmap({tx.Name}, {rx.Name}, ss_matrix', ...
    'ColorbarVisible','on', 'FontSize',9);
xlabel('Baz İstasyonu'); ylabel('Alıcı Noktası');
title('TX-RX Sinyal Gücü Isı Haritası (dBm)');
hm.Colormap = jet;

subplot(2,2,3);
b = bar(ss_matrix','grouped');
txRenk = {[0.8 0.2 0.2],[0.2 0.6 0.2],[0.2 0.2 0.8]};
for t=1:numel(tx); b(t).FaceColor = txRenk{t}; end
legend({tx.Name},'Location','best','Interpreter','none');
xticks(1:nRX); xticklabels({rx.Name}); xtickangle(22);
ylabel('Sinyal Gücü (dBm)'); title('Her TX için Alınan Güç');
grid on; yline(-100,'--r','Eşik');

subplot(2,2,4);
% Best-server pie
txCounts = histcounts(bestTX_idx, 1:numel(tx)+1);
pie(txCounts, {tx.Name});
title(sprintf('Best-Server Dağılımı (%d RX)', nRX));

sgtitle('KKÜ Kampüsü – 3 Baz İstasyonu Analizi | 2.6 GHz | Beton', ...
        'FontSize',12,'FontWeight','bold');

fprintf('\n[✓] Çok vericili analiz tamamlandı.\n\n');
