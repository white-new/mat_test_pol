%% TEST_TARGETS - Тестирование разных типов целей
%   Запускает модель для каждого типа цели

clear; clc; close all;

types = {'corner', 'dipole', 'sphere'};
angles = [0, 45, 90, 135];

for t = 1:length(types)
    for a = 1:length(angles)
        fprintf('\n========================================\n');
        fprintf('Тест: %s, угол %d°\n', types{t}, angles(a));
        fprintf('========================================\n');
        
        cfg = config();
        cfg.target_type = types{t};
        cfg.target_angle = angles(a);
        cfg.enable.PLOTS = false;  % Отключаем графики для скорости
        
        % Запуск модели
        main;
    end
end