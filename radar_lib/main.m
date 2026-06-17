%% =========================================================================
%  МОДЕЛЬ РАДАРА - НОВАЯ АРХИТЕКТУРА
%  =========================================================================
%
%  Особенности:
%  - Цели и помехи — отдельные объекты
%  - Можно добавлять сколько угодно объектов
%  - Антенна — отдельный объект (зеркальная, ФАР, изотропная)
%  =========================================================================

clear; clc; close all;

%% 1. КОНФИГУРАЦИЯ
cfg = config();
    cfg.enable.CHANNEL = true;        % Распространение (цель + помеха)
    cfg.enable.NOISE = false;          % Добавление шума
    cfg.enable.MATCHED_FILTER = true; % Согласованный фильтр
    cfg.enable.MTI = false;            % ЧМП-фильтр (подавление помех)
    cfg.enable.ACCUMULATION = true;   % Когерентное накопление
    cfg.enable.DETECTION = false;      % Обнаружение (порог)
    cfg.enable.DOPPLER = true;        % Доплеровская обработка
    cfg.enable.PLOTS = true;          % Отрисовка графиков
    cfg.enable.SNR_ANALYSIS = true;   % Дополнительный график SNR
%% 2. СОЗДАНИЕ ОБЪЕКТОВ
antenna = create_antenna(cfg);
targets = create_targets(cfg);
clutters = create_clutters(cfg);

%% 3. ФОРМИРОВАНИЕ СИГНАЛА
[x, x_active, t] = generate_lfm(cfg);

%% 4. РАСПРОСТРАНЕНИЕ С УЧЁТОМ АНТЕННЫ
[rx_H_cell, rx_V_cell] = propagate_objects(x, targets, clutters, antenna, cfg);

%% 5. ДОБАВЛЕНИЕ ШУМА
[rx_H_cell, rx_V_cell] = add_noise(rx_H_cell, rx_V_cell, cfg);

%% 6. ОБРАБОТКА
[detected_H, detected_V, results, R_y, y_H_MTI_norm, y_V_MTI_norm] = ...
    process_signal(rx_H_cell, rx_V_cell, x_active, cfg);

%% 7. ВИЗУАЛИЗАЦИЯ
plot_results(x_active, t, rx_H_cell, y_H_MTI_norm, y_V_MTI_norm, ...
             detected_H, detected_V, R_y, cfg, results);

%% 8. ВЫВОД
print_results(results, cfg);