function targets = create_targets(cfg)
    % CREATE_TARGETS - Создание списка целей

    % Если тип цели 'custom' — берём матрицу из cfg.target
    if strcmp(cfg.target_type, 'custom')
        PolMat = [
            cfg.target.HH_amp * exp(1j * cfg.target.HH_phase * pi/180), ...
            cfg.target.HV_amp * exp(1j * cfg.target.HV_phase * pi/180);
            cfg.target.VH_amp * exp(1j * cfg.target.VH_phase * pi/180), ...
            cfg.target.VV_amp * exp(1j * cfg.target.VV_phase * pi/180)
        ];
        type_name = 'Пользовательская цель';
    else
        [PolMat, type_name] = target_types(cfg.target_type, cfg.target_angle);
    end

    targets = struct();

    targets(1).range = cfg.targetRange;
    targets(1).speed = cfg.targetSpeed;
    targets(1).direction = cfg.targetDirection;
    targets(1).rcs = cfg.targetRCS;
    targets(1).height = cfg.targetHeight;
    targets(1).polarization_matrix = PolMat;
    targets(1).is_clutter = false;
    targets(1).type = cfg.target_type;
    targets(1).type_name = type_name;
    targets(1).rotate = cfg.target_rotate;
    targets(1).rotation_speed = cfg.target_rotation_speed;

    fprintf('Создано %d целей (тип: %s)\n', length(targets), type_name);
end