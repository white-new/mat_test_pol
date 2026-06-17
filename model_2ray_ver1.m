%% МОДЕЛЬ РАДАРА - ШАГ 11: Пассивные помехи на другой дальности
% Помеха на 4 км, цель на 5 км - наглядно видно подавление

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
targetRange = 5000;     % Дальность 5 км
targetSpeed = 25;       % 25 м/с
targetDirection = 1;    % приближается

% НОВОЕ: Помеха на другой дальности
clutterRange = 4000;    % Помеха на 4 км (отдельно от цели)
clutterRCS = 100;       % ЭПР помехи
clutterSpeed = 0;       % Неподвижная

% Количество импульсов
NumPulses = 32;

fprintf('Количество импульсов: %d\n', NumPulses);
fprintf('PRF: %.1f Гц\n', PRF);
fprintf('Цель: %.1f м/с на %.1f км\n', targetSpeed, targetRange/1000);
fprintf('Помеха: 0 м/с на %.1f км (ЭПР в %.1f раз больше цели)\n', ...
        clutterRange/1000, clutterRCS/10);

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

%% 9. ГРАФИКИ
figure('Position', [100 100 1400 900]);

subplot(3,3,1);
plot(t(1:N_active)*1e6, real(x_active), 'b', 'LineWidth', 1.5);
xlabel('Время (мкс)'); ylabel('Re');
title('ЛЧМ сигнал');
grid on;

subplot(3,3,2);
plot(t(1:N_active)*1e6, imag(x_active), 'r', 'LineWidth', 1.5);
xlabel('Время (мкс)'); ylabel('Im');
title('ЛЧМ сигнал (мнимая)');
grid on;

subplot(3,3,3);
freq = linspace(-Fs/2, Fs/2, N_active);
X = fftshift(fft(x_active));
plot(freq/1e6, abs(X), 'k', 'LineWidth', 1.5);
xlabel('Частота (МГц)'); ylabel('|X|');
title('Спектр ЛЧМ');
grid on;
xlim([-BW*2 BW*2]);

%% 10. МОДЕЛИРУЕМ РАСПРОСТРАНЕНИЕ
radarPos = [0; 0; altitude_radar];
radarVel = [0; 0; 0];

channel = phased.FreeSpace(...
    'SampleRate', Fs, ...
    'OperatingFrequency', fc, ...
    'TwoWayPropagation', true);

% Цель
targetPos = [targetRange; 0; altitude_target];
targetVel = [0; 0; 0];

% Помеха (на другой дальности)
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
    
    %% СИГНАЛ ОТ ЦЕЛИ
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
    
    %% СИГНАЛ ОТ ПОМЕХИ
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

%% 11. СУММИРУЕМ
rx_H_cell = cell(1, NumPulses);
rx_V_cell = cell(1, NumPulses);

for pulse = 1:NumPulses
    rx_H_cell{pulse} = rx_H_target_cell{pulse} + rx_H_clutter_cell{pulse};
    rx_V_cell{pulse} = rx_V_target_cell{pulse} + rx_V_clutter_cell{pulse};
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

fprintf('ЧМП-фильтр применен\n');

%% 14. КОГЕРЕНТНОЕ НАКОПЛЕНИЕ (ДО И ПОСЛЕ ЧМП)
y_H_accum = sum(y_H, 2);
y_V_accum = sum(y_V, 2);

y_H_MTI_accum = sum(y_H_MTI, 2);
y_V_MTI_accum = sum(y_V_MTI, 2);

% Нормировка
gmax = max([max(abs(y_H_accum)), max(abs(y_V_accum))]);
y_H_norm = y_H_accum / gmax;
y_V_norm = y_V_accum / gmax;

gmax_MTI = max([max(abs(y_H_MTI_accum)), max(abs(y_V_MTI_accum))]);
y_H_MTI_norm = y_H_MTI_accum / gmax_MTI;
y_V_MTI_norm = y_V_MTI_accum / gmax_MTI;

