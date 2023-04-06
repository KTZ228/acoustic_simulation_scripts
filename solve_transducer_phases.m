% Delete if you have rights to add paths to Matlab
cd /home/mrphys/kenvdzee/Documents/
addpath(genpath('SimNIBS-3.2'))
cd /home/mrphys/kenvdzee/Documents/MATLAB/
addpath(genpath('k-wave'))

cd /home/mrphys/kenvdzee/orca-lab/project/tuSIM % change path to demo data here

% add paths
addpath('functions')
addpath(genpath('toolboxes')) 
addpath('/home/common/matlab/fieldtrip/qsub') % uncomment if you are using Donders HPC

%% Start optimisation
cd /home/mrphys/kenvdzee/orca-lab/project/tuSIM
real_profile = readmatrix('examples/CTX-250-001_64.5.csv');
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

parameters = load_parameters('tutorial_config.yaml'); % load the configuration file

parameters.simulation_medium = 'water'; % indicate that we only want the simulation in the water medium for now

subject_id = 1; % subject id - we use the brain of Ernie from SimNIBS example dataset, renamed to sub-001 in the data folder

parameters.interactive = 0;
parameters.overwrite_files = 'always';
qsubfeval(@single_subject_pipeline_wrapper, subject_id, parameters, 'timreq',  60*60*7,  'memreq',  50*(1024^3),  'options', '-l "nodes=1:gpus=1,feature=cuda,reqattr=cudacap>=5.0"');

%% load results
load(sprintf('%s/sim_outputs/sub-%03d_water_results%s.mat', parameters.data_path , subject_id, parameters.results_filename_affix),'sensor_data','parameters');

% get maximum pressure
p_max = gather(sensor_data.p_max_all); % transform from GPU array to normal array

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

% compute the approximate adjustment from simulated (on a grid) to analytic solution
simulated_grid_adj_factor = max(pred_axial_pressure(:))/max(p_axial_oneil(:));

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
legend('Original', sprintf('Optimized to match the real profile'),'Real profile')
title('Pressure along the beam axis')

fprintf('Optimal phases: %s deg.; velocity: %.2f; optimization error: %.2f', mat2str(round(opt_phases_and_velocity(1:3)/pi*180)), opt_phases_and_velocity(4), min_err)