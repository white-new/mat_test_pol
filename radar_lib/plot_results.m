function plot_results(x_active, x_full, t, rx_H_cell, y_H_MTI_norm, y_V_MTI_norm, detected_H, detected_V, R_y, cfg, results)
    % PLOT_RESULTS - Визуализация результатов обработки
    %
    %   Управление графиками через cfg.enable:
    %       PLOTS         - основной figure (все графики)
    %       PLOTS_RANGE   - график дальности
    %       PLOTS_DOPPLER - доплеровские графики
    %       PLOTS_PHASE   - фазовый портрет
    %       PLOTS_SNR     - анализ SNR
    %       PLOTS_DIAG    - диагностика по импульсам

    if ~cfg.enable.PLOTS || ~cfg.enable.CHANNEL
        return;
    end

    figure('Name', 'Радарная обработка', 'Position', [50 50 1400 900]);

    % ===== ГРАФИК 1: ЛЧМ сигнал (всегда) =====
    subplot(3,3,1);
    plot(t(1:cfg.N_active)*1e6, real(x_active), 'b', 'LineWidth', 1.5);
    xlabel('Время (мкс)'); ylabel('Амплитуда');
    title('ЛЧМ сигнал (реальная часть)');
    grid on;

    % ===== ГРАФИК 2: Принятый сигнал (всегда) =====
    subplot(3,3,2);
    plot(real(rx_H_cell{1}), 'b', 'LineWidth', 0.5);
    xlabel('Отсчет'); ylabel('Амплитуда');
    title('Принятый сигнал (H)');
    grid on;

% ===== ГРАФИК 3: Спектр ЛЧМ (двусторонний, как у реального сигнала) =====
subplot(3,3,3);
% Берём реальную часть для двустороннего спектра
x_real = real(x_full);
N_full = length(x_real);
freq = linspace(-cfg.Fs/2, cfg.Fs/2, N_full);
X = fftshift(fft(x_real));
X_norm = abs(X) / max(abs(X));

% Сдвигаем ось на несущую частоту
freq_shifted = freq + cfg.fc;

plot(freq_shifted/1e6, 20*log10(X_norm + eps), 'k', 'LineWidth', 1.5);
xlabel('Частота (МГц)'); ylabel('Амплитуда (дБ)');
title('Спектр ЛЧМ (реальный сигнал)');
grid on; 
xlim([cfg.fc/1e6 - 2, cfg.fc/1e6 + 2]);
ylim([-80 0]);

% Отмечаем несущую
xline(cfg.fc/1e6, 'g--', sprintf('f_c = %.0f МГц', cfg.fc/1e6), 'LineWidth', 1.5);

% Отмечаем границы полосы (двусторонний)
xline((cfg.fc - cfg.BW/2)/1e6, 'r--', sprintf('f_c-BW/2', cfg.BW/1e6), 'LineWidth', 1);
xline((cfg.fc + cfg.BW/2)/1e6, 'r--', sprintf('f_c+BW/2', cfg.BW/1e6), 'LineWidth', 1);