%% 15. ОСЬ ДАЛЬНОСТИ
t_y = (0:length(y_H_accum)-1)/Fs;
t_y_corrected = t_y - (N_active - 1)/Fs;
R_y = c * t_y_corrected / 2;

idx = find(R_y > 0 & R_y < 20000);
R_y = R_y(idx);
y_H_norm = y_H_norm(idx);
y_V_norm = y_V_norm(idx);
y_H_MTI_norm = y_H_MTI_norm(idx);
y_V_MTI_norm = y_V_MTI_norm(idx);

%% 16. ВИЗУАЛИЗАЦИЯ
% График дальности ДО ЧМП
subplot(3,3,4);
plot(R_y/1000, abs(y_H_norm), 'b', 'LineWidth', 1.5);
hold on;
plot(R_y/1000, abs(y_V_norm), 'r', 'LineWidth', 1.5);
xlabel('Дальность (км)'); ylabel('Амплитуда');
title('ДО ЧМП: цель + помеха');
grid on; xlim([0 15]);
xline(targetRange/1000, 'g--', 'Цель 5 км', 'LineWidth', 2);
xline(clutterRange/1000, 'r--', 'Помеха 4 км', 'LineWidth', 2);
legend('H', 'V', 'Цель', 'Помеха');

% График дальности ПОСЛЕ ЧМП
subplot(3,3,5);
plot(R_y/1000, abs(y_H_MTI_norm), 'b', 'LineWidth', 1.5);
hold on;
plot(R_y/1000, abs(y_V_MTI_norm), 'r', 'LineWidth', 1.5);
xlabel('Дальность (км)'); ylabel('Амплитуда');
title('ПОСЛЕ ЧМП: помеха подавлена');
grid on; xlim([0 15]);
xline(targetRange/1000, 'g--', 'Цель 5 км', 'LineWidth', 2);
xline(clutterRange/1000, 'r--', 'Помеха 4 км', 'LineWidth', 2);
legend('H', 'V', 'Цель', 'Помеха');

% Доплер ДО ЧМП (на дальности цели)
[~, peak_idx] = max(abs(y_H_accum));
doppler_H_before = y_H(peak_idx, :);
D_H_before = fftshift(fft(doppler_H_before, 256));
freq_doppler = linspace(-PRF/2, PRF/2, 256);
speed_axis = freq_doppler * lambda / 2;

subplot(3,3,6);
plot(speed_axis, 20*log10(abs(D_H_before)/max(abs(D_H_before)) + eps), 'b', 'LineWidth', 1.5);
xlabel('Скорость (м/с)'); ylabel('Амплитуда (дБ)');
title('ДО ЧМП (на дальности цели)');
grid on; 
xline(0, 'r--', 'Помеха', 'LineWidth', 2);
xline(targetSpeed * targetDirection, 'g--', ['Цель ' num2str(targetSpeed) ' м/с'], 'LineWidth', 2);
xlim([-60 60]);

% Доплер ПОСЛЕ ЧМП
[~, peak_idx_MTI] = max(abs(y_H_MTI_accum));
doppler_H_after = y_H_MTI(peak_idx_MTI, :);
D_H_after = fftshift(fft(doppler_H_after, 256));

subplot(3,3,7);
plot(speed_axis, 20*log10(abs(D_H_after)/max(abs(D_H_after)) + eps), 'b', 'LineWidth', 1.5);
xlabel('Скорость (м/с)'); ylabel('Амплитуда (дБ)');
title('ПОСЛЕ ЧМП (помеха подавлена)');
grid on;
xline(0, 'r--', 'Помеха', 'LineWidth', 2);
xline(targetSpeed * targetDirection, 'g--', ['Цель ' num2str(targetSpeed) ' м/с'], 'LineWidth', 2);
xlim([-60 60]);

