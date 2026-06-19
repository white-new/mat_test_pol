function animate_target_3d(cfg)
    % ANIMATE_TARGET_3D - 3D-анимация вращения цели

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
    
    % Добавление шума
    [rx_HH_cell, rx_HV_cell, rx_VH_cell, rx_VV_cell] = ...
        add_noise_polarization(rx_HH_cell, rx_HV_cell, rx_VH_cell, rx_VV_cell, cfg);
    
    % ===== ИСПОЛЬЗУЕМ ДАННЫЕ ДО ЧМП =====
    [y_HH, y_HV, y_VH, y_VV, R_y] = ...
        process_signal_pre_mti(rx_HH_cell, rx_HV_cell, rx_VH_cell, rx_VV_cell, x_active, cfg);

    % Находим индекс цели
    [~, idx_target] = min(abs(R_y - cfg.targetRange));
    idx_target_int = round(idx_target);

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

    % ===== ОСНОВНОЙ ЦИКЛ СБОРА ДАННЫХ =====
    for pulse = 1:num_frames
        % 1. Сохраняем амплитуды
        HH_vals(pulse) = abs(y_HH(idx_target_int, pulse));
        HV_vals(pulse) = abs(y_HV(idx_target_int, pulse));
        VH_vals(pulse) = abs(y_VH(idx_target_int, pulse));
        VV_vals(pulse) = abs(y_VV(idx_target_int, pulse));
        
        % 2. Сохраняем фазы
        HH_phase_vals(pulse) = angle(y_HH(idx_target_int, pulse)) * 180/pi;
        HV_phase_vals(pulse) = angle(y_HV(idx_target_int, pulse)) * 180/pi;
        VH_phase_vals(pulse) = angle(y_VH(idx_target_int, pulse)) * 180/pi;
        VV_phase_vals(pulse) = angle(y_VV(idx_target_int, pulse)) * 180/pi;
        
        % 3. БЕРЁМ КОМПЛЕКСНЫЕ ЗНАЧЕНИЯ
        HH = y_HH(idx_target_int, pulse);
        HV = y_HV(idx_target_int, pulse);
        VH = y_VH(idx_target_int, pulse);
        VV = y_VV(idx_target_int, pulse);
        
        % 4. Квадраты модулей
        HH2 = abs(HH)^2;
        HV2 = abs(HV)^2;
        VH2 = abs(VH)^2;
        VV2 = abs(VV)^2;
        
        % 5. Stokes параметры
        S0 = HH2 + HV2 + VH2 + VV2;
        S1 = HH2 + HV2 - VH2 - VV2;
        S2 = 2 * real(HH * conj(VH) + HV * conj(VV));
        S3 = 2 * imag(HH * conj(VH) + HV * conj(VV));
        
        % 6. СОХРАНЯЕМ НОРМИРОВАННЫЕ STOKES В МАССИВЫ
        if S0 > 0
            s1_vals(pulse) = S1 / S0;
            s2_vals(pulse) = S2 / S0;
            s3_vals(pulse) = S3 / S0;
        else
            s1_vals(pulse) = 0;
            s2_vals(pulse) = 0;
            s3_vals(pulse) = 0;
        end
    end

    % ===== ПОШАГОВАЯ ДИАГНОСТИКА =====
    fprintf('\n========== ПОШАГОВАЯ ДИАГНОСТИКА ==========\n');
    for pulse = [1, 16, 32]
        HH = y_HH(idx_target_int, pulse);
        HV = y_HV(idx_target_int, pulse);
        VH = y_VH(idx_target_int, pulse);
        VV = y_VV(idx_target_int, pulse);
        
        HH2 = abs(HH)^2;
        HV2 = abs(HV)^2;
        VH2 = abs(VH)^2;
        VV2 = abs(VV)^2;
        S0 = HH2 + HV2 + VH2 + VV2;
        S1 = HH2 + HV2 - VH2 - VV2;
        S2 = 2 * real(HH * conj(VH) + HV * conj(VV));
        S3 = 2 * imag(HH * conj(VH) + HV * conj(VV));
        
        fprintf('\n--- Импульс %d ---\n', pulse);
        fprintf('HH = %.6e, HV = %.6e\n', HH, HV);
        fprintf('VH = %.6e, VV = %.6e\n', VH, VV);
        fprintf('S0 = %.6e, S1 = %.6e\n', S0, S1);
        fprintf('S2 = %.6e, S3 = %.6e\n', S2, S3);
        fprintf('s1 = %.6f, s2 = %.6f, s3 = %.6f (ИЗ МАССИВА)\n', ...
                s1_vals(pulse), s2_vals(pulse), s3_vals(pulse));
        fprintf('Матрица рассеяния:\n');
        fprintf('  [%.3f, %.3f]\n', HH, HV);
        fprintf('  [%.3f, %.3f]\n', VH, VV);
        
    end
    fprintf('============================================\n');
    % ===== ПАРАМЕТРЫ ЭЛЛИПСА ДЛЯ КОНТРОЛЬНЫХ ИМПУЛЬСОВ =====
    fprintf('\n========== ПАРАМЕТРЫ ЭЛЛИПСА ==========\n');
    for pulse = [1, 16, 32]
        s1 = s1_vals(pulse);
        s2 = s2_vals(pulse);
        s3 = s3_vals(pulse);
        
        chi = 0.5 * asin(s3);
        psi = 0.5 * atan2(s2, s1);
        
        fprintf('Имп. %d: s1=%.4f, s2=%.4f, s3=%.4f\n', pulse, s1, s2, s3);
        fprintf('  psi = %.1f°, chi = %.1f°\n', psi*180/pi, chi*180/pi);
    end
    fprintf('=========================================\n');
    % ===== ПРОВЕРКА ИЗМЕНЕНИЙ =====
    fprintf('\n=== ПРОВЕРКА ИЗМЕНЕНИЙ ===\n');
    fprintf('Имп. 1: s1=%.6f, s2=%.6f, s3=%.6f\n', s1_vals(1), s2_vals(1), s3_vals(1));
    fprintf('Имп. %d: s1=%.6f, s2=%.6f, s3=%.6f\n', num_frames, ...
            s1_vals(num_frames), s2_vals(num_frames), s3_vals(num_frames));
    
    delta_s1 = max(s1_vals) - min(s1_vals);
    delta_s2 = max(s2_vals) - min(s2_vals);
    delta_s3 = max(s3_vals) - min(s3_vals);
    fprintf('Размах: Δs1=%.6f, Δs2=%.6f, Δs3=%.6f\n', delta_s1, delta_s2, delta_s3);
    
    if delta_s1 < 1e-6 && delta_s2 < 1e-6 && delta_s3 < 1e-6
        fprintf('⚠️ Stokes параметры НЕ МЕНЯЮТСЯ!\n');
    else
        fprintf('✅ Stokes параметры МЕНЯЮТСЯ! Точка движется по сфере.\n');
    end

    % Нормировка амплитуд
    max_val = max([HH_vals; HV_vals; VH_vals; VV_vals]);
    if max_val == 0
        max_val = 1;
    end
    HH_norm = HH_vals / max_val;
    HV_norm = HV_vals / max_val;
    VH_norm = VH_vals / max_val;
    VV_norm = VV_vals / max_val;

    % Создаём фигуру
    fig = figure('Name', '3D-Анимация вращения цели', 'Position', [50 50 1400 900]);

    % Анимация
    for frame = 1:num_frames
        clf(fig);
        
        % ===== ГРАФИК 1: 3D-матрица рассеяния (амплитуды) =====
        subplot(2,3,1);
        S_amp = [HH_norm(frame), HV_norm(frame); 
                 VH_norm(frame), VV_norm(frame)];
        bar3(S_amp);
        colormap('hot');
        title(sprintf('Амплитуды (имп. %d)', frame));
        set(gca, 'XTick', [1 2], 'XTickLabel', {'H', 'V'});
        set(gca, 'YTick', [1 2], 'YTickLabel', {'H', 'V'});
        zlim([0 1.2]);
        view(45, 20);

        % ===== ГРАФИК 2: 3D-матрица рассеяния (фазы) =====
        subplot(2,3,2);
        S_phase = [HH_phase_vals(frame), HV_phase_vals(frame); 
                   VH_phase_vals(frame), VV_phase_vals(frame)];
        bar3(S_phase);
        colormap('hsv');
        title(sprintf('Фазы (имп. %d)', frame));
        set(gca, 'XTick', [1 2], 'XTickLabel', {'H', 'V'});
        set(gca, 'YTick', [1 2], 'YTickLabel', {'H', 'V'});
        zlim([-180 180]);
        view(45, 20);

        % ===== ГРАФИК 3: Амплитуды каналов по импульсам (3D) =====
        subplot(2,3,3);
        bar3_data = [HH_norm(1:frame), HV_norm(1:frame), ...
                     VH_norm(1:frame), VV_norm(1:frame)];
        bar3(bar3_data);
        colormap('parula');
        title('Амплитуды каналов');
        set(gca, 'XTick', [1 2 3 4], 'XTickLabel', {'HH', 'HV', 'VH', 'VV'});
        xlabel('Канал'); ylabel('Импульс'); zlabel('Амплитуда');
        zlim([0 1.2]);
        view(45, 30);

        % ===== ГРАФИК 4: 3D-Эллипс поляризации =====
        subplot(2,3,4);
        draw_3d_ellipsoid(s1_vals(frame), s2_vals(frame), s3_vals(frame), frame);
        title('3D-Эллипс поляризации');
        axis equal;
        xlim([-1.5 1.5]); ylim([-1.5 1.5]); zlim([-1.5 1.5]);
        grid on;
        view(45, 30);

        % ===== ГРАФИК 5: 3D-Сфера Пуанкаре с траекторией =====
        subplot(2,3,5);
        [X, Y, Z] = sphere(20);
        surf(X, Y, Z, 'FaceAlpha', 0.1, 'EdgeAlpha', 0.1, 'FaceColor', 'c');
        hold on;
        
        % Траектория (линия)
        plot3(s1_vals(1:frame), s2_vals(1:frame), s3_vals(1:frame), ...
              'k', 'LineWidth', 2);
        
        % Текущая точка (красная)
        scatter3(s1_vals(frame), s2_vals(frame), s3_vals(frame), ...
                 100, 'r', 'filled', 'MarkerEdgeColor', 'k');
        
        % Начальная точка (зелёная)
        scatter3(s1_vals(1), s2_vals(1), s3_vals(1), ...
                 80, 'g', 'filled', 'MarkerEdgeColor', 'k');
        
        % Оси
        plot3([-1.2 1.2], [0 0], [0 0], 'k--', 'LineWidth', 0.5);
        plot3([0 0], [-1.2 1.2], [0 0], 'k--', 'LineWidth', 0.5);
        plot3([0 0], [0 0], [-1.2 1.2], 'k--', 'LineWidth', 0.5);
        
        xlabel('s1 (H/V)'); ylabel('s2 (±45°)'); zlabel('s3 (круговая)');
        title('Сфера Пуанкаре');
        grid on;
        axis equal;
        xlim([-1.2 1.2]); ylim([-1.2 1.2]); zlim([-1.2 1.2]);
        legend('Сфера', 'Траектория', 'Текущая', 'Начало', 'Location', 'best');
        view(45, 30);

 % ===== ГРАФИК 6: Фазы каналов по импульсам =====
        subplot(2,3,6);
        plot(1:frame, HH_phase_vals(1:frame), 'b', 'LineWidth', 2);
        hold on;
        plot(1:frame, HV_phase_vals(1:frame), 'r', 'LineWidth', 2);
        plot(1:frame, VH_phase_vals(1:frame), 'g', 'LineWidth', 2);
        plot(1:frame, VV_phase_vals(1:frame), 'm', 'LineWidth', 2);
        xlabel('Импульс'); ylabel('Фаза (градусы)');
        title('Фазы каналов по импульсам');
        grid on;
        legend('HH', 'HV', 'VH', 'VV', 'Location', 'best');
        ylim([-180 180]);
        xlim([0 num_frames+1]);

        pause(0.15);
    end

    fprintf('3D-анимация завершена!\n');
