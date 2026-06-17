%% =========================================================================
%  МОДЕЛЬ РАДАРА С ДВУМЯ ПОЛЯРИЗАЦИЯМИ
%  =========================================================================
%  
%  Описание:
%  --------
%  Модель моностатического радара с импульсным ЛЧМ сигналом,
%  двумя поляризациями (H/V), учетом потерь, помех, шума,
%  доплеровской обработкой и автоматическим обнаружением.
%
%  Основные этапы:
%  1. Формирование ЛЧМ сигнала с двумя поляризациями
%  2. Моделирование распространения (цель + помеха + шум)
%  3. Согласованная фильтрация и сжатие импульса
%  4. ЧМП-фильтр (подавление неподвижных помех)
%  5. Когерентное накопление пачки импульсов
%  6. Доплеровская обработка (измерение скорости)
%  7. Обнаружение цели по порогу
%
%  Версия: 2.0 (рефакторинг)
%  Дата:   2024
%  =========================================================================

clear; clc; close all;

%% =========================================================================
%  1. КОНФИГУРАЦИЯ МОДЕЛИ
%  =========================================================================

% --- 1.1. Параметры радара ---
cfg.fc = 3e9;                   % Несущая частота, Гц
cfg.BW = 1e6;                   % Полоса ЛЧМ, Гц
cfg.PulseWidth = 20e-6;         % Длительность импульса, с
cfg.PRF = 1e3;                  % Частота повторения импульсов, Гц
cfg.Fs = 10 * cfg.BW;           % Частота дискретизации, Гц
cfg.NumPulses = 32;             % Количество импульсов в пачке

% --- 1.2. Параметры антенны ---
cfg.Diameter = 1.0;             % Диаметр зеркала, м
cfg.AntennaEfficiency = 0.6;    % КПД антенны (0-1)

% --- 1.3. Параметры цели ---
cfg.targetRange = 5000;         % Дальность до цели, м
cfg.targetSpeed = 25;           % Скорость цели, м/с
cfg.targetDirection = 1;        % 1 - приближается, -1 - удаляется
cfg.targetRCS = 10;             % ЭПР цели, кв.м

% --- 1.4. Параметры помехи ---
cfg.clutterRange = 4000;        % Дальность до помехи, м
cfg.clutterRCS = 100;           % ЭПР помехи, кв.м
cfg.clutterSpeed = 0;           % Скорость помехи, м/с

% --- 1.5. Параметры обработки ---
cfg.SNR_dB = 20;                % Отношение сигнал/шум, дБ
cfg.Pfa = 1e-6;                 % Вероятность ложной тревоги
cfg.NoiseFigure_dB = 5;         % Коэффициент шума приемника, дБ
cfg.Threshold_rel = 0.25;       % Относительный порог (0-1)

% --- 1.6. Производные параметры ---
cfg.PRI = 1 / cfg.PRF;          % Период повторения, с
cfg.lambda = 3e8 / cfg.fc;      % Длина волны, м
cfg.N_active = round(cfg.PulseWidth * cfg.Fs);  % Длина активной части

fprintf('\n========================================\n');
fprintf('МОДЕЛЬ РАДАРА\n');
fprintf('========================================\n');
fprintf('Несущая частота:  %.2f ГГц\n', cfg.fc/1e9);
fprintf('Полоса сигнала:   %.2f МГц\n', cfg.BW/1e6);
fprintf('Длительность:     %.2f мкс\n', cfg.PulseWidth*1e6);
fprintf('PRF:              %.1f Гц\n', cfg.PRF);
fprintf('Импульсов:        %d\n', cfg.NumPulses);
fprintf('Цель:             %.1f км, %.1f м/с\n', ...
        cfg.targetRange/1000, cfg.targetSpeed);
fprintf('Помеха:           %.1f км, %.1f м/с\n', ...
        cfg.clutterRange/1000, cfg.clutterSpeed);
fprintf('SNR:              %.1f дБ\n', cfg.SNR_dB);
fprintf('Pfa:              %.2e\n', cfg.Pfa);
fprintf('========================================\n');

%% =========================================================================
%  2. ИНИЦИАЛИЗАЦИЯ
%  =========================================================================

