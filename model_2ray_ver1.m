%% МОДЕЛЬ РАДАРА - ШАГ 8: Комплексная поляризационная матрица с фазовыми сдвигами
% Элементы матрицы - комплексные числа с фазами

clear; clc; close all;

%% 1. ПАРАМЕТРЫ
c = physconst('LightSpeed');
fc = 3e9;
lambda = c/fc;

BW = 1e6;           % 1 МГц
PulseWidth = 20e-6; % 20 мкс
PRF = 1e3;          % 1 кГц
Fs = 10 * BW;       % 10 МГц

% Цель
targetRange = 5000; % 5 км

%% 2. АНТЕННА
Diameter = 1.0;
AperturePhysical = pi * (Diameter/2)^2;
AntennaEfficiency = 0.6;
EffectiveAperture = AntennaEfficiency * AperturePhysical;
Gain_dBi = aperture2gain(EffectiveAperture, lambda);
Gain_Linear = 10^(Gain_dBi/10);

fprintf('Усиление антенны: %.2f дБи\n', Gain_dBi);

%% 3. ПОТЕРИ В ТРАКТЕ
Loss_Feed = 2.0;        % дБ
Loss_Circulator = 1.5;  % дБ
Loss_Radome = 0.5;      % дБ
TotalLoss_dB = Loss_Feed + Loss_Circulator + Loss_Radome;
TotalLoss_Linear = 10^(-TotalLoss_dB/10);

fprintf('Потери в тракте: %.2f дБ\n', TotalLoss_dB);

%% 4. СРЕДА РАСПРОСТРАНЕНИЯ
altitude_radar = 10;
altitude_target = 5;

AtmosLoss_dB_per_km = 0.01;
AtmosLoss_dB = AtmosLoss_dB_per_km * targetRange / 1000;
AtmosLoss_Linear = 10^(-AtmosLoss_dB/10);

delta_R = 2 * altitude_radar * altitude_target / targetRange;
delta_phi = 2 * pi * delta_R / lambda;
InterferenceFactor = abs(1 - exp(1j * delta_phi)).^2 / 4;
InterferenceLoss_dB = -10 * log10(InterferenceFactor + eps);

fprintf('Атмосферное затухание: %.3f дБ\n', AtmosLoss_dB);
fprintf('Потери от интерференции: %.2f дБ\n', InterferenceLoss_dB);

%% 5. НОВОЕ: КОМПЛЕКСНАЯ ПОЛЯРИЗАЦИОННАЯ МАТРИЦА
% Матрица рассеяния с комплексными элементами
% Амплитуды и фазы для каждого элемента

% Амплитуды (кв.м)
amp_HH = 10;
amp_HV = 3;
amp_VH = 3;
amp_VV = 8;

% Фазовые сдвиги (градусы)
phase_HH = 0;      % опорная фаза
phase_HV = 45;     % H->V сдвиг 45 градусов
phase_VH = -30;    % V->H сдвиг -30 градусов
phase_VV = 20;     % V->V сдвиг 20 градусов

% Формируем комплексную матрицу
PolarizationMatrix = [
    amp_HH * exp(1j * phase_HH * pi/180), amp_HV * exp(1j * phase_HV * pi/180);
    amp_VH * exp(1j * phase_VH * pi/180), amp_VV * exp(1j * phase_VV * pi/180)
];

fprintf('\n--- КОМПЛЕКСНАЯ ПОЛЯРИЗАЦИОННАЯ МАТРИЦА ---\n');
fprintf('HH = %.1f∠%.0f°  кв.м\n', amp_HH, phase_HH);
fprintf('HV = %.1f∠%.0f°  кв.м\n', amp_HV, phase_HV);
fprintf('VH = %.1f∠%.0f°  кв.м\n', amp_VH, phase_VH);
fprintf('VV = %.1f∠%.0f°  кв.м\n', amp_VV, phase_VV);

% Проверка на симметричность
if abs(amp_HV - amp_VH) < 0.1 && abs(phase_HV - phase_VH) < 1
    fprintf('Матрица СИММЕТРИЧНАЯ (HV ≈ VH)\n');
else
    fprintf('Матрица НЕСИММЕТРИЧНАЯ (HV ≠ VH)\n');
end

