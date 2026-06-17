function plot_results(x_active, t, rx_H_cell, y_H_MTI_norm, y_V_MTI_norm, detected_H, detected_V, R_y, cfg, results)
    % PLOT_RESULTS - Визуализация результатов обработки

    if ~cfg.enable.PLOTS || ~cfg.enable.CHANNEL
        return;
    end

    figure('Name', 'Радарная обработка', 'Position', [50 50 1400 900]);

    % График 1: ЛЧМ
    subplot(3,3,1);
    plot(t(1:cfg.N_active)*1e6, real(x_active), 'b', 'LineWidth', 1.5);
    xlabel('Время (мкс)'); ylabel('Амплитуда');
    title('ЛЧМ сигнал');
    grid on;

    % График 2: Принятый сигнал
    subplot(3,3,2);
    plot(real(rx_H_cell{1}), 'b', 'LineWidth', 0.5);
    xlabel('Отсчет'); ylabel('Амплитуда');
    title('Принятый сигнал (H)');
    grid on;

    % График 3: Спектр
    subplot(3,3,3);
    freq = linspace(-cfg.Fs/2, cfg.Fs/2, cfg.N_active);
    X = fftshift(fft(x_active));
    plot(freq/1e6, abs(X), 'k', 'LineWidth', 1.5);
    xlabel('Частота (МГц)'); ylabel('|X|');
    title('Спектр ЛЧМ');
    grid on; xlim([-cfg.BW*2 cfg.BW*2]);

    % График 4: После обработки
    subplot(3,3,4);
    plot(R_y/1000, y_H_MTI_norm, 'b', 'LineWidth', 1.5);
    hold on;
    plot(R_y/1000, y_V_MTI_norm, 'r', 'LineWidth', 1.5);
    if cfg.enable.DETECTION
        yline(cfg.Threshold_rel, 'k--', 'Порог', 'LineWidth', 1.5);
    end
    xlabel('Дальность (км)'); ylabel('Амплитуда');
    title(['После обработки' iif(cfg.enable.MTI, ' (ЧМП)', '')]);
    grid on; xlim([0 15]);
    xline(cfg.targetRange/1000, 'g--', 'Цель', 'LineWidth', 2);
    xline(cfg.clutterRange/1000, 'r--', 'Помеха', 'LineWidth', 2);
    legend('H', 'V', 'Location', 'best');

    % График 5: Обнаружение
    subplot(3,3,5);
    if cfg.enable.DETECTION
        plot(R_y/1000, detected_H, 'b', 'LineWidth', 2);
        hold on;
        plot(R_y/1000, detected_V, 'r', 'LineWidth', 2);
        xlabel('Дальность (км)'); ylabel('Обнаружено');
        title('Обнаружение');
        ylim([-0.1 1.1]);
        legend('H', 'V', 'Location', 'best');
    else
        text(5, 0.5, 'ОБНАРУЖЕНИЕ ВЫКЛЮЧЕНО', 'FontSize', 14, 'HorizontalAlignment', 'center');
        title('Обнаружение');
    end
    grid on; xlim([0 15]);
    xline(cfg.targetRange/1000, 'g--', 'Цель', 'LineWidth', 2);
    xline(cfg.clutterRange/1000, 'r--', 'Помеха', 'LineWidth', 2);

    % График 6: Статус
    subplot(3,3,6);
    axis off;
    text(0.1, 0.8, 'РЕЗУЛЬТАТЫ:', 'FontSize', 12, 'FontWeight', 'bold');
    if cfg.enable.DETECTION
        if results.target_detected_H || results.target_detected_V
            status = '✅ ЦЕЛЬ ОБНАРУЖЕНА';
        else
            status = '❌ ЦЕЛЬ НЕ ОБНАРУЖЕНА';
        end
        text(0.1, 0.6, status, 'FontSize', 11);
        
        if ~results.clutter_detected_H && ~results.clutter_detected_V
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

    % График 7: Фазовый портрет
    subplot(3,3,7);
    plot(real(rx_H_cell{1}), imag(rx_H_cell{1}), 'b.', 'MarkerSize', 1);
    xlabel('I'); ylabel('Q');
    title('Фазовый портрет (H)');
    axis equal; grid on;

    % График 8: Амплитуда по импульсам (для диагностики)
    subplot(3,3,8);
    [~, idx_target] = min(abs(R_y - cfg.targetRange));
    [~, idx_clutter] = min(abs(R_y - cfg.clutterRange));
    plot(1:cfg.NumPulses, y_H_MTI_norm(idx_target) * ones(1, cfg.NumPulses), 'g--', 'LineWidth', 1);
    hold on;
    plot(1:cfg.NumPulses, y_H_MTI_norm(idx_clutter) * ones(1, cfg.NumPulses), 'r--', 'LineWidth', 1);
    xlabel('Номер импульса'); ylabel('Амплитуда');
    title('Сигнал по импульсам');
    grid on; legend('Цель', 'Помеха');

    % График 9: SNR анализ
    subplot(3,3,9);
    plot(R_y/1000, 20*log10(y_H_MTI_norm + eps), 'b', 'LineWidth', 1.5);
    hold on;
    plot(R_y/1000, 20*log10(y_V_MTI_norm + eps), 'r', 'LineWidth', 1.5);
    if cfg.enable.DETECTION
        yline(20*log10(cfg.Threshold_rel + eps), 'k--', 'Порог', 'LineWidth', 1.5);
    end
    xlabel('Дальность (км)'); ylabel('Амплитуда (дБ)');
    title('Уровень сигнала');
    grid on; xlim([0 15]);
    xline(cfg.targetRange/1000, 'g--', 'Цель', 'LineWidth', 2);
    xline(cfg.clutterRange/1000, 'r--', 'Помеха', 'LineWidth', 2);
    legend('H', 'V', 'Location', 'best');
end

function out = iif(cond, t, f)
    if cond, out = t; else, out = f; end
end