% --- 2.1. Антенна ---
AperturePhysical = pi * (cfg.Diameter/2)^2;
EffectiveAperture = cfg.AntennaEfficiency * AperturePhysical;
cfg.Gain_dBi = aperture2gain(EffectiveAperture, cfg.lambda);
cfg.Gain_Linear = 10^(cfg.Gain_dBi/10);

% --- 2.2. Потери ---
Loss_Feed = 2.0;        % дБ
Loss_Circulator = 1.5;  % дБ
Loss_Radome = 0.5;      % дБ
cfg.TotalLoss_dB = Loss_Feed + Loss_Circulator + Loss_Radome;
cfg.TotalLoss_Linear = 10^(-cfg.TotalLoss_dB/10);

% --- 2.3. Среда распространения ---
altitude_radar = 10;
altitude_target = 5;

AtmosLoss_dB_per_km = 0.01;
cfg.AtmosLoss_dB = AtmosLoss_dB_per_km * cfg.targetRange / 1000;
cfg.AtmosLoss_Linear = 10^(-cfg.AtmosLoss_dB/10);

% --- 2.4. Поляризационная матрица цели ---
amp_HH = 10; phase_HH = 0;
amp_HV = 3;  phase_HV = 45;
amp_VH = 3;  phase_VH = -30;
amp_VV = 8;  phase_VV = 20;

cfg.PolarizationMatrix = [
    amp_HH * exp(1j * phase_HH * pi/180), amp_HV * exp(1j * phase_HV * pi/180);
    amp_VH * exp(1j * phase_VH * pi/180), amp_VV * exp(1j * phase_VV * pi/180)
];

fprintf('\nИнициализация завершена\n');

%% =========================================================================
%  3. ФОРМИРОВАНИЕ СИГНАЛА
%  =========================================================================

% --- 3.1. Создание ЛЧМ сигнала ---
waveform = phased.LinearFMWaveform(...
    'SampleRate', cfg.Fs, ...
    'SweepBandwidth', cfg.BW, ...
    'PulseWidth', cfg.PulseWidth, ...
    'PRF', cfg.PRF, ...
    'NumPulses', 1);

x = step(waveform);
N = length(x);
t = (0:N-1)/cfg.Fs;
x_active = x(1:cfg.N_active);

fprintf('Длина импульса: %d отсчетов\n', N);
fprintf('Активная часть: %d отсчетов\n', cfg.N_active);

%% =========================================================================
%  4. МОДЕЛИРОВАНИЕ СИГНАЛА
%  =========================================================================

% --- 4.1. Инициализация канала ---
radarPos = [0; 0; altitude_radar];
radarVel = [0; 0; 0];

channel = phased.FreeSpace(...
    'SampleRate', cfg.Fs, ...
    'OperatingFrequency', cfg.fc, ...
    'TwoWayPropagation', true);

targetPos = [cfg.targetRange; 0; altitude_target];
targetVel = [0; 0; 0];
clutterPos = [cfg.clutterRange; 0; altitude_target];
clutterVel = [0; 0; 0];

% --- 4.2. Доплеровский сдвиг ---
fd_target = 2 * cfg.targetSpeed * cfg.targetDirection / cfg.lambda;
delta_phase = 2 * pi * fd_target / cfg.PRF;
doppler_phase = exp(1j * (0:cfg.NumPulses-1) * delta_phase);

% --- 4.3. Генерация флуктуаций ---
mean_RCS = 10;
rcs_target = exprnd(mean_RCS, cfg.NumPulses, 1);
rcs_target = rcs_target / mean(rcs_target) * mean_RCS;

rcs_clutter = ones(cfg.NumPulses, 1) * cfg.clutterRCS;
rcs_clutter = rcs_clutter .* (0.9 + 0.2*rand(cfg.NumPulses, 1));

% --- 4.4. Основной цикл моделирования ---
fprintf('Моделирование сигнала: ');

rx_H_cell = cell(1, cfg.NumPulses);
rx_V_cell = cell(1, cfg.NumPulses);

