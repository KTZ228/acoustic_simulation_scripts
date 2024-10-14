% Clean house
clc; clear;

% Add simnibs to the path
cd /home/affneu/kenvdzee/SimNIBS-4.0/
addpath(genpath('simnibs_env'))

% Add PRESTUS to the path
cd /home/affneu/kenvdzee/Documents/PRESTUS/
addpath('functions')
addpath(genpath('toolboxes')) 
addpath('/home/common/matlab/fieldtrip/qsub')

%% The following options can be altered
run_amygdala_sims = 1;
run_layered_sims = 1;
test_pipeline = 0;

% Add an integer or list of the subjects you want to simulate
stimulation_depth = '65mm';
subject_list = 8%[8, 9, 10, 14];

% Set config files and export location
if run_amygdala_sims == 1
    config_left_transducer = sprintf('config_kenneth_phd_1_amygdala_exploratory_PCD15287_01002_left_%s.yaml', stimulation_depth);
    config_right_transducer = sprintf('config_kenneth_phd_1_amygdala_exploratory_PCD15287_01002_right_%s.yaml', stimulation_depth);
    stimulation_target_left = 'left_amygdala';
    stimulation_target_right = 'right_amygdala';
else
    config_left_transducer = sprintf('config_kenneth_phd_1_dACC_exploratory_PCD15287_01002_left_%s.yaml', stimulation_depth);
    config_right_transducer = sprintf('config_kenneth_phd_1_dACC_exploratory_PCD15287_01002_right_%s.yaml', stimulation_depth);
    stimulation_target_left = 'left_posterior_dacc';
    stimulation_target_right = 'right_posterior_dacc';
    %stimulation_target_left = 'left_medial_dacc';
    %stimulation_target_right = 'right_medial_dacc';
    %stimulation_target_left = 'left_anterior_dacc';
    %stimulation_target_right = 'right_anterior_dacc';
end

% Config location
config_location = '/home/affneu/kenvdzee/Documents/acoustic_simulation_scripts/configs/';

%% These parameters and functions should not be changed. Additional changes can be made in the config files
% Add string of simulation medium as input
if run_layered_sims == 1
    layered_simulations = 'layered';
else
    layered_simulations = 'water';
end

% Sets overwrite parameters and reference to transducer distance
overwrite_option = 'always';
interactive_option = 0;
% Load config once to be able to load the right structural files
parameters_left = load_parameters(config_left_transducer, config_location);

