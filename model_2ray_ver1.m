%% МОДЕЛЬ РАДАРА - ШАГ 4: Добавляем затухания в среде
% Атмосферное затухание + многолучевость

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

%% 4. НОВОЕ: ПАРАМЕТРЫ СРЕДЫ РАСПРОСТРАНЕНИЯ
% Высота радара и цели над землей (для многолучевости)
altitude_radar = 10;    % Радар на вышке 10 м
altitude_target = 5;    % Цель на высоте 5 м

% Атмосферное затухание (на 3 ГГц очень маленькое)
% Для примера возьмем 0.01 дБ/км (типично для 3 ГГц)
AtmosLoss_dB_per_km = 0.01;  % дБ/км
AtmosLoss_dB = AtmosLoss_dB_per_km * targetRange / 1000; % Для 5 км
AtmosLoss_Linear = 10^(-AtmosLoss_dB/10);

fprintf('Атмосферное затухание: %.3f дБ\n', AtmosLoss_dB);

% Многолучевость (интерференция прямого и отраженного от земли лучей)
delta_R = 2 * altitude_radar * altitude_target / targetRange;
delta_phi = 2 * pi * delta_R / lambda;
% Коэффициент отражения земли (для горизонтальной поляризации)
% При малых углах скольжения Γ ≈ -1
InterferenceFactor = abs(1 - exp(1j * delta_phi)).^2 / 4;
InterferenceLoss_dB = -10 * log10(InterferenceFactor + eps);

fprintf('Потери от интерференции с землей: %.2f дБ\n', InterferenceLoss_dB);

%% 5. СОЗДАЕМ ЛЧМ СИГНАЛ
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

%% 6. ГРАФИК 1: ЛЧМ СИГНАЛ
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

%% 7. МОДЕЛИРУЕМ РАСПРОСТРАНЕНИЕ (ОБНОВЛЕНО!)
% НОВОЕ: Поднимаем радар и цель над землей
radarPos = [0; 0; altitude_radar];
radarVel = [0; 0; 0];
targetPos = [targetRange; 0; altitude_target];
targetVel = [0; 0; 0];

% Канал распространения в свободном пространстве
channel = phased.FreeSpace(...
    'SampleRate', Fs, ...
    'OperatingFrequency', fc, ...
    'TwoWayPropagation', true);

% Передаем сигналы
tx_H = x;
tx_V = x;

% Проходим канал
rx_H = channel(tx_H, radarPos, targetPos, radarVel, targetVel);
rx_V = channel(tx_V, radarPos, targetPos, radarVel, targetVel);

% НОВОЕ: Применяем атмосферное затухание
rx_H = rx_H * sqrt(AtmosLoss_Linear);  % sqrt потому что двухпроходная схема
rx_V = rx_V * sqrt(AtmosLoss_Linear);

% НОВОЕ: Применяем потери от интерференции с землей (многолучевость)
rx_H = rx_H * 10^(-InterferenceLoss_dB/20);
rx_V = rx_V * 10^(-InterferenceLoss_dB/20);

% Применяем усиление антенны
rx_H = rx_H * Gain_Linear;
rx_V = rx_V * Gain_Linear;

% Применяем потери в тракте
rx_H = rx_H * sqrt(TotalLoss_Linear);
rx_V = rx_V * sqrt(TotalLoss_Linear);

fprintf('Общие потери в среде: %.2f дБ\n', AtmosLoss_dB + InterferenceLoss_dB);

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

%% 8. СОГЛАСОВАННЫЙ ФИЛЬТР
mf = phased.MatchedFilter(...
    'Coefficients', conj(flipud(x_active)));

y_H = mf(rx_H);
y_V = mf(rx_V);

y_H = y_H / max(abs(y_H));
y_V = y_V / max(abs(y_V));

% Визуализация выходов фильтров
subplot(3,3,6);
t_y = (0:length(y_H)-1)/Fs;
plot(t_y*1e6, abs(y_H), 'b', 'LineWidth', 1.5);
hold on;
plot(t_y*1e6, abs(y_V), 'r', 'LineWidth', 1.5);
xlabel('Время (мкс)'); ylabel('Амплитуда');
title('Выход согласованного фильтра (H - син, V - красн)');
grid on;
xlim([0 100]);
legend('H', 'V');

[peak_H, peak_idx_H] = max(abs(y_H));
[peak_V, peak_idx_V] = max(abs(y_V));
fprintf('Пик H: %.2f мкс, Пик V: %.2f мкс\n', t_y(peak_idx_H)*1e6, t_y(peak_idx_V)*1e6);

%% 9. ПЕРЕВОДИМ В ДАЛЬНОСТЬ
t_y_corrected = t_y - (N_active - 1)/Fs;
R_y = c * t_y_corrected / 2;