for pulse = 1:cfg.NumPulses
    if mod(pulse, 8) == 0
        fprintf('%d ', pulse);
    end
    
    % === Сигнал от цели ===
    rx_H_pulse = channel(x, radarPos, targetPos, radarVel, targetVel);
    rx_V_pulse = channel(x, radarPos, targetPos, radarVel, targetVel);
    
    % Потери
    rx_H_pulse = rx_H_pulse * sqrt(cfg.AtmosLoss_Linear);
    rx_V_pulse = rx_V_pulse * sqrt(cfg.AtmosLoss_Linear);
    
    % Поляризация и ЭПР
    rcs_scale = sqrt(rcs_target(pulse) / mean_RCS);
    PolMat = cfg.PolarizationMatrix * rcs_scale;
    
    rx_H_target = PolMat(1,1) * rx_H_pulse + PolMat(1,2) * rx_V_pulse;
    rx_V_target = PolMat(2,1) * rx_H_pulse + PolMat(2,2) * rx_V_pulse;
    
    % Доплер
    rx_H_target = rx_H_target * doppler_phase(pulse);
    rx_V_target = rx_V_target * doppler_phase(pulse);
    
    % Усиление антенны
    rx_H_target = rx_H_target * cfg.Gain_Linear * sqrt(cfg.TotalLoss_Linear);
    rx_V_target = rx_V_target * cfg.Gain_Linear * sqrt(cfg.TotalLoss_Linear);
    
    % === Сигнал от помехи ===
    rx_H_pulse = channel(x, radarPos, clutterPos, radarVel, clutterVel);
    rx_V_pulse = channel(x, radarPos, clutterPos, radarVel, clutterVel);
    
    rx_H_pulse = rx_H_pulse * sqrt(cfg.AtmosLoss_Linear);
    rx_V_pulse = rx_V_pulse * sqrt(cfg.AtmosLoss_Linear);
    
    rcs_scale = sqrt(rcs_clutter(pulse) / cfg.clutterRCS);
    PolMat = cfg.PolarizationMatrix * rcs_scale;
    
    rx_H_clutter = PolMat(1,1) * rx_H_pulse + PolMat(1,2) * rx_V_pulse;
    rx_V_clutter = PolMat(2,1) * rx_H_pulse + PolMat(2,2) * rx_V_pulse;
    
    rx_H_clutter = rx_H_clutter * cfg.Gain_Linear * sqrt(cfg.TotalLoss_Linear);
    rx_V_clutter = rx_V_clutter * cfg.Gain_Linear * sqrt(cfg.TotalLoss_Linear);
    
    % === Суммарный сигнал ===
    rx_H_cell{pulse} = rx_H_target + rx_H_clutter;
    rx_V_cell{pulse} = rx_V_target + rx_V_clutter;
end

fprintf('\n');

%% =========================================================================
%  5. ДОБАВЛЕНИЕ ШУМА
%  =========================================================================

signal_power = mean(abs(rx_H_cell{1}).^2);
SNR_linear = 10^(cfg.SNR_dB/10);
noise_power = signal_power / SNR_linear;

for pulse = 1:cfg.NumPulses
    noise_H = sqrt(noise_power/2) * (randn(size(rx_H_cell{pulse})) + 1j*randn(size(rx_H_cell{pulse})));
    noise_V = sqrt(noise_power/2) * (randn(size(rx_V_cell{pulse})) + 1j*randn(size(rx_V_cell{pulse})));
    
    rx_H_cell{pulse} = rx_H_cell{pulse} + noise_H;
    rx_V_cell{pulse} = rx_V_cell{pulse} + noise_V;
end

fprintf('Шум добавлен (SNR = %.1f дБ)\n', cfg.SNR_dB);

%% =========================================================================
%  6. ОБРАБОТКА СИГНАЛА
%  =========================================================================

% --- 6.1. Согласованный фильтр ---
mf = phased.MatchedFilter('Coefficients', conj(flipud(x_active)));

fprintf('Согласованная фильтрация: ');
y_H_cell = cell(1, cfg.NumPulses);
y_V_cell = cell(1, cfg.NumPulses);

for pulse = 1:cfg.NumPulses
    if mod(pulse, 8) == 0
        fprintf('%d ', pulse);
    end
    y_H_cell{pulse} = mf(rx_H_cell{pulse});
    y_V_cell{pulse} = mf(rx_V_cell{pulse});
