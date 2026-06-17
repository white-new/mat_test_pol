function cfg = config(varargin)
    % CONFIG - Конфигурация модели радара
    %
    %   cfg = config() - параметры по умолчанию
    %   cfg = config('SNR_dB', 15) - с измененным параметром

    %% =====================================================================
    %  1. ПАРАМЕТРЫ РАДАРА
    %  =====================================================================
    cfg.fc = 3e9;                   % Несущая частота, Гц
    cfg.BW = 1e6;                   % Полоса ЛЧМ, Гц
    cfg.PulseWidth = 20e-6;         % Длительность импульса, с
    cfg.PRF = 1e3;                  % Частота повторения импульсов, Гц
    cfg.Fs = 10 * cfg.BW;           % Частота дискретизации, Гц
    cfg.NumPulses = 32;             % Количество импульсов в пачке

    %% =====================================================================
    %  2. АНТЕННА
    %  =====================================================================
    cfg.antenna_type = 'parabolic'; % 'parabolic', 'phased_array', 'isotropic'
    cfg.altitude_radar = 10;        % Высота антенны над землей, м
    cfg.Diameter = 1.0;             % Диаметр зеркала, м
    cfg.AntennaEfficiency = 0.6;    % КПД антенны (0-1)
    
    % Для ФАР
    cfg.num_elements = 8;
    cfg.element_spacing = 0.05;
    cfg.taper_type = 'uniform';
    cfg.steering_angle_az = 0;
    cfg.steering_angle_el = 0;

    %% =====================================================================
    %  3. ОБЪЕКТЫ
    %  =====================================================================
    % --- Цель ---
    cfg.targetRange = 5000;
    cfg.targetSpeed = 25;
    cfg.targetDirection = 1;
    cfg.targetRCS = 10;
    cfg.targetHeight = 5;

    % --- Помеха ---
    cfg.clutterRange = 4000;
    cfg.clutterRCS = 100;           % 0 - отключить помеху
    cfg.clutterSpeed = 0;
    cfg.clutterHeight = 5;

    %% =====================================================================
    %  4. СРЕДА
    %  =====================================================================
    cfg.AtmosLoss_dB_per_km = 0.01;

    %% =====================================================================
    %  5. ПОЛЯРИЗАЦИОННАЯ МАТРИЦА (общая для всех объектов)
    %  =====================================================================
    cfg.polarization.HH_amp = 10;
    cfg.polarization.HH_phase = 0;
    cfg.polarization.HV_amp = 3;
    cfg.polarization.HV_phase = 45;
    cfg.polarization.VH_amp = 3;
    cfg.polarization.VH_phase = -30;
    cfg.polarization.VV_amp = 8;
    cfg.polarization.VV_phase = 20;

    %% =====================================================================
    %  6. ПАРАМЕТРЫ ОБРАБОТКИ
    %  =====================================================================
    cfg.SNR_dB = 20;
    cfg.Pfa = 1e-6;
    cfg.NoiseFigure_dB = 5;
    cfg.Threshold_rel = 0.25;

    %% =====================================================================
    %  7. ФЛАГИ УПРАВЛЕНИЯ (ВСЕ В ОДНОМ МЕСТЕ!)
    %  =====================================================================
    
    % --- Основные этапы ---
    cfg.enable.CHANNEL = true;          % Распространение сигнала
    cfg.enable.CLUTTER = true;          % Добавление помехи (clutter)
    cfg.enable.NOISE = true;            % Добавление шума
    cfg.enable.MATCHED_FILTER = true;   % Согласованный фильтр
    cfg.enable.MTI = true;              % ЧМП-фильтр
    cfg.enable.ACCUMULATION = true;     % Когерентное накопление
    cfg.enable.DETECTION = true;        % Обнаружение
    cfg.enable.DOPPLER = true;          % Доплеровская обработка
    
    % --- Графики (по отдельности!) ---
    cfg.enable.PLOTS = true;            % Основной figure (9 графиков)
    cfg.enable.PLOTS_RANGE = true;      % График дальности
    cfg.enable.PLOTS_DOPPLER = true;    % Доплеровские графики
    cfg.enable.PLOTS_PHASE = true;      % Фазовый портрет
    cfg.enable.PLOTS_SNR = true;        % Анализ SNR
    cfg.enable.PLOTS_DIAG = true;       % Диагностический график (импульсы)
    
    % --- Диагностика ---
    cfg.enable.VERBOSE = true;          % Подробный вывод в консоль
    cfg.enable.DIAGNOSTICS = true;      % Диагностика ЧМП

    %% =====================================================================
    %  8. ПРОИЗВОДНЫЕ ПАРАМЕТРЫ
    %  =====================================================================
    cfg.PRI = 1 / cfg.PRF;
    cfg.lambda = 3e8 / cfg.fc;
    cfg.N_active = round(cfg.PulseWidth * cfg.Fs);

    %% =====================================================================
    %  9. ОБНОВЛЕНИЕ ПАРАМЕТРОВ ИЗ АРГУМЕНТОВ
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
    %  10. ПЕЧАТЬ КОНФИГУРАЦИИ
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
        fprintf('Помеха:           %.1f км, RCS=%.1f\n', cfg.clutterRange/1000, cfg.clutterRCS);
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