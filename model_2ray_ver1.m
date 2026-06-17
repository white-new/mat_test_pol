%% МОДЕЛЬ РАДАРА - ШАГ 10: Движущаяся цель (ПРАВИЛЬНЫЙ ДОПЛЕР, без алиасинга)
% Скорость выбрана так, чтобы избежать наложения фаз

clear; clc; close all;

%% 1. ПАРАМЕТРЫ
c = physconst('LightSpeed');
fc = 3e9;
lambda = c/fc;

BW = 1e6;           % 1 МГц
PulseWidth = 20e-6; % 20 мкс
PRF = 1e3;          % 1 кГц (период 1 мс)
PRI = 1/PRF;
Fs = 10 * BW;       % 10 МГц

% Цель - скорость выбрана так, чтобы избежать алиасинга
targetRange = 5000;     % Дальность 5 км
targetSpeed = 25;       % ИСПРАВЛЕНО: 25 м/с (вместо 100)
targetDirection = 1;    % 1 - приближается, -1 - удаляется

% Количество импульсов
NumPulses = 32;

fprintf('Количество импульсов: %d\n', NumPulses);
fprintf('PRF: %.1f Гц\n', PRF);

if targetDirection == 1
    dir_str = 'приближается';
else
    dir_str = 'удаляется';
end
fprintf('Скорость цели: %.1f м/с (%s)\n', targetSpeed, dir_str);

% Доплеровская частота
fd = 2 * targetSpeed * targetDirection / lambda;
fprintf('Доплеровская частота: %.1f Гц\n', fd);
fprintf('Макс. частота без алиасинга (PRF/2): %.1f Гц\n', PRF/2);

if abs(fd) > PRF/2
    fprintf('⚠️ ВНИМАНИЕ: fd > PRF/2! Будет алиасинг!\n');
end

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

%% 7. ДОПЛЕРОВСКИЙ ФАЗОВЫЙ НАБЕГ
delta_phase = 2 * pi * fd / PRF;
fprintf('Фазовый набег за импульс: %.2f°\n', delta_phase * 180/pi);

% Вектор фазовых сдвигов
doppler_phase = exp(1j * (0:NumPulses-1) * delta_phase);

%% 8. СОЗДАЕМ ОДИН ЛЧМ ИМПУЛЬС
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

%% 9. ГРАФИК 1: ЛЧМ СИГНАЛ
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

%% 10. МОДЕЛИРУЕМ РАСПРОСТРАНЕНИЕ
radarPos = [0; 0; altitude_radar];
radarVel = [0; 0; 0];
targetPos = [targetRange; 0; altitude_target];
targetVel = [0; 0; 0];

channel = phased.FreeSpace(...
    'SampleRate', Fs, ...
    'OperatingFrequency', fc, ...
    'TwoWayPropagation', true);

rx_H_cell = cell(1, NumPulses);
rx_V_cell = cell(1, NumPulses);

fprintf('Обработка импульсов: ');

for pulse = 1:NumPulses
    if mod(pulse, 8) == 0
        fprintf('%d ', pulse);
    end
    
    rx_H_pulse = channel(x, radarPos, targetPos, radarVel, targetVel);
    rx_V_pulse = channel(x, radarPos, targetPos, radarVel, targetVel);
    
    rx_H_pulse = rx_H_pulse * sqrt(AtmosLoss_Linear);
    rx_V_pulse = rx_V_pulse * sqrt(AtmosLoss_Linear);
    
    rx_H_pulse = rx_H_pulse * 10^(-InterferenceLoss_dB/20);
    rx_V_pulse = rx_V_pulse * 10^(-InterferenceLoss_dB/20);
    
    rcs_scale = sqrt(rcs_factors(pulse) / mean_RCS);
    PolMat_scaled = PolarizationMatrix * rcs_scale;
    
    rx_H_target = PolMat_scaled(1,1) * rx_H_pulse + PolMat_scaled(1,2) * rx_V_pulse;
    rx_V_target = PolMat_scaled(2,1) * rx_H_pulse + PolMat_scaled(2,2) * rx_V_pulse;
    
    % ПРИМЕНЯЕМ ДОПЛЕР ПОСЛЕ ОТРАЖЕНИЯ
    rx_H_target = rx_H_target * doppler_phase(pulse);
    rx_V_target = rx_V_target * doppler_phase(pulse);
    
    rx_H_target = rx_H_target * Gain_Linear * sqrt(TotalLoss_Linear);
    rx_V_target = rx_V_target * Gain_Linear * sqrt(TotalLoss_Linear);
    
    rx_H_cell{pulse} = rx_H_target;
    rx_V_cell{pulse} = rx_V_target;
end

fprintf('\nОбработано %d импульсов\n', NumPulses);

% Визуализация доплеровского фазового набега
subplot(3,3,4);
plot(1:NumPulses, angle(doppler_phase)*180/pi, 'ko-', 'LineWidth', 1.5);
xlabel('Номер импульса'); ylabel('Фаза (градусы)');
title('Доплеровский фазовый набег');
grid on;

%% 11. СОГЛАСОВАННЫЙ ФИЛЬТР
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