for subject_id = subject_list
    
    % Setting folder locations
    filename_t1 = dir(sprintf(fullfile(parameters_left.data_path,parameters_left.t1_path_template), subject_id));
    t1_header = niftiinfo(fullfile(filename_t1.folder,filename_t1.name));
    t1_image = niftiread(fullfile(filename_t1.folder,filename_t1.name));
    
    %% Load configs for each transducer coordinate
    parameters_left = load_parameters(config_left_transducer, config_location);
    parameters_right = load_parameters(config_right_transducer, config_location);

    %% Load locations from the exploratory_coordinate_list
    exploratory_coordinate_list = readtable('/project/3023001.06/Simulations/kenneth_test/simulations/exploratory_coordinate_list.csv');
    
    index_subject = exploratory_coordinate_list.subject_id == subject_id;
    index_stimulation_target_left = strcmp(exploratory_coordinate_list.stimulation_target, stimulation_target_left);
    index_stimulation_target_right = strcmp(exploratory_coordinate_list.stimulation_target, stimulation_target_right);

    index_coordinates_left = index_subject & index_stimulation_target_left;
    index_coordinates_right = index_subject & index_stimulation_target_right;

    row_coordinates_left = exploratory_coordinate_list(index_coordinates_left, :);
    row_coordinates_right = exploratory_coordinate_list(index_coordinates_right, :);

    parameters_left.transducer.pos_t1_grid = [row_coordinates_left.pos_t1_grid_x, row_coordinates_left.pos_t1_grid_y, row_coordinates_left.pos_t1_grid_z];
    parameters_left.focus_pos_t1_grid = [row_coordinates_left.focus_pos_t1_grid_x, row_coordinates_left.focus_pos_t1_grid_y, row_coordinates_left.focus_pos_t1_grid_z];
    parameters_right.transducer.pos_t1_grid = [row_coordinates_right.pos_t1_grid_x, row_coordinates_right.pos_t1_grid_y, row_coordinates_right.pos_t1_grid_z];
    parameters_right.focus_pos_t1_grid = [row_coordinates_right.focus_pos_t1_grid_x, row_coordinates_right.focus_pos_t1_grid_y, row_coordinates_right.focus_pos_t1_grid_z];
    
    %% Label transducer and focus locations
    transducers = [parameters_left.transducer.pos_t1_grid' parameters_right.transducer.pos_t1_grid'];
    focus = [parameters_left.focus_pos_t1_grid' parameters_right.focus_pos_t1_grid'];

    %% Preview transducer locations
    % Makes a different slice depending on the target
    if run_amygdala_sims == 1
        slice_dim_right_figure = 3;
    else
        slice_dim_right_figure = 1;
    end

    figure(1);
    imshowpair(plot_t1_with_transducer(t1_image, t1_header.PixelDimensions(1), transducers(:,1), focus(:,1), parameters_left), ...
        plot_t1_with_transducer(t1_image, t1_header.PixelDimensions(1), transducers(:,1), focus(:,1), parameters_left, 'slice_dim', slice_dim_right_figure),'montage');
    title('Left target')

    figure(2);
    imshowpair(plot_t1_with_transducer(t1_image, t1_header.PixelDimensions(1), transducers(:,2), focus(:,2), parameters_left), ...
        plot_t1_with_transducer(t1_image, t1_header.PixelDimensions(1), transducers(:,2), focus(:,2), parameters_left, 'slice_dim', slice_dim_right_figure),'montage');
    title('Right target');
    
    %% Simulations for the left target
    % Load additional parameters into config
    parameters_left.overwrite_files = overwrite_option;
    parameters_left.interactive = interactive_option;
    parameters_left.simulation_medium = layered_simulations;

    % Adjust timelimit if heating simulations are to be run
    if isfield(parameters_left,'run_heating_sims') && parameters_left.run_heating_sims == 1
        timelimit = '24:00:00';
        memorylimit = 64;
    else
        timelimit = '04:00:00';
        memorylimit = 40;
    end

    % Set filename
    parameters_left.results_filename_affix = sprintf('_target_%s', stimulation_target_left);

    % Send job to qsub (if not in testing mode)
    if test_pipeline == 0
        single_subject_pipeline_with_slurm(subject_id, parameters_left, timelimit, memorylimit);%qsub(subject_id, parameters_left, 60*60*12, memorylimit);%
    end

    %% Simulations for right target
    % Load additional parameters into config
    parameters_right.overwrite_files = overwrite_option;
    parameters_right.interactive = interactive_option;
    parameters_right.simulation_medium = layered_simulations;

    % Adjust timelimit if heating simulations are to be run
    if isfield(parameters_right,'run_heating_sims') && parameters_right.run_heating_sims == 1
        timelimit = '24:00:00';
        memorylimit = 64;
    else
        timelimit = '04:00:00';
        memorylimit = 40;
    end

    % Set filename 
    parameters_right.results_filename_affix = sprintf('_target_%s', stimulation_target_right);

    % Send job to qsub (if not in testing mode)
    if test_pipeline == 0
        single_subject_pipeline_with_slurm(subject_id, parameters_right, timelimit, memorylimit);%qsub(subject_id, parameters_right, 60*60*12, memorylimit);
    end
end

% This is just here to go back to the script's directory
tmp = matlab.desktop.editor.getActive;
cd(fileparts(tmp.Filename));