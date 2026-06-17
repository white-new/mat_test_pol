%% МОДЕЛЬ РАДАРА - ШАГ 9: Флуктуации цели (Swerling 1) - ДИНАМИЧЕСКИЙ РАЗМЕР
% Автоматическое определение размера после фильтрации

clear; clc; close all;

%% 1. ПАРАМЕТРЫ
c = physconst('LightSpeed');
fc = 3e9;
lambda = c/fc;

BW = 1e6;           % 1 МГц
PulseWidth = 20e-6; % 20 мкс
PRF = 1e3;          % 1 кГц
PRI = 1/PRF;        % 1 мс
Fs = 10 * BW;       % 10 МГц

% Цель
targetRange = 5000; % 5 км

% Количество импульсов
NumPulses = 32;

fprintf('Количество импульсов: %d\n', NumPulses);

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

%% 5. ПОЛЯРИЗАЦИОННАЯ МАТРИЦА
amp_HH = 10; phase_HH = 0;
amp_HV = 3;  phase_HV = 45;
amp_VH = 3;  phase_VH = -30;
amp_VV = 8;  phase_VV = 20;

PolarizationMatrix = [
    amp_HH * exp(1j * phase_HH * pi/180), amp_HV * exp(1j * phase_HV * pi/180);
    amp_VH * exp(1j * phase_VH * pi/180), amp_VV * exp(1j * phase_VV * pi/180)
];

fprintf('\n--- ПОЛЯРИЗАЦИОННАЯ МАТРИЦА ---\n');
fprintf('HH = %.1f∠%.0f°  кв.м\n', amp_HH, phase_HH);
fprintf('HV = %.1f∠%.0f°  кв.м\n', amp_HV, phase_HV);
fprintf('VH = %.1f∠%.0f°  кв.м\n', amp_VH, phase_VH);
fprintf('VV = %.1f∠%.0f°  кв.м\n', amp_VV, phase_VV);

%% 6. ФЛУКТУАЦИИ ЦЕЛИ (Swerling 1)
mean_RCS = 10;
rcs_factors = exprnd(mean_RCS, NumPulses, 1);
rcs_factors = rcs_factors / mean(rcs_factors) * mean_RCS;

fprintf('\n--- ФЛУКТУАЦИИ ЦЕЛИ (Swerling 1) ---\n');
fprintf('Средняя ЭПР: %.1f кв.м\n', mean_RCS);
fprintf('Стандартное отклонение: %.2f кв.м\n', std(rcs_factors));
fprintf('Мин: %.2f, Макс: %.2f кв.м\n', min(rcs_factors), max(rcs_factors));

%% 7. СОЗДАЕМ ОДИН ЛЧМ ИМПУЛЬС
waveform = phased.LinearFMWaveform(...
    'SampleRate', Fs, ...
    'SweepBandwidth', BW, ...
    'PulseWidth', PulseWidth, ...
    'PRF', PRF, ...
    'NumPulses', 1);

x = step(waveform);
N = length(x);
t = (0:N-1)/Fs;

% Активная часть сигнала
N_active = round(PulseWidth * Fs);
x_active = x(1:N_active);

fprintf('Длина импульса: %d отсчетов (%.2f мкс)\n', N, N/Fs*1e6);
fprintf('Длина активной части: %d отсчетов (%.2f мкс)\n', N_active, N_active/Fs*1e6);

%% 8. ГРАФИК 1: ЛЧМ СИГНАЛ
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

%% 9. МОДЕЛИРУЕМ РАСПРОСТРАНЕНИЕ ДЛЯ ПАЧКИ ИМПУЛЬСОВ (ЦИКЛ)
radarPos = [0; 0; altitude_radar];
radarVel = [0; 0; 0];
targetPos = [targetRange; 0; altitude_target];
targetVel = [0; 0; 0];

channel = phased.FreeSpace(...
    'SampleRate', Fs, ...
    'OperatingFrequency', fc, ...
    'TwoWayPropagation', true);

% НОВОЕ: Динамическое выделение памяти
% Сначала создаем ячейки или используем цикл с сохранением в список
rx_H_cell = cell(1, NumPulses);
rx_V_cell = cell(1, NumPulses);

fprintf('Обработка импульсов: ');

