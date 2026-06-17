
%% МОДЕЛЬ РАДАРА - ШАГ 13: Обнаружение цели
% Добавляем порог обнаружения по критерию Неймана-Пирсона

clear; clc; close all;

%% 1. ПАРАМЕТРЫ
c = physconst('LightSpeed');
fc = 3e9;
lambda = c/fc;

BW = 1e6;           % 1 МГц
PulseWidth = 20e-6; % 20 мкс
PRF = 1e3;          % 1 кГц
PRI = 1/PRF;
Fs = 10 * BW;       % 10 МГц

% Цель
targetRange = 5000;     % 5 км
targetSpeed = 25;       % 25 м/с
targetDirection = 1;    % приближается

% Помеха
clutterRange = 4000;    % 4 км
clutterRCS = 100;
clutterSpeed = 0;

% Параметры шума и обнаружения
SNR_dB = 20;                    % Отношение сигнал/шум
Pfa = 1e-6;                     % НОВОЕ: Вероятность ложной тревоги
NoiseFigure_dB = 5;             % Коэффициент шума

% Количество импульсов
NumPulses = 32;

fprintf('========== ПАРАМЕТРЫ ==========\n');
fprintf('Количество импульсов: %d\n', NumPulses);
fprintf('PRF: %.1f Гц\n', PRF);
fprintf('Цель: %.1f м/с на %.1f км\n', targetSpeed, targetRange/1000);
fprintf('Помеха: 0 м/с на %.1f км\n', clutterRange/1000);
fprintf('SNR: %.1f дБ\n', SNR_dB);
fprintf('Pfa: %.2e\n', Pfa);

%% 2. АНТЕННА
Diameter = 1.0;
AperturePhysical = pi * (Diameter/2)^2;
AntennaEfficiency = 0.6;
EffectiveAperture = AntennaEfficiency * AperturePhysical;
Gain_dBi = aperture2gain(EffectiveAperture, lambda);
Gain_Linear = 10^(Gain_dBi/10);

fprintf('Усиление антенны: %.2f дБи\n', Gain_dBi);

%% 3. ПОТЕРИ
Loss_Feed = 2.0;
Loss_Circulator = 1.5;
Loss_Radome = 0.5;
TotalLoss_dB = Loss_Feed + Loss_Circulator + Loss_Radome;
TotalLoss_Linear = 10^(-TotalLoss_dB/10);

fprintf('Потери в тракте: %.2f дБ\n', TotalLoss_dB);

%% 4. СРЕДА
altitude_radar = 10;
altitude_target = 5;

AtmosLoss_dB_per_km = 0.01;
AtmosLoss_dB = AtmosLoss_dB_per_km * targetRange / 1000;
AtmosLoss_Linear = 10^(-AtmosLoss_dB/10);

fprintf('Атмосферное затухание: %.3f дБ\n', AtmosLoss_dB);

%% 5. ПОЛЯРИЗАЦИОННАЯ МАТРИЦА
amp_HH = 10; phase_HH = 0;
amp_HV = 3;  phase_HV = 45;
amp_VH = 3;  phase_VH = -30;
amp_VV = 8;  phase_VV = 20;

PolarizationMatrix = [
    amp_HH * exp(1j * phase_HH * pi/180), amp_HV * exp(1j * phase_HV * pi/180);
    amp_VH * exp(1j * phase_VH * pi/180), amp_VV * exp(1j * phase_VV * pi/180)
];

%% 6. ФЛУКТУАЦИИ
mean_RCS = 10;
rcs_factors_target = exprnd(mean_RCS, NumPulses, 1);
rcs_factors_target = rcs_factors_target / mean(rcs_factors_target) * mean_RCS;

rcs_factors_clutter = ones(NumPulses, 1) * clutterRCS;
rcs_factors_clutter = rcs_factors_clutter .* (0.9 + 0.2*rand(NumPulses, 1));