end
fprintf('\n');

% Приведение к единой длине
max_len = max([cellfun(@length, y_H_cell), cellfun(@length, y_V_cell)]);
y_H = zeros(max_len, cfg.NumPulses);
y_V = zeros(max_len, cfg.NumPulses);

for pulse = 1:cfg.NumPulses
    len_H = length(y_H_cell{pulse});
    len_V = length(y_V_cell{pulse});
    y_H(1:len_H, pulse) = y_H_cell{pulse};
    y_V(1:len_V, pulse) = y_V_cell{pulse};
end

% --- 6.2. ЧМП-фильтр ---
y_H_MTI = diff(y_H, 1, 2);
y_V_MTI = diff(y_V, 1, 2);
y_H_MTI = [y_H_MTI, zeros(size(y_H_MTI, 1), 1)];
y_V_MTI = [y_V_MTI, zeros(size(y_V_MTI, 1), 1)];

fprintf('ЧМП-фильтр применен\n');

% --- 6.3. Когерентное накопление ---
y_H_accum = sum(y_H, 2);
y_V_accum = sum(y_V, 2);
y_H_MTI_accum = sum(y_H_MTI, 2);
y_V_MTI_accum = sum(y_V_MTI, 2);

%% =========================================================================
%  7. ОСЬ ДАЛЬНОСТИ
%  =========================================================================

t_y = (0:length(y_H_accum)-1)/cfg.Fs;
t_y_corrected = t_y - (cfg.N_active - 1)/cfg.Fs;
R_y = 3e8 * t_y_corrected / 2;

idx = find(R_y > 0 & R_y < 20000);
R_y = R_y(idx);
y_H_norm = y_H_accum(idx) / max(abs(y_H_accum(idx)));
y_V_norm = y_V_accum(idx) / max(abs(y_V_accum(idx)));
y_H_MTI_norm = abs(y_H_MTI_accum(idx)) / max(abs(y_H_MTI_accum(idx)));
y_V_MTI_norm = abs(y_V_MTI_accum(idx)) / max(abs(y_V_MTI_accum(idx)));

%% =========================================================================
%  8. ОБНАРУЖЕНИЕ
%  =========================================================================

detected_H = y_H_MTI_norm > cfg.Threshold_rel;
detected_V = y_V_MTI_norm > cfg.Threshold_rel;

[~, idx_target] = min(abs(R_y - cfg.targetRange));
[~, idx_clutter] = min(abs(R_y - cfg.clutterRange));

target_detected_H = detected_H(idx_target);
target_detected_V = detected_V(idx_target);
clutter_detected_H = detected_H(idx_clutter);
clutter_detected_V = detected_V(idx_clutter);

fprintf('\n--- ОБНАРУЖЕНИЕ ---\n');
fprintf('Цель на %.1f км: H-%s, V-%s\n', cfg.targetRange/1000, ...
        iif(target_detected_H, '✅', '❌'), ...
        iif(target_detected_V, '✅', '❌'));
fprintf('Помеха на %.1f км: H-%s, V-%s\n', cfg.clutterRange/1000, ...
        iif(~clutter_detected_H, '✅ подавлена', '❌'), ...
        iif(~clutter_detected_V, '✅ подавлена', '❌'));

%% =========================================================================
%  9. ВИЗУАЛИЗАЦИЯ
%  =========================================================================

% --- 9.1. Основной figure ---
figure('Name', 'Радарная обработка', 'Position', [50 50 1400 900]);

% График 1: ЛЧМ сигнал
subplot(3,3,1);
plot(t(1:cfg.N_active)*1e6, real(x_active), 'b', 'LineWidth', 1.5);
xlabel('Время (мкс)'); ylabel('Амплитуда');
title('ЛЧМ сигнал');
grid on;

