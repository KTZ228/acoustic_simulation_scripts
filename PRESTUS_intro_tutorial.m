%% Part 1
clear
cd /home/mrphys/kenvdzee/Downloads/PRESTUS-b125251232cc33fe95ecc2733055664ca09bc5d3/ % change path to demo data here

% add paths
addpath('functions')
addpath(genpath('toolboxes')) 
addpath('/home/common/matlab/fieldtrip/qsub') % uncomment if you are using Donders HPC

if gpuDeviceCount==0 && ~exist('/home/common/matlab/fieldtrip/qsub','dir')
    error('Many of the examples in this tutorial assume that you have a GPU available for computations or that you''re using the Donders HPC cluster. It looks like this is not the case. You can still run the tutorial but you''ll need to switch to using CPU (see matlab_code parameter in the config) and it would be slow.')
end

%% Part 2
real_profile = readmatrix('examples/acoustic_profile_tutorial.csv');
desired_intensity = 30;

dist_to_exit_plane = round(63.2-52.38); % from the transducer specifications

figure('Position', [10 10 900 500]);
real_profile(:,1) = dist_to_exit_plane + real_profile(:,1);
plot(real_profile(:,1),real_profile(:,2))

halfMax = (min(real_profile(:,2)) + max(real_profile(:,2))) / 2;
% Find where the data first drops below half the max.
index1 = find(real_profile(:,2) >= halfMax, 1, 'first');
% Find where the data last rises above half the max.
index2 = find(real_profile(:,2) >= halfMax, 1, 'last');

flhm = real_profile(index2,1) - real_profile(index1,1);
flhm_center_x = (real_profile(index2,1) - real_profile(index1,1))/2+real_profile(index1,1);
flhm_center_intensity = real_profile(real_profile(:,1)==flhm_center_x, 2);
xlabel('Axial Position [mm]');
ylabel('Intensity [W/cm^2]');
yline(desired_intensity, '--');
yline(halfMax, '--');
xline(real_profile(index1,1), '--');
xline(real_profile(index2,1), '--');
xline(flhm_center_x,'r--');
text(flhm_center_x+0.5, flhm_center_intensity+3, sprintf('FLHM center intensity %.2f [W/cm^2] at %i mm',flhm_center_intensity,flhm_center_x), "Color",'r');
expected_focus = 60;
intensity_at_expected_focus = mean(real_profile(real_profile(:,1)>=59&real_profile(:,1)<=61,2));
xline(expected_focus,'b--');
text(expected_focus+0.5, intensity_at_expected_focus+4, sprintf('Expected focus intensity %.2f [W/cm^2] at %i mm',intensity_at_expected_focus,expected_focus),"Color",'b');
[max_intensity, max_x] = max(real_profile(:,2));
xline(real_profile(max_x,1),'--','Color','#7E2F8E');
text(real_profile(max_x,1)+0.5, max_intensity+4, sprintf('Max intensity %.2f [W/cm^2] at %i mm',max_intensity,real_profile(max_x,1)),"Color",'#7E2F8E');

%% Part 3
parameters = load_parameters('tutorial_config.yaml'); % load the configuration file

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

single_subject_pipeline(subject_id, parameters);

%% Part 4
% load results
outputs_folder = sprintf('%s/sim_outputs/sub-%03d', parameters.data_path, subject_id);

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
    [parameters.transducer.Elements_ID_mm; parameters.transducer.Elements_OD_mm]/1e3, repmat(velocity,1,4), ...
    parameters.transducer.source_phase_rad, parameters.transducer.source_freq_hz, parameters.medium.water.sound_speed, ...
    parameters.medium.water.density, (axial_position-0.5)*1e-3);

% plot focal axis pressure
figure('Position', [10 10 900 500]);

