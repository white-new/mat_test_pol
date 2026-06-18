function [rx_HH_cell, rx_HV_cell, rx_VH_cell, rx_VV_cell] = propagate_objects(x, targets, clutters, antenna, cfg)
    % PROPAGATE_OBJECTS - Распространение сигнала от всех объектов

    if ~cfg.enable.CHANNEL
        fprintf('Канал распространения ВЫКЛЮЧЕН\n');
        rx_HH_cell = cell(1, cfg.NumPulses);
        rx_HV_cell = cell(1, cfg.NumPulses);
        rx_VH_cell = cell(1, cfg.NumPulses);
        rx_VV_cell = cell(1, cfg.NumPulses);
        for pulse = 1:cfg.NumPulses
            rx_HH_cell{pulse} = zeros(length(x), 1);
            rx_HV_cell{pulse} = zeros(length(x), 1);
            rx_VH_cell{pulse} = zeros(length(x), 1);
            rx_VV_cell{pulse} = zeros(length(x), 1);
        end
        return;
    end

    % Потери в тракте (общие для всех)
    Loss_Feed = 2.0;
    Loss_Circulator = 1.5;
    Loss_Radome = 0.5;
    TotalLoss_Linear = 10^(-(Loss_Feed + Loss_Circulator + Loss_Radome)/10);

    % Канал распространения
    channel = phased.FreeSpace(...
        'SampleRate', cfg.Fs, ...
        'OperatingFrequency', cfg.fc, ...
        'TwoWayPropagation', true);

    radarPos = antenna.position;
    radarVel = [0; 0; 0];

    % ===== ОБЪЕДИНЯЕМ ОБЪЕКТЫ С ПРОВЕРКОЙ =====
    if isempty(clutters) || ~isfield(clutters, 'range')
        all_objects = targets;
    else
        all_objects = [targets, clutters];
    end
    num_objects = length(all_objects);

    fprintf('Количество объектов: %d\n', num_objects);
    for obj_idx = 1:num_objects
        obj = all_objects(obj_idx);
        if isfield(obj, 'is_clutter')
            fprintf('  Объект %d: range=%.1f, is_clutter=%d\n', ...
                    obj_idx, obj.range, obj.is_clutter);
        end
    end

    fprintf('Распространение от %d объектов: ', num_objects);

    % Инициализация ячеек для 4 каналов
    rx_HH_cell = cell(1, cfg.NumPulses);
    rx_HV_cell = cell(1, cfg.NumPulses);
    rx_VH_cell = cell(1, cfg.NumPulses);
    rx_VV_cell = cell(1, cfg.NumPulses);

    for pulse = 1:cfg.NumPulses
        if mod(pulse, 8) == 0
            fprintf('%d ', pulse);
        end

        % Инициализация для текущего импульса
        rx_HH_cell{pulse} = zeros(length(x), 1);
        rx_HV_cell{pulse} = zeros(length(x), 1);
        rx_VH_cell{pulse} = zeros(length(x), 1);
        rx_VV_cell{pulse} = zeros(length(x), 1);

        for obj_idx = 1:num_objects
            obj = all_objects(obj_idx);
            
            objPos = [obj.range; 0; obj.height];
            objVel = [obj.speed * obj.direction; 0; 0];

            % === УЧЁТ ДИАГРАММЫ НАПРАВЛЕННОСТИ АНТЕННЫ ===
            dx = obj.range;
            dy = 0;
            dz = obj.height - antenna.position(3);
            az = atan2d(dy, dx);
            el = atan2d(dz, sqrt(dx^2 + dy^2));
            
            gain_dir = antenna_pattern(az, el, antenna);
            
            % === ПРОХОД ЧЕРЕЗ КАНАЛ (ДО ЦЕЛИ) ===
            rx_H_pulse = channel(x, radarPos, objPos, radarVel, objVel);
            rx_V_pulse = channel(x, radarPos, objPos, radarVel, objVel);

            % === ПОЛЯРИЗАЦИОННАЯ МАТРИЦА ===
            PolMat = obj.polarization_matrix;
            
 % ===== ДИАГНОСТИКА ДЛЯ ДИПОЛЯ (ДО ВРАЩЕНИЯ) =====
            if isfield(obj, 'type') && strcmp(obj.type, 'dipole') && pulse <= 3
                fprintf('\n=== ДИПОЛЬ (имп. %d) ===\n', pulse);
                fprintf('Угол поворота: %.1f°\n', (pulse-1) * obj.rotation_speed * cfg.PRI);
                fprintf('Матрица ДО вращения: [%.3f, %.3f; %.3f, %.3f]\n', ...
                        real(PolMat(1,1)), real(PolMat(1,2)), ...
                        real(PolMat(2,1)), real(PolMat(2,2)));
            end