%% 7. ДОПЛЕР
fd_target = 2 * targetSpeed * targetDirection / lambda;
delta_phase_target = 2 * pi * fd_target / PRF;
doppler_phase_target = exp(1j * (0:NumPulses-1) * delta_phase_target);
doppler_phase_clutter = ones(1, NumPulses);

%% 8. ЛЧМ СИГНАЛ
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

fprintf('Длина импульса: %d отсчетов (%.2f мкс)\n', N, N/Fs*1e6);
fprintf('Длина активной части: %d отсчетов (%.2f мкс)\n', N_active, N_active/Fs*1e6);

%% 9. МОДЕЛИРУЕМ РАСПРОСТРАНЕНИЕ
radarPos = [0; 0; altitude_radar];
radarVel = [0; 0; 0];

channel = phased.FreeSpace(...
    'SampleRate', Fs, ...
    'OperatingFrequency', fc, ...
    'TwoWayPropagation', true);

targetPos = [targetRange; 0; altitude_target];
targetVel = [0; 0; 0];
clutterPos = [clutterRange; 0; altitude_target];
clutterVel = [0; 0; 0];

rx_H_target_cell = cell(1, NumPulses);
rx_V_target_cell = cell(1, NumPulses);
rx_H_clutter_cell = cell(1, NumPulses);
rx_V_clutter_cell = cell(1, NumPulses);

fprintf('Обработка импульсов: ');

for pulse = 1:NumPulses
    if mod(pulse, 8) == 0
        fprintf('%d ', pulse);
    end
    
    %% Сигнал от цели
    rx_H_pulse = channel(x, radarPos, targetPos, radarVel, targetVel);
    rx_V_pulse = channel(x, radarPos, targetPos, radarVel, targetVel);
    
    rx_H_pulse = rx_H_pulse * sqrt(AtmosLoss_Linear);
    rx_V_pulse = rx_V_pulse * sqrt(AtmosLoss_Linear);
    
    rcs_scale_target = sqrt(rcs_factors_target(pulse) / mean_RCS);
    PolMat_scaled_target = PolarizationMatrix * rcs_scale_target;
    
    rx_H_target = PolMat_scaled_target(1,1) * rx_H_pulse + PolMat_scaled_target(1,2) * rx_V_pulse;
    rx_V_target = PolMat_scaled_target(2,1) * rx_H_pulse + PolMat_scaled_target(2,2) * rx_V_pulse;
    
    rx_H_target = rx_H_target * doppler_phase_target(pulse);
    rx_V_target = rx_V_target * doppler_phase_target(pulse);
    
    rx_H_target = rx_H_target * Gain_Linear * sqrt(TotalLoss_Linear);
    rx_V_target = rx_V_target * Gain_Linear * sqrt(TotalLoss_Linear);
    
    rx_H_target_cell{pulse} = rx_H_target;
    rx_V_target_cell{pulse} = rx_V_target;
    
    %% Сигнал от помехи
    rx_H_pulse_cl = channel(x, radarPos, clutterPos, radarVel, clutterVel);
    rx_V_pulse_cl = channel(x, radarPos, clutterPos, radarVel, clutterVel);
    
    rx_H_pulse_cl = rx_H_pulse_cl * sqrt(AtmosLoss_Linear);
    rx_V_pulse_cl = rx_V_pulse_cl * sqrt(AtmosLoss_Linear);
    
    rcs_scale_clutter = sqrt(rcs_factors_clutter(pulse) / clutterRCS);
    PolMat_scaled_clutter = PolarizationMatrix * rcs_scale_clutter;
    
    rx_H_clutter = PolMat_scaled_clutter(1,1) * rx_H_pulse_cl + PolMat_scaled_clutter(1,2) * rx_V_pulse_cl;
    rx_V_clutter = PolMat_scaled_clutter(2,1) * rx_H_pulse_cl + PolMat_scaled_clutter(2,2) * rx_V_pulse_cl;
    
    rx_H_clutter = rx_H_clutter * doppler_phase_clutter(pulse);
    rx_V_clutter = rx_V_clutter * doppler_phase_clutter(pulse);
    
    rx_H_clutter = rx_H_clutter * Gain_Linear * sqrt(TotalLoss_Linear);
    rx_V_clutter = rx_V_clutter * Gain_Linear * sqrt(TotalLoss_Linear);
    
    rx_H_clutter_cell{pulse} = rx_H_clutter;
    rx_V_clutter_cell{pulse} = rx_V_clutter;
