%% Part 1
clear, clc, close all
cd /home/affneu/kenvdzee/Documents/PRESTUS/ % change path to demo data here

% add paths
addpath('functions')
addpath(genpath('toolboxes')) 
addpath('/home/common/matlab/fieldtrip/qsub') % uncomment if you are using Donders HPC

if gpuDeviceCount==0 && ~exist('/home/common/matlab/fieldtrip/qsub','dir')
    error('Many of the examples in this tutorial assume that you have a GPU available for computations or that you''re using the Donders HPC cluster. It looks like this is not the case. You can still run the tutorial but you''ll need to switch to using CPU (see matlab_code parameter in the config) and it would be slow.')
end

%% Part 2
real_profile = readmatrix('/home/affneu/kenvdzee/Documents/focal_steering_tables/extracted_files/Imasonic_test_ISPPA_40%_R75_55mm.csv');
desired_intensity = 36;

[max_intensity, max_x] = max(real_profile(:,2));
adjustment_factor_intensity = max_intensity / desired_intensity;
real_profile_adjusted_for_intensity = real_profile;
real_profile_adjusted_for_intensity(:,2) = real_profile_adjusted_for_intensity(:,2)./adjustment_factor_intensity;

%% Part 3
parameters = load_parameters('phase_optimisation_config.yaml', '/home/affneu/kenvdzee/Documents/acoustic_simulation_scripts/configs/'); % load the configuration file

parameters.simulation_medium = 'water'; % indicate that we only want the simulation in the water medium for now

subject_id = 1; % subject id doesn't matter here as we use the brain of Ernie from SimNIBS example dataset and the paths to T1/T2 files are hardcoded in the tutorial config; for the real analysis one usually uses templates based on subject ID, see example in the default config.
% Start the simulations - uncomment the next line if you haven't run them yet
%single_subject_pipeline(subject_id, parameters);
%
% If you are using the Donders HPC cluster, you can do the simulations in
% a non-interactive session with a qsub. To do so, set the interactive flag
% to zero, set overwrite_files to 'always' (if you already have the results and want to recompute them), and run single_subject_pipeline_with_qsub. 
%
parameters.interactive = 0;
parameters.overwrite_files = 'always';

single_subject_pipeline_with_slurm(subject_id, parameters);

%% Part 4
% load results
outputs_folder = sprintf('%s/sub-%03d', parameters.output_location, subject_id);

load(sprintf('%s/sub-%03d_water_results%s.mat', outputs_folder, subject_id, parameters.results_filename_affix),'sensor_data','parameters');

% get maximum pressure
p_max = gather(sensor_data.p_max_all); % transform from GPU array to normal array

