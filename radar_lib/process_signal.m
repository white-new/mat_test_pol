function [detected_H, detected_V, results, R_y, y_H_MTI_norm, y_V_MTI_norm] = process_signal(rx_H_cell, rx_V_cell, x_active, cfg)
    % PROCESS_SIGNAL - Полный цикл обработки сигнала
    %
    %   Управление диагностикой через cfg.enable:
    %       VERBOSE     - подробный вывод в консоль
    %       DIAGNOSTICS - диагностика ЧМП

    % === Согласованный фильтр ===
    if cfg.enable.MATCHED_FILTER && cfg.enable.CHANNEL
        mf = phased.MatchedFilter('Coefficients', conj(flipud(x_active)));
        y_H_cell = cell(1, cfg.NumPulses);
        y_V_cell = cell(1, cfg.NumPulses);
        for pulse = 1:cfg.NumPulses
            y_H_cell{pulse} = mf(rx_H_cell{pulse});
            y_V_cell{pulse} = mf(rx_V_cell{pulse});
        end
        max_len = max([cellfun(@length, y_H_cell), cellfun(@length, y_V_cell)]);
        y_H = zeros(max_len, cfg.NumPulses);
        y_V = zeros(max_len, cfg.NumPulses);
        for pulse = 1:cfg.NumPulses
            len_H = length(y_H_cell{pulse});
            len_V = length(y_V_cell{pulse});
            y_H(1:len_H, pulse) = y_H_cell{pulse};
            y_V(1:len_V, pulse) = y_V_cell{pulse};
        end
        if cfg.enable.VERBOSE
            fprintf('Согласованная фильтрация выполнена\n');
        end
    else
        if cfg.enable.CHANNEL && cfg.enable.VERBOSE
            fprintf('Согласованный фильтр ВЫКЛЮЧЕН\n');
        end
        max_len = length(rx_H_cell{1});
        y_H = zeros(max_len, cfg.NumPulses);
        y_V = zeros(max_len, cfg.NumPulses);
        for pulse = 1:cfg.NumPulses
            len_H = length(rx_H_cell{pulse});
            len_V = length(rx_V_cell{pulse});
            y_H(1:len_H, pulse) = rx_H_cell{pulse};
            y_V(1:len_V, pulse) = rx_V_cell{pulse};
        end
    end

    % ===== ДИАГНОСТИКА ЧМП (управляется DIAGNOSTICS) =====
    if cfg.enable.DIAGNOSTICS && cfg.enable.CHANNEL
        % Найдём индекс помехи в полных данных
        t_y = (0:length(y_H)-1)/cfg.Fs;
        t_y_corrected = t_y - (cfg.N_active - 1)/cfg.Fs;
        R_y_full = 3e8 * t_y_corrected / 2;
        [~, idx_clutter_full] = min(abs(R_y_full - cfg.clutterRange));
        
        fprintf('\n=== ДИАГНОСТИКА ЧМП ===\n');
        fprintf('Индекс помехи: %d\n', idx_clutter_full);
        
        % Сигнал помехи на 1-м и 2-м импульсе
        signal_1 = y_H(idx_clutter_full, 1);
        signal_2 = y_H(idx_clutter_full, 2);
        fprintf('Помеха (имп.1): %.3e\n', abs(signal_1));
        fprintf('Помеха (имп.2): %.3e\n', abs(signal_2));
        fprintf('Разница: %.3e\n', abs(signal_2 - signal_1));
        
        if abs(signal_2 - signal_1) < 1e-10
            fprintf('✅ Помеха ПОСТОЯННАЯ (ЧМП должен сработать)\n');
        else
            fprintf('⚠️ Помеха МЕНЯЕТСЯ (ЧМП может не сработать)\n');
        end
    end

    % === ЧМП-фильтр ===
    if cfg.enable.MTI && cfg.enable.CHANNEL
        y_H_MTI = diff(y_H, 1, 2);
        y_V_MTI = diff(y_V, 1, 2);
        y_H_MTI = [y_H_MTI, zeros(size(y_H_MTI, 1), 1)];
        y_V_MTI = [y_V_MTI, zeros(size(y_V_MTI, 1), 1)];
        
        if cfg.enable.DIAGNOSTICS && cfg.enable.CHANNEL
            y_clutter_after = y_H_MTI(idx_clutter_full, :);
            fprintf('Мощность помехи ПОСЛЕ ЧМП: %.3e\n', mean(abs(y_clutter_after).^2));
        end
        
        if cfg.enable.VERBOSE
            fprintf('ЧМП-фильтр применен\n');
        end
    else
        if cfg.enable.CHANNEL && cfg.enable.VERBOSE
            fprintf('ЧМП-фильтр ВЫКЛЮЧЕН\n');
        end
        y_H_MTI = y_H;
        y_V_MTI = y_V;
    end

    % === Когерентное накопление ===
    if cfg.enable.ACCUMULATION && cfg.enable.CHANNEL
        y_H_accum = sum(y_H, 2);
        y_V_accum = sum(y_V, 2);
        y_H_MTI_accum = sum(y_H_MTI, 2);
        y_V_MTI_accum = sum(y_V_MTI, 2);
        if cfg.enable.VERBOSE
            fprintf('Когерентное накопление применено (%d импульсов)\n', cfg.NumPulses);
        end
    else
        if cfg.enable.CHANNEL && cfg.enable.VERBOSE
            fprintf('Когерентное накопление ВЫКЛЮЧЕНО\n');
        end
        y_H_accum = y_H(:, 1);
        y_V_accum = y_V(:, 1);
        y_H_MTI_accum = y_H_MTI(:, 1);
        y_V_MTI_accum = y_V_MTI(:, 1);
    end

    % === Ось дальности ===
    t_y = (0:length(y_H_accum)-1)/cfg.Fs;
    t_y_corrected = t_y - (cfg.N_active - 1)/cfg.Fs;
    R_y = 3e8 * t_y_corrected / 2;
    idx = find(R_y > 0 & R_y < 20000);
    R_y = R_y(idx);
    y_H_MTI_norm = abs(y_H_MTI_accum(idx)) / (max(abs(y_H_MTI_accum(idx))) + eps);
    y_V_MTI_norm = abs(y_V_MTI_accum(idx)) / (max(abs(y_V_MTI_accum(idx))) + eps);

    % === Обнаружение ===
    results = struct();
    results.target_detected_H = false;
    results.target_detected_V = false;
    results.clutter_detected_H = false;
    results.clutter_detected_V = false;

    if cfg.enable.DETECTION && cfg.enable.CHANNEL
        detected_H = y_H_MTI_norm > cfg.Threshold_rel;
        detected_V = y_V_MTI_norm > cfg.Threshold_rel;
        [~, idx_target] = min(abs(R_y - cfg.targetRange));
        [~, idx_clutter] = min(abs(R_y - cfg.clutterRange));
        results.target_detected_H = detected_H(idx_target);
        results.target_detected_V = detected_V(idx_target);
        results.clutter_detected_H = detected_H(idx_clutter);
        results.clutter_detected_V = detected_V(idx_clutter);
        
        fprintf('\n--- ОБНАРУЖЕНИЕ ---\n');
        fprintf('Цель на %.1f км: H-%s, V-%s\n', cfg.targetRange/1000, ...
                iif(results.target_detected_H, '✅', '❌'), ...
                iif(results.target_detected_V, '✅', '❌'));
        fprintf('Помеха на %.1f км: H-%s, V-%s\n', cfg.clutterRange/1000, ...
                iif(~results.clutter_detected_H, '✅ подавлена', '❌'), ...
                iif(~results.clutter_detected_V, '✅ подавлена', '❌'));
    else
        detected_H = false(size(R_y));
        detected_V = false(size(R_y));
        if cfg.enable.VERBOSE
            fprintf('\n--- ОБНАРУЖЕНИЕ ВЫКЛЮЧЕНО ---\n');
        end
    end
end

function out = iif(cond, t, f)
    if cond, out = t; else, out = f; end
end