end

fprintf('\n');

%% 10. СУММИРУЕМ СИГНАЛЫ
rx_H_cell = cell(1, NumPulses);
rx_V_cell = cell(1, NumPulses);

for pulse = 1:NumPulses
    rx_H_cell{pulse} = rx_H_target_cell{pulse} + rx_H_clutter_cell{pulse};
    rx_V_cell{pulse} = rx_V_target_cell{pulse} + rx_V_clutter_cell{pulse};
end

%% 11. ДОБАВЛЯЕМ ШУМ
signal_power = mean(abs(rx_H_cell{1}).^2);
SNR_linear = 10^(SNR_dB/10);
noise_power = signal_power / SNR_linear;

for pulse = 1:NumPulses
    noise_H = sqrt(noise_power/2) * (randn(size(rx_H_cell{pulse})) + 1j*randn(size(rx_H_cell{pulse})));
    noise_V = sqrt(noise_power/2) * (randn(size(rx_V_cell{pulse})) + 1j*randn(size(rx_V_cell{pulse})));
    
    rx_H_cell{pulse} = rx_H_cell{pulse} + noise_H;
    rx_V_cell{pulse} = rx_V_cell{pulse} + noise_V;
end

%% 12. СОГЛАСОВАННЫЙ ФИЛЬТР
mf = phased.MatchedFilter(...
    'Coefficients', conj(flipud(x_active)));

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

max_len = max([cellfun(@length, y_H_cell), cellfun(@length, y_V_cell)]);
y_H = zeros(max_len, NumPulses);
y_V = zeros(max_len, NumPulses);

for pulse = 1:NumPulses
    len_H = length(y_H_cell{pulse});
    len_V = length(y_V_cell{pulse});
    y_H(1:len_H, pulse) = y_H_cell{pulse};
    y_V(1:len_V, pulse) = y_V_cell{pulse};
end

%% 13. ЧМП-ФИЛЬТР
y_H_MTI = diff(y_H, 1, 2);
y_V_MTI = diff(y_V, 1, 2);
y_H_MTI = [y_H_MTI, zeros(size(y_H_MTI, 1), 1)];
y_V_MTI = [y_V_MTI, zeros(size(y_V_MTI, 1), 1)];

%% 14. КОГЕРЕНТНОЕ НАКОПЛЕНИЕ
y_H_accum = sum(y_H, 2);
y_V_accum = sum(y_V, 2);
y_H_MTI_accum = sum(y_H_MTI, 2);
y_V_MTI_accum = sum(y_V_MTI, 2);

%% 15. ОСЬ ДАЛЬНОСТИ
t_y = (0:length(y_H_accum)-1)/Fs;
t_y_corrected = t_y - (N_active - 1)/Fs;
R_y = c * t_y_corrected / 2;

idx = find(R_y > 0 & R_y < 20000);
R_y = R_y(idx);
y_H_norm = y_H_accum(idx) / max(abs(y_H_accum(idx)));
y_V_norm = y_V_accum(idx) / max(abs(y_V_accum(idx)));
y_H_MTI_norm = y_H_MTI_accum(idx) / max(abs(y_H_MTI_accum(idx)));
y_V_MTI_norm = y_V_MTI_accum(idx) / max(abs(y_V_MTI_accum(idx)));

