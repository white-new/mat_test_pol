function [y_HH, y_HV, y_VH, y_VV, R_y, results] = process_signal_polarization(rx_HH_cell, rx_HV_cell, rx_VH_cell, rx_VV_cell, x_active, cfg)
    % PROCESS_SIGNAL_POLARIZATION - Обработка 4 поляризационных каналов
    %   Возвращает КОМПЛЕКСНЫЕ значения (сохраняем фазы!)

    % === Обработка каждого канала (возвращает комплексные значения) ===
    [y_HH, R_y] = process_single_channel(rx_HH_cell, x_active, cfg);
    [y_HV, ~] = process_single_channel(rx_HV_cell, x_active, cfg);
    [y_VH, ~] = process_single_channel(rx_VH_cell, x_active, cfg);
    [y_VV, ~] = process_single_channel(rx_VV_cell, x_active, cfg);

    % === Обнаружение (по амплитуде каждого канала) ===
    results = struct();
    results.target_detected_HH = false;
    results.target_detected_HV = false;
    results.target_detected_VH = false;
    results.target_detected_VV = false;
    results.clutter_detected_HH = false;
    results.clutter_detected_HV = false;
    results.clutter_detected_VH = false;
    results.clutter_detected_VV = false;

    if cfg.enable.DETECTION && cfg.enable.CHANNEL
        th = cfg.Threshold_rel;
        
        % Находим индексы цели и помехи
        [~, idx_target] = min(abs(R_y - cfg.targetRange));
        [~, idx_clutter] = min(abs(R_y - cfg.clutterRange));
        
        % Нормируем КАЖДЫЙ КАНАЛ ОТДЕЛЬНО для обнаружения
        HH_norm = abs(y_HH) / (max(abs(y_HH)) + eps);
        HV_norm = abs(y_HV) / (max(abs(y_HV)) + eps);
        VH_norm = abs(y_VH) / (max(abs(y_VH)) + eps);
        VV_norm = abs(y_VV) / (max(abs(y_VV)) + eps);
        
        % Обнаружение
        results.target_detected_HH = HH_norm(idx_target) > th;
        results.target_detected_HV = HV_norm(idx_target) > th;
        results.target_detected_VH = VH_norm(idx_target) > th;
        results.target_detected_VV = VV_norm(idx_target) > th;
        
        results.clutter_detected_HH = HH_norm(idx_clutter) > th;
        results.clutter_detected_HV = HV_norm(idx_clutter) > th;
        results.clutter_detected_VH = VH_norm(idx_clutter) > th;
        results.clutter_detected_VV = VV_norm(idx_clutter) > th;
        
        fprintf('\n--- ОБНАРУЖЕНИЕ (4 канала) ---\n');
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
    end
end

% ===== ВСПОМОГАТЕЛЬНАЯ ФУНКЦИЯ (возвращает КОМПЛЕКСНЫЕ значения) =====
function [y_complex, R_y] = process_single_channel(rx_cell, x_active, cfg)
    % PROCESS_SINGLE_CHANNEL - Обработка одного поляризационного канала
    %   Возвращает КОМПЛЕКСНЫЕ значения (сохраняем фазы!)

    % Согласованный фильтр
    if cfg.enable.MATCHED_FILTER && cfg.enable.CHANNEL
        mf = phased.MatchedFilter('Coefficients', conj(flipud(x_active)));
        y_cell = cell(1, cfg.NumPulses);
        for pulse = 1:cfg.NumPulses
            y_cell{pulse} = mf(rx_cell{pulse});
        end
        max_len = max(cellfun(@length, y_cell));
        y = zeros(max_len, cfg.NumPulses);
        for pulse = 1:cfg.NumPulses
            len_y = length(y_cell{pulse});
            y(1:len_y, pulse) = y_cell{pulse};
        end
    else
        max_len = length(rx_cell{1});
        y = zeros(max_len, cfg.NumPulses);
        for pulse = 1:cfg.NumPulses
            len_y = length(rx_cell{pulse});
            y(1:len_y, pulse) = rx_cell{pulse};
        end
    end

    % ЧМП-фильтр
    if cfg.enable.MTI && cfg.enable.CHANNEL
        y_MTI = diff(y, 1, 2);
        y_MTI = [y_MTI, zeros(size(y_MTI, 1), 1)];
    else
        y_MTI = y;
    end

    % Когерентное накопление (суммируем по импульсам)
    if cfg.enable.ACCUMULATION && cfg.enable.CHANNEL
        y_accum = sum(y_MTI, 2);
    else
        y_accum = y_MTI(:, 1);
    end

    % Ось дальности
    t_y = (0:length(y_accum)-1)/cfg.Fs;
    t_y_corrected = t_y - (cfg.N_active - 1)/cfg.Fs;
    R_y = 3e8 * t_y_corrected / 2;
    idx = find(R_y > 0 & R_y < 20000);
    R_y = R_y(idx);
    
    % ВОЗВРАЩАЕМ КОМПЛЕКСНЫЕ ЗНАЧЕНИЯ (без нормировки!)
    y_complex = y_accum(idx);
end

function out = iif(cond, t, f)
    if cond, out = t; else, out = f; end
end