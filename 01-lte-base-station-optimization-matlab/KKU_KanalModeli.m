%% =========================================================
%%  KKU_KanalModeli.m
%%  Kırıkkale Üniversitesi – comm.RayTracingChannel Analizi
%%
%%  Güç-Gecikme Profili (PDP), Varış/Kalkış Açıları,
%%  RMS Delay Spread ve kanal filtreleme gösterimi
%%  (MathWorks Urban Channel Link Analysis örneğine göre)
%% =========================================================

clear; clc; close all;

fprintf('╔══════════════════════════════════════════════════════════╗\n');
fprintf('║   KKÜ – Kanal Modeli ve Gecikme Profili Analizi         ║\n');
fprintf('╚══════════════════════════════════════════════════════════╝\n\n');

%% ── Harita ──────────────────────────────────────────────────────────────
viewer = siteviewer(Buildings='map.osm', Basemap='openstreetmap');

%% ── Verici Anten ────────────────────────────────────────────────────────
tx = txsite( ...
    Name                 = 'TX-Rektorluk', ...
    Latitude             = 39.879439, ...
    Longitude            = 33.445946, ...
    AntennaHeight        = 18, ...
    TransmitterFrequency = 2.6e9, ...
    TransmitterPower     = 2.0);

%% ── İki Farklı Alıcı Senaryo ────────────────────────────────────────────
%  Senaryo A: Kütüphane – TX'e yakın, muhtemelen LOS veya az engel
%  Senaryo B: KYK Yurt   – uzak, çok engel, zengin çok-yollu kanal
scenarios = struct( ...
    'ad',  {'Kutuphane_LOS', 'KYK_Yurt_NLOS'}, ...
    'lat', {39.880190,        39.873928}, ...
    'lon', {33.447136,        33.455910});

for sc = 1:2
    fprintf('── Senaryo %d: %s ──\n', sc, scenarios(sc).ad);

    rx_sc = rxsite( ...
        Name          = scenarios(sc).ad, ...
        Latitude      = scenarios(sc).lat, ...
        Longitude     = scenarios(sc).lon, ...
        AntennaHeight = 1.5);

    %% Yayılım Modeli (yüksek çözünürlük – 'low' açısal ayrım)
    rtpm = propagationModel('raytracing', ...
        Method             = 'sbr', ...
        MaxNumReflections  = 3, ...
        MaxNumDiffractions = 1, ...
        AngularSeparation  = 'low', ...
        BuildingsMaterial  = 'concrete', ...
        TerrainMaterial    = 'concrete');

    %% Işınları Hesapla
    clearMap(viewer);
    show(tx, 'ShowAntennaHeight', true);
    show(rx_sc);
    rays_cell = raytrace(tx, rx_sc, rtpm, 'Type', 'pathloss');
    rays = rays_cell{1};

    if isempty(rays)
        fprintf('  Uyarı: Bu TX-RX çifti için ışın bulunamadı.\n\n');
        continue;
    end

    title(sprintf('KKÜ Ray Tracing – %s', scenarios(sc).ad));

    fprintf('  Bulunan ışın sayısı: %d\n', numel(rays));

    %% Işın Tablosu
    fprintf('  %-5s  %-5s  %-8s  %-12s  %-10s  %-8s\n', ...
            '#', 'LOS', 'Yans.', 'Kayıp(dB)', 'Gec.(ns)', 'AoA(°)');
    fprintf('  %s\n', repmat('-',1,58));
    for r = 1:numel(rays)
        fprintf('  %-5d  %-5s  %-8d  %-12.2f  %-10.3f  %-8.1f\n', r, ...
            string(rays(r).LineOfSight), rays(r).NumReflections, ...
            rays(r).PathLoss, rays(r).PropagationDelay*1e9, ...
            rays(r).AngleOfArrival(1));
    end

    %% comm.RayTracingChannel
    rtChan = comm.RayTracingChannel(rays, tx, rx_sc);
    rtChan.SampleRate = 30.72e6;
    rtChan.ReceiverVirtualVelocity = [0; 0; 0];

    %% Kanal Profili Görselleştir (MATLAB showProfile)
    showProfile(rtChan);
    sgtitle(sprintf('KKÜ Kanal Profili – %s', scenarios(sc).ad));

    %% Manuel Güç-Gecikme Profili (PDP)
    delays  = [rays.PropagationDelay];
    ploss   = [rays.PathLoss];
    P_lin   = 10.^(-ploss/10);
    delays_ns = (delays - min(delays)) * 1e9;

    figure('Name', sprintf('PDP – %s', scenarios(sc).ad), ...
           'Position', [50+sc*50, 50, 780, 380]);

    subplot(1,2,1);
    stem(delays_ns, 10*log10(P_lin/max(P_lin)), 'filled', ...
         'LineWidth', 1.8, 'MarkerSize', 7, 'Color', [0.15 0.45 0.75]);
    xlabel('Gecikme (ns)'); ylabel('Normalize Güç (dB)');
    title('Güç-Gecikme Profili (PDP)');
    grid on; xlim([-0.2 max(delays_ns)+0.5]);

    subplot(1,2,2);
    aoa_az = arrayfun(@(r) r.AngleOfArrival(1), rays);
    polarplot(deg2rad(aoa_az), P_lin/max(P_lin), 'o', ...
              'MarkerSize', 8, 'MarkerFaceColor', [0.9 0.3 0.2], ...
              'MarkerEdgeColor', 'k');
    title('AoA Azimut Dağılımı'); rlim([0 1.1]);

    sgtitle(sprintf('KKÜ Kanal Analizi – %s | 2.6 GHz | Beton', ...
            scenarios(sc).ad));

    %% RMS Gecikme Yayılımı
    tau_mean = sum(P_lin .* delays_ns) / sum(P_lin);
    tau_rms  = sqrt(sum(P_lin .* (delays_ns - tau_mean).^2) / sum(P_lin));

    fprintf('\n  Kanal Metrikleri:\n');
    fprintf('  ┌──────────────────────────────────────────┐\n');
    fprintf('  │ RMS Gecikme Yayılımı  : %8.3f ns       │\n', tau_rms);
    fprintf('  │ Ortalama Gecikme      : %8.3f ns       │\n', tau_mean);
    fprintf('  │ Maksimum Gecikme      : %8.3f ns       │\n', max(delays_ns));
    fprintf('  │ Uyumlu CP Uzunluğu    : %8.3f μs      │\n', tau_rms*4/1e3);
    fprintf('  └──────────────────────────────────────────┘\n\n');

    %% Kanal Filtresi Testi (16-QAM)
    M       = 16;
    frmLen  = 1000;
    numTx   = rtChan.info.NumTransmitElements;
    x_tx    = qammod(randi([0 M-1], frmLen, numTx), M, 'UnitAveragePower', true);
    y_rx    = rtChan(x_tx);

    figure('Name', sprintf('Konst. Diyagramı – %s', scenarios(sc).ad), ...
           'Position', [150+sc*50, 500, 500, 420]);
    const = comm.ConstellationDiagram('NumInputPorts', 1, ...
        'XLimits', [-2.5 2.5], 'YLimits', [-2.5 2.5], ...
        'ReferenceConstellation', qammod(0:M-1, M, 'UnitAveragePower', true), ...
        'ChannelNames', {sprintf('%s – Kanal Çıkışı', scenarios(sc).ad)});
    const(y_rx(:,1));
    title(sprintf('16-QAM Konstelasyon – %s', scenarios(sc).ad));

    pause(0.5);
end

fprintf('[✓] Kanal modeli analizi tamamlandı.\n\n');