% График 2: Принятый сигнал (с шумом)
% ИСПРАВЛЕНО: используем rx_H_cell{1} для сигнала с шумом
subplot(3,3,2);
plot(real(rx_H_cell{1}), 'b', 'LineWidth', 0.5);
hold on;
% Для сигнала без шума используем разность: сигнал с шумом минус шум
% Но проще просто показать сигнал с шумом
xlabel('Отсчет'); ylabel('Амплитуда');
title('Принятый сигнал с шумом (H-канал)');
grid on; legend('С шумом', 'Location', 'best');

% График 3: Спектр
subplot(3,3,3);
freq = linspace(-cfg.Fs/2, cfg.Fs/2, cfg.N_active);
X = fftshift(fft(x_active));
plot(freq/1e6, abs(X), 'k', 'LineWidth', 1.5);
xlabel('Частота (МГц)'); ylabel('|X|');
title('Спектр ЛЧМ');
grid on; xlim([-cfg.BW*2 cfg.BW*2]);

% График 4: После ЧМП с порогом
subplot(3,3,4);
plot(R_y/1000, y_H_MTI_norm, 'b', 'LineWidth', 1.5);
hold on;
plot(R_y/1000, y_V_MTI_norm, 'r', 'LineWidth', 1.5);
yline(cfg.Threshold_rel, 'k--', 'Порог', 'LineWidth', 1.5);
xlabel('Дальность (км)'); ylabel('Амплитуда');
title('После ЧМП с порогом');
grid on; xlim([0 15]);
xline(cfg.targetRange/1000, 'g--', 'Цель', 'LineWidth', 2);
xline(cfg.clutterRange/1000, 'r--', 'Помеха', 'LineWidth', 2);
legend('H', 'V', 'Порог', 'Location', 'best');

% График 5: Результат обнаружения
subplot(3,3,5);
plot(R_y/1000, detected_H, 'b', 'LineWidth', 2);
hold on;
plot(R_y/1000, detected_V, 'r', 'LineWidth', 2);
xlabel('Дальность (км)'); ylabel('Обнаружено');
title('Обнаружение цели');
grid on; xlim([0 15]); ylim([-0.1 1.1]);
xline(cfg.targetRange/1000, 'g--', 'Цель', 'LineWidth', 2);
xline(cfg.clutterRange/1000, 'r--', 'Помеха', 'LineWidth', 2);
legend('H', 'V', 'Location', 'best');

% График 6: Доплер ДО ЧМП
[~, peak_idx] = max(abs(y_H_accum));
doppler_H = y_H(peak_idx, :);
D_H = fftshift(fft(doppler_H, 256));
freq_dop = linspace(-cfg.PRF/2, cfg.PRF/2, 256);
speed_axis = freq_dop * cfg.lambda / 2;

subplot(3,3,6);
plot(speed_axis, 20*log10(abs(D_H)/max(abs(D_H)) + eps), 'b', 'LineWidth', 1.5);
xlabel('Скорость (м/с)'); ylabel('Амплитуда (дБ)');
title('Доплер ДО ЧМП');
grid on;
xline(0, 'r--', 'Помеха', 'LineWidth', 2);
xline(cfg.targetSpeed * cfg.targetDirection, 'g--', ...
      ['Цель ' num2str(cfg.targetSpeed) ' м/с'], 'LineWidth', 2);
xlim([-60 60]);

% График 7: Доплер ПОСЛЕ ЧМП
[~, peak_idx_MTI] = max(abs(y_H_MTI_accum));
doppler_H_MTI = y_H_MTI(peak_idx_MTI, :);
D_H_MTI = fftshift(fft(doppler_H_MTI, 256));

subplot(3,3,7);
plot(speed_axis, 20*log10(abs(D_H_MTI)/max(abs(D_H_MTI)) + eps), 'b', 'LineWidth', 1.5);
xlabel('Скорость (м/с)'); ylabel('Амплитуда (дБ)');
title('Доплер ПОСЛЕ ЧМП');
grid on;
xline(0, 'r--', 'Помеха', 'LineWidth', 2);
xline(cfg.targetSpeed * cfg.targetDirection, 'g--', ...
      ['Цель ' num2str(cfg.targetSpeed) ' м/с'], 'LineWidth', 2);
xlim([-60 60]);

