function targets = create_targets(cfg)
    % CREATE_TARGETS - Создание списка целей

    % Матрица рассеяния ЦЕЛИ (из cfg.target)
    PolMat = [
        cfg.target.HH_amp * exp(1j * cfg.target.HH_phase * pi/180), ...
        cfg.target.HV_amp * exp(1j * cfg.target.HV_phase * pi/180);
        cfg.target.VH_amp * exp(1j * cfg.target.VH_phase * pi/180), ...
        cfg.target.VV_amp * exp(1j * cfg.target.VV_phase * pi/180)
    ];

    targets = struct();

    targets(1).range = cfg.targetRange;
    targets(1).speed = cfg.targetSpeed;
    targets(1).direction = cfg.targetDirection;
    targets(1).rcs = cfg.targetRCS;
    targets(1).height = cfg.targetHeight;
    targets(1).polarization_matrix = PolMat;
    targets(1).is_clutter = false;

    fprintf('Создано %d целей\n', length(targets));
end