% plot 2d intensity map
imagesc((1:size(p_max,1))*parameters.grid_step_mm, ...
    (1:size(p_max,3))*parameters.grid_step_mm , ...
    squeeze(p_max(:,parameters.transducer.pos_grid(2),:))')
axis image;
colormap(getColorMap);
xlabel('Lateral Position [mm]');
ylabel('Axial Position [mm]');
axis image;
cb = colorbar;
title('Pressure for the focal plane')

%% Part 5
% simulated pressure along the focal axis
pred_axial_pressure = squeeze(p_max(parameters.transducer.pos_grid(1),parameters.transducer.pos_grid(2),:)); % get the values at the focal axis

% compute O'Neil solution and plot it along with comparisons
% define transducer parameters

velocity = parameters.transducer.source_amp(1)/(parameters.medium.water.density*parameters.medium.water.sound_speed);   % [m/s]

% define position vectors
axial_position   = (1:parameters.default_grid_dims(3))*0.5;       % [mm]

% evaluate pressure analytically
% focusedAnnulusONeil provides an analytic solution for the pressure at the
% focal (beam) axis
[p_axial_oneil] = focusedAnnulusONeil(parameters.transducer.curv_radius_mm/1e3, ...
    [parameters.transducer.Elements_ID_mm; parameters.transducer.Elements_OD_mm]/1e3, repmat(velocity,1,parameters.transducer.n_elements), ...
    parameters.transducer.source_phase_rad, parameters.transducer.source_freq_hz, parameters.medium.water.sound_speed, ...
    parameters.medium.water.density, (axial_position-0.5)*1e-3);

% plot focal axis pressure
figure('Position', [10 10 900 500]);

plot(axial_position, p_axial_oneil .^2/(2*parameters.medium.water.sound_speed*parameters.medium.water.density) .* 1e-4);
xlabel('Axial Position [mm]');
ylabel('Intensity [W/cm^2]');
hold on
plot(axial_position-(parameters.transducer.pos_grid(3)-1)*0.5, pred_axial_pressure.^2/(2*parameters.medium.water.sound_speed*parameters.medium.water.density) .* 1e-4,'--');
plot(real_profile_adjusted_for_intensity(:,1),real_profile_adjusted_for_intensity(:,2))
hold off
xline(parameters.expected_focal_distance_mm, '--');
legend('Analytic solution','Simulated results','Real profile')
title('Pressure along the beam axis')

% what is distance to the maximum pressure?
fprintf('Estimated distance to the point of maximum pressure: %.2f mm\n',axial_position(p_axial_oneil==max(p_axial_oneil)))

% compute the approximate adjustment from simulated (on a grid) to analytic solution
simulated_grid_adj_factor = max(pred_axial_pressure(:))/max(p_axial_oneil(:));
%% Part 6
gs = GlobalSearch;
%opt_velocity = desired_pressure/max_pressure*velocity;

%optimize_phases = @(phases) phase_optimization_annulus(phases, parameters, velocity, axial_position, parameters.expected_focal_distance_mm);
optimize_phases = @(phases_and_velocity) phase_optimization_annulus_full_curve(phases_and_velocity(1:(parameters.transducer.n_elements-1)),...
    parameters, phases_and_velocity(parameters.transducer.n_elements),...
    real_profile_adjusted_for_intensity(:,1), real_profile_adjusted_for_intensity(:,2));

rng(195,'twister') % setting seed for consistency
problem = createOptimProblem('fmincon','x0', [randi(360, [1 parameters.transducer.n_elements-1])/180*pi velocity],...
    'objective',optimize_phases,'lb',zeros(1,parameters.transducer.n_elements),'ub',[2*pi*ones(1,parameters.transducer.n_elements-1) 0.2],...
    'options', optimoptions('fmincon','OptimalityTolerance', 1e-8)); 

[opt_phases_and_velocity, min_err] = run(gs,problem);
% plot optimization results
phase_optimization_annulus_full_curve(opt_phases_and_velocity(1:(parameters.transducer.n_elements-1)), parameters,...
    opt_phases_and_velocity(parameters.transducer.n_elements),...
    real_profile_adjusted_for_intensity(:,1), real_profile_adjusted_for_intensity(:,2), 1);

fprintf('Optimal phases: %s deg.; velocity: %.2f; optimization error: %.2f', mat2str(round(opt_phases_and_velocity(1:(parameters.transducer.n_elements-1))/pi*180)),...
    opt_phases_and_velocity((parameters.transducer.n_elements)), min_err);

%% Part 7
opt_phases = opt_phases_and_velocity(1:(parameters.transducer.n_elements-1));
opt_velocity = opt_phases_and_velocity(parameters.transducer.n_elements);

[p_axial_oneil_opt] = focusedAnnulusONeil(parameters.transducer.curv_radius_mm/1e3, ...
    [parameters.transducer.Elements_ID_mm; parameters.transducer.Elements_OD_mm]/1e3, repmat(opt_velocity,1,parameters.transducer.n_elements), ...
    [0 opt_phases], parameters.transducer.source_freq_hz, parameters.medium.water.sound_speed, ...
    parameters.medium.water.density, (axial_position-0.5)*1e-3);


figure('Position', [10 10 900 500]);
plot(axial_position, p_axial_oneil.^2/(2*parameters.medium.water.sound_speed*parameters.medium.water.density) .* 1e-4);
xlabel('Axial Position [mm]');
ylabel('Intensity [W/cm^2]');
hold on
plot(axial_position, p_axial_oneil_opt .^2/(2*parameters.medium.water.sound_speed*parameters.medium.water.density) .* 1e-4);
plot(real_profile_adjusted_for_intensity(:,1),real_profile_adjusted_for_intensity(:,2))
hold off
xline(parameters.expected_focal_distance_mm, '--');
yline(30, '--');
legend('Original simulation', sprintf('Optimized to match the real profile'),'Real profile')
title('Pressure along the beam axis')

fprintf('Estimated distance to the point of maximum pressure: %.2f mm\n',axial_position(p_axial_oneil_opt==max(p_axial_oneil_opt)))

fprintf('Estimated distance to the center of half-maximum range: %.2f mm\n', get_flhm_center_position(axial_position, p_axial_oneil_opt))

%% Part 8
opt_source_amp = round(opt_velocity/velocity*parameters.transducer.source_amp/simulated_grid_adj_factor);
sprintf('the optimised source_amp = %i', opt_source_amp(1))

opt_parameters = load_parameters('tutorial_config.yaml'); 
opt_parameters.transducer.source_amp = opt_source_amp;
opt_parameters.transducer.source_phase_rad = [0 opt_phases];
opt_parameters.transducer.source_phase_deg = [0 opt_phases]/pi*180;
opt_parameters.results_filename_affix = '_optimized';
opt_parameters.simulation_medium = 'water';

% single_subject_pipeline(subject_id, opt_parameters)

% If you are using the Donders HPC cluster, you can do the simulations in
% a non-interactive session with a qsub. To do so, set the interactive flag
% to zero and set overwrite_files to 'always' (if you already have the results and want to recompute them). 
%  
opt_parameters.interactive = 0;
opt_parameters.overwrite_files = 'always';
% 
single_subject_pipeline(subject_id, opt_parameters);

%% Part 9
opt_res = load(sprintf('%s/sub-%03d_water_results%s.mat', outputs_folder, subject_id, opt_parameters.results_filename_affix),'sensor_data','parameters');

% get maximum pressure
p_max = gather(opt_res.sensor_data.p_max_all);
pred_axial_pressure_opt = squeeze(p_max(opt_res.parameters.transducer.pos_grid(1), opt_res.parameters.transducer.pos_grid(2),:));

figure('Position', [10 10 900 500]);
hold on
plot(axial_position, p_axial_oneil.^2/(2*parameters.medium.water.sound_speed*parameters.medium.water.density) .* 1e-4);
xlabel('Axial Position [mm]');
ylabel('Intensity [W/cm^2]');
plot(axial_position, p_axial_oneil_opt .^2/(2*parameters.medium.water.sound_speed*parameters.medium.water.density) .* 1e-4);

sim_res_axial_position = axial_position-(opt_res.parameters.transducer.pos_grid(3)-1)*0.5; % axial position for the simulated results, relative to transducer position
plot(sim_res_axial_position, ...
    pred_axial_pressure_opt .^2/(2*parameters.medium.water.sound_speed*parameters.medium.water.density) .* 1e-4);
plot(real_profile_adjusted_for_intensity(:,1),real_profile_adjusted_for_intensity(:,2))
hold off
xline(opt_res.parameters.expected_focal_distance_mm, '--');
yline(desired_intensity, '--');
legend('Original simulation', sprintf('Optimized for %2.f mm distance, analytical', opt_res.parameters.expected_focal_distance_mm), ...
    sprintf('Optimized for %2.f mm distance, simulated', opt_res.parameters.expected_focal_distance_mm),'Real profile','Location', 'best')

fprintf('Estimated distance to the point of maximum pressure: %.2f mm\n',sim_res_axial_position(pred_axial_pressure_opt==max(pred_axial_pressure_opt)))
