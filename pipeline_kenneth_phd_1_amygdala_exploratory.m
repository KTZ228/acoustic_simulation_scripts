% Delete if you have rights to add paths to Matlab
cd /home/mrphys/kenvdzee/SimNIBS-4.0/
addpath(genpath('simnibs_env'))

cd /home/mrphys/kenvdzee/Documents/PRESTUS/
addpath('functions')
addpath(genpath('toolboxes')) 
addpath('/home/common/matlab/fieldtrip/qsub')

run_250KHz = 1;
run_layered_sims = 1;
timelimit = 60*60*24; % For heating sims

% Set config files and export location
if run_250KHz == 1
    config_left_transducer = 'config_kenneth_phd_1_amygdala_exploratory_CTX250-001_203_60.9mm.yaml';
    config_right_transducer = 'config_kenneth_phd_1_amygdala_exploratory_CTX250-026_105_61.5mm.yaml';
else
    config_left_transducer = 'config_kenneth_phd_1_amygdala_exploratory_CTX250-001_203_60.9mm.yaml';
    config_right_transducer = 'config_kenneth_phd_1_amygdala_exploratory_CTX250-026_105_61.5mm.yaml';
end
% Add string of simulation medium as input
if run_layered_sims == 1
    layered_simulations = 'layered';
end

overwrite_option = 'always';
parameters = load_parameters(config_left_transducer);
reference_to_transducer_distance = -(parameters.transducer.curv_radius_mm - parameters.transducer.dist_to_plane_mm);

% Create list of files in datafolder (location can be changed in config file)
files = struct2table(dir(parameters.data_path));
subject_list_table = files(logical(contains(files.name, 'sub') .* ~contains(files.name, 'm2m')),:);
subject_list = str2double((extract(subject_list_table{:,1}, digitsPattern))');

% Add subject numbers for whom the localite files are flipped
incorrectly_named_localite_files = [];

for subject_id = subject_list

    % Setting folder locations
    %subj_folder = fullfile(parameters.data_path,sprintf('sub-%1$03d/', subject_id));
    filename_t1 = dir(sprintf(fullfile(parameters.data_path,parameters.t1_path_template), subject_id));
    t1_header = niftiinfo(fullfile(filename_t1.folder,filename_t1.name));
    t1_image = niftiread(fullfile(filename_t1.folder,filename_t1.name));
    
    %% Extract left transducer location from localite file
    if ismember(subject_id, incorrectly_named_localite_files)
        trig_mark_files = dir(sprintf('%ssub-%03d/localite_sub%03d_ses01_right*.xml',parameters.data_path, subject_id, subject_id));
        extract_dt = @(x) datetime(x.name(29:end-4),'InputFormat','yyyyMMddHHmmssSSS');
    else
        trig_mark_files = dir(sprintf('%ssub-%03d/localite_sub%03d_ses01_left*.xml',parameters.data_path, subject_id, subject_id));
        extract_dt = @(x) datetime(x.name(28:end-4),'InputFormat','yyyyMMddHHmmssSSS');
    end
    
    % Sort by datetime to pick the most recent file
    [~,idx] = sort([arrayfun(extract_dt,trig_mark_files)],'descend');
    trig_mark_files = trig_mark_files(idx);
    
    % Translate transducer trigger markers to raster positions
    [left_trans_ras_pos, left_focus_ras_pos] = get_trans_pos_from_trigger_markers(fullfile(trig_mark_files(1).folder, trig_mark_files(1).name), 5, ...
        reference_to_transducer_distance, parameters.expected_focal_distance_mm);
    left_trans_pos = ras_to_grid(left_trans_ras_pos, t1_header);
    left_focus_pos = ras_to_grid(left_focus_ras_pos, t1_header);
    
    %% Extract right transducer location from localite file
    if ismember(subject_id, incorrectly_named_localite_files)
        trig_mark_files = dir(sprintf('%ssub-%03d/localite_sub%03d_ses01_left*.xml',parameters.data_path, subject_id, subject_id));
        extract_dt = @(x) datetime(x.name(28:end-4),'InputFormat','yyyyMMddHHmmssSSS');
    else
        trig_mark_files = dir(sprintf('%ssub-%03d/localite_sub%03d_ses01_right*.xml',parameters.data_path, subject_id, subject_id));
        extract_dt = @(x) datetime(x.name(29:end-4),'InputFormat','yyyyMMddHHmmssSSS');
    end
    
    % Sort by datetime
    [~,idx] = sort([arrayfun(extract_dt,trig_mark_files)],'descend');
    trig_mark_files = trig_mark_files(idx);
    
    % Translate transducer trigger markers to raster positions
    [right_trans_ras_pos, right_focus_ras_pos] = get_trans_pos_from_trigger_markers(fullfile(trig_mark_files(1).folder, trig_mark_files(1).name), 5, ...
        reference_to_transducer_distance, parameters.expected_focal_distance_mm);
    right_trans_pos = ras_to_grid(right_trans_ras_pos, t1_header);
    right_focus_pos = ras_to_grid(right_focus_ras_pos, t1_header);

    % Index transducer locations for simulation selection (and flip if necessary)
    transducers = [left_trans_pos right_trans_pos];
    targets = [left_focus_pos right_focus_pos];
    target_names = {'left_amygdala', 'right_amygdala'};

    %% Preview transducer locations
    imshowpair(plot_t1_with_transducer(t1_image, t1_header.PixelDimensions(1), left_trans_pos, left_focus_pos, parameters), plot_t1_with_transducer(t1_image, t1_header.PixelDimensions(1), right_trans_pos, right_focus_pos, parameters),'montage');
    
    %% Simulations for the left amygdala
    parameters = load_parameters(config_left_transducer);
    parameters.overwrite_files = overwrite_option;
    
    % Select 'layered' when simulating the transmission in a skull
    parameters.simulation_medium = layered_simulations;
    reference_to_transducer_distance = -(parameters.transducer.curv_radius_mm - parameters.transducer.dist_to_plane_mm);
    
    target_id = 1;
    parameters.transducer.pos_t1_grid = transducers(:,target_id)';
    parameters.focus_pos_t1_grid = targets(:,target_id)';
    parameters.results_filename_affix = sprintf('_target_%s', target_names{target_id});
    parameters.interactive = 0;
    single_subject_pipeline_with_qsub(subject_id, parameters, timelimit);

    %% Simulations for right amygdala
    parameters = load_parameters(config_right_transducer);
    parameters.overwrite_files = overwrite_option;
    
    % Select 'layered' when simulating the transmission in a skull
    parameters.simulation_medium = layered_simulations;
    reference_to_transducer_distance = -(parameters.transducer.curv_radius_mm - parameters.transducer.dist_to_plane_mm);
    
    target_id = 2;
    parameters.transducer.pos_t1_grid = transducers(:,target_id)';
    parameters.focus_pos_t1_grid = targets(:,target_id)';
    parameters.results_filename_affix = sprintf('_target_%s', target_names{target_id});
    parameters.interactive = 0;
    single_subject_pipeline_with_qsub(subject_id, parameters, timelimit);

end