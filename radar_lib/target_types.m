function [S, name] = target_types(type, angle_deg)
    % TARGET_TYPES - Возвращает матрицу рассеяния для разных типов целей

    switch type
        case 'corner'
            % Уголковый отражатель
            S = [1 0; 0 1];
            name = 'Уголковый отражатель';
            
        case 'dipole'
            % Диполь (поворачивает поляризацию)
            S = [0 1; 1 0];
            name = 'Диполь';
            
        case 'sphere'
            % Сфера (изотропная, сохраняет поляризацию)
            S = [1 0; 0 1];
            name = 'Сфера';
            
        case 'rotating_corner'
            % Вращающийся уголковый отражатель
            S = [1 0; 0 -1];
            name = 'Вращающийся уголковый отражатель';
            
        case 'anisotropic'
            % Анизотропная цель
            S = [2 1; 1 1];
            name = 'Анизотропная цель';
            
        case 'custom'
            % Пользовательская матрица (из cfg.target)
            % ВНИМАНИЕ: эта матрица должна быть задана в cfg.target
            % и передана через create_targets.m
            S = eye(2);  % Заглушка, реальная матрица будет из cfg
            name = 'Пользовательская цель';
            
        otherwise
            error('Неизвестный тип цели: %s', type);
    end

    % Поворот матрицы (если задан угол)
    if nargin > 1 && angle_deg ~= 0
        theta = angle_deg * pi/180;
        R = [cos(theta), -sin(theta); sin(theta), cos(theta)];
        S = R * S * R';
        name = sprintf('%s (повёрнута на %.0f°)', name, angle_deg);
    end
end