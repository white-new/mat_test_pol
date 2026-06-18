function animate_target_3d(cfg)
    % ANIMATE_TARGET_3D - 3D-анимация вращения цели (ДО ЧМП)

    if ~cfg.target_rotate
        warning('Вращение выключено. Установите cfg.target_rotate = true');
        return;
    end

    fprintf('\n========================================\n');
    fprintf('3D-АНИМАЦИЯ ВРАЩЕНИЯ ЦЕЛИ\n');
    fprintf('Тип цели: %s\n', cfg.target_type);
    fprintf('Скорость вращения: %.1f град/с\n', cfg.target_rotation_speed);
    fprintf('========================================\n');

    % Генерируем сигнал
    [x, x_active, ~] = generate_lfm(cfg);
    antenna = create_antenna(cfg);
    targets = create_targets(cfg);
    clutters = create_clutters(cfg);
    
    [rx_HH_cell, rx_HV_cell, rx_VH_cell, rx_VV_cell] = ...
        propagate_objects(x, targets, clutters, antenna, cfg);
    
    [rx_HH_cell, rx_HV_cell, rx_VH_cell, rx_VV_cell] = ...
        add_noise_polarization(rx_HH_cell, rx_HV_cell, rx_VH_cell, rx_VV_cell, cfg);
    
    % ===== ИСПРАВЛЕНО: используем данные ДО ЧМП =====
    [y_HH, y_HV, y_VH, y_VV, R_y] = process_signal_pre_mti(...
        rx_HH_cell, rx_HV_cell, rx_VH_cell, rx_VV_cell, x_active, cfg);

    % Находим индекс цели
    [~, idx_target] = min(abs(R_y - cfg.targetRange));

    num_frames = cfg.NumPulses;
    
    % Подготовка данных
    HH_vals = zeros(num_frames, 1);
    HV_vals = zeros(num_frames, 1);
    VH_vals = zeros(num_frames, 1);
    VV_vals = zeros(num_frames, 1);
    
    HH_phase_vals = zeros(num_frames, 1);
    HV_phase_vals = zeros(num_frames, 1);
    VH_phase_vals = zeros(num_frames, 1);
    VV_phase_vals = zeros(num_frames, 1);
    
    s1_vals = zeros(num_frames, 1);
    s2_vals = zeros(num_frames, 1);
    s3_vals = zeros(num_frames, 1);

    % Сбор данных
    for pulse = 1:num_frames
        HH_vals(pulse) = abs(y_HH(idx_target, pulse));
        HV_vals(pulse) = abs(y_HV(idx_target, pulse));
        VH_vals(pulse) = abs(y_VH(idx_target, pulse));
        VV_vals(pulse) = abs(y_VV(idx_target, pulse));
        
        HH_phase_vals(pulse) = angle(y_HH(idx_target, pulse)) * 180/pi;
        HV_phase_vals(pulse) = angle(y_HV(idx_target, pulse)) * 180/pi;
        VH_phase_vals(pulse) = angle(y_VH(idx_target, pulse)) * 180/pi;
        VV_phase_vals(pulse) = angle(y_VV(idx_target, pulse)) * 180/pi;
        
        % Stokes параметры
        E_H = y_HH(idx_target, pulse) + y_VH(idx_target, pulse);
        E_V = y_HV(idx_target, pulse) + y_VV(idx_target, pulse);
        
        S0 = abs(E_H)^2 + abs(E_V)^2;
        S1 = abs(E_H)^2 - abs(E_V)^2;
        S2 = 2 * real(E_H * conj(E_V));
        S3 = 2 * imag(E_H * conj(E_V));
        
        s1_vals(pulse) = S1 / (S0 + eps);
        s2_vals(pulse) = S2 / (S0 + eps);
        s3_vals(pulse) = S3 / (S0 + eps);
    end

    % Нормируем амплитуды для отображения
    max_val = max([HH_vals; HV_vals; VH_vals; VV_vals]);
    HH_norm = HH_vals / max_val;
    HV_norm = HV_vals / max_val;
    VH_norm = VH_vals / max_val;
    VV_norm = VV_vals / max_val;

    % ===== АНИМАЦИЯ =====
    for frame = 1:num_frames
        % Очищаем фигуру
        clf(fig);
        
        % --- График 1: Амплитуды матрицы рассеяния ---
        subplot(2,3,1);
        S_amp = [HH_norm(frame), HV_norm(frame); 
                 VH_norm(frame), VV_norm(frame)];
        imagesc(S_amp);
        colorbar;
        colormap('hot');
        title(sprintf('Амплитуды (имп. %d)', frame));
        set(gca, 'XTick', [1 2], 'XTickLabel', {'H', 'V'});
        set(gca, 'YTick', [1 2], 'YTickLabel', {'H', 'V'});
        for i = 1:2
            for j = 1:2
                text(j, i, sprintf('%.2f', S_amp(i,j)), ...
                     'HorizontalAlignment', 'center', 'Color', 'w', 'FontSize', 10);
            end
        end
        caxis([0 1]);

        % --- График 2: Фазы матрицы рассеяния ---
        subplot(2,3,2);
        S_phase = [HH_phase_vals(frame), HV_phase_vals(frame); 
                   VH_phase_vals(frame), VV_phase_vals(frame)];
        imagesc(S_phase);
        colorbar;
        colormap('hsv');
        title(sprintf('Фазы (имп. %d)', frame));
        set(gca, 'XTick', [1 2], 'XTickLabel', {'H', 'V'});
        set(gca, 'YTick', [1 2], 'YTickLabel', {'H', 'V'});
        for i = 1:2
            for j = 1:2
                text(j, i, sprintf('%.0f', S_phase(i,j)), ...
                     'HorizontalAlignment', 'center', 'Color', 'w', 'FontSize', 10);
            end
        end
        caxis([-180 180]);

        % --- График 3: Амплитуды каналов по импульсам ---
        subplot(2,3,3);
        plot(1:frame, HH_norm(1:frame), 'b', 'LineWidth', 2);
        hold on;
        plot(1:frame, HV_norm(1:frame), 'r', 'LineWidth', 2);
        plot(1:frame, VH_norm(1:frame), 'g', 'LineWidth', 2);
        plot(1:frame, VV_norm(1:frame), 'm', 'LineWidth', 2);
        xlabel('Импульс'); ylabel('Амплитуда');
        title('Амплитуды каналов');
        legend('HH', 'HV', 'VH', 'VV', 'Location', 'best');
        grid on;
        xlim([0 num_frames+1]);
        ylim([0 1.2]);

        % --- График 4: Поляризационный эллипс ---
        subplot(2,3,4);
        % Восстанавливаем Stokes параметры для текущего импульса
        E_H = y_HH(idx_target, frame) + y_VH(idx_target, frame);
        E_V = y_HV(idx_target, frame) + y_VV(idx_target, frame);
        
        S0 = abs(E_H)^2 + abs(E_V)^2;
        S1 = abs(E_H)^2 - abs(E_V)^2;
        S2 = 2 * real(E_H * conj(E_V));
        S3 = 2 * imag(E_H * conj(E_V));
        
        s1 = S1 / (S0 + eps);
        s2 = S2 / (S0 + eps);
        s3 = S3 / (S0 + eps);
        
        % Рисуем эллипс
        draw_polarization_ellipse(s1, s2, s3, 'b', sprintf('Имп. %d', frame));
        title('Эллипс поляризации');
        axis equal;
        xlim([-1.5 1.5]); ylim([-1.5 1.5]);
        grid on;

        % --- График 5: Сфера Пуанкаре (траектория) ---
        subplot(2,3,5);
        % Сфера
        [X, Y, Z] = sphere(20);
        surf(X, Y, Z, 'FaceAlpha', 0.1, 'EdgeAlpha', 0.1, 'FaceColor', 'c');
        hold on;
        
        % Траектория
        s1_vals = zeros(frame, 1);
        s2_vals = zeros(frame, 1);
        s3_vals = zeros(frame, 1);
        
        for f = 1:frame
            E_H_f = y_HH(idx_target, f) + y_VH(idx_target, f);
            E_V_f = y_HV(idx_target, f) + y_VV(idx_target, f);
            
            S0_f = abs(E_H_f)^2 + abs(E_V_f)^2;
            S1_f = abs(E_H_f)^2 - abs(E_V_f)^2;
            S2_f = 2 * real(E_H_f * conj(E_V_f));
            S3_f = 2 * imag(E_H_f * conj(E_V_f));
            
            s1_vals(f) = S1_f / (S0_f + eps);
            s2_vals(f) = S2_f / (S0_f + eps);
            s3_vals(f) = S3_f / (S0_f + eps);
        end
        
        plot3(s1_vals, s2_vals, s3_vals, 'k', 'LineWidth', 2);
        scatter3(s1_vals(end), s2_vals(end), s3_vals(end), 50, 'r', 'filled');
        
        xlabel('s1'); ylabel('s2'); zlabel('s3');
        title('Сфера Пуанкаре');
        axis equal;
        xlim([-1.2 1.2]); ylim([-1.2 1.2]); zlim([-1.2 1.2]);
        grid on;
        view(45, 30);

        % --- График 6: Информация ---
        subplot(2,3,6);
        axis off;
        text(0.1, 0.9, sprintf('Тип цели: %s', cfg.target_type), 'FontSize', 12, 'FontWeight', 'bold');
        text(0.1, 0.8, sprintf('Скорость вращения: %.1f град/с', cfg.target_rotation_speed), 'FontSize', 12);
        text(0.1, 0.7, sprintf('Импульс: %d / %d', frame, num_frames), 'FontSize', 12);
        text(0.1, 0.6, sprintf('Угол поворота: %.1f°', (frame-1) * cfg.target_rotation_speed * cfg.PRI), 'FontSize', 12);
        text(0.1, 0.4, 'Матрица рассеяния:', 'FontSize', 12, 'FontWeight', 'bold');
        text(0.1, 0.3, sprintf('HH = %.2f ∠ %.0f°', HH_norm(frame), HH_phase_vals(frame)), 'FontSize', 11);
        text(0.1, 0.2, sprintf('HV = %.2f ∠ %.0f°', HV_norm(frame), HV_phase_vals(frame)), 'FontSize', 11);
        text(0.1, 0.1, sprintf('VH = %.2f ∠ %.0f°', VH_norm(frame), VH_phase_vals(frame)), 'FontSize', 11);
        text(0.1, 0.0, sprintf('VV = %.2f ∠ %.0f°', VV_norm(frame), VV_phase_vals(frame)), 'FontSize', 11);

        % Пауза для анимации
        pause(0.1);
    end

    fprintf('Анимация завершена!\n');
