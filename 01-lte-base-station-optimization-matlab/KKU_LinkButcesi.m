%% =========================================================
%%  KKU_LinkButcesi.m
%%  Kırıkkale Üniversitesi – Link Bütçesi ve Malzeme Analizi
%%
%%  Karşılaştırmalar:
%%   (1) Malzeme: PEC / Beton / Tuğla
%%   (2) Yansıma sayısı: 0 / 1 / 2 / 3
%%   (3) Hava koşulları: Kuru / Nemli (ITU-R P.676)
%% =========================================================

clear; clc; close all;

fprintf('╔══════════════════════════════════════════════════════════╗\n');
fprintf('║   KKÜ – Link Bütçesi Analizi                            ║\n');
fprintf('╚══════════════════════════════════════════════════════════╝\n\n');

viewer = siteviewer(Buildings='map.osm', Basemap='openstreetmap');

%% ── Ortak TX ────────────────────────────────────────────────────────────
tx = txsite( ...
    Name='TX-Rektorluk', Latitude=39.879439, Longitude=33.445946, ...
    AntennaHeight=18, TransmitterFrequency=2.6e9, TransmitterPower=2.0);

%% ── Alıcılar ────────────────────────────────────────────────────────────
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

nRX = numel(rx);

%% ════════════════════════════════════════════════════════
%%  SENARYO 1: Malzeme Etkisi
%% ════════════════════════════════════════════════════════
fprintf('══ Senaryo 1: Malzeme Etkisi ══\n');
malzeme  = {'PEC',   'concrete', 'brick'};
malzStr  = {'PEC (İdeal)', 'Beton', 'Tuğla'};
ss_mat   = zeros(numel(malzeme), nRX);

for m = 1:numel(malzeme)
    rtpm = propagationModel('raytracing', Method='sbr', ...
        MaxNumReflections=2, MaxNumDiffractions=1, ...
        BuildingsMaterial=malzeme{m}, TerrainMaterial=malzeme{m});
    for k = 1:nRX
        ss_mat(m,k) = sigstrength(rx(k), tx, rtpm);
    end
end

fprintf('%-18s', 'RX \\ Malzeme');
for m = 1:numel(malzStr); fprintf('%16s', malzStr{m}); end
fprintf('\n%s\n', repmat('-',1,18+16*3));
for k = 1:nRX
    fprintf('%-18s', rx(k).Name);
    for m = 1:numel(malzeme)
        fprintf('%14.1f dBm', ss_mat(m,k));
    end
    fprintf('\n');
end

%% ════════════════════════════════════════════════════════
%%  SENARYO 2: Yansıma Sayısı Etkisi
%% ════════════════════════════════════════════════════════
fprintf('\n══ Senaryo 2: Yansıma Sayısı ══\n');
nRefList = [0, 1, 2, 3];
ss_ref   = zeros(numel(nRefList), nRX);

for i = 1:numel(nRefList)
    rtpm = propagationModel('raytracing', Method='sbr', ...
        MaxNumReflections=nRefList(i), MaxNumDiffractions=0, ...
        BuildingsMaterial='concrete', TerrainMaterial='concrete');
    for k = 1:nRX
        ss_ref(i,k) = sigstrength(rx(k), tx, rtpm);
    end
end

fprintf('%-18s', 'RX \\ MaxRef');
for i = 1:numel(nRefList); fprintf('%10s', sprintf('Ref=%d',nRefList(i))); end
fprintf('\n%s\n', repmat('-',1,18+10*4));
for k = 1:nRX
    fprintf('%-18s', rx(k).Name);
    for i = 1:numel(nRefList)
        fprintf('%8.1f dBm', ss_ref(i,k));
    end
    fprintf('\n');
end

%% ════════════════════════════════════════════════════════
%%  SENARYO 3: Hava Koşulları
%% ════════════════════════════════════════════════════════
fprintf('\n══ Senaryo 3: Hava Koşulları ══\n');
rtpm_base = propagationModel('raytracing', Method='sbr', ...
    MaxNumReflections=2, MaxNumDiffractions=1, ...
    BuildingsMaterial='concrete', TerrainMaterial='concrete');

ss_kuru   = zeros(1, nRX);
ss_yagmur = zeros(1, nRX);
ss_sis    = zeros(1, nRX);

