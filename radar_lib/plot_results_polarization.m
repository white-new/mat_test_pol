function plot_results_polarization(x_active, t, rx_HH_cell, y_HH, y_HV, y_VH, y_VV, R_y, cfg, results)
    % PLOT_RESULTS_POLARIZATION - Визуализация 4 поляризационных каналов
    %   Использует КОМПЛЕКСНЫЕ значения

    if ~cfg.enable.PLOTS || ~cfg.enable.CHANNEL
        return;
    end

    % === Вычисляем амплитуды и фазы ===
    HH_abs = abs(y_HH);
    HV_abs = abs(y_HV);
    VH_abs = abs(y_VH);
    VV_abs = abs(y_VV);
    
    HH_phase = angle(y_HH) * 180/pi;
    HV_phase = angle(y_HV) * 180/pi;
    VH_phase = angle(y_VH) * 180/pi;
    VV_phase = angle(y_VV) * 180/pi;

    % Нормируем амплитуды КАЖДОГО канала отдельно для отображения
    HH_norm = HH_abs / (max(HH_abs) + eps);
    HV_norm = HV_abs / (max(HV_abs) + eps);
    VH_norm = VH_abs / (max(VH_abs) + eps);
    VV_norm = VV_abs / (max(VV_abs) + eps);

    figure('Name', 'Радарная обработка (4 канала)', 'Position', [50 50 1400 900]);

    % ===== ГРАФИК 1: ЛЧМ сигнал =====
    subplot(3,3,1);
    plot(t(1:cfg.N_active)*1e6, real(x_active), 'b', 'LineWidth', 1.5);
    xlabel('Время (мкс)'); ylabel('Амплитуда');
    title('ЛЧМ сигнал');
    grid on;

    % ===== ГРАФИК 2: Принятый сигнал (HH) =====
    subplot(3,3,2);
    plot(real(rx_HH_cell{1}), 'b', 'LineWidth', 0.5);
    xlabel('Отсчет'); ylabel('Амплитуда');
    title('Принятый сигнал (HH)');
    grid on;

    % ===== ГРАФИК 3: Спектр ЛЧМ =====
    subplot(3,3,3);
    x_real = real(x_active);
    N_full = length(x_real);
    freq = linspace(-cfg.Fs/2, cfg.Fs/2, N_full);
    X = fftshift(fft(x_real));
    X_norm = abs(X) / max(abs(X));
    freq_shifted = freq + cfg.fc;
    plot(freq_shifted/1e6, 20*log10(X_norm + eps), 'k', 'LineWidth', 1.5);
    xlabel('Частота (МГц)'); ylabel('Амплитуда (дБ)');
    title('Спектр ЛЧМ');
    grid on;
    xlim([cfg.fc/1e6 - 2, cfg.fc/1e6 + 2]);
    ylim([-80 0]);
    xline(cfg.fc/1e6, 'g--', sprintf('f_c = %.0f МГц', cfg.fc/1e6), 'LineWidth', 1.5);
    xline((cfg.fc - cfg.BW/2)/1e6, 'r--', sprintf('f_c-BW/2', cfg.BW/1e6), 'LineWidth', 1);
    xline((cfg.fc + cfg.BW/2)/1e6, 'r--', sprintf('f_c+BW/2', cfg.BW/1e6), 'LineWidth', 1);

    % ===== ГРАФИК 4: Все 4 канала =====
    subplot(3,3,4);
    plot(R_y/1000, HH_norm, 'b', 'LineWidth', 1.5);
    hold on;
    plot(R_y/1000, HV_norm, 'r', 'LineWidth', 1.5);
    plot(R_y/1000, VH_norm, 'g', 'LineWidth', 1.5);
    plot(R_y/1000, VV_norm, 'm', 'LineWidth', 1.5);
    if cfg.enable.DETECTION
        yline(cfg.Threshold_rel, 'k--', 'Порог', 'LineWidth', 1.5);
    end
    xlabel('Дальность (км)'); ylabel('Норм. амплитуда');
    title('Все 4 канала');
    grid on; xlim([0 15]);
    xline(cfg.targetRange/1000, 'g--', 'Цель', 'LineWidth', 2);
    xline(cfg.clutterRange/1000, 'r--', 'Помеха', 'LineWidth', 2);
    legend('HH', 'HV', 'VH', 'VV', 'Location', 'best');

    % ===== ГРАФИК 5: Матрица рассеяния (АМПЛИТУДЫ) =====
    subplot(3,3,5);
    [~, idx_target] = min(abs(R_y - cfg.targetRange));
    
    % Берём значения НА ПИКЕ (idx_target)
    HH_abs_target = abs(y_HH(idx_target));
    HV_abs_target = abs(y_HV(idx_target));
    VH_abs_target = abs(y_VH(idx_target));
    VV_abs_target = abs(y_VV(idx_target));
    
    S_target = [HH_abs_target, HV_abs_target; 
                VH_abs_target, VV_abs_target];
    S_target_norm = S_target / max(S_target(:));
    
    imagesc(S_target_norm);
    colorbar;
    colormap('hot');
    title(sprintf('Матрица рассеяния (цель %.1f км)', cfg.targetRange/1000));
    set(gca, 'XTick', [1 2], 'XTickLabel', {'H', 'V'});
    set(gca, 'YTick', [1 2], 'YTickLabel', {'H', 'V'});
    for i = 1:2
        for j = 1:2
            text(j, i, sprintf('%.3f', S_target_norm(i,j)), ...
                 'HorizontalAlignment', 'center', 'Color', 'w', 'FontSize', 12);
        end
    end

    % ===== ГРАФИК 6: Статус =====
    subplot(3,3,6);
    axis off;
    text(0.1, 0.8, 'РЕЗУЛЬТАТЫ:', 'FontSize', 12, 'FontWeight', 'bold');
    if cfg.enable.DETECTION
        if results.target_detected_HH || results.target_detected_HV || ...
           results.target_detected_VH || results.target_detected_VV
            status = '✅ ЦЕЛЬ ОБНАРУЖЕНА';
        else
            status = '❌ ЦЕЛЬ НЕ ОБНАРУЖЕНА';
        end
        text(0.1, 0.6, status, 'FontSize', 11);
        
        if ~results.clutter_detected_HH && ~results.clutter_detected_HV && ...
           ~results.clutter_detected_VH && ~results.clutter_detected_VV
            status = '✅ ПОМЕХА ПОДАВЛЕНА';
        else
            status = '⚠️ ПОМЕХА НЕ ПОДАВЛЕНА';
        end
        text(0.1, 0.4, status, 'FontSize', 11);
    else
        text(0.1, 0.6, 'ОБНАРУЖЕНИЕ ВЫКЛЮЧЕНО', 'FontSize', 11);
    end
    text(0.1, 0.2, ['SNR: ' num2str(cfg.SNR_dB) ' дБ'], 'FontSize', 11);
    text(0.1, 0.05, ['Импульсов: ' num2str(cfg.NumPulses)], 'FontSize', 11);

    % ===== ГРАФИК 7: Фазы матрицы =====
    subplot(3,3,7);
    HH_phase_target = angle(y_HH(idx_target)) * 180/pi;
    HV_phase_target = angle(y_HV(idx_target)) * 180/pi;
    VH_phase_target = angle(y_VH(idx_target)) * 180/pi;
    VV_phase_target = angle(y_VV(idx_target)) * 180/pi;
    
    S_target_phase = [HH_phase_target, HV_phase_target; 
                      VH_phase_target, VV_phase_target];
    imagesc(S_target_phase);
    colorbar;
    colormap('hsv');
    title(sprintf('Фазы матрицы (цель %.1f км, град)', cfg.targetRange/1000));
    set(gca, 'XTick', [1 2], 'XTickLabel', {'H', 'V'});
    set(gca, 'YTick', [1 2], 'YTickLabel', {'H', 'V'});
    for i = 1:2
        for j = 1:2
            text(j, i, sprintf('%.0f', S_target_phase(i,j)), ...
                 'HorizontalAlignment', 'center', 'Color', 'w', 'FontSize', 12);
        end
    end

    % ===== ГРАФИК 8: Сравнение каналов =====
    subplot(3,3,8);
    channels = {'HH', 'HV', 'VH', 'VV'};
    
    % Индексы цели и помехи
    [~, idx_target] = min(abs(R_y - cfg.targetRange));
    [~, idx_clutter] = min(abs(R_y - cfg.clutterRange));
    
    target_amps = [abs(y_HH(idx_target)), abs(y_HV(idx_target)), ...
                   abs(y_VH(idx_target)), abs(y_VV(idx_target))];
    clutter_amps = [abs(y_HH(idx_clutter)), abs(y_HV(idx_clutter)), ...
                    abs(y_VH(idx_clutter)), abs(y_VV(idx_clutter))];
    bar([target_amps; clutter_amps]');
    set(gca, 'XTickLabel', channels);
    xlabel('Канал'); ylabel('Амплитуда');
    title('Абсолютные амплитуды каналов');
    legend('Цель', 'Помеха', 'Location', 'best');
    grid on;

    % ===== ГРАФИК 9: Уровень сигнала (дБ) =====
    subplot(3,3,9);
    plot(R_y/1000, 20*log10(HH_abs + eps), 'b', 'LineWidth', 1.5);
    hold on;
    plot(R_y/1000, 20*log10(HV_abs + eps), 'r', 'LineWidth', 1.5);
    plot(R_y/1000, 20*log10(VH_abs + eps), 'g', 'LineWidth', 1.5);
    plot(R_y/1000, 20*log10(VV_abs + eps), 'm', 'LineWidth', 1.5);
    if cfg.enable.DETECTION
        yline(20*log10(cfg.Threshold_rel + eps), 'k--', 'Порог', 'LineWidth', 1.5);
    end
    xlabel('Дальность (км)'); ylabel('Амплитуда (дБ)');
    title('Уровень сигнала (все каналы)');
    grid on; xlim([0 15]);
    xline(cfg.targetRange/1000, 'g--', 'Цель', 'LineWidth', 2);
    xline(cfg.clutterRange/1000, 'r--', 'Помеха', 'LineWidth', 2);
    legend('HH', 'HV', 'VH', 'VV', 'Location', 'best');
end