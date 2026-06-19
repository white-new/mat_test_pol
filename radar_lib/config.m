function cfg = config(varargin)
    % CONFIG - Конфигурация модели радара

    %% =====================================================================
    %  1. ПАРАМЕТРЫ РАДАРА
    %  =====================================================================
    cfg.fc = 3e9;
    cfg.BW = 1e6;
    cfg.PulseWidth = 20e-6;
    cfg.PRF = 1e3;
    cfg.Fs = 10 * cfg.BW;
    cfg.NumPulses = 32;

    %% =====================================================================
    %  2. АНТЕННА
    %  =====================================================================
    cfg.antenna_type = 'parabolic';
    cfg.altitude_radar = 10;
    cfg.Diameter = 1.0;
    cfg.AntennaEfficiency = 0.6;
    
    cfg.num_elements = 8;
    cfg.element_spacing = 0.05;
    cfg.taper_type = 'uniform';
    cfg.steering_angle_az = 0;
    cfg.steering_angle_el = 0;
    
    switch cfg.taper_type
        case 'uniform'
            cfg.taper = ones(1, cfg.num_elements);
        case 'taylor'
            cfg.taper = taylorwin(cfg.num_elements)';
        case 'chebyshev'
            cfg.taper = chebwin(cfg.num_elements, 30)';
        otherwise
            cfg.taper = ones(1, cfg.num_elements);
    end

    %% =====================================================================
    %  3. ОБЪЕКТЫ
    %  =====================================================================
    % --- Цель ---
    cfg.targetRange = 5000;
    cfg.targetSpeed = 25;
    cfg.targetDirection = 1;
    cfg.targetRCS = 10;
    cfg.targetHeight = 5;
    cfg.target_type = 'custom';
    cfg.target_angle = 0;
    cfg.target_rotate = false;
    cfg.target_rotation_speed = 10;

    % --- Помеха ---
    cfg.clutterRange = 4000;
    cfg.clutterRCS = 0;
    cfg.clutterSpeed = 0;
    cfg.clutterHeight = 5;
    
    % НОВОЕ: Тип помехи и параметры распределённой помехи
    cfg.clutter_type = 'point';   % 'point' - точечная, 'distributed' - распределённая
    cfg.clutter.num_points = 50;
    cfg.clutter.range_min = 1000;
    cfg.clutter.range_max = 10000;
    cfg.clutter.rcs_min = 0.1;
    cfg.clutter.rcs_max = 10;
    cfg.clutter.speed_min = -5;
    cfg.clutter.speed_max = 5;
    % Для распределённой помехи:
    % cfg.clutter_type = 'distributed';
    % cfg.clutter.num_points = 100;  % количество точек
    % cfg.clutter.range_min = 1000;
    % cfg.clutter.range_max = 10000;
    %% =====================================================================
    %  4. СРЕДА
    %  =====================================================================
    cfg.AtmosLoss_dB_per_km = 0.01;

    %% =====================================================================
    %  5. ПОЛЯРИЗАЦИОННЫЕ МАТРИЦЫ
    %  =====================================================================
    cfg.target.HH_amp = 10;
    cfg.target.HH_phase = 0;
    cfg.target.HV_amp = 3;
    cfg.target.HV_phase = 45;
    cfg.target.VH_amp = 3;
    cfg.target.VH_phase = -30;
    cfg.target.VV_amp = 8;
    cfg.target.VV_phase = 20;

    cfg.clutter.HH_amp = 5;
    cfg.clutter.HH_phase = 10;
    cfg.clutter.HV_amp = 0.5;
    cfg.clutter.HV_phase = 30;
    cfg.clutter.VH_amp = 0.5;
    cfg.clutter.VH_phase = -20;
    cfg.clutter.VV_amp = 4;
    cfg.clutter.VV_phase = 15;

    %% =====================================================================
    %  6. ПАРАМЕТРЫ ОБРАБОТКИ
    %  =====================================================================
    cfg.SNR_dB = 20;
    cfg.Pfa = 1e-6;
    cfg.NoiseFigure_dB = 5;
    cfg.Threshold_rel = 0.25;

    %% =====================================================================
    %  7. ФЛАГИ УПРАВЛЕНИЯ
    %  =====================================================================
    cfg.enable.CHANNEL = true;
    cfg.enable.CLUTTER = true;
    cfg.enable.NOISE = true;
    cfg.enable.MATCHED_FILTER = true;
    cfg.enable.MTI = true;
    cfg.enable.ACCUMULATION = true;
    cfg.enable.DETECTION = true;
    cfg.enable.DOPPLER = true;
    cfg.enable.FLUCTUATIONS = true;
    cfg.enable.POLARIZATION_ANALYSIS_PRE_MTI = true;
    
    cfg.enable.PLOTS = true;
    cfg.enable.PLOTS_RANGE = true;
    cfg.enable.PLOTS_DOPPLER = true;
    cfg.enable.PLOTS_PHASE = true;
    cfg.enable.PLOTS_SNR = true;
    cfg.enable.PLOTS_DIAG = true;
    
    cfg.enable.VERBOSE = true;
    cfg.enable.DIAGNOSTICS = true;

    %% =====================================================================
    %  8. ПРОИЗВОДНЫЕ
    %  =====================================================================
    cfg.PRI = 1 / cfg.PRF;
    cfg.lambda = 3e8 / cfg.fc;
    cfg.N_active = round(cfg.PulseWidth * cfg.Fs);

    %% =====================================================================
    %  9. ОБНОВЛЕНИЕ ИЗ АРГУМЕНТОВ
    %  =====================================================================
    if nargin > 0
        for i = 1:2:nargin
            field = varargin{i};
            if ischar(field) && isfield(cfg, field)
                cfg.(field) = varargin{i+1};
            elseif ischar(field) && isfield(cfg.enable, field)
                cfg.enable.(field) = varargin{i+1};
            end
        end
    end

    %% =====================================================================
    %  10. ПЕЧАТЬ
    %  =====================================================================
    if nargout == 0 || cfg.enable.VERBOSE
        fprintf('\n========================================\n');
        fprintf('КОНФИГУРАЦИЯ РАДАРА\n');
        fprintf('========================================\n');
        fprintf('Несущая частота:  %.2f ГГц\n', cfg.fc/1e9);
        fprintf('Полоса:           %.2f МГц\n', cfg.BW/1e6);
        fprintf('PRF:              %.1f Гц\n', cfg.PRF);
        fprintf('Импульсов:        %d\n', cfg.NumPulses);
        fprintf('Цель:             %.1f км, %.1f м/с\n', cfg.targetRange/1000, cfg.targetSpeed);
        fprintf('Тип помехи:        %s\n', cfg.clutter_type);
        fprintf('SNR:              %.1f дБ\n', cfg.SNR_dB);
        fprintf('----------------------------------------\n');
        fprintf('ФЛАГИ:\n');
        fprintf('  CLUTTER:   %s\n', iif(cfg.enable.CLUTTER, 'ON', 'OFF'));
        fprintf('  NOISE:     %s\n', iif(cfg.enable.NOISE, 'ON', 'OFF'));
        fprintf('  MTI:       %s\n', iif(cfg.enable.MTI, 'ON', 'OFF'));
        fprintf('  DETECTION: %s\n', iif(cfg.enable.DETECTION, 'ON', 'OFF'));
        fprintf('========================================\n');
    end
end

function out = iif(cond, t, f)
    if cond, out = t; else, out = f; end
end