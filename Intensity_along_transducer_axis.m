% Get data
cd /home/mrphys/kenvdzee/orca-lab/project/tuSIM

% add paths
addpath('functions')
addpath(genpath('toolboxes')) 

opt_parameters = load_parameters('tutorial_config.yaml'); 

opt_parameters.results_filename_affix = '_optimized';
 % see default config for the list of mediums possible
opt_parameters.run_heating_sims = 1;

subfolders = ["250KHz" "500KHz"];
target = ["left" "right"];

figure = tiledlayout(2,2);
xlabel('Axial Position [mm]');
ylabel('Intensity [W/cm^2]');

%%
for f = 1:length(subfolders)
    for k = 1:length(target)
        opt_parameters.data_path = sprintf('/project/3023001.06/Simulations/all_files_with_output/%s/40W_per_cm2/',subfolders(f));

        files = dir(opt_parameters.data_path);
        notsubjects = (strlength(extractfield(files,'name')) == 7);
        files(~notsubjects) = [];
        subject_list = {'1'};
        medium_list = {'water'};
        for i = 1:length(files)
            fname = files(i).name;
            if regexp(fname, 'sub-\d+')
                fname = regexprep(fname,'sub-0','','ignorecase');
                subject_list{(i+1)} = fname;
                medium_list{(i+1)} = 'layered';
            end
        end

        sim_res = struct('subject_id',subject_list,'type', medium_list,'isppa_max',[],'p_max',[],'parameters',[],'pred_axial_pressure',[],'pred_axial_intensity',[],'isspa_max_pos',[],'isspa_max_pos_brain',[]);

        opt_parameters.simulation_medium = 'layered';
        opt_parameters.results_filename_affix = sprintf('_target_%s_amygdala',target(k));

        for sim_i = 1:length(sim_res)
            cur_sim = sim_res(sim_i);
            sim_type = cur_sim.type;
            subject = str2num(cur_sim.subject_id);

            load(fullfile(opt_parameters.data_path, sprintf('sub-%03d/sub-%03d_%s_after_cropping_and_smoothing%s.mat', subject, subject,...
                'layered', opt_parameters.results_filename_affix)), 'medium_masks')

            res = load(sprintf('%ssub-%03d/sub-%03d_%s_results%s.mat', opt_parameters.data_path, subject, subject, sim_type, opt_parameters.results_filename_affix),'sensor_data','parameters','kwave_medium');
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

        nexttile
        hold on
        for sim_i = 1:length(sim_res)
            cur_sim = sim_res(sim_i);
            axial_position = (1:cur_sim.parameters.grid_dims(3))*0.5;
            if contains(opt_parameters.results_filename_affix, 'right')
                axial_position = -(axial_position-(cur_sim.parameters.transducer.pos_grid(3)-1)*0.5);
            else
                axial_position = axial_position-(cur_sim.parameters.transducer.pos_grid(3)-1)*0.5;
            end
            plot(axial_position, cur_sim.pred_axial_intensity, 'DisplayName',cur_sim.subject_id);
        end
        hold off
        xlim([0 200])
        ylim([0 42])
        title(sprintf('Profile-%s-%s',subfolders(f),target(k)));
    end
end

legend show