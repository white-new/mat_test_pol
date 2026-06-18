function clutters = create_clutters(cfg)
    % CREATE_CLUTTERS - Создание списка помех

    % Матрица рассеяния ПОМЕХИ (из cfg.clutter)
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

    fprintf('Создано %d помех\n', length(clutters));
end