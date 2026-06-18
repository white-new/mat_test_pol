function analyze_polarization(y_HH, y_HV, y_VH, y_VV, R_y, cfg)
    % analyze_polarization - Анализ поляризации
    %   y_HH, ... - матрицы [дальность × импульсы]
    %   R_y - ось дальности
    %   cfg - конфигурация

    fprintf('\n=== АНАЛИЗ ПОЛЯРИЗАЦИИ ===\n');

    % === 1. Берём данные на дальности цели (для анализа по импульсам) ===
    [~, idx_target] = min(abs(R_y - cfg.targetRange));
    
    y_HH_pulse = y_HH(idx_target, :);
    y_HV_pulse = y_HV(idx_target, :);
    y_VH_pulse = y_VH(idx_target, :);
    y_VV_pulse = y_VV(idx_target, :);

    % === 2. Берём первый импульс (для анализа по дальности) ===
    y_HH_range = y_HH(:, 1);
    y_HV_range = y_HV(:, 1);
    y_VH_range = y_VH(:, 1);
    y_VV_range = y_VV(:, 1);

    % === 3. Функция для расчёта Stokes ===
    function [S0, S1, S2, S3, s1, s2, s3, p] = calc_stokes(HH, HV, VH, VV)
        E_H = HH + VH;
        E_V = HV + VV;
        S0 = abs(E_H).^2 + abs(E_V).^2;
        S1 = abs(E_H).^2 - abs(E_V).^2;
        S2 = 2 * real(E_H .* conj(E_V));
        S3 = 2 * imag(E_H .* conj(E_V));
        s1 = S1 ./ (S0 + eps);
        s2 = S2 ./ (S0 + eps);
        s3 = S3 ./ (S0 + eps);
        p = sqrt(s1.^2 + s2.^2 + s3.^2);
    end

    % === 4. Считаем Stokes ===
    [S0_r, S1_r, S2_r, S3_r, s1_r, s2_r, s3_r, p_r] = calc_stokes(y_HH_range, y_HV_range, y_VH_range, y_VV_range);
    [S0_p, S1_p, S2_p, S3_p, s1_p, s2_p, s3_p, p_p] = calc_stokes(y_HH_pulse, y_HV_pulse, y_VH_pulse, y_VV_pulse);

% === 5. Средние и углы ===
s1_avg = mean(s1_p); s2_avg = mean(s2_p); s3_avg = mean(s3_p);

% Используем поэлементное возведение в квадрат
p_avg = sqrt(s1_avg.^2 + s2_avg.^2 + s3_avg.^2);

% Добавляем защиту от деления на ноль
if s1_avg == 0 && s2_avg == 0
    psi_avg = 0;
else
    psi_avg = 0.5 * atan2(s2_avg, s1_avg);
end
chi_avg = 0.5 * asin(max(min(s3_avg, 1), -1)); % Ограничиваем значение

fprintf('  Степень поляризации: %.3f\n', p_avg);
fprintf('  Угол эллиптичности: %.1f°\n', chi_avg * 180/pi);
fprintf('  Угол ориентации: %.1f°\n', psi_avg * 180/pi);

    % === 6. ГРАФИКИ ===
    figure('Name', 'Поляризационный анализ', 'Position', [100 100 1400 900]);

    % --- По дальности ---
    subplot(2,3,1);
    plot(R_y/1000, S0_r, 'k'); hold on;
    plot(R_y/1000, S1_r, 'r');
    plot(R_y/1000, S2_r, 'g');
    plot(R_y/1000, S3_r, 'b');
    xlabel('Дальность (км)'); ylabel('Stokes');
    title('Stokes по дальности');
    grid on; xlim([0 15]);
    xline(cfg.targetRange/1000, 'g--', 'Цель');

    subplot(2,3,2);
    plot(R_y/1000, s1_r, 'r'); hold on;
    plot(R_y/1000, s2_r, 'g');
    plot(R_y/1000, s3_r, 'b');
    xlabel('Дальность (км)'); ylabel('Норм. Stokes');
    title('Норм. Stokes по дальности');
    grid on; xlim([0 15]); ylim([-1.2 1.2]);
    xline(cfg.targetRange/1000, 'g--', 'Цель');

    subplot(2,3,3);
    plot(R_y/1000, p_r, 'b', 'LineWidth', 2);
    xlabel('Дальность (км)'); ylabel('Степень поляризации');
    title('Степень поляризации');
    grid on; xlim([0 15]); ylim([0 1.1]);
    xline(cfg.targetRange/1000, 'g--', 'Цель');

    % --- По импульсам ---
    subplot(2,3,4);
    plot(1:length(S0_p), S0_p, 'k'); hold on;
    plot(1:length(S1_p), S1_p, 'r');
    plot(1:length(S2_p), S2_p, 'g');
    plot(1:length(S3_p), S3_p, 'b');
    xlabel('Импульс'); ylabel('Stokes');
    title('Stokes по импульсам');
    grid on;

    subplot(2,3,5);
    plot(1:length(s1_p), s1_p, 'r'); hold on;
    plot(1:length(s2_p), s2_p, 'g');
    plot(1:length(s3_p), s3_p, 'b');
    xlabel('Импульс'); ylabel('Норм. Stokes');
    title('Норм. Stokes по импульсам');
    grid on; ylim([-1.2 1.2]);

    subplot(2,3,6);
    [X, Y, Z] = sphere(30);
    surf(X, Y, Z, 'FaceAlpha', 0.1, 'EdgeAlpha', 0.1, 'FaceColor', 'c');
    hold on;
    plot3(s1_p, s2_p, s3_p, 'k', 'LineWidth', 1.5);
    scatter3(s1_p(end), s2_p(end), s3_p(end), 80, 'r', 'filled');
    scatter3(s1_p(1), s2_p(1), s3_p(1), 80, 'g', 'filled');
    xlabel('s1'); ylabel('s2'); zlabel('s3');
    title('Сфера Пуанкаре');
    axis equal; grid on; view(45, 30);

    fprintf('\n✅ Поляризационный анализ завершён\n');
end