function antenna = create_antenna(cfg)
    % CREATE_ANTENNA - Создание антенны
    %
    %   antenna = create_antenna(cfg)
    %
    %   Выход:
    %       antenna - структура с полями:
    %           .type        - 'parabolic' или 'phased_array'
    %           .position    - [x; y; z] положение в пространстве
    %           .orientation - [az; el] направление луча
    %           .diameter    - диаметр (для зеркальной)
    %           .efficiency  - КПД
    %           .gain        - коэффициент усиления (рассчитывается)
    %           .taper       - амплитудное распределение (для ФАР)
    %           .num_elements - число элементов (для ФАР)
    %           .element_spacing - расстояние между элементами (для ФАР)
    %           .beamwidth   - ширина луча
    %           .pattern     - функция для диаграммы направленности

    switch cfg.antenna_type
        case 'parabolic'
            % === ЗЕРКАЛЬНАЯ АНТЕННА ===
            antenna.type = 'parabolic';
            antenna.position = [0; 0; cfg.altitude_radar];
            antenna.orientation = [0; 0];  % азимут, угол места
            antenna.diameter = cfg.Diameter;
            antenna.efficiency = cfg.AntennaEfficiency;
            
            % Расчёт усиления
            AperturePhysical = pi * (antenna.diameter/2)^2;
            EffectiveAperture = antenna.efficiency * AperturePhysical;
            antenna.gain_dBi = aperture2gain(EffectiveAperture, cfg.lambda);
            antenna.gain_linear = 10^(antenna.gain_dBi/10);
            
            % Ширина луча
            antenna.beamwidth = 1.22 * cfg.lambda / antenna.diameter * 180/pi;
            
            % Диаграмма направленности (гауссова аппроксимация)
            antenna.pattern = @(az, el) exp(-2.77 * ((az)^2 + (el)^2) / (antenna.beamwidth/2)^2);
            
            fprintf('Создана зеркальная антенна: D=%.2f м, Gain=%.2f дБи\n', ...
                    antenna.diameter, antenna.gain_dBi);
            
        case 'phased_array'
            % === ФАЗИРОВАННАЯ АНТЕННАЯ РЕШЁТКА ===
            antenna.type = 'phased_array';
            antenna.position = [0; 0; cfg.altitude_radar];
            antenna.orientation = [0; 0];
            antenna.num_elements = cfg.num_elements;
            antenna.element_spacing = cfg.element_spacing;
            antenna.taper = cfg.taper;  % амплитудное распределение
            
            % Расчёт усиления ФАР
            % G = 4*pi*A/λ^2 * efficiency
            AperturePhysical = (antenna.num_elements * antenna.element_spacing)^2;
            EffectiveAperture = AperturePhysical * cfg.AntennaEfficiency;
            antenna.gain_dBi = aperture2gain(EffectiveAperture, cfg.lambda);
            antenna.gain_linear = 10^(antenna.gain_dBi/10);
            
            % Ширина луча
            antenna.beamwidth = 0.886 * cfg.lambda / (antenna.num_elements * antenna.element_spacing) * 180/pi;
            
            % Диаграмма направленности ФАР
            antenna.pattern = @(az, el) array_pattern(az, el, antenna);
            
            fprintf('Создана ФАР: %dx%d элементов, Gain=%.2f дБи\n', ...
                    antenna.num_elements, antenna.num_elements, antenna.gain_dBi);
            
        otherwise
            % === ИЗОТРОПНАЯ АНТЕННА (по умолчанию) ===
            antenna.type = 'isotropic';
            antenna.position = [0; 0; cfg.altitude_radar];
            antenna.orientation = [0; 0];
            antenna.gain_dBi = 0;
            antenna.gain_linear = 1;
            antenna.pattern = @(az, el) 1;
            fprintf('Создана изотропная антенна\n');
    end
end

% ===== ДИАГРАММА НАПРАВЛЕННОСТИ ФАР =====
function pattern = array_pattern(az, el, antenna)
    % ARRAY_PATTERN - Диаграмма направленности ФАР
    %
    %   pattern = array_pattern(az, el, antenna)
    
    % Углы в радианах
    az_rad = az * pi/180;
    el_rad = el * pi/180;
    
    % Волновое число
    k = 2*pi / (3e8 / 3e9);  % lambda для 3 ГГц
    
    % Фазовое распределение (линейное для простоты)
    phase_shift = 0;  % можно управлять лучом
    
    % Множитель решётки
    N = antenna.num_elements;
    d = antenna.element_spacing;
    
    u = sin(el_rad) * cos(az_rad);
    v = sin(el_rad) * sin(az_rad);
    
    % Сумма по элементам
    pattern = 0;
    for ix = 1:N
        for iy = 1:N
            % Положение элемента
            x = (ix - (N+1)/2) * d;
            y = (iy - (N+1)/2) * d;
            
            % Фаза элемента
            phase = k * (x * u + y * v) + phase_shift;
            
            % Амплитудное распределение (тейлоровское окно)
            amp = antenna.taper(ix) * antenna.taper(iy);
            
            pattern = pattern + amp * exp(1j * phase);
        end
    end
    
    pattern = abs(pattern) / max(abs(pattern(:)));
end