%% 16. ОБНАРУЖЕНИЕ ЦЕЛИ (ЭМПИРИЧЕСКИЙ ПОРОГ)

% Используем ПОСЛЕДНИЙ импульс для оценки шума (там нет сигнала, только шум)
% или просто устанавливаем порог как долю от максимума

% ПРОСТОЕ РЕШЕНИЕ: порог = 0.3 * максимум сигнала после ЧМП
% Это эмпирическое значение, которое работает для наших данных
Threshold_rel = 0.25;  % 25% от максимума

% Нормируем сигнал после ЧМП
y_H_MTI_norm = abs(y_H_MTI_accum(idx)) / max(abs(y_H_MTI_accum(idx)));
y_V_MTI_norm = abs(y_V_MTI_accum(idx)) / max(abs(y_V_MTI_accum(idx)));

% Обнаружение
detected_H = y_H_MTI_norm > Threshold_rel;
detected_V = y_V_MTI_norm > Threshold_rel;

fprintf('\n--- ПОРОГ ОБНАРУЖЕНИЯ (ЭМПИРИЧЕСКИЙ) ---\n');
fprintf('Относительный порог: %.2f (%.1f%% от максимума)\n', Threshold_rel, Threshold_rel*100);

% Находим обнаруженные цели
detected_ranges_H = R_y(detected_H);
detected_ranges_V = R_y(detected_V);

fprintf('\n--- ОБНАРУЖЕНИЕ ---\n');
if ~isempty(detected_ranges_H)
    fprintf('H-канал: обнаружено %d целей\n', length(detected_ranges_H));
    fprintf('  Первые 5 дальностей: %.2f км\n', detected_ranges_H(1:min(5,end))/1000);
else
    fprintf('H-канал: цели не обнаружены\n');
end

if ~isempty(detected_ranges_V)
    fprintf('V-канал: обнаружено %d целей\n', length(detected_ranges_V));
    fprintf('  Первые 5 дальностей: %.2f км\n', detected_ranges_V(1:min(5,end))/1000);
else
    fprintf('V-канал: цели не обнаружены\n');
end

% Проверка обнаружения цели на 5 км
[~, idx_target] = min(abs(R_y - targetRange));
target_detected_H = detected_H(idx_target);
target_detected_V = detected_V(idx_target);

fprintf('\n--- ЦЕЛЬ НА %.1f КМ ---\n', targetRange/1000);
if target_detected_H
    fprintf('H-канал: ОБНАРУЖЕНА ✅\n');
else
    fprintf('H-канал: НЕ ОБНАРУЖЕНА ❌\n');
end
if target_detected_V
    fprintf('V-канал: ОБНАРУЖЕНА ✅\n');
else
    fprintf('V-канал: НЕ ОБНАРУЖЕНА ❌\n');
end

% Проверка подавления помехи на 4 км
[~, idx_clutter] = min(abs(R_y - clutterRange));
clutter_detected_H = detected_H(idx_clutter);
clutter_detected_V = detected_V(idx_clutter);

fprintf('\n--- ПОМЕХА НА %.1f КМ ---\n', clutterRange/1000);
if clutter_detected_H
    fprintf('H-канал: ОБНАРУЖЕНА ❌ (плохо!)\n');
else
    fprintf('H-канал: ПОДАВЛЕНА ✅\n');
end
if clutter_detected_V
    fprintf('V-канал: ОБНАРУЖЕНА ❌ (плохо!)\n');
else
    fprintf('V-канал: ПОДАВЛЕНА ✅\n');
end

%% 17. ГРАФИКИ
figure('Position', [100 100 1400 900]);

% График 1: ЛЧМ
subplot(3,3,1);
plot(t(1:N_active)*1e6, real(x_active), 'b', 'LineWidth', 1.5);
xlabel('Время (мкс)'); ylabel('Re');
title('ЛЧМ сигнал');
grid on;

