% Get data
%cd /home/mrphys/kenvdzee/orca-lab/project/tuSIM

% add paths
%addpath('functions')
%addpath(genpath('toolboxes')) 

opt_parameters = struct([]); 
opt_parameters(1).results_filename_affix = '_optimized';

subfolders = ["250KHz" "250KHz" "500KHz" "500KHz"];
target = ["right" "left" "right" "left"];
condition = cellstr(subfolders + '-' + target);

% Empty structure with results
sim_res = struct('name',condition,'isppa_max',[],'p_max',[],'parameters',[],'pred_axial_pressure',[],'pred_axial_intensity',[],'isspa_max_pos',[],'isspa_max_pos_brain',[]);


for sim_i = 1:length(subfolders)
    opt_parameters.simulation_medium = 'water';
    opt_parameters.data_path = sprintf('/project/3023001.06/Simulations/all_files_with_output/%s/40W_per_cm2/sub-001/',subfolders(sim_i));
    opt_parameters.results_filename_affix = sprintf('_target_%s_amygdala',target(sim_i));
    cur_sim = sim_res(sim_i);
    sim_type = 'water';

    %load(fullfile(opt_parameters.data_path, sprintf('%s_after_cropping_and_smoothing%s.mat',...
        %'water', opt_parameters.results_filename_affix)), 'medium_masks')

    res = load(sprintf('%ssub-001_%s_results%s.mat', opt_parameters.data_path, sim_type, opt_parameters.results_filename_affix),'sensor_data','parameters','kwave_medium');
    cur_sim.p_max = gather(res.sensor_data.p_max_all);
    cur_sim.isppa_max = cur_sim.p_max.^2./(2*(res.kwave_medium.sound_speed.*res.kwave_medium.density)).*1e-4; 

    cur_sim.parameters = res.parameters;
    cur_sim.isspa_max_pos = squeeze(cur_sim.p_max(res.parameters.transducer.pos_grid(1), res.parameters.transducer.pos_grid(2),:));

    cur_sim.pred_axial_pressure = squeeze(cur_sim.p_max(res.parameters.transducer.pos_grid(1), res.parameters.transducer.pos_grid(2),:));
    cur_sim.pred_axial_intensity = squeeze(cur_sim.isppa_max(res.parameters.transducer.pos_grid(1), res.parameters.transducer.pos_grid(2),:));
    sim_res(sim_i) = cur_sim;
end

%% Plot
figure;
xlabel('Axial Position [mm]');
ylabel('Intensity [W/cm^2]');

hold on

for sim_i = 1:length(sim_res)
    cur_sim = sim_res(sim_i);
    axial_position = (1:cur_sim.parameters.grid_dims(3))*0.5;
    if contains(cur_sim.name, 'right')
        axial_position = -(axial_position-(cur_sim.parameters.transducer.pos_grid(3)-1)*0.5);
    else
        axial_position = axial_position-(cur_sim.parameters.transducer.pos_grid(3)-1)*0.5;
    end
    plot(axial_position, cur_sim.pred_axial_intensity, 'DisplayName',cur_sim.name);
    %xlim([0 200])
end
        
hold off
title('Profile in water');
legend show