% Помеха на 4 км: ДО и ПОСЛЕ ЧМП
subplot(3,3,8);
[~, idx_clutter] = min(abs(R_y - clutterRange));
doppler_clutter_before = y_H(idx_clutter, :);
doppler_clutter_after = y_H_MTI(idx_clutter, :);
D_clutter_before = fftshift(fft(doppler_clutter_before, 256));
D_clutter_after = fftshift(fft(doppler_clutter_after, 256));

plot(speed_axis, 20*log10(abs(D_clutter_before)/max(abs(D_clutter_before)) + eps), 'r', 'LineWidth', 1.5);
hold on;
plot(speed_axis, 20*log10(abs(D_clutter_after)/max(abs(D_clutter_after)) + eps), 'b', 'LineWidth', 1.5);
xlabel('Скорость (м/с)'); ylabel('Амплитуда (дБ)');
title('Помеха на 4 км: ДО (красн) и ПОСЛЕ (син) ЧМП');
grid on; legend('ДО ЧМП', 'ПОСЛЕ ЧМП');
xline(0, 'k--', '0 м/с', 'LineWidth', 1);
xlim([-60 60]);

% Фазовый портрет
subplot(3,3,9);
plot(real(rx_H_cell{1}), imag(rx_H_cell{1}), 'b.', 'MarkerSize', 1);
hold on;
plot(real(rx_V_cell{1}), imag(rx_V_cell{1}), 'r.', 'MarkerSize', 1);
xlabel('I'); ylabel('Q');
title('Фазовый портрет (суммарный)');
axis equal; grid on;
legend('H', 'V');

%% 17. ДОПОЛНИТЕЛЬНЫЙ ГРАФИК
figure('Name', 'Эффективность ЧМП');
subplot(2,1,1);
plot(R_y/1000, abs(y_H_norm), 'b', 'LineWidth', 2);
hold on;
plot(R_y/1000, abs(y_H_MTI_norm), 'r', 'LineWidth', 2);
xlabel('Дальность (км)'); ylabel('Амплитуда');
title('Сравнение ДО и ПОСЛЕ ЧМП (H-канал)');
grid on; xlim([0 15]);
xline(targetRange/1000, 'g--', 'Цель 5 км', 'LineWidth', 2);
xline(clutterRange/1000, 'm--', 'Помеха 4 км', 'LineWidth', 2);
legend('ДО ЧМП', 'ПОСЛЕ ЧМП', 'Цель', 'Помеха');

subplot(2,1,2);
plot(R_y/1000, 20*log10(abs(y_H_norm)+eps), 'b', 'LineWidth', 2);
hold on;
plot(R_y/1000, 20*log10(abs(y_H_MTI_norm)+eps), 'r', 'LineWidth', 2);
xlabel('Дальность (км)'); ylabel('Амплитуда (дБ)');
title('Сравнение ДО и ПОСЛЕ ЧМП (дБ)');
grid on; xlim([0 15]);
xline(targetRange/1000, 'g--', 'Цель 5 км', 'LineWidth', 2);
xline(clutterRange/1000, 'm--', 'Помеха 4 км', 'LineWidth', 2);
legend('ДО ЧМП', 'ПОСЛЕ ЧМП', 'Цель', 'Помеха');

%% 18. ВЫВОД
fprintf('\n========== РЕЗУЛЬТАТЫ ==========\n');
fprintf('Цель на %.1f км, скорость %.1f м/с\n', targetRange/1000, targetSpeed);
fprintf('Помеха на %.1f км, скорость 0 м/с\n', clutterRange/1000);

% Проверка подавления помехи на её дальности
amp_clutter_before = abs(y_H_norm(idx_clutter));
amp_clutter_after = abs(y_H_MTI_norm(idx_clutter));
suppression_dB = 20*log10(amp_clutter_before / (amp_clutter_after + eps));

fprintf('Подавление помехи: %.1f дБ\n', suppression_dB);

if suppression_dB > 10
    fprintf('\n✅ ЧМП ЭФФЕКТИВНО подавил помеху (>10 дБ)!\n');
else
    fprintf('\n❌ ЧМП слабо подавил помеху\n');
end