% ===== ДИАГНОСТИКА: ПРОВЕРКА УСЛОВИЙ ВРАЩЕНИЯ =====
if isfield(obj, 'type') && strcmp(obj.type, 'corner') && pulse == 1
    fprintf('\n=== ПРОВЕРКА ВРАЩЕНИЯ ДЛЯ CORNER ===\n');
    fprintf('obj.rotate = %d\n', isfield(obj, 'rotate') && obj.rotate);
    fprintf('obj.rotation_speed = %.1f\n', obj.rotation_speed);
    fprintf('pulse = %d\n', pulse);
end
            % ===== ВРАЩЕНИЕ =====
            if isfield(obj, 'rotate') && obj.rotate
                angle = (pulse-1) * obj.rotation_speed * cfg.PRI;
                theta = angle * pi/180;
                R = [cos(theta), -sin(theta); sin(theta), cos(theta)];
                PolMat = R * PolMat * R';
                
                % ===== ДИАГНОСТИКА ПОСЛЕ ВРАЩЕНИЯ =====
                if isfield(obj, 'type') && strcmp(obj.type, 'dipole') && pulse <= 3
                    fprintf('Матрица ПОСЛЕ вращения: [%.3f, %.3f; %.3f, %.3f]\n', ...
                            real(PolMat(1,1)), real(PolMat(1,2)), ...
                            real(PolMat(2,1)), real(PolMat(2,2)));
                end
            end
            
            % Флуктуации
            if cfg.enable.FLUCTUATIONS
                if isfield(obj, 'is_clutter') && obj.is_clutter
                    fluct = 1;
                else
                    fluct = sqrt(exprnd(1));
                end
            else
                fluct = 1;
            end
            PolMat = PolMat * fluct;

            % ===== ДИАГНОСТИКА 2: ПОСЛЕ ВРАЩЕНИЯ =====
            if isfield(obj, 'type') && strcmp(obj.type, 'sphere') && pulse == 1
                fprintf('=== ДИАГНОСТИКА 2: ПОСЛЕ ВРАЩЕНИЯ ===\n');
                fprintf('  [%.6f, %.6f]\n', real(PolMat(1,1)), real(PolMat(1,2)));
                fprintf('  [%.6f, %.6f]\n', real(PolMat(2,1)), real(PolMat(2,2)));
            end

            % === ОТРАЖЕНИЕ ===
            rx_HH = PolMat(1,1) * rx_H_pulse;
            rx_HV = PolMat(1,2) * rx_V_pulse;
            rx_VH = PolMat(2,1) * rx_H_pulse;
            rx_VV = PolMat(2,2) * rx_V_pulse;

            % ===== ДИАГНОСТИКА 3: ПОСЛЕ ОТРАЖЕНИЯ (ДО УСИЛЕНИЯ) =====
            if pulse == 1 && obj_idx == 1
                [~, idx_peak] = max(abs(rx_HH));
                fprintf('\n=== ДИАГНОСТИКА 3: ПОСЛЕ ОТРАЖЕНИЯ (ДО УСИЛЕНИЯ) ===\n');
                fprintf('Пик %d: HH=%.3e, HV=%.3e, VH=%.3e, VV=%.3e\n', ...
                        idx_peak, abs(rx_HH(idx_peak))^2, abs(rx_HV(idx_peak))^2, ...
                        abs(rx_VH(idx_peak))^2, abs(rx_VV(idx_peak))^2);
            end

            % === ДОПЛЕР ===
            if obj.speed ~= 0
                fd = 2 * obj.speed * obj.direction / cfg.lambda;
                delta_phase = 2 * pi * fd / cfg.PRF;
                doppler_shift = exp(1j * (pulse-1) * delta_phase);
                rx_HH = rx_HH * doppler_shift;
                rx_HV = rx_HV * doppler_shift;
                rx_VH = rx_VH * doppler_shift;
                rx_VV = rx_VV * doppler_shift;
            end

            % ===== ДИАГНОСТИКА 4: ПОСЛЕ ДОПЛЕРА =====
            if pulse == 1 && obj_idx == 1
                [~, idx_peak] = max(abs(rx_HH));
                fprintf('=== ДИАГНОСТИКА 4: ПОСЛЕ ДОПЛЕРА ===\n');
                fprintf('Пик %d: HH=%.3e, HV=%.3e, VH=%.3e, VV=%.3e\n', ...
                        idx_peak, abs(rx_HH(idx_peak))^2, abs(rx_HV(idx_peak))^2, ...
                        abs(rx_VH(idx_peak))^2, abs(rx_VV(idx_peak))^2);
            end

            % === УСИЛЕНИЕ АНТЕННЫ И ПОТЕРИ ===
            rx_HH = rx_HH * gain_dir * sqrt(TotalLoss_Linear);
            rx_HV = rx_HV * gain_dir * sqrt(TotalLoss_Linear);
            rx_VH = rx_VH * gain_dir * sqrt(TotalLoss_Linear);
            rx_VV = rx_VV * gain_dir * sqrt(TotalLoss_Linear);

            % ===== ДИАГНОСТИКА 5: ПОСЛЕ УСИЛЕНИЯ =====
            if pulse == 1 && obj_idx == 1
                [~, idx_peak] = max(abs(rx_HH));
                fprintf('=== ДИАГНОСТИКА 5: ПОСЛЕ УСИЛЕНИЯ ===\n');
                fprintf('Пик %d: HH=%.3e, HV=%.3e, VH=%.3e, VV=%.3e\n', ...
                        idx_peak, abs(rx_HH(idx_peak))^2, abs(rx_HV(idx_peak))^2, ...
                        abs(rx_VH(idx_peak))^2, abs(rx_VV(idx_peak))^2);
            end

            % ===== ДИАГНОСТИКА 6: ПЕРЕД СОХРАНЕНИЕМ В ЯЧЕЙКУ =====
            if pulse == 1 && obj_idx == 1
                [~, idx_peak] = max(abs(rx_HH));
                fprintf('=== ДИАГНОСТИКА 6: ПЕРЕД СОХРАНЕНИЕМ В ЯЧЕЙКУ ===\n');
                fprintf('Пик %d: HH=%.3e, HV=%.3e, VH=%.3e, VV=%.3e\n', ...
                        idx_peak, abs(rx_HH(idx_peak))^2, abs(rx_HV(idx_peak))^2, ...
                        abs(rx_VH(idx_peak))^2, abs(rx_VV(idx_peak))^2);
            end

            % ===== ДИАГНОСТИКА 7: ЧТО В ЯЧЕЙКЕ ДО СУММИРОВАНИЯ =====
            if pulse == 1 && obj_idx == 1
                fprintf('=== ДИАГНОСТИКА 7: В ЯЧЕЙКЕ ДО СУММИРОВАНИЯ ===\n');
                fprintf('rx_HV в ячейке (power): %.3e\n', mean(abs(rx_HV_cell{pulse}).^2));
            end

            % === СУММИРУЕМ ===
            rx_HH_cell{pulse} = rx_HH_cell{pulse} + rx_HH;
            rx_HV_cell{pulse} = rx_HV_cell{pulse} + rx_HV;
            rx_VH_cell{pulse} = rx_VH_cell{pulse} + rx_VH;
            rx_VV_cell{pulse} = rx_VV_cell{pulse} + rx_VV;

            % ===== ДИАГНОСТИКА 8: ПОСЛЕ СУММИРОВАНИЯ =====
            if pulse == 1 && obj_idx == 1
                [~, idx_peak] = max(abs(rx_HH_cell{pulse}));
                fprintf('=== ДИАГНОСТИКА 8: ПОСЛЕ СУММИРОВАНИЯ В ЯЧЕЙКУ ===\n');
                fprintf('Пик %d: HH=%.3e, HV=%.3e, VH=%.3e, VV=%.3e\n', ...
                        idx_peak, abs(rx_HH_cell{pulse}(idx_peak))^2, ...
                        abs(rx_HV_cell{pulse}(idx_peak))^2, ...
                        abs(rx_VH_cell{pulse}(idx_peak))^2, ...
                        abs(rx_VV_cell{pulse}(idx_peak))^2);
            end
            
            % === СРЕДНЯЯ МОЩНОСТЬ (оригинальная диагностика) ===
            if pulse == 1 && obj_idx == 1
                fprintf('Объект %d: range=%.1f, HH=%.3e, HV=%.3e, VH=%.3e, VV=%.3e\n', ...
                        obj_idx, obj.range, ...
                        mean(abs(rx_HH).^2), mean(abs(rx_HV).^2), ...
                        mean(abs(rx_VH).^2), mean(abs(rx_VV).^2));
            end
        end
    end

    % === ДИАГНОСТИКА: ПОСЛЕ ЗАПОЛНЕНИЯ ВСЕХ ИМПУЛЬСОВ ===
    [~, idx_peak_final] = max(abs(rx_HH_cell{1}));
    fprintf('\n=== ДИАГНОСТИКА: ПОСЛЕ ЗАПОЛНЕНИЯ ВСЕХ ИМПУЛЬСОВ ===\n');
    fprintf('Пик %d: HH=%.3e, HV=%.3e, VH=%.3e, VV=%.3e\n', ...
            idx_peak_final, abs(rx_HH_cell{1}(idx_peak_final))^2, ...
            abs(rx_HV_cell{1}(idx_peak_final))^2, ...
            abs(rx_VH_cell{1}(idx_peak_final))^2, ...
            abs(rx_VV_cell{1}(idx_peak_final))^2);

    fprintf('\n');
end