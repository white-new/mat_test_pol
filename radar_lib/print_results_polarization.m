function print_results_polarization(results, cfg)
    % PRINT_RESULTS_POLARIZATION - Вывод результатов для 4 каналов

    fprintf('\n========================================\n');
    fprintf('РЕЗУЛЬТАТЫ ОБРАБОТКИ (4 канала)\n');
    fprintf('========================================\n');

    if cfg.enable.DETECTION && cfg.enable.CHANNEL
        fprintf('Цель на %.1f км:\n', cfg.targetRange/1000);
        fprintf('  HH: %s, HV: %s, VH: %s, VV: %s\n', ...
                iif(results.target_detected_HH, '✅', '❌'), ...
                iif(results.target_detected_HV, '✅', '❌'), ...
                iif(results.target_detected_VH, '✅', '❌'), ...
                iif(results.target_detected_VV, '✅', '❌'));
        
        fprintf('Помеха на %.1f км:\n', cfg.clutterRange/1000);
        fprintf('  HH: %s, HV: %s, VH: %s, VV: %s\n', ...
                iif(~results.clutter_detected_HH, '✅ подавлена', '❌'), ...
                iif(~results.clutter_detected_HV, '✅ подавлена', '❌'), ...
                iif(~results.clutter_detected_VH, '✅ подавлена', '❌'), ...
                iif(~results.clutter_detected_VV, '✅ подавлена', '❌'));
    else
        fprintf('Обнаружение ВЫКЛЮЧЕНО\n');
    end
    fprintf('========================================\n');
end

function out = iif(cond, t, f)
    if cond, out = t; else, out = f; end
end