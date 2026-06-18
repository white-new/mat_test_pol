function [y_HH, y_HV, y_VH, y_VV, R_y, idx_target] = process_signal_pre_mti(rx_HH_cell, rx_HV_cell, rx_VH_cell, rx_VV_cell, x_active, cfg)
    % PROCESS_SIGNAL_PRE_MTI - Ручной согласованный фильтр

    % Импульсная характеристика согласованного фильтра
    h_mf = conj(flipud(x_active));
    
    y_HH_cell = cell(1, cfg.NumPulses);
    y_HV_cell = cell(1, cfg.NumPulses);
    y_VH_cell = cell(1, cfg.NumPulses);
    y_VV_cell = cell(1, cfg.NumPulses);
    
    for pulse = 1:cfg.NumPulses
        y_HH_cell{pulse} = conv(rx_HH_cell{pulse}, h_mf, 'same');
        y_HV_cell{pulse} = conv(rx_HV_cell{pulse}, h_mf, 'same');
        y_VH_cell{pulse} = conv(rx_VH_cell{pulse}, h_mf, 'same');
        y_VV_cell{pulse} = conv(rx_VV_cell{pulse}, h_mf, 'same');
    end
    
    % Приведение к матрицам
    max_len = length(y_HH_cell{1});
    y_HH = zeros(max_len, cfg.NumPulses);
    y_HV = zeros(max_len, cfg.NumPulses);
    y_VH = zeros(max_len, cfg.NumPulses);
    y_VV = zeros(max_len, cfg.NumPulses);
    
    for pulse = 1:cfg.NumPulses
        y_HH(:, pulse) = y_HH_cell{pulse};
        y_HV(:, pulse) = y_HV_cell{pulse};
        y_VH(:, pulse) = y_VH_cell{pulse};
        y_VV(:, pulse) = y_VV_cell{pulse};
    end

    % Ось дальности
    t_y = (0:length(y_HH)-1)/cfg.Fs;
    t_y_corrected = t_y - (cfg.N_active - 1)/cfg.Fs;
    R_y = 3e8 * t_y_corrected / 2;
    idx = find(R_y > 0 & R_y < 20000);
    R_y = R_y(idx);
    
    y_HH = y_HH(idx, :);
    y_HV = y_HV(idx, :);
    y_VH = y_VH(idx, :);
    y_VV = y_VV(idx, :);
    
    % === НАХОДИМ ПИК НА ЗАДАННОЙ ДАЛЬНОСТИ ===
    [~, idx_target] = min(abs(R_y - cfg.targetRange));
    idx_target_int = round(idx_target);

    fprintf('Цель на дальности: %.1f м (индекс %d)\n', R_y(idx_target_int), idx_target_int);
end