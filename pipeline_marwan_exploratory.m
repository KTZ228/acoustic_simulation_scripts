%% These parameters can be changed
% Delete if you have rights to add paths to Matlab
cd /home/affneu/kenvdzee/SimNIBS-4.0/
addpath(genpath('simnibs_env'))

cd /home/affneu/kenvdzee/Documents/PRESTUS/
addpath('functions')
addpath(genpath('toolboxes')) 
addpath('/home/common/matlab/fieldtrip/qsub')

run_layered_sims = 1;
test_pipeline = 0;

%% Add subject numbers for whom the localite files are flipped
incorrectly_named_files_table = readtable('/project/3023001.06/Simulations/kenneth_test/original_data/incorrectly_named_files.csv', 'Delimiter', ',');
config_location = '/home/affneu/kenvdzee/Documents/acoustic_simulation_scripts/configs/';
% Set config files and export location
target_names = {'left_amygdala', 'right_amygdala'};
config_left_transducer = 'config_marwan_amygdala_exploratory_PCD15287_01002_left_65mm.yaml';
config_right_transducer = 'config_marwan_amygdala_exploratory_PCD15287_01002_right_65mm.yaml';

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
parameters_left = load_parameters(config_left_transducer, config_location);

% Create a list containing all subjects with folders in 'raw_data'
files = struct2table(dir(parameters_left.data_path));
subject_list_table = files(logical(contains(files.name, 'sub') .* ~contains(files.name, 'm2m')),:);
subject_list = str2double((extract(subject_list_table{:,1}, digitsPattern))');
subject_list = 8; % change to own sub-id

for subject_id = subject_list
    
    % Setting folder locations
    filename_t1 = dir(sprintf(fullfile(parameters_left.data_path,parameters_left.t1_path_template), subject_id));
    t1_header = niftiinfo(fullfile(filename_t1.folder,filename_t1.name));
    t1_image = niftiread(fullfile(filename_t1.folder,filename_t1.name));
    
    %% Load configs for each transducer coordinate
    parameters_left = load_parameters(config_left_transducer, config_location);
    parameters_right = load_parameters(config_right_transducer, config_location);
    
    %% Label transducer and focus locations
    transducers = [parameters_left.transducer.pos_t1_grid' parameters_right.transducer.pos_t1_grid'];
    focus = [parameters_left.focus_pos_t1_grid' parameters_right.focus_pos_t1_grid'];

    %% Preview transducer locations
    imshowpair(plot_t1_with_transducer(t1_image, t1_header.PixelDimensions(1), transducers(:,1), focus(:,1), parameters_left), ...
        plot_t1_with_transducer(t1_image, t1_header.PixelDimensions(1), transducers(:,2), focus(:,2), parameters_left),'montage');
    
    %% Simulations for the left target
    % Reload the parameters for the specific transducer
    parameters_left = load_parameters(config_left_transducer, config_location);
    parameters_left.overwrite_files = overwrite_option;
    parameters_left.interactive = interactive_option;
    
    % Selects the simulation medium
    parameters_left.simulation_medium = layered_simulations;

    % Adjust timelimit if heating simulations are to be run
    if isfield(parameters_left,'run_heating_sims') && parameters_left.run_heating_sims == 1
        timelimit = 60*60*24;
        memorylimit = 64;
    else
        timelimit = 60*60*4;
        memorylimit = 40;
    end

    % Select localite coordinates (all redundant depending on how
    % coordinates are translated)
    target_id = 1;
    parameters_left.transducer.pos_t1_grid = transducers(:,target_id)';
    parameters_left.focus_pos_t1_grid = focus(:,target_id)';

    % Set filename
    parameters_left.results_filename_affix = sprintf('_target_%s', target_names{target_id});

    % Send job to qsub (if not in testing mode)
    if test_pipeline == 0
        single_subject_pipeline_with_qsub(subject_id, parameters_left, timelimit, memorylimit);
    end

    %% Simulations for right target
    parameters_right = load_parameters(config_right_transducer, config_location);
    parameters_right.overwrite_files = overwrite_option;
    parameters_right.interactive = interactive_option;
    
    % Select 'layered' when simulating the transmission in a skull
    parameters_right.simulation_medium = layered_simulations;

    % Adjust timelimit if heating simulations are to be run
    if isfield(parameters_right,'run_heating_sims') && parameters_right.run_heating_sims == 1
        timelimit = 60*60*24;
        memorylimit = 64;
    else
        timelimit = 60*60*4;
        memorylimit = 40;
    end
    
    % Select localite coordinates
    target_id = 2;
    parameters_right.transducer.pos_t1_grid = transducers(:,target_id)';
    parameters_right.focus_pos_t1_grid = focus(:,target_id)';

    % Set filename 
    parameters_right.results_filename_affix = sprintf('_target_%s', target_names{target_id});

    % Send job to qsub (if not in testing mode)
    if test_pipeline == 0
        single_subject_pipeline_with_qsub(subject_id, parameters_right, timelimit, memorylimit);
    end
end