end

% ===== ВСПОМОГАТЕЛЬНАЯ ФУНКЦИЯ: отрисовка эллипса =====
function draw_polarization_ellipse(s1, s2, s3, color, label)
    chi = 0.5 * asin(s3);
    psi = 0.5 * atan2(s2, s1);
    
    a = 1;
    b = a * tan(chi);
    
    theta = linspace(0, 2*pi, 100);
    x_ell = a * cos(theta);
    y_ell = b * sin(theta);
    
    R = [cos(psi), -sin(psi); sin(psi), cos(psi)];
    ell_rot = R * [x_ell; y_ell];
    
    plot(ell_rot(1,:), ell_rot(2,:), color, 'LineWidth', 2);
    hold on;
    
    quiver(0, 0, ell_rot(1,end), ell_rot(2,end), 0.1, color, 'LineWidth', 2, 'MaxHeadSize', 0.5);
    
    if nargin > 4 && ~isempty(label)
        text(ell_rot(1,1) + 0.1, ell_rot(2,1) + 0.1, label, 'Color', color, 'FontSize', 9);
    end
end

% ===== НОВАЯ ФУНКЦИЯ: обработка ДО ЧМП =====
function [y_HH, y_HV, y_VH, y_VV, R_y] = process_signal_pre_mti(rx_HH_cell, rx_HV_cell, rx_VH_cell, rx_VV_cell, x_active, cfg)
    % PROCESS_SIGNAL_PRE_MTI - Обработка ДО ЧМП (только согласованный фильтр)

    mf = phased.MatchedFilter('Coefficients', conj(flipud(x_active)));
    
    y_HH_cell = cell(1, cfg.NumPulses);
    y_HV_cell = cell(1, cfg.NumPulses);
    y_VH_cell = cell(1, cfg.NumPulses);
    y_VV_cell = cell(1, cfg.NumPulses);
    
    for pulse = 1:cfg.NumPulses
        y_HH_cell{pulse} = mf(rx_HH_cell{pulse});
        y_HV_cell{pulse} = mf(rx_HV_cell{pulse});
        y_VH_cell{pulse} = mf(rx_VH_cell{pulse});
        y_VV_cell{pulse} = mf(rx_VV_cell{pulse});
    end
    
    max_len = max([cellfun(@length, y_HH_cell), cellfun(@length, y_HV_cell), ...
                   cellfun(@length, y_VH_cell), cellfun(@length, y_VV_cell)]);
    
    y_HH = zeros(max_len, cfg.NumPulses);
    y_HV = zeros(max_len, cfg.NumPulses);
    y_VH = zeros(max_len, cfg.NumPulses);
    y_VV = zeros(max_len, cfg.NumPulses);
    
    for pulse = 1:cfg.NumPulses
        len_HH = length(y_HH_cell{pulse});
        len_HV = length(y_HV_cell{pulse});
        len_VH = length(y_VH_cell{pulse});
        len_VV = length(y_VV_cell{pulse});
        
        y_HH(1:len_HH, pulse) = y_HH_cell{pulse};
        y_HV(1:len_HV, pulse) = y_HV_cell{pulse};
        y_VH(1:len_VH, pulse) = y_VH_cell{pulse};
        y_VV(1:len_VV, pulse) = y_VV_cell{pulse};
    end

    % Ось дальности (по первому импульсу)
    t_y = (0:length(y_HH)-1)/cfg.Fs;
    t_y_corrected = t_y - (cfg.N_active - 1)/cfg.Fs;
    R_y = 3e8 * t_y_corrected / 2;
    idx = find(R_y > 0 & R_y < 20000);
    R_y = R_y(idx);
    y_HH = y_HH(idx, :);
    y_HV = y_HV(idx, :);
    y_VH = y_VH(idx, :);
    y_VV = y_VV(idx, :);
end