%% 12. КОГЕРЕНТНОЕ НАКОПЛЕНИЕ
y_H_accum = sum(y_H, 2);
y_V_accum = sum(y_V, 2);

global_max = max([max(abs(y_H_accum)), max(abs(y_V_accum))]);
y_H_norm = y_H_accum / global_max;
y_V_norm = y_V_accum / global_max;

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

%% 13. ПЕРЕВОДИМ В ДАЛЬНОСТЬ
t_y_corrected = t_y - (N_active - 1)/Fs;
R_y = c * t_y_corrected / 2;

idx = find(R_y > 0 & R_y < 20000);
R_y = R_y(idx);
y_H_norm = y_H_norm(idx);
y_V_norm = y_V_norm(idx);

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

%% 14. ЛОГАРИФМИЧЕСКИЙ МАСШТАБ
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

%% 15. ДОПЛЕРОВСКАЯ ОБРАБОТКА
[~, peak_idx] = max(abs(y_H_accum));
peak_sample = peak_idx;

doppler_H = y_H(peak_sample, :);
doppler_V = y_V(peak_sample, :);

Nfft = 256;
D_H = fftshift(fft(doppler_H, Nfft));
D_V = fftshift(fft(doppler_V, Nfft));

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

% Отмечаем ожидаемую скорость
xline(targetSpeed * targetDirection, 'g--', ['Ожидаемая ' num2str(targetSpeed) ' м/с'], 'LineWidth', 2);
xlim([-60 60]);

[~, max_idx_H] = max(abs(D_H));
[~, max_idx_V] = max(abs(D_V));
speed_peak_H = speed_axis(max_idx_H);
speed_peak_V = speed_axis(max_idx_V);

fprintf('Пик скорости H: %.1f м/с\n', speed_peak_H);
fprintf('Пик скорости V: %.1f м/с\n', speed_peak_V);

%% 16. ФАЗОВЫЙ ПОРТРЕТ
subplot(3,3,9);
plot(real(rx_H_cell{1}), imag(rx_H_cell{1}), 'b.', 'MarkerSize', 1);
hold on;
plot(real(rx_V_cell{1}), imag(rx_V_cell{1}), 'r.', 'MarkerSize', 1);
xlabel('I'); ylabel('Q');
title('Фазовые портреты (1-й импульс)');
axis equal;
grid on;
legend('H', 'V');

%% 17. ДОПОЛНИТЕЛЬНЫЙ ГРАФИК: ФАЗА ВО ВРЕМЕНИ
figure('Name', 'Доплеровский сдвиг во времени');

phase_H = angle(doppler_H);
phase_V = angle(doppler_V);

subplot(2,1,1);
plot(1:NumPulses, phase_H * 180/pi, 'bo-', 'LineWidth', 1.5);
hold on;
plot(1:NumPulses, phase_V * 180/pi, 'ro-', 'LineWidth', 1.5);
xlabel('Номер импульса'); ylabel('Фаза (градусы)');
title('Фаза сигнала на пиковой дальности');
grid on;
legend('H', 'V');

p_H = polyfit(1:NumPulses, unwrap(phase_H), 1);
p_V = polyfit(1:NumPulses, unwrap(phase_V), 1);
fprintf('Скорость из фазы H: %.1f м/с\n', -p_H(1) * lambda * PRF / (4*pi));
fprintf('Скорость из фазы V: %.1f м/с\n', -p_V(1) * lambda * PRF / (4*pi));

subplot(2,1,2);
plot(1:NumPulses, unwrap(phase_H), 'bo-', 'LineWidth', 1.5);
hold on;
plot(1:NumPulses, unwrap(phase_V), 'ro-', 'LineWidth', 1.5);
plot(1:NumPulses, polyval(p_H, 1:NumPulses), 'b--', 'LineWidth', 1);
plot(1:NumPulses, polyval(p_V, 1:NumPulses), 'r--', 'LineWidth', 1);
xlabel('Номер импульса'); ylabel('Фаза (радианы)');
title('Развернутая фаза с линейной аппроксимацией');
grid on;
legend('H', 'V', 'Аппроксимация H', 'Аппроксимация V');

%% 18. ВЫВОД
fprintf('\n========== РЕЗУЛЬТАТЫ ==========\n');
fprintf('Заданная дальность: %.2f м\n', targetRange);
fprintf('H-канал: дальность %.2f м\n', R_peak_H);
fprintf('V-канал: дальность %.2f м\n', R_peak_V);
fprintf('Ошибка H: %.2f м\n', abs(R_peak_H - targetRange));
fprintf('Ошибка V: %.2f м\n', abs(R_peak_V - targetRange));
fprintf('Заданная скорость: %.1f м/с\n', targetSpeed * targetDirection);
fprintf('Измеренная скорость H: %.1f м/с\n', speed_peak_H);
fprintf('Измеренная скорость V: %.1f м/с\n', speed_peak_V);
fprintf('Количество импульсов: %d\n', NumPulses);

if abs(R_peak_H - targetRange) < c/(2*BW) && abs(R_peak_V - targetRange) < c/(2*BW)
    fprintf('\n✅ ОБА КАНАЛА работают правильно!\n');
else
    fprintf('\n❌ ОШИБКА в одном из каналов\n');
end