idx = find(R_y > 0);
R_y = R_y(idx);
y_H = y_H(idx);
y_V = y_V(idx);

% График в дальности
subplot(3,3,7);
plot(R_y/1000, abs(y_H), 'b', 'LineWidth', 1.5);
hold on;
plot(R_y/1000, abs(y_V), 'r', 'LineWidth', 1.5);
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

plot(R_peak_H/1000, max(abs(y_H)), 'bo', 'MarkerSize', 10, 'LineWidth', 2);
plot(R_peak_V/1000, max(abs(y_V)), 'ro', 'MarkerSize', 10, 'LineWidth', 2);
legend('H', 'V', 'Цель', 'Location', 'best');

%% 10. ЛОГАРИФМИЧЕСКИЙ МАСШТАБ
subplot(3,3,8);
plot(R_y/1000, 20*log10(abs(y_H)+eps), 'b', 'LineWidth', 1.5);
hold on;
plot(R_y/1000, 20*log10(abs(y_V)+eps), 'r', 'LineWidth', 1.5);
xlabel('Дальность (км)'); ylabel('Амплитуда (дБ)');
title('Выход фильтра (дБ)');
grid on;
xlim([0 15]);
ylim([-60 0]);

hold on;
xline(targetRange/1000, 'k--', 'Цель 5 км', 'LineWidth', 2);
legend('H', 'V');

%% 11. ФАЗОВЫЙ ПОРТРЕТ
subplot(3,3,9);
plot(real(rx_H), imag(rx_H), 'b.', 'MarkerSize', 1);
hold on;
plot(real(rx_V), imag(rx_V), 'r.', 'MarkerSize', 1);
xlabel('I'); ylabel('Q');
title('Фазовые портреты (H - син, V - красн)');
axis equal;
grid on;
legend('H', 'V');

%% 12. УВЕЛИЧЕННЫЙ ГРАФИК
figure('Name', 'Пики на 5 км (с затуханиями)');
plot(R_y/1000, abs(y_H), 'b', 'LineWidth', 2);
hold on;
plot(R_y/1000, abs(y_V), 'r', 'LineWidth', 2);
xline(targetRange/1000, 'k--', 'Цель 5 км', 'LineWidth', 2);
plot(R_peak_H/1000, max(abs(y_H)), 'bo', 'MarkerSize', 15, 'LineWidth', 3);
plot(R_peak_V/1000, max(abs(y_V)), 'ro', 'MarkerSize', 15, 'LineWidth', 3);
xlabel('Дальность (км)'); ylabel('Амплитуда');
title(['Пики с затуханиями (атмосф. ' num2str(AtmosLoss_dB, '%.2f') ' дБ, земля ' num2str(InterferenceLoss_dB, '%.2f') ' дБ)']);
grid on;
xlim([4.5 5.5]);
ylim([0.9 1.05]);
legend('H', 'V', 'Цель', 'Пик H', 'Пик V', 'Location', 'best');

%% 13. ВЫВОД
fprintf('\n========== РЕЗУЛЬТАТЫ ==========\n');
fprintf('Заданная дальность: %.2f м\n', targetRange);
fprintf('H-канал: дальность %.2f м\n', R_peak_H);
fprintf('V-канал: дальность %.2f м\n', R_peak_V);
fprintf('Ошибка H: %.2f м\n', abs(R_peak_H - targetRange));
fprintf('Ошибка V: %.2f м\n', abs(R_peak_V - targetRange));
fprintf('Атмосферное затухание: %.3f дБ\n', AtmosLoss_dB);
fprintf('Потери от интерференции: %.2f дБ\n', InterferenceLoss_dB);

if abs(R_peak_H - targetRange) < c/(2*BW) && abs(R_peak_V - targetRange) < c/(2*BW)
    fprintf('\n✅ ОБА КАНАЛА работают правильно!\n');
else
    fprintf('\n❌ ОШИБКА в одном из каналов\n');
end

%% 14. ДИАГНОСТИКА ПОТЕРЬ
fprintf('\n--- СВОДКА ПОТЕРЬ ---\n');
fprintf('Потери в тракте:         %.2f дБ\n', TotalLoss_dB);
fprintf('Атмосферное затухание:   %.3f дБ\n', AtmosLoss_dB);
fprintf('Интерференция с землей:  %.2f дБ\n', InterferenceLoss_dB);
fprintf('Усиление антенны:        +%.2f дБ (x2 = +%.2f дБ)\n', Gain_dBi, 2*Gain_dBi);
fprintf('ИТОГО (без усиления):    %.2f дБ\n', TotalLoss_dB + AtmosLoss_dB + InterferenceLoss_dB);