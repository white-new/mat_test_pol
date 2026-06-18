function [rx_HH_cell, rx_HV_cell, rx_VH_cell, rx_VV_cell] = add_noise_polarization(rx_HH_cell, rx_HV_cell, rx_VH_cell, rx_VV_cell, cfg)
    % ADD_NOISE_POLARIZATION - Добавление шума ко всем 4 каналам

    if ~cfg.enable.NOISE || ~cfg.enable.CHANNEL
        fprintf('Шум ВЫКЛЮЧЕН\n');
        return;
    end

    % Используем HH для оценки мощности сигнала
    signal_power = mean(abs(rx_HH_cell{1}).^2);
    SNR_linear = 10^(cfg.SNR_dB/10);
    noise_power = signal_power / SNR_linear;

    for pulse = 1:cfg.NumPulses
        % Генерируем шум для каждого канала
        noise_HH = sqrt(noise_power/2) * (randn(size(rx_HH_cell{pulse})) + 1j*randn(size(rx_HH_cell{pulse})));
        noise_HV = sqrt(noise_power/2) * (randn(size(rx_HV_cell{pulse})) + 1j*randn(size(rx_HV_cell{pulse})));
        noise_VH = sqrt(noise_power/2) * (randn(size(rx_VH_cell{pulse})) + 1j*randn(size(rx_VH_cell{pulse})));
        noise_VV = sqrt(noise_power/2) * (randn(size(rx_VV_cell{pulse})) + 1j*randn(size(rx_VV_cell{pulse})));
        
        rx_HH_cell{pulse} = rx_HH_cell{pulse} + noise_HH;
        rx_HV_cell{pulse} = rx_HV_cell{pulse} + noise_HV;
        rx_VH_cell{pulse} = rx_VH_cell{pulse} + noise_VH;
        rx_VV_cell{pulse} = rx_VV_cell{pulse} + noise_VV;
    end

    fprintf('Шум добавлен ко всем 4 каналам (SNR = %.1f дБ)\n', cfg.SNR_dB);
end