% Цикл по импульсам
for pulse = 1:NumPulses
    % Прогресс
    if mod(pulse, 8) == 0
        fprintf('%d ', pulse);
    end
    
    % Передаем сигнал
    rx_H_pulse = channel(x, radarPos, targetPos, radarVel, targetVel);
    rx_V_pulse = channel(x, radarPos, targetPos, radarVel, targetVel);
    
    % Атмосферное затухание
    rx_H_pulse = rx_H_pulse * sqrt(AtmosLoss_Linear);
    rx_V_pulse = rx_V_pulse * sqrt(AtmosLoss_Linear);
    
    % Потери от интерференции
    rx_H_pulse = rx_H_pulse * 10^(-InterferenceLoss_dB/20);
    rx_V_pulse = rx_V_pulse * 10^(-InterferenceLoss_dB/20);
    
    % Применяем флуктуации ЭПР
    rcs_scale = sqrt(rcs_factors(pulse) / mean_RCS);
    PolMat_scaled = PolarizationMatrix * rcs_scale;
    
    % Применяем поляризационную матрицу
    rx_H_target = PolMat_scaled(1,1) * rx_H_pulse + PolMat_scaled(1,2) * rx_V_pulse;
    rx_V_target = PolMat_scaled(2,1) * rx_H_pulse + PolMat_scaled(2,2) * rx_V_pulse;
    
    % Усиление антенны и потери в тракте
    rx_H_target = rx_H_target * Gain_Linear * sqrt(TotalLoss_Linear);
    rx_V_target = rx_V_target * Gain_Linear * sqrt(TotalLoss_Linear);
    
    % Сохраняем в ячейки
    rx_H_cell{pulse} = rx_H_target;
    rx_V_cell{pulse} = rx_V_target;
end

fprintf('\nОбработано %d импульсов с флуктуациями\n', NumPulses);

% Визуализация ЭПР по импульсам
subplot(3,3,4);
plot(1:NumPulses, rcs_factors, 'ko-', 'LineWidth', 1.5);
xlabel('Номер импульса'); ylabel('ЭПР (кв.м)');
title('Флуктуации ЭПР (Swerling 1)');
grid on;

%% 10. СОГЛАСОВАННЫЙ ФИЛЬТР (С ДИНАМИЧЕСКИМ РАЗМЕРОМ)
mf = phased.MatchedFilter(...
    'Coefficients', conj(flipud(x_active)));

% НОВОЕ: Используем ячейки для хранения результатов фильтрации
y_H_cell = cell(1, NumPulses);
y_V_cell = cell(1, NumPulses);

fprintf('Согласованная фильтрация: ');
for pulse = 1:NumPulses
    if mod(pulse, 8) == 0
        fprintf('%d ', pulse);
    end
    y_H_cell{pulse} = mf(rx_H_cell{pulse});
    y_V_cell{pulse} = mf(rx_V_cell{pulse});
end
fprintf('\n');

% Находим максимальную длину после фильтрации
max_len_H = max(cellfun(@length, y_H_cell));
max_len_V = max(cellfun(@length, y_V_cell));
max_len = max(max_len_H, max_len_V);

fprintf('Максимальная длина после фильтрации: %d\n', max_len);

% Приводим все к одинаковой длине (дополняем нулями)
y_H = zeros(max_len, NumPulses);
y_V = zeros(max_len, NumPulses);

for pulse = 1:NumPulses
    len_H = length(y_H_cell{pulse});
    len_V = length(y_V_cell{pulse});
    y_H(1:len_H, pulse) = y_H_cell{pulse};
    y_V(1:len_V, pulse) = y_V_cell{pulse};
end

%% 11. КОГЕРЕНТНОЕ НАКОПЛЕНИЕ
y_H_accum = sum(y_H, 2);
y_V_accum = sum(y_V, 2);

% Нормируем
global_max = max([max(abs(y_H_accum)), max(abs(y_V_accum))]);
y_H_norm = y_H_accum / global_max;
y_V_norm = y_V_accum / global_max;

% Визуализация выходов фильтров
subplot(3,3,5);
t_y = (0:length(y_H_accum)-1)/Fs;
plot(t_y*1e6, abs(y_H_norm), 'b', 'LineWidth', 1.5);
hold on;
plot(t_y*1e6, abs(y_V_norm), 'r', 'LineWidth', 1.5);
xlabel('Время (мкс)'); ylabel('Амплитуда');
title('Выход фильтра (с накоплением)');
grid on;
xlim([0 100]);
legend('H', 'V');

%% 12. ПЕРЕВОДИМ В ДАЛЬНОСТЬ
t_y_corrected = t_y - (N_active - 1)/Fs;
R_y = c * t_y_corrected / 2;

idx = find(R_y > 0 & R_y < 20000);
R_y = R_y(idx);
y_H_norm = y_H_norm(idx);
y_V_norm = y_V_norm(idx);

% График в дальности
subplot(3,3,6);
plot(R_y/1000, abs(y_H_norm), 'b', 'LineWidth', 1.5);
hold on;
plot(R_y/1000, abs(y_V_norm), 'r', 'LineWidth', 1.5);
xlabel('Дальность (км)'); ylabel('Амплитуда');
title('Выход фильтра (дальность)');
grid on;
xlim([0 15]);

hold on;
xline(targetRange/1000, 'k--', 'Цель 5 км', 'LineWidth', 2);