plot(axial_position, p_axial_oneil .^2/(2*parameters.medium.water.sound_speed*parameters.medium.water.density) .* 1e-4);
xlabel('Axial Position [mm]');
ylabel('Intensity [W/cm^2]');
hold on
plot(axial_position-(parameters.transducer.pos_grid(3)-1)*0.5, pred_axial_pressure.^2/(2*parameters.medium.water.sound_speed*parameters.medium.water.density) .* 1e-4,'--');
plot(real_profile(:,1),real_profile(:,2))
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
optimize_phases = @(phases_and_velocity) phase_optimization_annulus_full_curve(phases_and_velocity(1:3), parameters, phases_and_velocity(4),...
    real_profile(:,1), real_profile(:,2));

rng(195,'twister') % setting seed for consistency
problem = createOptimProblem('fmincon','x0', [randi(360, [1 3])/180*pi velocity],...
    'objective',optimize_phases,'lb',zeros(1,4),'ub',[2*pi*ones(1,3) 0.2], 'options', optimoptions('fmincon','OptimalityTolerance', 1e-8)); 

[opt_phases_and_velocity, min_err] = run(gs,problem);

% plot optimization results
phase_optimization_annulus_full_curve(opt_phases_and_velocity(1:3), parameters, opt_phases_and_velocity(4),...
    real_profile(:,1), real_profile(:,2), 1);

fprintf('Optimal phases: %s deg.; velocity: %.2f; optimization error: %.2f', mat2str(round(opt_phases_and_velocity(1:3)/pi*180)), opt_phases_and_velocity(4), min_err)

%% Part 7
opt_phases = opt_phases_and_velocity(1:3);
opt_velocity = opt_phases_and_velocity(4);

[p_axial_oneil_opt] = focusedAnnulusONeil(parameters.transducer.curv_radius_mm/1e3, ...
    [parameters.transducer.Elements_ID_mm; parameters.transducer.Elements_OD_mm]/1e3, repmat(opt_velocity,1,4), ...
    [0 opt_phases], parameters.transducer.source_freq_hz, parameters.medium.water.sound_speed, ...
    parameters.medium.water.density, (axial_position-0.5)*1e-3);


figure('Position', [10 10 900 500]);
plot(axial_position, p_axial_oneil.^2/(2*parameters.medium.water.sound_speed*parameters.medium.water.density) .* 1e-4);
xlabel('Axial Position [mm]');
ylabel('Intensity [W/cm^2]');
hold on
plot(axial_position, p_axial_oneil_opt .^2/(2*parameters.medium.water.sound_speed*parameters.medium.water.density) .* 1e-4);
plot(real_profile(:,1),real_profile(:,2))
hold off
xline(parameters.expected_focal_distance_mm, '--');
yline(30, '--');
legend('Original simulation', sprintf('Optimized to match the real profile'),'Real profile')
title('Pressure along the beam axis')

fprintf('Estimated distance to the point of maximum pressure: %.2f mm\n',axial_position(p_axial_oneil_opt==max(p_axial_oneil_opt)))

fprintf('Estimated distance to the center of half-maximum range: %.2f mm\n', get_flhm_center_position(axial_position, p_axial_oneil_opt))

%% Part 8
opt_source_amp = round(opt_velocity/velocity*parameters.transducer.source_amp/simulated_grid_adj_factor);

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
single_subject_pipeline_with_qsub(subject_id, opt_parameters);

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
plot(real_profile(:,1),real_profile(:,2))
hold off
xline(opt_res.parameters.expected_focal_distance_mm, '--');
yline(desired_intensity, '--');
legend('Original simulation', sprintf('Optimized for %2.f mm distance, analytical', opt_res.parameters.expected_focal_distance_mm), ...
    sprintf('Optimized for %2.f mm distance, simulated', opt_res.parameters.expected_focal_distance_mm),'Real profile','Location', 'best')

fprintf('Estimated distance to the point of maximum pressure: %.2f mm\n',sim_res_axial_position(pred_axial_pressure_opt==max(pred_axial_pressure_opt)))

%% Part 10
opt_parameters = load_parameters('tutorial_config.yaml'); 

opt_parameters.transducer.source_amp = opt_source_amp;
opt_parameters.transducer.source_phase_rad = [0 opt_phases];
opt_parameters.transducer.source_phase_deg = [0 opt_phases]/pi*180;
opt_parameters.results_filename_affix = '_optimized';

