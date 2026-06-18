%% =========================================================================
%  МОДЕЛЬ РАДАРА - НОВАЯ АРХИТЕКТУРА
%  =========================================================================
%
%  Особенности:
%  - Цели и помехи — отдельные объекты
%  - Можно добавлять сколько угодно объектов
%  - Антенна — отдельный объект (зеркальная, ФАР, изотропная)
%  - Полная поляриметрия: 4 канала (HH, HV, VH, VV)
%  =========================================================================

clear; clc; close all;

%% 1. КОНФИГУРАЦИЯ
cfg = config();

%% 2. СОЗДАНИЕ ОБЪЕКТОВ
antenna = create_antenna(cfg);
targets = create_targets(cfg);
clutters = create_clutters(cfg);

%% 3. ФОРМИРОВАНИЕ СИГНАЛА
[x, x_active, t] = generate_lfm(cfg);

%% 4. РАСПРОСТРАНЕНИЕ С УЧЁТОМ АНТЕННЫ
[rx_HH_cell, rx_HV_cell, rx_VH_cell, rx_VV_cell] = propagate_objects(x, targets, clutters, antenna, cfg);

%% 5. ДОБАВЛЕНИЕ ШУМА
[rx_HH_cell, rx_HV_cell, rx_VH_cell, rx_VV_cell] = ...
    add_noise_polarization(rx_HH_cell, rx_HV_cell, rx_VH_cell, rx_VV_cell, cfg);

%% 6. ОБРАБОТКА (4 канала)
[y_HH_norm, y_HV_norm, y_VH_norm, y_VV_norm, R_y, results] = ...
    process_signal_polarization(rx_HH_cell, rx_HV_cell, rx_VH_cell, rx_VV_cell, x_active, cfg);

%% 7. ВИЗУАЛИЗАЦИЯ
plot_results_polarization(x_active, t, rx_HH_cell, y_HH_norm, y_HV_norm, y_VH_norm, y_VV_norm, ...
                          R_y, cfg, results);

%% 8. ВЫВОД
print_results_polarization(results, cfg);