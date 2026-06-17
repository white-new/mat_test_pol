%% МИНИМАЛЬНАЯ МОДЕЛЬ С ТУЛБОКСАМИ - ОКОНЧАТЕЛЬНАЯ
% Учитываем, что waveform создает сигнал с паузой

clear; clc; close all;

%% 1. ПАРАМЕТРЫ
c = physconst('LightSpeed');
fc = 3e9;
lambda = c/fc;

BW = 1e6;           % 1 МГц
PulseWidth = 20e-6; % 20 мкс
PRF = 1e3;          % 1 кГц (период 1 мс)
Fs = 10 * BW;       % 10 МГц

% Цель
targetRange = 5000; % 5 км

%% 2. СОЗДАЕМ ЛЧМ СИГНАЛ
waveform = phased.LinearFMWaveform(...
    'SampleRate', Fs, ...
    'SweepBandwidth', BW, ...
    'PulseWidth', PulseWidth, ...
    'PRF', PRF, ...
    'NumPulses', 1);

x = step(waveform);
N = length(x);
t = (0:N-1)/Fs;

% Активная часть сигнала (только импульс, без паузы)
N_active = round(PulseWidth * Fs);  % 200 отсчетов
x_active = x(1:N_active);

fprintf('Длина сигнала (весь период PRF): %d отсчетов (%.2f мкс)\n', N, N/Fs*1e6);
fprintf('Длина активной части: %d отсчетов (%.2f мкс)\n', N_active, N_active/Fs*1e6);

%% 3. ГРАФИК 1: ЛЧМ СИГНАЛ
figure('Position', [100 100 1400 900]);

subplot(3,3,1);
plot(t(1:N_active)*1e6, real(x_active), 'b', 'LineWidth', 1.5);
xlabel('Время (мкс)'); ylabel('Re');
title('ЛЧМ сигнал (активная часть)');
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

%% 4. МОДЕЛИРУЕМ РАСПРОСТРАНЕНИЕ
channel = phased.FreeSpace(...
    'SampleRate', Fs, ...
    'OperatingFrequency', fc, ...
    'TwoWayPropagation', true);

radarPos = [0; 0; 0];
radarVel = [0; 0; 0];
targetPos = [targetRange; 0; 0];
targetVel = [0; 0; 0];

% Передаем ВЕСЬ сигнал (с паузой)
rx_signal = channel(x, radarPos, targetPos, radarVel, targetVel);

% Визуализация принятого сигнала
subplot(3,3,4);
plot((0:length(rx_signal)-1)/Fs*1e6, real(rx_signal), 'b', 'LineWidth', 1);
xlabel('Время (мкс)'); ylabel('Re');
title('Принятый сигнал (весь период)');
grid on;
xlim([0 100]); % Показываем первые 100 мкс

% Отмечаем положение импульса
hold on;
xline(2*targetRange/c*1e6, 'r--', 'Задержка', 'LineWidth', 2);
xline(2*targetRange/c*1e6 + PulseWidth*1e6, 'g--', 'Конец', 'LineWidth', 2);

subplot(3,3,5);
plot((0:length(rx_signal)-1)/Fs*1e6, imag(rx_signal), 'r', 'LineWidth', 1);
xlabel('Время (мкс)'); ylabel('Im');
title('Принятый сигнал (мнимая часть)');
grid on;
xlim([0 100]);

%% 5. СОГЛАСОВАННЫЙ ФИЛЬТР
% Используем коэффициенты от активной части
mf = phased.MatchedFilter(...
    'Coefficients', conj(flipud(x_active)));

y = mf(rx_signal);

% Нормируем
y = y / max(abs(y));

% Визуализация выхода фильтра (ВО ВРЕМЕНИ)
subplot(3,3,6);
t_y = (0:length(y)-1)/Fs;
plot(t_y*1e6, abs(y), 'b', 'LineWidth', 1.5);
xlabel('Время (мкс)'); ylabel('Амплитуда');
title('Выход согласованного фильтра');
grid on;
xlim([0 100]);