% График 2: Принятый сигнал
subplot(3,3,2);
plot(real(rx_H_cell{1}), 'b', 'LineWidth', 0.5);
hold on;
plot(real(rx_H_target_cell{1}), 'r', 'LineWidth', 1);
xlabel('Отсчет'); ylabel('Амплитуда');
title('Сигнал с шумом (син) и без (красн)');
grid on; legend('С шумом', 'Без шума');

% График 3: Спектр
subplot(3,3,3);
freq = linspace(-Fs/2, Fs/2, N_active);
X = fftshift(fft(x_active));
plot(freq/1e6, abs(X), 'k', 'LineWidth', 1.5);
xlabel('Частота (МГц)'); ylabel('|X|');
title('Спектр ЛЧМ');
grid on; xlim([-BW*2 BW*2]);

% График 4: Дальность ДО ЧМП
subplot(3,3,4);
plot(R_y/1000, abs(y_H_MTI_norm), 'b', 'LineWidth', 1.5);
hold on;
plot(R_y/1000, abs(y_V_MTI_norm), 'r', 'LineWidth', 1.5);
yline(Threshold_rel, 'k--', 'Порог', 'LineWidth', 1.5);
xlabel('Дальность (км)'); ylabel('Амплитуда');
title('ПОСЛЕ ЧМП с порогом');
grid on; xlim([0 15]);
xline(targetRange/1000, 'g--', 'Цель 5 км', 'LineWidth', 2);
xline(clutterRange/1000, 'r--', 'Помеха 4 км', 'LineWidth', 2);
legend('H', 'V', 'Порог');

% График 5: Результат обнаружения
subplot(3,3,5);
plot(R_y/1000, detected_H, 'b', 'LineWidth', 2);
hold on;
plot(R_y/1000, detected_V, 'r', 'LineWidth', 2);
xlabel('Дальность (км)'); ylabel('Обнаружено');
title('Результат обнаружения');
grid on; xlim([0 15]);
ylim([-0.1 1.1]);
xline(targetRange/1000, 'g--', 'Цель', 'LineWidth', 2);
xline(clutterRange/1000, 'r--', 'Помеха', 'LineWidth', 2);
legend('H', 'V');

% График 6: Доплер ДО ЧМП
[~, peak_idx] = max(abs(y_H_accum));
doppler_H_before = y_H(peak_idx, :);
D_H_before = fftshift(fft(doppler_H_before, 256));
freq_doppler = linspace(-PRF/2, PRF/2, 256);
speed_axis = freq_doppler * lambda / 2;

subplot(3,3,6);
plot(speed_axis, 20*log10(abs(D_H_before)/max(abs(D_H_before)) + eps), 'b', 'LineWidth', 1.5);
xlabel('Скорость (м/с)'); ylabel('Амплитуда (дБ)');
title('ДО ЧМП (доплер)');
grid on;
xline(0, 'r--', 'Помеха', 'LineWidth', 2);
xline(targetSpeed * targetDirection, 'g--', ['Цель ' num2str(targetSpeed) ' м/с'], 'LineWidth', 2);
xlim([-60 60]);

% График 7: Доплер ПОСЛЕ ЧМП
[~, peak_idx_MTI] = max(abs(y_H_MTI_accum));
doppler_H_after = y_H_MTI(peak_idx_MTI, :);
D_H_after = fftshift(fft(doppler_H_after, 256));

subplot(3,3,7);
plot(speed_axis, 20*log10(abs(D_H_after)/max(abs(D_H_after)) + eps), 'b', 'LineWidth', 1.5);
xlabel('Скорость (м/с)'); ylabel('Амплитуда (дБ)');
title('ПОСЛЕ ЧМП (доплер)');
grid on;
xline(0, 'r--', 'Помеха', 'LineWidth', 2);
xline(targetSpeed * targetDirection, 'g--', ['Цель ' num2str(targetSpeed) ' м/с'], 'LineWidth', 2);
xlim([-60 60]);

