function cfg = config(varargin)
    % CONFIG - Конфигурация модели радара
    %
    %   cfg = config() - параметры по умолчанию
    %   cfg = config('SNR_dB', 15) - с измененным параметром
    %
    %   Параметры (можно передавать парами 'имя', значение):
    %       fc, BW, PulseWidth, PRF, Fs, NumPulses
    %       antenna_type, altitude_radar, Diameter, AntennaEfficiency
    %       targetRange, targetSpeed, targetDirection, targetRCS
    %       clutterRange, clutterRCS, clutterSpeed
    %       SNR_dB, Pfa, NoiseFigure_dB, Threshold_rel
    %       enable.CHANNEL, enable.NOISE, enable.MTI, enable.DETECTION, enable.PLOTS

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
    % Тип антенны: 'parabolic' - зеркальная, 'phased_array' - ФАР, 'isotropic' - изотропная
    cfg.antenna_type = 'parabolic';
    
    % Высота антенны над землей, м
    cfg.altitude_radar = 10;
    
    % --- Для зеркальной антенны ---
    cfg.Diameter = 1.0;             % Диаметр зеркала, м
    cfg.AntennaEfficiency = 0.6;    % КПД антенны (0-1)
    
    % --- Для ФАР (phased_array) ---
    cfg.num_elements = 8;           % Количество элементов по горизонтали/вертикали (8x8 = 64 элемента)
    cfg.element_spacing = 0.05;     % Расстояние между элементами, м (для 3 ГГц λ=0.1 м, spacing=λ/2)
    cfg.taper_type = 'uniform';     % Тип амплитудного распределения: 'uniform', 'taylor', 'chebyshev'
    cfg.steering_angle_az = 0;      % Угол управления лучом по азимуту, град
    cfg.steering_angle_el = 0;      % Угол управления лучом по углу места, град

    %% =====================================================================
    %  3. ОБЪЕКТЫ (ЦЕЛИ И ПОМЕХИ)
    %  =====================================================================
    % --- Цель ---
    cfg.targetRange = 5000;         % Дальность до цели, м
    cfg.targetSpeed = 25;           % Скорость цели, м/с
    cfg.targetDirection = 1;        % 1 - приближается, -1 - удаляется
    cfg.targetRCS = 10;             % ЭПР цели, кв.м
    cfg.targetHeight = 5;           % Высота цели, м

    % --- Помеха ---
    cfg.clutterRange = 4000;        % Дальность до помехи, м
    cfg.clutterRCS = 0;           % ЭПР помехи, кв.м
    cfg.clutterSpeed = 0.1;           % Скорость помехи, м/с
    cfg.clutterHeight = 5;          % Высота помехи, м

    %% =====================================================================
    %  4. СРЕДА РАСПРОСТРАНЕНИЯ
    %  =====================================================================
    cfg.AtmosLoss_dB_per_km = 0.01; % Атмосферное затухание, дБ/км

    %% =====================================================================
    %  5. ПОЛЯРИЗАЦИОННАЯ МАТРИЦА (общая для всех объектов)
    %  =====================================================================
    cfg.polarization.HH_amp = 10;   % Амплитуда HH, кв.м
    cfg.polarization.HH_phase = 0;  % Фаза HH, град
    cfg.polarization.HV_amp = 3;    % Амплитуда HV, кв.м
    cfg.polarization.HV_phase = 45; % Фаза HV, град
    cfg.polarization.VH_amp = 3;    % Амплитуда VH, кв.м
    cfg.polarization.VH_phase = -30;% Фаза VH, град
    cfg.polarization.VV_amp = 8;    % Амплитуда VV, кв.м
    cfg.polarization.VV_phase = 20; % Фаза VV, град

    %% =====================================================================
    %  6. ПАРАМЕТРЫ ОБРАБОТКИ
    %  =====================================================================
    cfg.SNR_dB = 20;                % Отношение сигнал/шум, дБ
    cfg.Pfa = 1e-6;                 % Вероятность ложной тревоги
    cfg.NoiseFigure_dB = 5;         % Коэффициент шума приемника, дБ
    cfg.Threshold_rel = 0.25;       % Относительный порог (0-1)

    %% =====================================================================
    %  7. ФЛАГИ УПРАВЛЕНИЯ
    %  =====================================================================
    cfg.enable.CHANNEL = true;        % Распространение (цель + помеха)
    cfg.enable.NOISE = true;          % Добавление шума
    cfg.enable.MATCHED_FILTER = true; % Согласованный фильтр
    cfg.enable.MTI = true;            % ЧМП-фильтр (подавление помех)
    cfg.enable.ACCUMULATION = true;   % Когерентное накопление
    cfg.enable.DETECTION = true;      % Обнаружение (порог)
    cfg.enable.DOPPLER = true;        % Доплеровская обработка
    cfg.enable.PLOTS = true;          % Отрисовка графиков
    cfg.enable.SNR_ANALYSIS = true;   % Дополнительный график SNR

    %% =====================================================================
    %  8. ПРОИЗВОДНЫЕ ПАРАМЕТРЫ (НЕ ИЗМЕНЯТЬ ВРУЧНУЮ)
    %  =====================================================================
    cfg.PRI = 1 / cfg.PRF;          % Период повторения, с
    cfg.lambda = 3e8 / cfg.fc;      % Длина волны, м
    cfg.N_active = round(cfg.PulseWidth * cfg.Fs);  % Длина активной части

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
    %  10. ПЕЧАТЬ КОНФИГУРАЦИИ (если включено)
    %  =====================================================================
    if nargout == 0
        fprintf('\n========================================\n');
        fprintf('КОНФИГУРАЦИЯ РАДАРА\n');
        fprintf('========================================\n');
        fprintf('Несущая частота:  %.2f ГГц\n', cfg.fc/1e9);
        fprintf('Полоса сигнала:   %.2f МГц\n', cfg.BW/1e6);
        fprintf('Длительность:     %.2f мкс\n', cfg.PulseWidth*1e6);
        fprintf('PRF:              %.1f Гц\n', cfg.PRF);
        fprintf('Импульсов:        %d\n', cfg.NumPulses);
        fprintf('Тип антенны:      %s\n', cfg.antenna_type);
        fprintf('Высота антенны:   %.1f м\n', cfg.altitude_radar);
        if strcmp(cfg.antenna_type, 'parabolic')
            fprintf('Диаметр:          %.2f м\n', cfg.Diameter);
            fprintf('КПД:              %.2f\n', cfg.AntennaEfficiency);
        elseif strcmp(cfg.antenna_type, 'phased_array')
            fprintf('Элементов:        %dx%d\n', cfg.num_elements, cfg.num_elements);
            fprintf('Шаг решётки:      %.3f м\n', cfg.element_spacing);
        end
        fprintf('Цель:             %.1f км, %.1f м/с\n', cfg.targetRange/1000, cfg.targetSpeed);
        fprintf('Помеха:           %.1f км, %.1f м/с\n', cfg.clutterRange/1000, cfg.clutterSpeed);
        fprintf('SNR:              %.1f дБ\n', cfg.SNR_dB);
        fprintf('========================================\n');
    end
end