%% 6. СОЗДАЕМ ЛЧМ СИГНАЛ
waveform = phased.LinearFMWaveform(...
    'SampleRate', Fs, ...
    'SweepBandwidth', BW, ...
    'PulseWidth', PulseWidth, ...
    'PRF', PRF, ...
    'NumPulses', 1);

x = step(waveform);
N = length(x);
t = (0:N-1)/Fs;

N_active = round(PulseWidth * Fs);
x_active = x(1:N_active);

fprintf('Длина активной части: %d отсчетов (%.2f мкс)\n', N_active, N_active/Fs*1e6);

%% 7. ГРАФИК 1: ЛЧМ СИГНАЛ
figure('Position', [100 100 1400 900]);

subplot(3,3,1);
plot(t(1:N_active)*1e6, real(x_active), 'b', 'LineWidth', 1.5);
xlabel('Время (мкс)'); ylabel('Re');
title('ЛЧМ сигнал (реальная часть)');
grid on;

subplot(3,3,2);
plot(t(1:N_active)*1e6, imag(x_active), 'r', 'LineWidth', 1.5);
xlabel('Время (мкс)'); ylabel('Im');
title('ЛЧМ сигнал (мнимая часть)');
grid on;

subplot(3,3,3);
freq = linspace(-Fs/2, Fs/2, N_active);
X = fftshift(fft(x_active));
plot(freq/1e6, abs(X), 'k', 'LineWidth', 1.5);
xlabel('Частота (МГц)'); ylabel('|X|');
title('Спектр ЛЧМ сигнала');
grid on;
xlim([-BW*2 BW*2]);

%% 8. МОДЕЛИРУЕМ РАСПРОСТРАНЕНИЕ
radarPos = [0; 0; altitude_radar];
radarVel = [0; 0; 0];
targetPos = [targetRange; 0; altitude_target];
targetVel = [0; 0; 0];

channel = phased.FreeSpace(...
    'SampleRate', Fs, ...
    'OperatingFrequency', fc, ...
    'TwoWayPropagation', true);

% Передаем два сигнала (H и V)
tx_H = x;
tx_V = x;

% Проходим канал
rx_H = channel(tx_H, radarPos, targetPos, radarVel, targetVel);
rx_V = channel(tx_V, radarPos, targetPos, radarVel, targetVel);

% Атмосферное затухание
rx_H = rx_H * sqrt(AtmosLoss_Linear);
rx_V = rx_V * sqrt(AtmosLoss_Linear);

% Потери от интерференции с землей
rx_H = rx_H * 10^(-InterferenceLoss_dB/20);
rx_V = rx_V * 10^(-InterferenceLoss_dB/20);

%% 9. ПРИМЕНЯЕМ КОМПЛЕКСНУЮ МАТРИЦУ
% rx_H_out = HH * rx_H + HV * rx_V
% rx_V_out = VH * rx_H + VV * rx_V

% Применяем матрицу рассеяния к сигналу
rx_H_target = PolarizationMatrix(1,1) * rx_H + PolarizationMatrix(1,2) * rx_V;
rx_V_target = PolarizationMatrix(2,1) * rx_H + PolarizationMatrix(2,2) * rx_V;

% Теперь сигнал после отражения от цели
rx_H = rx_H_target;
rx_V = rx_V_target;

% Применяем усиление антенны
rx_H = rx_H * Gain_Linear;
rx_V = rx_V * Gain_Linear;

% Применяем потери в тракте
rx_H = rx_H * sqrt(TotalLoss_Linear);
rx_V = rx_V * sqrt(TotalLoss_Linear);

fprintf('\nОбщие потери в среде: %.2f дБ\n', AtmosLoss_dB + InterferenceLoss_dB);

% Визуализация принятых сигналов
subplot(3,3,4);
plot((0:length(rx_H)-1)/Fs*1e6, real(rx_H), 'b', 'LineWidth', 1);
hold on;
plot((0:length(rx_V)-1)/Fs*1e6, real(rx_V), 'r', 'LineWidth', 1);
xlabel('Время (мкс)'); ylabel('Re');
title('Принятые сигналы (H - син, V - красн)');
grid on;
xlim([0 100]);
legend('H', 'V');

