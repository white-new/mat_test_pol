function clutters = create_distributed_clutter(cfg)
    % CREATE_DISTRIBUTED_CLUTTER - Создание распределённой помехи
    %
    %   clutters = create_distributed_clutter(cfg)
    %
    %   Вход:
    %       cfg - конфигурация с полями:
    %           clutter.num_points - количество точек помехи
    %           clutter.range_min - минимальная дальность
    %           clutter.range_max - максимальная дальность
    %           clutter.rcs_min - минимальная ЭПР
    %           clutter.rcs_max - максимальная ЭПР
    %           clutter.speed_min - минимальная скорость
    %           clutter.speed_max - максимальная скорость

    % Параметры по умолчанию (если не заданы)
    if ~isfield(cfg.clutter, 'num_points')
        cfg.clutter.num_points = 50;
        cfg.clutter.range_min = 1000;
        cfg.clutter.range_max = 10000;
        cfg.clutter.rcs_min = 0.1;
        cfg.clutter.rcs_max = 10;
        cfg.clutter.speed_min = -5;
        cfg.clutter.speed_max = 5;
    end

    num_points = cfg.clutter.num_points;
    
    % Случайные дальности
    ranges = cfg.clutter.range_min + (cfg.clutter.range_max - cfg.clutter.range_min) * rand(num_points, 1);
    
    % Случайные ЭПР (логнормальное распределение для реалистичности)
    rcs = exp(0.5 * randn(num_points, 1) + log(mean([cfg.clutter.rcs_min, cfg.clutter.rcs_max])));
    rcs = max(rcs, cfg.clutter.rcs_min);
    rcs = min(rcs, cfg.clutter.rcs_max);
    
    % Случайные скорости (для моделирования ветра)
    speeds = cfg.clutter.speed_min + (cfg.clutter.speed_max - cfg.clutter.speed_min) * rand(num_points, 1);
    
    % Случайные высоты (над землёй)
    heights = 0 + 2 * rand(num_points, 1);
    
    % Базовая поляризационная матрица (как у помехи)
    PolMat = [
        cfg.clutter.HH_amp * exp(1j * cfg.clutter.HH_phase * pi/180), ...
        cfg.clutter.HV_amp * exp(1j * cfg.clutter.HV_phase * pi/180);
        cfg.clutter.VH_amp * exp(1j * cfg.clutter.VH_phase * pi/180), ...
        cfg.clutter.VV_amp * exp(1j * cfg.clutter.VV_phase * pi/180)
    ];

    % Создаём структуру
    clutters = struct();
    
    for i = 1:num_points
        clutters(i).range = ranges(i);
        clutters(i).speed = speeds(i);
        clutters(i).direction = 1;
        clutters(i).rcs = rcs(i);
        clutters(i).height = heights(i);
        clutters(i).polarization_matrix = PolMat * (0.8 + 0.4 * rand);
        clutters(i).is_clutter = true;
        clutters(i).type = 'clutter';
        clutters(i).type_name = 'Распределённая помеха';
        clutters(i).rotate = false;
        clutters(i).rotation_speed = 0;
    end

    fprintf('Создано %d точек распределённой помехи\n', num_points);
end