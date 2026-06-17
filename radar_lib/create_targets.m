function targets = create_targets(cfg)
    % CREATE_TARGETS - Создание списка целей

    PolMat = [
        cfg.polarization.HH_amp * exp(1j * cfg.polarization.HH_phase * pi/180), ...
        cfg.polarization.HV_amp * exp(1j * cfg.polarization.HV_phase * pi/180);
        cfg.polarization.VH_amp * exp(1j * cfg.polarization.VH_phase * pi/180), ...
        cfg.polarization.VV_amp * exp(1j * cfg.polarization.VV_phase * pi/180)
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