subplot(3,3,5);
plot((0:length(rx_H)-1)/Fs*1e6, imag(rx_H), 'b', 'LineWidth', 1);
hold on;
plot((0:length(rx_V)-1)/Fs*1e6, imag(rx_V), 'r', 'LineWidth', 1);
xlabel('Время (мкс)'); ylabel('Im');
title('Мнимые части (H - син, V - красн)');
grid on;
xlim([0 100]);
legend('H', 'V');

%% 10. СОГЛАСОВАННЫЙ ФИЛЬТР
mf = phased.MatchedFilter(...
    'Coefficients', conj(flipud(x_active)));

y_H = mf(rx_H);
y_V = mf(rx_V);

% НЕ нормируем отдельно, чтобы сохранить информацию об амплитудах
% y_H = y_H / max(abs(y_H));
% y_V = y_V / max(abs(y_V));

% Находим максимум для нормализации обоих каналов
global_max = max([max(abs(y_H)), max(abs(y_V))]);
y_H_norm = y_H / global_max;
y_V_norm = y_V / global_max;

% Визуализация выходов фильтров
subplot(3,3,6);
t_y = (0:length(y_H)-1)/Fs;
plot(t_y*1e6, abs(y_H_norm), 'b', 'LineWidth', 1.5);
hold on;
plot(t_y*1e6, abs(y_V_norm), 'r', 'LineWidth', 1.5);
xlabel('Время (мкс)'); ylabel('Амплитуда');
title('Выход согласованного фильтра (H - син, V - красн)');
grid on;
xlim([0 100]);
legend('H', 'V');

[peak_H, peak_idx_H] = max(abs(y_H));
[peak_V, peak_idx_V] = max(abs(y_V));
fprintf('Пик H: %.2f мкс, Пик V: %.2f мкс\n', t_y(peak_idx_H)*1e6, t_y(peak_idx_V)*1e6);

%% 11. ПЕРЕВОДИМ В ДАЛЬНОСТЬ
t_y_corrected = t_y - (N_active - 1)/Fs;
R_y = c * t_y_corrected / 2;

idx = find(R_y > 0);
R_y = R_y(idx);
y_H = y_H(idx);
y_V = y_V(idx);
y_H_norm = y_H_norm(idx);
y_V_norm = y_V_norm(idx);

% График в дальности
subplot(3,3,7);
plot(R_y/1000, abs(y_H_norm), 'b', 'LineWidth', 1.5);
hold on;
plot(R_y/1000, abs(y_V_norm), 'r', 'LineWidth', 1.5);
xlabel('Дальность (км)'); ylabel('Амплитуда');
title('Выход фильтра (дальность)');
grid on;
xlim([0 15]);

hold on;
xline(targetRange/1000, 'k--', 'Цель 5 км', 'LineWidth', 2);

[~, peak_idx_R_H] = max(abs(y_H));
[~, peak_idx_R_V] = max(abs(y_V));
R_peak_H = R_y(peak_idx_R_H);
R_peak_V = R_y(peak_idx_R_V);

plot(R_peak_H/1000, max(abs(y_H_norm)), 'bo', 'MarkerSize', 10, 'LineWidth', 2);
plot(R_peak_V/1000, max(abs(y_V_norm)), 'ro', 'MarkerSize', 10, 'LineWidth', 2);
legend('H', 'V', 'Цель', 'Location', 'best');

%% 12. ЛОГАРИФМИЧЕСКИЙ МАСШТАБ
subplot(3,3,8);
plot(R_y/1000, 20*log10(abs(y_H_norm)+eps), 'b', 'LineWidth', 1.5);
hold on;
plot(R_y/1000, 20*log10(abs(y_V_norm)+eps), 'r', 'LineWidth', 1.5);
xlabel('Дальность (км)'); ylabel('Амплитуда (дБ)');
title('Выход фильтра (дБ)');
grid on;
xlim([0 15]);
ylim([-60 0]);

hold on;
xline(targetRange/1000, 'k--', 'Цель 5 км', 'LineWidth', 2);
legend('H', 'V');

