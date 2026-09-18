clc;
clear;
close all;

%% =========================================================
% KKU / YAHSIHAN LTE-5G DIGITAL TWIN
%% =========================================================

%% LOAD SITE VIEWER

viewer = siteviewer( ...
    Buildings="map (3).osm", ...
    Basemap="satellite");

%% CAMERA POSITION

campos(viewer,39.8695,33.4525,1800);

%% LOAD BASE STATIONS

tbl = readtable("base_stations.csv");

N = height(tbl);

tx = txsite.empty;

%% =========================================================
% CREATE TRANSMITTERS
%% =========================================================

for i = 1:N

    freq = tbl.FreqMHz(i) * 1e6;

    tx(i) = txsite( ...
        Name = sprintf('%s_%d', ...
        tbl.Operator{i}, tbl.eNB(i)), ...
        Latitude = tbl.Lat(i), ...
        Longitude = tbl.Lon(i), ...
        AntennaHeight = tbl.Height(i), ...
        TransmitterFrequency = freq, ...
        TransmitterPower = tbl.Power(i));

    %% ANTENNA CONFIGURATION

    tx(i).Antenna = arrayConfig(Size=[8 1]);

    %% SHOW TX

  show(tx(i));

end

%% =========================================================
% PROPAGATION MODEL
%% =========================================================

pm = propagationModel("raytracing", ...
    CoordinateSystem="geographic", ...
    Method="sbr", ...
    AngularSeparation="low", ...
    MaxNumReflections=4, ...
    MaxNumDiffractions=1);

%% =========================================================
% COVERAGE MAPS
%% =========================================================
%% COVERAGE MAPS

fprintf('\nGenerating Coverage Maps...\n');

for i = 1:N

    coverage(tx(i), ...
        "PropagationModel", pm, ...
        "MaxRange", 2500, ...
        "Resolution", 20);

end

%% =========================================================
% CAMPUS RECEIVERS
%% =========================================================

rx(1) = rxsite( ...
    Name="Rektorluk", ...
    Latitude=39.8705, ...
    Longitude=33.4525, ...
    AntennaHeight=1.5);

rx(2) = rxsite( ...
    Name="Hospital", ...
    Latitude=39.8709, ...
    Longitude=33.4555, ...
    AntennaHeight=1.5);

rx(3) = rxsite( ...
    Name="Muhendislik", ...
    Latitude=39.8698, ...
    Longitude=33.4580, ...
    AntennaHeight=1.5);

rx(4) = rxsite( ...
    Name="KYK", ...
    Latitude=39.8675, ...
    Longitude=33.4605, ...
    AntennaHeight=1.5);

show(rx)

%% =========================================================
% SIGNAL REPORT
%% =========================================================

fprintf('\n========== SIGNAL REPORT ==========\n');

for r = 1:length(rx)

    fprintf('\nReceiver: %s\n', rx(r).Name);

    bestSignal = -999;

    bestCell = "";

    for i = 1:N

        ss = sigstrength(rx(r), tx(i), pm);

        fprintf('%s -> %.2f dBm\n', ...
            tx(i).Name, ss);

        if ss > bestSignal

            bestSignal = ss;
            bestCell = tx(i).Name;

        end
    end

    fprintf('BEST SERVER: %s (%.2f dBm)\n', ...
        bestCell, bestSignal);

end

%% =========================================================
% LINE OF SIGHT ANALYSIS
%% =========================================================

fprintf('\n========== LOS ANALYSIS ==========\n');

for r = 1:length(rx)

    for i = 1:N

        islos = los(tx(i), rx(r));

        fprintf('%s -> %s : %d\n', ...
            tx(i).Name, ...
            rx(r).Name, ...
            islos);

    end
end

%% =========================================================
% RAY TRACING
%% =========================================================

fprintf('\n========== RAY TRACING ==========\n');

for r = 1:length(rx)

    for i = 1:N

        raytrace(tx(i), rx(r), pm);

    end
end

%% =========================================================
% D200 MOBILITY ANALYSIS
%% =========================================================

fprintf('\n========== D200 HANDOVER ==========\n');

latPath = linspace(39.8670,39.8690,20);
lonPath = linspace(33.4440,33.4620,20);

bestServer = strings(length(latPath),1);

for k = 1:length(latPath)

    mobile = rxsite( ...
        Latitude=latPath(k), ...
        Longitude=lonPath(k), ...
        AntennaHeight=1.5);

    bestSig = -999;

    for i = 1:N

        ss = sigstrength(mobile, tx(i), pm);

        if ss > bestSig

            bestSig = ss;
            bestServer(k) = tx(i).Name;

        end
    end
end

%% PRINT HANDOVERS

for k = 2:length(bestServer)

    if bestServer(k) ~= bestServer(k-1)

        fprintf('HANDOVER: %s -> %s\n', ...
            bestServer(k-1), ...
            bestServer(k));

    end
end

%% =========================================================
% SAVE FIGURE
%% =========================================================

saveas(gcf,'results/kku_network.png')

fprintf('\nSimulation Complete.\n');