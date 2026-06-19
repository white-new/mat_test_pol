function clutters = create_clutters(cfg)
    % CREATE_CLUTTERS - Создание списка помех
    %   Если помеха выключена — возвращаем пустой массив
    %   Если clutter_type = 'distributed' — создаём распределённую помеху

    if cfg.clutterRCS == 0 || ~cfg.enable.CLUTTER
        clutters = struct();
        fprintf('Помеха ВЫКЛЮЧЕНА\n');
        return;
    end

    % Если включена распределённая помеха
    if isfield(cfg, 'clutter_type') && strcmp(cfg.clutter_type, 'distributed')
        clutters = create_distributed_clutter(cfg);
        return;
    end

    % ===== ТОЧЕЧНАЯ ПОМЕХА (как было) =====
    PolMat = [
        cfg.clutter.HH_amp * exp(1j * cfg.clutter.HH_phase * pi/180), ...
        cfg.clutter.HV_amp * exp(1j * cfg.clutter.HV_phase * pi/180);
        cfg.clutter.VH_amp * exp(1j * cfg.clutter.VH_phase * pi/180), ...
        cfg.clutter.VV_amp * exp(1j * cfg.clutter.VV_phase * pi/180)
    ];

    clutters = struct();

    clutters(1).range = cfg.clutterRange;
    clutters(1).speed = cfg.clutterSpeed;
    clutters(1).direction = 1;
    clutters(1).rcs = cfg.clutterRCS;
    clutters(1).height = cfg.clutterHeight;
    clutters(1).polarization_matrix = PolMat;
    clutters(1).is_clutter = true;
    clutters(1).type = 'clutter';
    clutters(1).type_name = 'Точечная помеха';
    clutters(1).rotate = false;
    clutters(1).rotation_speed = 0;

    fprintf('Создана точечная помеха (RCS=%.1f)\n', cfg.clutterRCS);
end