% Находим пик
[peak_val, peak_idx] = max(abs(y));
hold on;
plot(t_y(peak_idx)*1e6, peak_val, 'ro', 'MarkerSize', 10, 'LineWidth', 2);
fprintf('Пик на времени: %.2f мкс (отсчет %d)\n', t_y(peak_idx)*1e6, peak_idx);

%% 6. ПЕРЕВОДИМ В ДАЛЬНОСТЬ
% Компенсируем задержку фильтра (N_active - 1 отсчетов)
t_y_corrected = t_y - (N_active - 1)/Fs;

% Переводим в дальность
R_y = c * t_y_corrected / 2;

% Обрезаем отрицательные
idx = find(R_y > 0);
R_y = R_y(idx);
y = y(idx);

% График в дальности
subplot(3,3,7);
plot(R_y/1000, abs(y), 'b', 'LineWidth', 1.5);
xlabel('Дальность (км)'); ylabel('Амплитуда');
title('Выход фильтра (дальность)');
grid on;
xlim([0 15]);

hold on;
xline(targetRange/1000, 'r--', 'Цель 5 км', 'LineWidth', 2);

% Находим пик
[~, peak_idx_R] = max(abs(y));
R_peak = R_y(peak_idx_R);
plot(R_peak/1000, max(abs(y)), 'ro', 'MarkerSize', 10, 'LineWidth', 2);

%% 7. ЛОГАРИФМИЧЕСКИЙ МАСШТАБ
subplot(3,3,8);
plot(R_y/1000, 20*log10(abs(y)+eps), 'b', 'LineWidth', 1.5);
xlabel('Дальность (км)'); ylabel('Амплитуда (дБ)');
title('Выход фильтра (дБ)');
grid on;
xlim([0 15]);
ylim([-60 0]);

hold on;
xline(targetRange/1000, 'r--', 'Цель 5 км', 'LineWidth', 2);

%% 8. ФАЗОВЫЙ ПОРТРЕТ
subplot(3,3,9);
plot(real(rx_signal), imag(rx_signal), '.', 'MarkerSize', 1);
xlabel('I'); ylabel('Q');
title('Фазовый портрет принятого сигнала');
axis equal;
grid on;

%% 9. УВЕЛИЧЕННЫЙ ГРАФИК ВОКРУГ ЦЕЛИ
figure('Name', 'Пик на 5 км');
plot(R_y/1000, abs(y), 'b', 'LineWidth', 2);
hold on;
xline(targetRange/1000, 'r--', 'Цель 5 км', 'LineWidth', 2);
plot(R_peak/1000, max(abs(y)), 'ro', 'MarkerSize', 15, 'LineWidth', 3);
xlabel('Дальность (км)'); ylabel('Амплитуда');
title('Пик согласованного фильтра (увеличенно)');
grid on;
xlim([4.5 5.5]);
ylim([0.9 1.05]);
legend('Сигнал', 'Цель', 'Пик', 'Location', 'best');

%% 10. ВЫВОД
fprintf('\n========== РЕЗУЛЬТАТЫ ==========\n');
fprintf('Заданная дальность: %.2f м\n', targetRange);
fprintf('Измеренная дальность: %.2f м\n', R_peak);
fprintf('Ошибка: %.2f м\n', abs(R_peak - targetRange));
fprintf('Разрешение по дальности: %.2f м\n', c/(2*BW));

if abs(R_peak - targetRange) < c/(2*BW)
    fprintf('\n✅ СОВПАДЕНИЕ в пределах разрешения!\n');
else
    fprintf('\n❌ ОШИБКА: разница %d отсчетов\n', ...
            round((R_peak - targetRange)/(c/Fs/2)));
end

%% 11. ДИАГНОСТИКА
fprintf('\n--- ДИАГНОСТИКА ---\n');
fprintf('Задержка до цели: %.2f мкс\n', 2*targetRange/c*1e6);
fprintf('Задержка в отсчетах: %.0f\n', 2*targetRange/c*Fs);
fprintf('Длина активной части: %d отсчетов\n', N_active);
fprintf('Пик на отсчете: %d\n', peak_idx);
fprintf('Ожидаемый пик: %d\n', round(2*targetRange/c*Fs + N_active - 1));