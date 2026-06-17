function [rx_H_cell, rx_V_cell] = add_noise(rx_H_cell, rx_V_cell, cfg)
    % ADD_NOISE - Добавление теплового шума
    %
    %   [rx_H_cell, rx_V_cell] = add_noise(rx_H_cell, rx_V_cell, cfg)

    if ~cfg.enable.NOISE || ~cfg.enable.CHANNEL
        fprintf('Шум ВЫКЛЮЧЕН\n');
        return;
    end

    signal_power = mean(abs(rx_H_cell{1}).^2);
    SNR_linear = 10^(cfg.SNR_dB/10);
    noise_power = signal_power / SNR_linear;

    for pulse = 1:cfg.NumPulses
        noise_H = sqrt(noise_power/2) * (randn(size(rx_H_cell{pulse})) + 1j*randn(size(rx_H_cell{pulse})));
        noise_V = sqrt(noise_power/2) * (randn(size(rx_V_cell{pulse})) + 1j*randn(size(rx_V_cell{pulse})));
        
        rx_H_cell{pulse} = rx_H_cell{pulse} + noise_H;
        rx_V_cell{pulse} = rx_V_cell{pulse} + noise_V;
    end

    fprintf('Шум добавлен (SNR = %.1f дБ)\n', cfg.SNR_dB);
end