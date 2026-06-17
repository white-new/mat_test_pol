function clutters = create_clutters(cfg)
    % CREATE_CLUTTERS - Создание списка помех

    PolMat = [
        cfg.polarization.HH_amp * exp(1j * cfg.polarization.HH_phase * pi/180), ...
        cfg.polarization.HV_amp * exp(1j * cfg.polarization.HV_phase * pi/180);
        cfg.polarization.VH_amp * exp(1j * cfg.polarization.VH_phase * pi/180), ...
        cfg.polarization.VV_amp * exp(1j * cfg.polarization.VV_phase * pi/180)
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