opt_parameters.simulation_medium = 'layered'; % see default config for the list of mediums possible

opt_parameters.run_heating_sims = 1; % this indicates that we want the heating simulations as well

% Again, if you want to rerun the simulations, you can do it in an
% interactive mode (useful when running on your laptop) or
% non-interactively (useful at the cluster) with
opt_parameters.interactive = 1;
single_subject_pipeline(subject_id, opt_parameters); 

% or with
opt_parameters.overwrite_files = 'always';
%single_subject_pipeline_with_qsub(subject_id, opt_parameters);

%% Part 11
imshow(imread(sprintf('%s/sub-%03d/sub-%03d_t1_with_transducer_orig%s.png', opt_parameters.output_dir, subject_id,subject_id,  '_optimized')))

imshow(imread(sprintf('%s/sub-%03d/sub-%03d_layered_segmented_brain_final%s.png', opt_parameters.output_dir, subject_id, subject_id,  '_optimized')))

imshow(imread(sprintf('%s/sub-%03d/sub-%03d_layered_isppa%s.png', opt_parameters.output_dir , subject_id, subject_id,  '_optimized')))

imshow(imread(sprintf('%s/sub-%03d/sub-%03d_water_isppa%s.png', opt_parameters.output_dir , subject_id, subject_id, '_optimized')))

imshow(imread(sprintf('%s/sub-%03d/sub-%03d_layered_heating_by_time%s.png',opt_parameters.output_dir , subject_id, subject_id, '_optimized')))

%% Part 12
sim_res = struct('type', {'water','layered'},'isppa_max',[],'p_max',[],'parameters',[],'pred_axial_pressure',[],'pred_axial_intensity',[],'isspa_max_pos',[],'isspa_max_pos_brain',[]);

load(fullfile(opt_parameters.output_dir, sprintf('sub-%03d/sub-%03d_%s_after_cropping_and_smoothing%s.mat', subject_id,subject_id,...
    opt_parameters.simulation_medium, opt_parameters.results_filename_affix)), 'medium_masks')

for sim_i = 1:length(sim_res)
    cur_sim = sim_res(sim_i);
    sim_type = cur_sim.type;
    res = load(sprintf('%s/sim_outputs/sub-%03d/sub-%03d_%s_results%s.mat', opt_parameters.data_path,subject_id, subject_id, sim_type, '_optimized'),'sensor_data','parameters','kwave_medium');
    cur_sim.p_max = gather(res.sensor_data.p_max_all);
    cur_sim.isppa_max = cur_sim.p_max.^2./(2*(res.kwave_medium.sound_speed.*res.kwave_medium.density)).*1e-4; 

    if strcmp(sim_type, 'layered')
       [max_Isppa_brain, Ix_brain, Iy_brain, Iz_brain] = masked_max_3d(cur_sim.isppa_max, medium_masks>0 & medium_masks<3);
       cur_sim.isspa_max_pos_brain = [Ix_brain, Iy_brain, Iz_brain];
    end
    cur_sim.parameters = res.parameters;
    cur_sim.isspa_max_pos = squeeze(cur_sim.p_max(res.parameters.transducer.pos_grid(1), res.parameters.transducer.pos_grid(2),:));

    cur_sim.pred_axial_pressure = squeeze(cur_sim.p_max(res.parameters.transducer.pos_grid(1), res.parameters.transducer.pos_grid(2),:));
    cur_sim.pred_axial_intensity = squeeze(cur_sim.isppa_max(res.parameters.transducer.pos_grid(1), res.parameters.transducer.pos_grid(2),:));
    sim_res(sim_i) = cur_sim;

end

%% Part 13
figure;
xlabel('Axial Position [mm]');
ylabel('Intensity [W/cm^2]');

hold on
for sim_i = 1:length(sim_res)
    cur_sim = sim_res(sim_i);
    axial_position = (1:cur_sim.parameters.grid_dims(3))*0.5;
    plot(axial_position-(cur_sim.parameters.transducer.pos_grid(3)-1)*0.5, cur_sim.pred_axial_intensity, 'DisplayName',cur_sim.parameters.simulation_medium);
end
hold off
legend show