for k = 1:nRX
    ss_kuru(k) = sigstrength(rx(k), tx, rtpm_base);
    % Mesafe (m)
    d_m = distance(tx.Latitude, tx.Longitude, ...
                   rx(k).Latitude, rx(k).Longitude) * 111320;
    % ITU-R P.838-3: 2.6 GHz yağmur zayıflama (orta yoğunluk ~10 mm/h)
    % alpha_H=0.0247, k_H=1.03 → γ_R ≈ 0.026 dB/km
    rain_dB = 0.026 * d_m/1000;
    % Sis: ~0.05 dB/km@2.6GHz (yaklaşık)
    fog_dB  = 0.05 * d_m/1000;
    ss_yagmur(k) = ss_kuru(k) - rain_dB;
    ss_sis(k)    = ss_kuru(k) - fog_dB;
end

fprintf('%-18s  %12s  %14s  %12s\n', 'Alıcı', 'Kuru(dBm)', 'Yağmur(dBm)', 'Sis(dBm)');
fprintf('%s\n', repmat('-',1,62));
for k = 1:nRX
    fprintf('%-18s  %12.2f  %14.2f  %12.2f\n', ...
        rx(k).Name, ss_kuru(k), ss_yagmur(k), ss_sis(k));
end

%% ── Grafikler ───────────────────────────────────────────────────────────
figure('Name','Link Bütçe Analizi','Position',[50 50 1100 820]);

subplot(2,2,1);
b1 = bar(ss_mat','grouped');
colors = {[0.2 0.5 0.8],[0.7 0.3 0.2],[0.4 0.7 0.3]};
for i=1:3; b1(i).FaceColor = colors{i}; end
legend(malzStr,'Location','best'); grid on;
xticks(1:nRX); xticklabels({rx.Name}); xtickangle(20);
ylabel('Sinyal Gücü (dBm)');
title('Senaryo 1: Malzeme Etkisi');
yline(-100,'--r','Eşik');

subplot(2,2,2);
b2 = bar(ss_ref','grouped');
legend(arrayfun(@(n) sprintf('MaxRef=%d',n), nRefList,'UniformOutput',false),'Location','best');
grid on;
xticks(1:nRX); xticklabels({rx.Name}); xtickangle(20);
ylabel('Sinyal Gücü (dBm)');
title('Senaryo 2: Yansıma Sayısı Etkisi');
yline(-100,'--r','Eşik');

subplot(2,2,3);
x = 1:nRX;
plot(x, ss_kuru,   '-o','LineWidth',2,'DisplayName','Kuru','Color',[0.2 0.5 0.8]);
hold on;
plot(x, ss_yagmur,'-s','LineWidth',2,'DisplayName','Yağmurlu','Color',[0.8 0.4 0.1]);
plot(x, ss_sis,   '-^','LineWidth',2,'DisplayName','Sisli','Color',[0.5 0.5 0.5]);
hold off;
legend('Location','best'); grid on;
xticks(1:nRX); xticklabels({rx.Name}); xtickangle(20);
ylabel('Sinyal Gücü (dBm)');
title('Senaryo 3: Hava Koşulları');
yline(-100,'--r','Eşik');

subplot(2,2,4);
% Mesafe vs Sinyal Gücü (Beton, 2 yansıma)
dist_m = zeros(1,nRX);
for k=1:nRX
    dist_m(k) = distance(tx.Latitude,tx.Longitude, ...
                         rx(k).Latitude,rx(k).Longitude)*111320;
end
[dist_sorted, idx] = sort(dist_m);
scatter(dist_sorted, ss_mat(2,idx), 80, 'filled', ...
        'CData', ss_mat(2,idx), 'MarkerEdgeColor','k');
colorbar; colormap(gca,'jet');
xlabel('TX-RX Mesafesi (m)'); ylabel('Sinyal Gücü (dBm)');
title('Mesafe vs Sinyal Gücü (Beton)');
grid on; box on;
text(dist_sorted+8, ss_mat(2,idx), {rx(idx).Name}, 'FontSize',8);

sgtitle('KKÜ Kampüsü – Link Bütçesi Analizi | 2.6 GHz | Rektörlük TX', ...
        'FontSize',13,'FontWeight','bold');

fprintf('\n[✓] Link bütçesi analizi tamamlandı.\n\n');
