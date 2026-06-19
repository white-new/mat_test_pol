% main_animate.m
clear; clc; close all;
%% ЗАПУСК АНИМАЦИИ
cfg = config();
cfg.target_type = 'custom';      % 'corner', 'dipole', 'sphere', 'rotating_corner', 'custom'
cfg.target_rotate = true;
cfg.target_rotation_speed = 3000;  % град/с
cfg.enable.PLOTS = false;        % отключаем основной figure
cfg.enable.NOISE = false;
cfg.clutterRCS = 0;  % убираем помеху
cfg.enable.CLUTTER = false;
cfg.enable.FLUCTUATIONS = false;
cfg.targetSpeed = 0;
% animate_target(cfg);
animate_target_3d(cfg);