[~, peak_idx_R_H] = max(abs(y_H_norm));
[~, peak_idx_R_V] = max(abs(y_V_norm));
R_peak_H = R_y(peak_idx_R_H);
R_peak_V = R_y(peak_idx_R_V);

plot(R_peak_H/1000, max(abs(y_H_norm)), 'bo', 'MarkerSize', 10, 'LineWidth', 2);
plot(R_peak_V/1000, max(abs(y_V_norm)), 'ro', 'MarkerSize', 10, 'LineWidth', 2);
legend('H', 'V', 'Цель', 'Location', 'best');

%% 13. ЛОГАРИФМИЧЕСКИЙ МАСШТАБ
subplot(3,3,7);
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

%% 14. ДОПЛЕРОВСКАЯ ОБРАБОТКА
% Берем пиковый отсчет по дальности
[~, peak_idx] = max(abs(y_H_accum));
peak_sample = peak_idx;

% Извлекаем сигналы на пиковой дальности по всем импульсам
doppler_H = y_H(peak_sample, :);
doppler_V = y_V(peak_sample, :);

% БПФ для доплеровского спектра
Nfft = 256;
D_H = fftshift(fft(doppler_H, Nfft));
D_V = fftshift(fft(doppler_V, Nfft));

% Доплеровская ось
freq_doppler = linspace(-PRF/2, PRF/2, Nfft);
speed_axis = freq_doppler * lambda / 2;

subplot(3,3,8);
plot(speed_axis, 20*log10(abs(D_H)/max(abs(D_H)) + eps), 'b', 'LineWidth', 1.5);
hold on;
plot(speed_axis, 20*log10(abs(D_V)/max(abs(D_V)) + eps), 'r', 'LineWidth', 1.5);
xlabel('Скорость (м/с)'); ylabel('Амплитуда (дБ)');
title('Доплеровский спектр');
grid on;
legend('H', 'V');
xlim([-50 50]);

%% 15. ФАЗОВЫЙ ПОРТРЕТ (первый импульс)
subplot(3,3,9);
plot(real(rx_H_cell{1}), imag(rx_H_cell{1}), 'b.', 'MarkerSize', 1);
hold on;
plot(real(rx_V_cell{1}), imag(rx_V_cell{1}), 'r.', 'MarkerSize', 1);
xlabel('I'); ylabel('Q');
title('Фазовые портреты (1-й импульс)');
axis equal;
grid on;
legend('H', 'V');

%% 16. ДОПОЛНИТЕЛЬНЫЙ ГРАФИК
figure('Name', 'Пики с флуктуациями');
plot(R_y/1000, abs(y_H_norm), 'b', 'LineWidth', 2);
hold on;
plot(R_y/1000, abs(y_V_norm), 'r', 'LineWidth', 2);
xline(targetRange/1000, 'k--', 'Цель 5 км', 'LineWidth', 2);
plot(R_peak_H/1000, max(abs(y_H_norm)), 'bo', 'MarkerSize', 15, 'LineWidth', 3);
plot(R_peak_V/1000, max(abs(y_V_norm)), 'ro', 'MarkerSize', 15, 'LineWidth', 3);
xlabel('Дальность (км)'); ylabel('Амплитуда');
title(['Флуктуации цели (Swerling 1), ' num2str(NumPulses) ' импульсов']);
grid on;
xlim([4.5 5.5]);
ylim([0 1.05]);
legend('H', 'V', 'Цель', 'Пик H', 'Пик V', 'Location', 'best');

%% 17. АНАЛИЗ
amp_H = max(abs(y_H_accum));
amp_V = max(abs(y_V_accum));

fprintf('\n--- АНАЛИЗ ---\n');
fprintf('Амплитуда H (с накоплением): %.3f\n', amp_H);
fprintf('Амплитуда V (с накоплением): %.3f\n', amp_V);
fprintf('Отношение H/V: %.2f (%.2f дБ)\n', amp_H/amp_V, 20*log10(amp_H/amp_V));
fprintf('Выигрыш от когерентного накопления: %.1f дБ\n', 10*log10(NumPulses));

%% 18. ВЫВОД
fprintf('\n========== РЕЗУЛЬТАТЫ ==========\n');
fprintf('Заданная дальность: %.2f м\n', targetRange);
fprintf('H-канал: дальность %.2f м\n', R_peak_H);
fprintf('V-канал: дальность %.2f м\n', R_peak_V);
fprintf('Ошибка H: %.2f м\n', abs(R_peak_H - targetRange));
fprintf('Ошибка V: %.2f м\n', abs(R_peak_V - targetRange));
fprintf('Количество импульсов: %d\n', NumPulses);

if abs(R_peak_H - targetRange) < c/(2*BW) && abs(R_peak_V - targetRange) < c/(2*BW)
    fprintf('\n✅ ОБА КАНАЛА работают правильно!\n');
else
    fprintf('\n❌ ОШИБКА в одном из каналов\n');
end