text(0.05, 0.95, sprintf('BW = %.1f МГц', cfg.BW/1e6), 'Units', 'normalized', 'FontSize', 9);
text(0.05, 0.88, sprintf('f_c = %.0f ГГц', cfg.fc/1e9), 'Units', 'normalized', 'FontSize', 9);

    % ===== ГРАФИК 4: Дальность (управляется PLOTS_RANGE) =====
    if cfg.enable.PLOTS_RANGE
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
    else
        subplot(3,3,4);
        axis off;
        text(0.5, 0.5, 'ГРАФИК ДАЛЬНОСТИ ОТКЛЮЧЕН', 'FontSize', 12, 'HorizontalAlignment', 'center');
    end

    % ===== ГРАФИК 5: Обнаружение (управляется PLOTS_RANGE) =====
    if cfg.enable.PLOTS_RANGE && cfg.enable.DETECTION
        subplot(3,3,5);
        plot(R_y/1000, detected_H, 'b', 'LineWidth', 2);
        hold on;
        plot(R_y/1000, detected_V, 'r', 'LineWidth', 2);
        xlabel('Дальность (км)'); ylabel('Обнаружено');
        title('Обнаружение');
        ylim([-0.1 1.1]);
        legend('H', 'V', 'Location', 'best');
        grid on; xlim([0 15]);
        xline(cfg.targetRange/1000, 'g--', 'Цель', 'LineWidth', 2);
        xline(cfg.clutterRange/1000, 'r--', 'Помеха', 'LineWidth', 2);
    else
        subplot(3,3,5);
        if cfg.enable.DETECTION
            axis off;
            text(0.5, 0.5, 'ОБНАРУЖЕНИЕ ВЫКЛЮЧЕНО', 'FontSize', 12, 'HorizontalAlignment', 'center');
        else
            axis off;
            text(0.5, 0.5, 'ГРАФИК ОБНАРУЖЕНИЯ ОТКЛЮЧЕН', 'FontSize', 12, 'HorizontalAlignment', 'center');
        end
    end

    % ===== ГРАФИК 6: Статус (всегда) =====
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

    % ===== ГРАФИК 7: Фазовый портрет (управляется PLOTS_PHASE) =====
    if cfg.enable.PLOTS_PHASE
        subplot(3,3,7);
        plot(real(rx_H_cell{1}), imag(rx_H_cell{1}), 'b.', 'MarkerSize', 1);
        xlabel('I'); ylabel('Q');
        title('Фазовый портрет (H)');
        axis equal; grid on;
    else
        subplot(3,3,7);
        axis off;
        text(0.5, 0.5, 'ФАЗОВЫЙ ПОРТРЕТ ОТКЛЮЧЕН', 'FontSize', 12, 'HorizontalAlignment', 'center');
    end

    % ===== ГРАФИК 8: Диагностика по импульсам (управляется PLOTS_DIAG) =====
    if cfg.enable.PLOTS_DIAG
        subplot(3,3,8);
        [~, idx_target] = min(abs(R_y - cfg.targetRange));
        [~, idx_clutter] = min(abs(R_y - cfg.clutterRange));
        plot(1:cfg.NumPulses, y_H_MTI_norm(idx_target) * ones(1, cfg.NumPulses), 'g--', 'LineWidth', 1);
        hold on;
        plot(1:cfg.NumPulses, y_H_MTI_norm(idx_clutter) * ones(1, cfg.NumPulses), 'r--', 'LineWidth', 1);
        xlabel('Номер импульса'); ylabel('Амплитуда');
        title('Сигнал по импульсам');
        grid on; legend('Цель', 'Помеха');
    else
        subplot(3,3,8);
        axis off;
        text(0.5, 0.5, 'ДИАГНОСТИКА ОТКЛЮЧЕНА', 'FontSize', 12, 'HorizontalAlignment', 'center');
    end

    % ===== ГРАФИК 9: SNR анализ (управляется PLOTS_SNR) =====
    if cfg.enable.PLOTS_SNR
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
    else
        subplot(3,3,9);
        axis off;
        text(0.5, 0.5, 'SNR АНАЛИЗ ОТКЛЮЧЕН', 'FontSize', 12, 'HorizontalAlignment', 'center');
    end

    % Если все графики отключены — показываем сообщение
    if ~cfg.enable.PLOTS_RANGE && ~cfg.enable.PLOTS_PHASE && ...
       ~cfg.enable.PLOTS_DIAG && ~cfg.enable.PLOTS_SNR
        clf;
        text(0.5, 0.5, 'ВСЕ ГРАФИКИ ОТКЛЮЧЕНЫ', 'FontSize', 16, 'HorizontalAlignment', 'center');
        axis off;
    end
end

function out = iif(cond, t, f)
    if cond, out = t; else, out = f; end
end