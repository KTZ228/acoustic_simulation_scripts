%% These parameters can be changed
% Delete if you have rights to add paths to Matlab
cd /home/affneu/kenvdzee/SimNIBS-4.0/
addpath(genpath('simnibs_env'))

% Add some functions to the path
cd /home/affneu/kenvdzee/Documents/PRESTUS/
addpath('functions')
addpath(genpath('toolboxes')) 
addpath('/home/common/matlab/fieldtrip/qsub')

% Load the transducer_preview_config
config_location = '/home/affneu/kenvdzee/Documents/acoustic_simulation_scripts/configs/';
config_name = 'transducer_preview_config.yaml';
parameters = load_parameters(config_name, config_location);

% Load the coordinate list
coordinate_list_location = '/project/3023001.06/Simulations/kenneth_test/simulations/coordinate_lists/transducer_coordinates_subjects_sjoerd.csv';
coordinate_list = readtable(coordinate_list_location);

for i = 1:height(coordinate_list)
    
    % set parameters based on coordinate_list data
    subject_id_string = string(coordinate_list.subject_id(i));
    subject_id = sscanf(subject_id_string, 'sub-%03d');
    stim_target = string(coordinate_list.stim_target(i));
    stim_site = string(coordinate_list.stim_site(i));

    %% Setting folder locations
    filename_t1 = dir(sprintf(fullfile(parameters.data_path,parameters.t1_path_template), subject_id));
    t1_header = niftiinfo(fullfile(filename_t1.folder,filename_t1.name));
    t1_image = niftiread(fullfile(filename_t1.folder,filename_t1.name));

    %% Load coordinates
    pos_t1_grid = [coordinate_list.pos_t1_grid_x(i) coordinate_list.pos_t1_grid_y(i) coordinate_list.pos_t1_grid_z(i)];
    focus_pos_t1_grid = [coordinate_list.focus_pos_t1_grid_x(i) coordinate_list.focus_pos_t1_grid_y(i) coordinate_list.focus_pos_t1_grid_z(i)];

    parameters.transducer.pos_t1_grid = pos_t1_grid;
    parameters.focus_pos_t1_grid = focus_pos_t1_grid;

    %% Run the beginning of the simulations
    parameters.overwrite_files = 'always';
    parameters.interactive = 0;
    
    % Selects the simulation medium
    parameters.simulation_medium = 'layered';

    % Set filename
    pos_t1_grid_string = sprintf('-%d',pos_t1_grid);
    pos_t1_grid_string = pos_t1_grid_string(2:end);
    focus_pos_t1_grid_string = sprintf('-%d',focus_pos_t1_grid);
    focus_pos_t1_grid_string = focus_pos_t1_grid_string(2:end);
    parameters.results_filename_affix = sprintf('_positioning_preview_%s_%s_%s_%s', stim_target, stim_site, pos_t1_grid_string, focus_pos_t1_grid_string);

    %% Send jobs to qsub
    single_subject_pipeline_with_qsub(subject_id, parameters);
end