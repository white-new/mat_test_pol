function print_results(results, cfg)
    % PRINT_RESULTS - Вывод результатов в консоль

    fprintf('\n========================================\n');
    fprintf('РЕЗУЛЬТАТЫ ОБРАБОТКИ\n');
    fprintf('========================================\n');

    if cfg.enable.DETECTION && cfg.enable.CHANNEL
        if results.target_detected_H || results.target_detected_V
            fprintf('Цель:   %.1f км, %.1f м/с -> ОБНАРУЖЕНА ✅\n', ...
                    cfg.targetRange/1000, cfg.targetSpeed);
        else
            fprintf('Цель:   %.1f км, %.1f м/с -> НЕ ОБНАРУЖЕНА ❌\n', ...
                    cfg.targetRange/1000, cfg.targetSpeed);
        end
        
        if ~results.clutter_detected_H && ~results.clutter_detected_V
            fprintf('Помеха: %.1f км, %.1f м/с -> ПОДАВЛЕНА ✅\n', ...
                    cfg.clutterRange/1000, cfg.clutterSpeed);
        else
            fprintf('Помеха: %.1f км, %.1f м/с -> НЕ ПОДАВЛЕНА ❌\n', ...
                    cfg.clutterRange/1000, cfg.clutterSpeed);
        end
    else
        fprintf('Обнаружение ВЫКЛЮЧЕНО\n');
    end
    fprintf('========================================\n');
end