%% 13. ФАЗОВЫЙ ПОРТРЕТ
subplot(3,3,9);
plot(real(rx_H), imag(rx_H), 'b.', 'MarkerSize', 1);
hold on;
plot(real(rx_V), imag(rx_V), 'r.', 'MarkerSize', 1);
xlabel('I'); ylabel('Q');
title('Фазовые портреты (H - син, V - красн)');
axis equal;
grid on;
legend('H', 'V');

%% 14. УВЕЛИЧЕННЫЙ ГРАФИК
figure('Name', 'Пики на 5 км (комплексная матрица)');
plot(R_y/1000, abs(y_H_norm), 'b', 'LineWidth', 2);
hold on;
plot(R_y/1000, abs(y_V_norm), 'r', 'LineWidth', 2);
xline(targetRange/1000, 'k--', 'Цель 5 км', 'LineWidth', 2);
plot(R_peak_H/1000, max(abs(y_H_norm)), 'bo', 'MarkerSize', 15, 'LineWidth', 3);
plot(R_peak_V/1000, max(abs(y_V_norm)), 'ro', 'MarkerSize', 15, 'LineWidth', 3);
xlabel('Дальность (км)'); ylabel('Амплитуда');
title(['Комплексная матрица (фазы: HV=' num2str(phase_HV) '°, VH=' num2str(phase_VH) '°)']);
grid on;
xlim([4.5 5.5]);
ylim([0.9 1.05]);
legend('H', 'V', 'Цель', 'Пик H', 'Пик V', 'Location', 'best');

%% 15. АНАЛИЗ ПОЛЯРИЗАЦИОННЫХ ЭФФЕКТОВ
amp_H = max(abs(y_H));
amp_V = max(abs(y_V));

% Фазовая разница между каналами
phase_diff = angle(mean(y_H(peak_idx_R_H-10:peak_idx_R_H+10))) - ...
             angle(mean(y_V(peak_idx_R_V-10:peak_idx_R_V+10)));
phase_diff_deg = phase_diff * 180/pi;

fprintf('\n--- АНАЛИЗ ПОЛЯРИЗАЦИИ ---\n');
fprintf('Амплитуда H: %.3f\n', amp_H);
fprintf('Амплитуда V: %.3f\n', amp_V);
fprintf('Отношение H/V: %.2f (%.2f дБ)\n', amp_H/amp_V, 20*log10(amp_H/amp_V));
fprintf('Фазовая разница H-V: %.1f°\n', phase_diff_deg);

if abs(amp_H - amp_V) / max(amp_H, amp_V) < 0.05
    fprintf('▶ Амплитуды сбалансированы\n');
elseif amp_H > amp_V
    fprintf('▶ Доминирует H (%.1f дБ)\n', 20*log10(amp_H/amp_V));
else
    fprintf('▶ Доминирует V (%.1f дБ)\n', 20*log10(amp_V/amp_H));
end

%% 16. ВЫВОД
fprintf('\n========== РЕЗУЛЬТАТЫ ==========\n');
fprintf('Заданная дальность: %.2f м\n', targetRange);
fprintf('H-канал: дальность %.2f м\n', R_peak_H);
fprintf('V-канал: дальность %.2f м\n', R_peak_V);
fprintf('Ошибка H: %.2f м\n', abs(R_peak_H - targetRange));
fprintf('Ошибка V: %.2f м\n', abs(R_peak_V - targetRange));

if abs(R_peak_H - targetRange) < c/(2*BW) && abs(R_peak_V - targetRange) < c/(2*BW)
    fprintf('\n✅ ОБА КАНАЛА работают правильно!\n');
else
    fprintf('\n❌ ОШИБКА в одном из каналов\n');
end

%% 17. СВОДКА ПОТЕРЬ
fprintf('\n--- СВОДКА ПОТЕРЬ ---\n');
fprintf('Потери в тракте:         %.2f дБ\n', TotalLoss_dB);
fprintf('Атмосферное затухание:   %.3f дБ\n', AtmosLoss_dB);
fprintf('Интерференция с землей:  %.2f дБ\n', InterferenceLoss_dB);
fprintf('Усиление антенны:        +%.2f дБ (x2 = +%.2f дБ)\n', Gain_dBi, 2*Gain_dBi);
fprintf('ИТОГО (без усиления):    %.2f дБ\n', TotalLoss_dB + AtmosLoss_dB + InterferenceLoss_dB);