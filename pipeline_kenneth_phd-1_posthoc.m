%% These parameters can be changed
% Delete if you have rights to add paths to Matlab
cd /home/mrphys/kenvdzee/SimNIBS-4.0/
addpath(genpath('simnibs_env'))

cd /home/mrphys/kenvdzee/Documents/PRESTUS/
addpath('functions')
addpath('configs')
addpath(genpath('toolboxes')) 
addpath('/home/common/matlab/fieldtrip/qsub')

run_amygdala_sims = 1;
run_250KHz = 1;
run_layered_sims = 1;

% Load a lookup table for incorrectly named files
incorrectly_named_files_table = readtable('/project/3023001.06/Simulations/kenneth_test/original_data/incorrectly_named_files.csv', 'Delimiter', ',');

% Set config files and export location
if run_amygdala_sims == 1
    target_names = {'left_amygdala', 'right_amygdala'};
    if run_250KHz == 1
        config_left_transducer = 'config_kenneth_phd_1_amygdala_posthoc_CTX250-001_203_60.9mm.yaml';
        config_right_transducer = 'config_kenneth_phd_1_amygdala_posthoc_CTX250-026_105_61.5mm.yaml';
    else
        config_left_transducer = 'config_kenneth_phd_1_amygdala_posthoc_CTX250-001_203_60.9mm.yaml';
        config_right_transducer = 'config_kenneth_phd_1_amygdala_posthoc_CTX250-026_105_61.5mm.yaml';
    end
else
    target_names = {'left_thalamus', 'right_thalamus'};
    if run_250KHz == 1
        config_left_transducer = 'config_kenneth_phd_1_thalamus_posthoc_CTX250-001_203_60.9mm.yaml';
        config_right_transducer = 'config_kenneth_phd_1_thalamus_posthoc_CTX250-026_105_61.5mm.yaml';
    else
        config_left_transducer = 'config_kenneth_phd_1_thalamus_posthoc_CTX250-001_203_60.9mm.yaml';
        config_right_transducer = 'config_kenneth_phd_1_thalamus_posthoc_CTX250-026_105_61.5mm.yaml';
    end
end

%% These parameters and functions should not be changed. Additional settings can be changed in the config files
% Add string of simulation medium as input
if run_layered_sims == 1
    layered_simulations = 'layered';
else
    layered_simulations = 'water';
end

% Sets overwrite parameters and reference to transducer distance
overwrite_option = 'always';
interactive_option = 0;
parameters_left = load_parameters(config_left_transducer);

