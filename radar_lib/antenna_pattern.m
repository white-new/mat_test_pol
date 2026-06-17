function gain = antenna_pattern(az, el, antenna)
    % ANTENNA_PATTERN - Диаграмма направленности антенны
    %
    %   gain = antenna_pattern(az, el, antenna)
    %
    %   Вход:
    %       az, el   - азимут и угол места (градусы)
    %       antenna  - структура антенны
    %
    %   Выход:
    %       gain     - коэффициент усиления в направлении (az, el)

    if isfield(antenna, 'pattern')
        gain = antenna.gain_linear * antenna.pattern(az, el);
    else
        gain = antenna.gain_linear;
    end
end