end

% ===== ВСПОМОГАТЕЛЬНАЯ ФУНКЦИЯ: 3D-эллипсоид =====
function draw_3d_ellipsoid(s1, s2, s3, frame)
    % DRAW_3D_ELLIPSOID - Отрисовка 3D-эллипсоида поляризации
    
    chi = 0.5 * asin(s3);
    psi = 0.5 * atan2(s2, s1);
    
    a = 1;
    b = a * tan(chi);
    % Если chi = 0, b = 0 — эллипс вырождается, делаем его видимым
    if b < 0.01
        b = 0.01;  % минимальная толщина для видимости
    end
    c = 0.1;
    
    [X, Y, Z] = ellipsoid(0, 0, 0, a, b, c, 30);
    
    R1 = [cos(psi), -sin(psi), 0; sin(psi), cos(psi), 0; 0, 0, 1];
    R2 = [1, 0, 0; 0, cos(chi), -sin(chi); 0, sin(chi), cos(chi)];
    R = R1 * R2;
    
    for i = 1:size(X,1)
        for j = 1:size(X,2)
            v = [X(i,j); Y(i,j); Z(i,j)];
            v_rot = R * v;
            X(i,j) = v_rot(1);
            Y(i,j) = v_rot(2);
            Z(i,j) = v_rot(3);
        end
    end
    
    surf(X, Y, Z, 'FaceColor', 'b', 'FaceAlpha', 0.6, 'EdgeAlpha', 0.3);
    hold on;
    
    plot3([-1.5 1.5], [0 0], [0 0], 'k--', 'LineWidth', 0.5);
    plot3([0 0], [-1.5 1.5], [0 0], 'k--', 'LineWidth', 0.5);
    plot3([0 0], [0 0], [-1.5 1.5], 'k--', 'LineWidth', 0.5);
    
    text(0, 0, 0, sprintf('%d', frame), 'FontSize', 8, 'Color', 'w', ...
         'HorizontalAlignment', 'center');
end