% График 8: Фазовый портрет (первый импульс)
subplot(3,3,8);
plot(real(rx_H_cell{1}), imag(rx_H_cell{1}), 'b.', 'MarkerSize', 1);
hold on;
plot(real(rx_V_cell{1}), imag(rx_V_cell{1}), 'r.', 'MarkerSize', 1);
xlabel('I'); ylabel('Q');
title('Фазовый портрет (1-й импульс)');
axis equal; grid on;
legend('H', 'V', 'Location', 'best');

% График 9: Эффективность ЧМП на помехе
subplot(3,3,9);
doppler_clutter = y_H(idx_clutter, :);
doppler_clutter_MTI = y_H_MTI(idx_clutter, :);
D_clutter = fftshift(fft(doppler_clutter, 256));
D_clutter_MTI = fftshift(fft(doppler_clutter_MTI, 256));

plot(speed_axis, 20*log10(abs(D_clutter)/max(abs(D_clutter)) + eps), 'r', 'LineWidth', 1.5);
hold on;
plot(speed_axis, 20*log10(abs(D_clutter_MTI)/max(abs(D_clutter_MTI)) + eps), 'b', 'LineWidth', 1.5);
xlabel('Скорость (м/с)'); ylabel('Амплитуда (дБ)');
title('Помеха: ДО (красн) и ПОСЛЕ (син) ЧМП');
grid on; legend('ДО ЧМП', 'ПОСЛЕ ЧМП', 'Location', 'best');
xline(0, 'k--', '0 м/с', 'LineWidth', 1);
xlim([-60 60]);

%% =========================================================================
%  10. ФИНАЛЬНЫЙ ВЫВОД
%  =========================================================================

fprintf('\n========================================\n');
fprintf('РЕЗУЛЬТАТЫ ОБРАБОТКИ\n');
fprintf('========================================\n');
fprintf('Цель:   %.1f км, %.1f м/с -> %s\n', ...
        cfg.targetRange/1000, cfg.targetSpeed, ...
        iif(target_detected_H || target_detected_V, 'ОБНАРУЖЕНА ✅', 'НЕ ОБНАРУЖЕНА ❌'));
fprintf('Помеха: %.1f км, %.1f м/с -> %s\n', ...
        cfg.clutterRange/1000, cfg.clutterSpeed, ...
        iif(~clutter_detected_H && ~clutter_detected_V, 'ПОДАВЛЕНА ✅', 'НЕ ПОДАВЛЕНА ❌'));
fprintf('========================================\n');

%% =========================================================================
%  11. ДОПОЛНИТЕЛЬНЫЙ ГРАФИК: АНАЛИЗ SNR
%  =========================================================================

figure('Name', 'Анализ SNR');
subplot(2,1,1);
plot(R_y/1000, 20*log10(y_H_MTI_norm + eps), 'b', 'LineWidth', 2);
hold on;
plot(R_y/1000, 20*log10(y_V_MTI_norm + eps), 'r', 'LineWidth', 2);
yline(20*log10(cfg.Threshold_rel + eps), 'k--', 'Порог', 'LineWidth', 2);
xlabel('Дальность (км)'); ylabel('Амплитуда (дБ)');
title('Уровень сигнала и порог');
grid on; xlim([0 15]);
xline(cfg.targetRange/1000, 'g--', 'Цель', 'LineWidth', 2);
xline(cfg.clutterRange/1000, 'r--', 'Помеха', 'LineWidth', 2);
legend('H', 'V', 'Порог', 'Location', 'best');

subplot(2,1,2);
plot(R_y/1000, detected_H, 'b', 'LineWidth', 2);
hold on;
plot(R_y/1000, detected_V, 'r', 'LineWidth', 2);
xlabel('Дальность (км)'); ylabel('Обнаружено');
title('Результат обнаружения');
grid on; xlim([0 15]); ylim([-0.1 1.1]);
xline(cfg.targetRange/1000, 'g--', 'Цель', 'LineWidth', 2);
xline(cfg.clutterRange/1000, 'r--', 'Помеха', 'LineWidth', 2);
legend('H', 'V', 'Location', 'best');

%% =========================================================================
%  12. ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
%  =========================================================================

function out = iif(cond, t, f)
    % Условный оператор (тернарный)
    if cond, out = t; else, out = f; end
end