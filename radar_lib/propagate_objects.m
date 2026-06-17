function [rx_H_cell, rx_V_cell] = propagate_objects(x, targets, clutters, antenna, cfg)
    % PROPAGATE_OBJECTS - Распространение сигнала от всех объектов

    if ~cfg.enable.CHANNEL
        fprintf('Канал распространения ВЫКЛЮЧЕН\n');
        rx_H_cell = cell(1, cfg.NumPulses);
        rx_V_cell = cell(1, cfg.NumPulses);
        for pulse = 1:cfg.NumPulses
            rx_H_cell{pulse} = zeros(length(x), 1);
            rx_V_cell{pulse} = zeros(length(x), 1);
        end
        return;
    end

    % Параметры среды
    AtmosLoss_dB_per_km = 0.01;

    % Потери в тракте (общие для всех)
    Loss_Feed = 2.0;
    Loss_Circulator = 1.5;
    Loss_Radome = 0.5;
    TotalLoss_Linear = 10^(-(Loss_Feed + Loss_Circulator + Loss_Radome)/10);

    % Канал
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

    rx_H_cell = cell(1, cfg.NumPulses);
    rx_V_cell = cell(1, cfg.NumPulses);

    for pulse = 1:cfg.NumPulses
        if mod(pulse, 8) == 0
            fprintf('%d ', pulse);
        end

        rx_H_cell{pulse} = zeros(length(x), 1);
        rx_V_cell{pulse} = zeros(length(x), 1);

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
            
            % === ПРОХОД ЧЕРЕЗ КАНАЛ ===
            rx_H_pulse = channel(x, radarPos, objPos, radarVel, objVel);
            rx_V_pulse = channel(x, radarPos, objPos, radarVel, objVel);

            % ===== ИСПРАВЛЕНО: потери зависят от дальности объекта =====
%             AtmosLoss_Linear_obj = 10^(-AtmosLoss_dB_per_km * obj.range / 1000 / 10);
%             rx_H_pulse = rx_H_pulse * sqrt(AtmosLoss_Linear_obj);
%             rx_V_pulse = rx_V_pulse * sqrt(AtmosLoss_Linear_obj);

            % === ПОЛЯРИЗАЦИЯ И ЭПР ===
if isfield(obj, 'is_clutter') && obj.is_clutter
    % Для помехи: ЭПР постоянная, но учитываем её значение!
    rcs_scale = sqrt(obj.rcs / obj.rcs);  % = 1, но сохраняем структуру
    % ИЛИ ПРОЩЕ:
    rcs_scale = 1;
    % НО нужно умножить на sqrt(obj.rcs) отдельно!
else
    % Для цели: флуктуации с сохранением средней ЭПР
    rcs_scale = sqrt(exprnd(obj.rcs) / obj.rcs);
end

% Амплитуда сигнала пропорциональна sqrt(ЭПР)
% Поэтому умножаем на sqrt(obj.rcs) для обоих случаев
amplitude_scale = sqrt(obj.rcs);
PolMat = obj.polarization_matrix * rcs_scale * amplitude_scale;

            rx_H_obj = PolMat(1,1) * rx_H_pulse + PolMat(1,2) * rx_V_pulse;
            rx_V_obj = PolMat(2,1) * rx_H_pulse + PolMat(2,2) * rx_V_pulse;

            % === ДОПЛЕР ===
            if obj.speed ~= 0
                fd = 2 * obj.speed * obj.direction / cfg.lambda;
                delta_phase = 2 * pi * fd / cfg.PRF;
                doppler_shift = exp(1j * (pulse-1) * delta_phase);
                rx_H_obj = rx_H_obj * doppler_shift;
                rx_V_obj = rx_V_obj * doppler_shift;
            end

            % === УСИЛЕНИЕ АНТЕННЫ И ПОТЕРИ В ТРАКТЕ ===
            rx_H_obj = rx_H_obj * gain_dir * sqrt(TotalLoss_Linear);
            rx_V_obj = rx_V_obj * gain_dir * sqrt(TotalLoss_Linear);

            % === ДОБАВЛЯЕМ К СУММАРНОМУ СИГНАЛУ ===
            % === ДИАГНОСТИКА (для первого импульса) ===
if pulse == 1 && obj_idx == 1
    fprintf('Объект %d: range=%.1f, power_H=%.3e, power_V=%.3e\n', ...
            obj_idx, obj.range, mean(abs(rx_H_obj).^2), mean(abs(rx_V_obj).^2));
end
            rx_H_cell{pulse} = rx_H_cell{pulse} + rx_H_obj;
            rx_V_cell{pulse} = rx_V_cell{pulse} + rx_V_obj;
        end
    end

    fprintf('\n');
end