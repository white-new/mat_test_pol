function [x, x_active, t, cfg] = generate_lfm(cfg)
    % GENERATE_LFM - Генерация ЛЧМ сигнала
    %
    %   [x, x_active, t] = generate_lfm(cfg)
    %
    %   Вход:
    %       cfg - структура с параметрами
    %
    %   Выход:
    %       x        - полный импульс (с паузой) [N x 1]
    %       x_active - активная часть сигнала [N_active x 1]
    %       t        - временная ось [N x 1]

    waveform = phased.LinearFMWaveform(...
        'SampleRate', cfg.Fs, ...
        'SweepBandwidth', cfg.BW, ...
        'PulseWidth', cfg.PulseWidth, ...
        'PRF', cfg.PRF, ...
        'NumPulses', 1);

    x = step(waveform);
    N = length(x);
    t = (0:N-1)/cfg.Fs;
    x_active = x(1:cfg.N_active);

    fprintf('Длина импульса: %d отсчетов\n', N);
    fprintf('Активная часть: %d отсчетов\n', cfg.N_active);
end