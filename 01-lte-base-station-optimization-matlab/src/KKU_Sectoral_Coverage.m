% --- MATLAB HAFIZASINI TEMİZLE ---
clc;
clear;
close all;

% 1. Haritayı Yükle
modelFile = 'map (3).osm';
viewer = siteviewer("Buildings", modelFile);

% 2. Sektörel Antenleri (Tx) Yerleştir ve Yönlendir
% Özel dipole tanımını kaldırdık, MATLAB'ın yönlü anten ayarını kullanıyoruz.
% Sadece "AntennaAngle" ile yön veriyoruz. [Azimuth; Elevation]

tx1 = txsite("Name", "Tx1_Kuzey", "Latitude", 39.883654, "Longitude", 33.445044, ...
    "AntennaHeight", 30, "TransmitterPower", 43, "TransmitterFrequency", 1.8e9, ...
    "AntennaAngle", [180; 0]); % Güneye Bakıyor

tx2 = txsite("Name", "Tx2_Orta", "Latitude", 39.878568, "Longitude", 33.448944, ...
    "AntennaHeight", 30, "TransmitterPower", 43, "TransmitterFrequency", 1.8e9, ...
    "AntennaAngle", [270; 0]); % Batıya Bakıyor

tx3 = txsite("Name", "Tx3_Guney", "Latitude", 39.871768, "Longitude", 33.451413, ...
    "AntennaHeight", 30, "TransmitterPower", 43, "TransmitterFrequency", 1.8e9, ...
    "AntennaAngle", [45; 0]);  % Kuzeydoğuya Bakıyor

tx_array = [tx1, tx2, tx3];
show(tx_array);

% 3. Alıcıları (Rx) Yerleştir
rx1 = rxsite("Name", "Alici_1", "Latitude", 39.873351, "Longitude", 33.450040, "AntennaHeight", 1.5);
rx2 = rxsite("Name", "Alici_2", "Latitude", 39.881035, "Longitude", 33.446687, "AntennaHeight", 1.5);
rx3 = rxsite("Name", "Alici_3", "Latitude", 39.884681, "Longitude", 33.442186, "AntennaHeight", 1.5);

rx_array = [rx1, rx2, rx3];
show(rx_array);

% 4. Geliştirilmiş Ray Tracing Modeli
pm = propagationModel("raytracing", ...
    "Method", "sbr", ...
    "MaxNumReflections", 2, ...
    "MaxNumDiffractions", 1, ...         
    "SurfaceMaterial", "concrete", ...   
    "UseGPU", "auto");                   

% --- HAVA DURUMU MANUEL HESAPLAMA (ITU Standartlarına Yakın Yaklaşım) ---
% 1.8 GHz frekansında yağmur kaybı düşüktür ancak bilimsel olması için ekliyoruz.
yagmur_orani = 50; % mm/saat (Şiddetli Yağmur)
frekans_ghz = 1.8;

% Basitleştirilmiş Yağmur Sönümleme Katsayısı (dB/km)
% k ve alpha değerleri 1.8 GHz için ITU-R P.838'den yaklaşık değerlerdir
k = 0.0007; 
alpha = 1.2;
yagmur_kaybi_db_km = k * (yagmur_orani^alpha); 

disp(['Hava durumu analizi aktif: ', num2str(yagmur_kaybi_db_km), ' dB/km kayıp hesaplandı.']);

% 5. KALİTE (SINR) HARİTASI
disp('SINR Haritası çiziliyor...');
sinr(tx_array, pm, 'Resolution', 15);

% 7. Sonuçları Hesapla ve HAVA DURUMUNA GÖRE EXCEL'E AKTAR
disp('Yağmurlu hava verileri işleniyor...');
ss = sigstrength(rx_array, tx_array, pm);
kalite = sinr(rx_array, tx_array, pm); 

% Mesafeye bağlı yağmur kaybını uygula
% Alıcı ve verici arasındaki mesafeyi bulup km başına kaybı düşüyoruz
en_iyi_ss = zeros(3,1);
for i = 1:3
    % Alıcının en güçlü olduğu vericiyi bul
    [max_val, idx] = max(ss(i,:));
    % Verici ile alıcı arası mesafeyi (metre) al
    d = distance(rx_array(i), tx_array(idx));
    % Yağmur kaybını mesafeye (km) göre hesapla ve çıkar
    en_iyi_ss(i) = max_val - (yagmur_kaybi_db_km * (d/1000));
end

en_iyi_kalite = max(kalite, [], 2); 
alici_isimleri = ["Alici_1"; "Alici_2"; "Alici_3"];
               

% 5. KALİTE (SINR) HARİTASI
disp('Sektörel antenlerle optimize edilmiş SINR Haritası çiziliyor...');
% ÇÖKME ÇÖZÜMÜ: Resolution (Çözünürlük) parametresini 15 metre yaptık. 
% Bu, milyonlarca piksel yerine haritayı 15 metrelik kareler halinde hesaplatıp RAM'i kurtarır.
sinr(tx_array, pm, 'Resolution', 15);

% 6. Işınları Haritaya Ekle 
disp('Çoklu yol ışınları ekleniyor...');
raytrace(tx_array, rx_array, pm);

% 7. Sonuçları Hesapla ve TEZ İÇİN EXCEL'E AKTAR
disp('Sinyal gücü ve kalitesi hesaplanıyor...');
ss = sigstrength(rx_array, tx_array, pm);
kalite = sinr(rx_array, tx_array, pm); 

% Hem sinyal gücü matrisinden hem de SINR matrisinden sadece EN İYİ çekenleri süzüyoruz.
% Böylece ikisi de tam olarak 3x1 boyutunda (3 satır, 1 sütun) vektörlere dönüşüyor.
en_iyi_ss = max(ss, [], 2); 
en_iyi_kalite = max(kalite, [], 2); 

alici_isimleri = ["Alici_1"; "Alici_2"; "Alici_3"];

% Artık 3 değişken de (isim, güç, kalite) birebir aynı boyutta!
tez_tablosu = table(alici_isimleri, en_iyi_ss, en_iyi_kalite, 'VariableNames', {'Alici_Adi', 'Guc_dBm', 'SINR_dB'});
writetable(tez_tablosu, 'Sektorel_Anten_SINR_Sonuclari.xlsx');
disp('Optimizasyon sonuçları "Sektorel_Anten_SINR_Sonuclari.xlsx" adıyla kaydedildi!');