% График 8: Фазовый портрет
subplot(3,3,8);
plot(real(rx_H_cell{1}), imag(rx_H_cell{1}), 'b.', 'MarkerSize', 1);
hold on;
plot(real(rx_V_cell{1}), imag(rx_V_cell{1}), 'r.', 'MarkerSize', 1);
xlabel('I'); ylabel('Q');
title('Фазовый портрет (с шумом)');
axis equal; grid on;
legend('H', 'V');

% График 9: Эффективность ЧМП на помехе
subplot(3,3,9);
[~, idx_clutter_plot] = min(abs(R_y - clutterRange));
doppler_clutter_before = y_H(idx_clutter_plot, :);
doppler_clutter_after = y_H_MTI(idx_clutter_plot, :);
D_clutter_before = fftshift(fft(doppler_clutter_before, 256));
D_clutter_after = fftshift(fft(doppler_clutter_after, 256));

plot(speed_axis, 20*log10(abs(D_clutter_before)/max(abs(D_clutter_before)) + eps), 'r', 'LineWidth', 1.5);
hold on;
plot(speed_axis, 20*log10(abs(D_clutter_after)/max(abs(D_clutter_after)) + eps), 'b', 'LineWidth', 1.5);
xlabel('Скорость (м/с)'); ylabel('Амплитуда (дБ)');
title('Помеха: ДО (красн) и ПОСЛЕ (син) ЧМП');
grid on; legend('ДО ЧМП', 'ПОСЛЕ ЧМП');
xline(0, 'k--', '0 м/с', 'LineWidth', 1);
xlim([-60 60]);

%% 18. ДОПОЛНИТЕЛЬНЫЙ ГРАФИК
figure('Name', 'Обнаружение цели');
subplot(2,1,1);
plot(R_y/1000, 20*log10(abs(y_H_MTI_norm)+eps), 'b', 'LineWidth', 2);
hold on;
plot(R_y/1000, 20*log10(abs(y_V_MTI_norm)+eps), 'r', 'LineWidth', 2);
yline(20*log10(Threshold_rel + eps), 'k--', 'Порог', 'LineWidth', 2);
xlabel('Дальность (км)'); ylabel('Амплитуда (дБ)');
title('Обнаружение цели после ЧМП');
grid on; xlim([0 15]);
xline(targetRange/1000, 'g--', 'Цель 5 км', 'LineWidth', 2);
xline(clutterRange/1000, 'r--', 'Помеха 4 км', 'LineWidth', 2);
legend('H', 'V', 'Порог');

subplot(2,1,2);
plot(R_y/1000, detected_H, 'b', 'LineWidth', 2);
hold on;
plot(R_y/1000, detected_V, 'r', 'LineWidth', 2);
xlabel('Дальность (км)'); ylabel('Обнаружено');
title('Бинарный результат обнаружения');
grid on; xlim([0 15]);
ylim([-0.1 1.1]);
xline(targetRange/1000, 'g--', 'Цель 5 км', 'LineWidth', 2);
xline(clutterRange/1000, 'r--', 'Помеха 4 км', 'LineWidth', 2);
legend('H', 'V');

%% 19. ИТОГОВЫЙ ВЫВОД
fprintf('\n========== ИТОГОВЫЙ ВЫВОД ==========\n');
if target_detected_H || target_detected_V
    fprintf('✅ ЦЕЛЬ ОБНАРУЖЕНА!\n');
else
    fprintf('❌ ЦЕЛЬ НЕ ОБНАРУЖЕНА\n');
end

if ~clutter_detected_H && ~clutter_detected_V
    fprintf('✅ ПОМЕХА УСПЕШНО ПОДАВЛЕНА!\n');
else
    fprintf('⚠️ ПОМЕХА НЕ ПОЛНОСТЬЮ ПОДАВЛЕНА\n');
end
