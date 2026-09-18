% --- MATLAB HAFIZASINI TEMİZLE ---
clc; clear; close all;

% 1. Haritayı Yükle
modelFile = 'map (3).osm';
viewer = siteviewer("Buildings", modelFile);

% --- KAMPÜS SINIRLARINI GÖRSELDEKİ GİBİ DOLGULU YAP (Garantili Yöntem) ---
lat_sinir = [39.8870, 39.8860, 39.8780, 39.8680, 39.8680, 39.8750, 39.8870];
lon_sinir = [33.4410, 33.4560, 33.4580, 33.4550, 33.4480, 33.4380, 33.4410];

% Kampüs sınırını poligon olarak tanımla
pgon = geopolyshape(lat_sinir, lon_sinir);

% Sürüm hatalarını aşmak için show fonksiyonunu en basit haliyle kullanıyoruz
% Eğer show(pgon) hata verirse, sadece dış hattı (line) çizecek
try
    show(pgon); 
    disp('Kampüs alanı dolgulu olarak işaretlendi.');
catch
    line(lat_sinir, lon_sinir, 'Color', 'red', 'LineWidth', 2);
    disp('Dolgulu alan sürüm hatası verdi, sadece kırmızı sınır çizildi.');
end

% 2. Sektörel Antenleri (Tx) Yerleştir
tx1 = txsite("Name", "Tx1_Kuzey", "Latitude", 39.883654, "Longitude", 33.445044, "AntennaHeight", 30, "TransmitterPower", 43, "TransmitterFrequency", 1.8e9, "AntennaAngle", [180; 0]); 
tx2 = txsite("Name", "Tx2_Orta", "Latitude", 39.878568, "Longitude", 33.448944, "AntennaHeight", 30, "TransmitterPower", 43, "TransmitterFrequency", 1.8e9, "AntennaAngle", [270; 0]); 
tx3 = txsite("Name", "Tx3_Guney", "Latitude", 39.871768, "Longitude", 33.451413, "AntennaHeight", 30, "TransmitterPower", 43, "TransmitterFrequency", 1.8e9, "AntennaAngle", [45; 0]);  
tx_array = [tx1, tx2, tx3];
show(tx_array);

% 3. Alıcıları (Rx) Yerleştir
rx1 = rxsite("Name", "Alici_1", "Latitude", 39.873351, "Longitude", 33.450040, "AntennaHeight", 1.5);
rx2 = rxsite("Name", "Alici_2", "Latitude", 39.881035, "Longitude", 33.446687, "AntennaHeight", 1.5);
rx3 = rxsite("Name", "Alici_3", "Latitude", 39.884681, "Longitude", 33.442186, "AntennaHeight", 1.5);
rx_array = [rx1, rx2, rx3];
show(rx_array);

% 4. Ray Tracing Modeli
pm = propagationModel("raytracing", "Method", "sbr", "MaxNumReflections", 2, "MaxNumDiffractions", 1, "SurfaceMaterial", "concrete", "UseGPU", "auto");                   

% 5. KALİTE (SINR) HARİTASI
disp('SINR Haritası çiziliyor...');
sinr(tx_array, pm, 'Resolution', 20); % Çözünürlüğü biraz düşürdük ki donmasın

% 6. Işınlar (Raytrace)
disp('Işınlar ekleniyor...');
raytrace(tx_array, rx_array, pm);

disp('Simülasyon başarıyla tamamlandı.');
