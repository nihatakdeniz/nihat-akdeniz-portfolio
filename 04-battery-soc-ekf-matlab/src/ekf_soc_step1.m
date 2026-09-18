% Tez İçin Şekil 3.1: Coulomb Sayma Yöntemi SOC Grafiği
clc; clear; close all;

% Zaman vektörü (saniye)
t = 0:1:1000;

% 1. Durum: Sabit Akım (Doğrusal Azalma)
% SOC %100'den başlar, doğrusal iner
soc_sabit = 100 - (0.05 * t);

% 2. Durum: Değişken Akım (Dinamik Azalma)
% Gürültü ve dalgalanma ekleyerek dinamik yük simülasyonu
rng(42); % Tutarlı sonuç için seed
noise = -0.05 + 0.05 * randn(size(t)); % Rastgele akım değişimleri
soc_degisken = 100 + cumsum(noise);
% Sınırları 100'e sabitle (fiziksel sınır)
soc_degisken(soc_degisken > 100) = 100;

% Grafik Çizimi
figure('Color', 'w'); % Arka plan beyaz
hold on;

% Sabit Akım Çizgisi (Mavi, Kesikli)
plot(t, soc_sabit, '--b', 'LineWidth', 2, 'DisplayName', 'Sabit Akım (Constant Current)');

% Değişken Akım Çizgisi (Kırmızı, Düz)
plot(t, soc_degisken, '-r', 'LineWidth', 1.5, 'DisplayName', 'Değişken Akım (Variable Current)');

% Eksenler ve Başlıklar
title('Şekil 3.1: Coulomb Sayma Yöntemine Göre SOC Değişimi', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Zaman (t)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Şarj Durumu - SOC (%)', 'FontSize', 11, 'FontWeight', 'bold');

% Lejant ve Izgara
legend('show', 'Location', 'northeast');
grid on;
box on; % Çerçeveyi kapat

% Eksen sınırlarını ayarla
ylim([50 105]);
xlim([0 1000]);

hold off;