% Create a list containing all subjects with folders in 'raw_data'
files = struct2table(dir(parameters_left.data_path));
subject_list_table = files(logical(contains(files.name, 'sub') .* ~contains(files.name, 'm2m')),:);
subject_list = str2double((extract(subject_list_table{:,1}, digitsPattern))');

for subject_id = subject_list
    %% Load T1 image
    % Setting folder locations
    filename_t1 = dir(sprintf(fullfile(parameters_left.data_path,parameters_left.t1_path_template), subject_id));
    if isempty(filename_t1)
        error('T1 file `%s` cannot be found', filename_t1)
    end

    % Load T1 header and file separately
    t1_header = niftiinfo(fullfile(filename_t1.folder,filename_t1.name));
    t1_image = niftiread(fullfile(filename_t1.folder,filename_t1.name));
    
    %% Extract left transducer location from localite file
    parameters_left = load_parameters(config_left_transducer);
    reference_to_transducer_distance = -(parameters_left.transducer.curv_radius_mm - parameters_left.transducer.dist_to_plane_mm);
    extract_dt = @(x) datetime(x.name(end-20:end-4),'InputFormat','yyyyMMddHHmmssSSS');
    
    % Load the trigger mark file
    localite_file_name_and_location = sprintf('%ssub-%03d/localite_sub%03d_ses01_left*.xml',parameters_left.data_path, subject_id, subject_id);
    trig_mark_files = dir(localite_file_name_and_location);
    if isempty(trig_mark_files)
        error('Localite file `%s` cannot be found', localite_file_name_and_location)
    end
    
    % Select the most recent file
    [~,idx] = sort([arrayfun(extract_dt,trig_mark_files)],'descend');
    trig_mark_files = trig_mark_files(idx);

    % Check whether file is mentioned in 'incorrectly_named_files_table' and replace it if found
    if any(trig_mark_files.name == string(incorrectly_named_files_table.original_name), 'all')
        idx = find(strcmp(trig_mark_files.name,incorrectly_named_files_table.original_name));
        localite_file_name_and_location = sprintf('%ssub-%03d/%s',parameters_left.data_path, subject_id, string(incorrectly_named_files_table.correct_name(idx)));
        trig_mark_files = dir(localite_file_name_and_location);
        if isempty(trig_mark_files)
            error('Localite file `%s` cannot be found', localite_file_name_and_location)
        end
    end
    
    % Translate transducer trigger markers to raster positions
    [left_trans_ras_pos, left_focus_ras_pos] = get_trans_pos_from_trigger_markers(fullfile(trig_mark_files(1).folder, trig_mark_files(1).name), 5, ...
        reference_to_transducer_distance, parameters_left.expected_focal_distance_mm);
    left_trans_pos = ras_to_grid(left_trans_ras_pos, t1_header);
    left_focus_pos = ras_to_grid(left_focus_ras_pos, t1_header);
    
    %% Extract right transducer location from localite file
    parameters_right = load_parameters(config_left_transducer);
    reference_to_transducer_distance = -(parameters_right.transducer.curv_radius_mm - parameters_right.transducer.dist_to_plane_mm);
    
    % Load the trigger mark file
    localite_file_name_and_location = sprintf('%ssub-%03d/localite_sub%03d_ses01_right*.xml',parameters_right.data_path, subject_id, subject_id);
    trig_mark_files = dir(localite_file_name_and_location);
    if isempty(trig_mark_files)
        error('Localite file `%s` is not found', localite_file_name_and_location)
    end
    
    % Select the most recent file
    [~,idx] = sort([arrayfun(extract_dt,trig_mark_files)],'descend');
    trig_mark_files = trig_mark_files(idx);

    % Check whether file is mentioned in 'incorrectly_named_files_table' and replace it if found
    if any(trig_mark_files.name == string(incorrectly_named_files_table.original_name), 'all')
        idx = find(strcmp(trig_mark_files.name,incorrectly_named_files_table.original_name));
        localite_file_name_and_location = sprintf('%ssub-%03d/%s',parameters_right.data_path, subject_id, string(incorrectly_named_files_table.correct_name(idx)));
        trig_mark_files = dir(localite_file_name_and_location);
        if isempty(trig_mark_files)
            error('Localite file `%s` is not found', localite_file_name_and_location)
        end
    end
    
    % Translate transducer trigger markers to raster positions
    [right_trans_ras_pos, right_focus_ras_pos] = get_trans_pos_from_trigger_markers(fullfile(trig_mark_files(1).folder, trig_mark_files(1).name), 5, ...
        reference_to_transducer_distance, parameters_right.expected_focal_distance_mm);
    right_trans_pos = ras_to_grid(right_trans_ras_pos, t1_header);
    right_focus_pos = ras_to_grid(right_focus_ras_pos, t1_header);

    %% Index transducer locations for simulation selection
    transducers = [left_trans_pos right_trans_pos];
    targets = [left_focus_pos right_focus_pos];

    %% Preview transducer locations
    imshowpair(plot_t1_with_transducer(t1_image, t1_header.PixelDimensions(1), left_trans_pos, left_focus_pos, parameters_left), plot_t1_with_transducer(t1_image, t1_header.PixelDimensions(1), right_trans_pos, right_focus_pos, parameters_left),'montage');
    
    %% Simulations for the left target
    % Reload the parameters for the specific transducer
    parameters_left = load_parameters(config_left_transducer);
    parameters_left.overwrite_files = overwrite_option;
    parameters_left.interactive = interactive_option;
    
    % Selects the simulation medium
    parameters_left.simulation_medium = layered_simulations;

    % Adjust timelimit if heating simulations are to be run
    if isfield(parameters_left,'run_heating_sims') && parameters_left.run_heating_sims == 1
        timelimit = 60*60*24;
    else
        timelimit = 60*60*4;
    end

    % Select localite coordinates
    target_id = 1;
    parameters_left.transducer.pos_t1_grid = transducers(:,target_id)';
    parameters_left.focus_pos_t1_grid = targets(:,target_id)';

    % Set filename
    parameters_left.results_filename_affix = sprintf('_target_%s', target_names{target_id});

    % Send job to qsub
    single_subject_pipeline_with_qsub(subject_id, parameters_left, timelimit);

    %% Simulations for right target
    parameters_right = load_parameters(config_right_transducer);
    parameters_right.overwrite_files = overwrite_option;
    parameters_right.interactive = interactive_option;
    
    % Select 'layered' when simulating the transmission in a skull
    parameters_right.simulation_medium = layered_simulations;

    % Adjust timelimit if heating simulations are to be run
    if isfield(parameters_right,'run_heating_sims') && parameters_right.run_heating_sims == 1
        timelimit = 60*60*24;
    else
        timelimit = 60*60*4;
    end
    
    % Select localite coordinates
    target_id = 2;
    parameters_right.transducer.pos_t1_grid = transducers(:,target_id)';
    parameters_right.focus_pos_t1_grid = targets(:,target_id)';

    % Set filename 
    parameters_right.results_filename_affix = sprintf('_target_%s', target_names{target_id});

    % Send job to qsub
    single_subject_pipeline_with_qsub(subject_id, parameters_right, timelimit);

end