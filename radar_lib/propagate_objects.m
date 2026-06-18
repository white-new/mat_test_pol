function [rx_HH_cell, rx_HV_cell, rx_VH_cell, rx_VV_cell] = propagate_objects(x, targets, clutters, antenna, cfg)
    % PROPAGATE_OBJECTS - Распространение сигнала от всех объектов
    %   Возвращает 4 поляризационных канала: HH, HV, VH, VV

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

    % Объединяем все объекты
    all_objects = [targets, clutters];
    num_objects = length(all_objects);

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
            % Передаём H и V сигналы
            rx_H_pulse = channel(x, radarPos, objPos, radarVel, objVel);
            rx_V_pulse = channel(x, radarPos, objPos, radarVel, objVel);

            % === ПОЛЯРИЗАЦИОННАЯ МАТРИЦА ===
            PolMat = obj.polarization_matrix;
            
            % Флуктуации
            if isfield(obj, 'is_clutter') && obj.is_clutter
                fluct = 1;
            else
                fluct = sqrt(exprnd(1));
            end
            PolMat = PolMat * fluct;

            % === ОТРАЖЕНИЕ (ВСЕ 4 КАНАЛА) ===
            % HH: передали H, приняли H
            rx_HH = PolMat(1,1) * rx_H_pulse;
            % HV: передали H, приняли V
            rx_HV = PolMat(1,2) * rx_V_pulse;
            % VH: передали V, приняли H
            rx_VH = PolMat(2,1) * rx_H_pulse;
            % VV: передали V, приняли V
            rx_VV = PolMat(2,2) * rx_V_pulse;

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

            % === УСИЛЕНИЕ АНТЕННЫ И ПОТЕРИ ===
            rx_HH = rx_HH * gain_dir * sqrt(TotalLoss_Linear);
            rx_HV = rx_HV * gain_dir * sqrt(TotalLoss_Linear);
            rx_VH = rx_VH * gain_dir * sqrt(TotalLoss_Linear);
            rx_VV = rx_VV * gain_dir * sqrt(TotalLoss_Linear);

            % === ДИАГНОСТИКА ===
            if pulse == 1 && obj_idx == 1
                fprintf('Объект %d: range=%.1f, HH=%.3e, HV=%.3e, VH=%.3e, VV=%.3e\n', ...
                        obj_idx, obj.range, ...
                        mean(abs(rx_HH).^2), mean(abs(rx_HV).^2), ...
                        mean(abs(rx_VH).^2), mean(abs(rx_VV).^2));
            end
            
            % === СУММИРУЕМ ===
            rx_HH_cell{pulse} = rx_HH_cell{pulse} + rx_HH;
            rx_HV_cell{pulse} = rx_HV_cell{pulse} + rx_HV;
            rx_VH_cell{pulse} = rx_VH_cell{pulse} + rx_VH;
            rx_VV_cell{pulse} = rx_VV_cell{pulse} + rx_VV;
        end
    end

    fprintf('\n');
end