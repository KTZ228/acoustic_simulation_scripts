%% These parameters can be changed
% Delete if you have rights to add paths to Matlab
cd /home/affneu/kenvdzee/SimNIBS-4.0/
addpath(genpath('simnibs_env'))

cd /home/affneu/kenvdzee/Documents/PRESTUS/
addpath('functions')
addpath(genpath('toolboxes')) 
addpath('/home/common/matlab/fieldtrip/qsub')

config_location = '/home/affneu/kenvdzee/Documents/acoustic_simulation_scripts/configs/';
config_name = 'transducer_preview_config.yaml';

% Sets overwrite parameters and reference to transducer distance
overwrite_option = 'always';
interactive_option = 0;

subject_list = 1;
stimulate_amygdala = 1;
coordinate_list_name_location = '/project/3023001.06/Simulations/kenneth_test/simulations/coordinate_lists/transducer_coordinates_subjects_sjoerd.csv';

% Read coordinate list
coordinate_list = readtable(coordinate_list_name_location);

if stimulate_amygdala == 1
    stimulation_target = 'amygdala';
else
    stimulation_target = 'dACC';
end

for subject_id = subject_list
    
    % Load config for specific participant
    parameters = load_parameters(config_name, config_location);
    full_sub_id = sprintf('sub-%03d',subject_id);

    %% Setting folder locations
    filename_t1 = dir(sprintf(fullfile(parameters.data_path,parameters.t1_path_template), subject_id));
    t1_header = niftiinfo(fullfile(filename_t1.folder,filename_t1.name));
    t1_image = niftiread(fullfile(filename_t1.folder,filename_t1.name));
    
    %% Run the beginning of the simulations
    parameters.overwrite_files = overwrite_option;
    parameters.interactive = interactive_option;
    
    % Selects the simulation medium
    parameters.simulation_medium = 'layered';

    % Set filename
    parameters.results_filename_affix = 'positioning_preview';

    %% Load coordinates 
    row_left = coordinate_list(strcmp(coordinate_list.subject_id, full_sub_id) .* strcmp(coordinate_list.stim_target, stimulation_target) .* strcmp(coordinate_list.stim_site), 'left',:);

    row_right = coordinate_list(strcmp(coordinate_list.subject_id, full_sub_id) .*...
        strcmp(coordinate_list.stim_target, stimulation_target) .*...
        strcmp(coordinate_list.stim_site, 'right'),:);

    parameters_left.transducer.pos_t1_grid
    parameters_left.focus_pos_t1_grid

    parameters_right.transducer.pos_t1_grid
    parameters_right.focus_pos_t1_grid

    %% Send jobs to qsub
    single_subject_pipeline_with_qsub(subject_id, parameters_left, timelimit, memorylimit);
    single_subject_pipeline_with_qsub(subject_id, parameters_right, timelimit, memorylimit);
end