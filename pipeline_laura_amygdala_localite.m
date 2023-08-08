% Delete if you have rights to add paths to Matlab
cd /home/mrphys/kenvdzee/SimNIBS-4.0/
addpath(genpath('simnibs_env'))

cd /home/mrphys/kenvdzee/Documents/PRESTUS/
addpath('functions')
addpath(genpath('toolboxes')) 
addpath('/home/common/matlab/fieldtrip/qsub')

run_500KHz = 1;
timelimit = 60*60*24;

% Set config files and export location
if run_500KHz == 0
    config_left_transducer = 'laura_config_opt_CTX250-001_203_60.9mm.yaml';
    config_right_transducer = 'laura_config_opt_CTX250-001_203_60.9mm.yaml';
    subject_list = [1];
else
    config_left_transducer = 'laura_config_opt_CTX500-024_203_77.3mm.yaml';
    config_right_transducer = 'laura_config_opt_CTX500-024_203_77.3mm.yaml';
    subject_list = [2];
end

overwrite_option = 'always';
parameters = load_parameters(config_left_transducer);
reference_to_transducer_distance = -(parameters.transducer.curv_radius_mm - parameters.transducer.dist_to_plane_mm);

incorrectly_named_transducers = [];

for subject_id = subject_list

    % Setting folder locations
    subj_folder = fullfile(parameters.data_path,sprintf('sub-%1$03d/', subject_id));
    filename_t1 = dir(sprintf(fullfile(parameters.data_path,parameters.t1_path_template), subject_id));
    t1_header = niftiinfo(fullfile(filename_t1.folder,filename_t1.name));
    t1_image = niftiread(fullfile(filename_t1.folder,filename_t1.name));
    %{
    % Left transducer localite files
    if ismember(subject_id, incorrectly_named_transducers)
        trig_mark_files = dir(sprintf('%ssub-%03d/localite_sub%03d_ses01_right*.xml',parameters.data_path, subject_id, subject_id));
        extract_dt = @(x) datetime(x.name(29:end-4),'InputFormat','yyyyMMddHHmmssSSS');
    else
        trig_mark_files = dir(sprintf('%ssub-%03d/localite_sub%03d_ses01_left*.xml',parameters.data_path, subject_id, subject_id));
        extract_dt = @(x) datetime(x.name(28:end-4),'InputFormat','yyyyMMddHHmmssSSS');
    end
    
    % sort by datetime to pick the most recent file
    [~,idx] = sort([arrayfun(extract_dt,trig_mark_files)],'descend');
    trig_mark_files = trig_mark_files(idx);
    
    % Translate transducer trigger markers to raster positions
    [left_trans_ras_pos, left_amygdala_ras_pos] = get_trans_pos_from_trigger_markers(fullfile(trig_mark_files(1).folder, trig_mark_files(1).name), 5, ...
        reference_to_transducer_distance, parameters.expected_focal_distance_mm);
    left_trans_pos = ras_to_grid(left_trans_ras_pos, t1_header);
    left_amygdala_pos = ras_to_grid(left_amygdala_ras_pos, t1_header);
    %}
    left_trans_pos = [0;0;0];
    left_amygdala_pos = [0;0;0];
    % Right traleft_amygdala_posnsducer localite file
    if ismember(subject_id, incorrectly_named_transducers)
        trig_mark_files = dir(sprintf('%ssub-%03d/localite_sub%03d_ses01_left*.xml',parameters.data_path, subject_id, subject_id));
        extract_dt = @(x) datetime(x.name(28:end-4),'InputFormat','yyyyMMddHHmmssSSS');
    else
        trig_mark_files = dir(sprintf('%ssub-%03d/localite_sub%03d_ses01_right*.xml',parameters.data_path, subject_id, subject_id));
        extract_dt = @(x) datetime(x.name(29:end-4),'InputFormat','yyyyMMddHHmmssSSS');
    end
    
    % sort by datetime
    [~,idx] = sort([arrayfun(extract_dt,trig_mark_files)],'descend');
    trig_mark_files = trig_mark_files(idx);
    
    % Translate transducer trigger markers to raster positions
    [right_trans_ras_pos, right_amygdala_ras_pos] = get_trans_pos_from_trigger_markers(fullfile(trig_mark_files(1).folder, trig_mark_files(1).name), 5, ...
        reference_to_transducer_distance, parameters.expected_focal_distance_mm);
    right_trans_pos = ras_to_grid(right_trans_ras_pos, t1_header);
    right_amygdala_pos = ras_to_grid(right_amygdala_ras_pos, t1_header);

    % Generate plots with both transducers and targets separately
    %imshowpair(plot_t1_with_transducer(t1_image, t1_header.PixelDimensions(1), left_trans_pos, left_amygdala_pos, parameters), plot_t1_with_transducer(t1_image, t1_header.PixelDimensions(1), right_trans_pos, right_amygdala_pos, parameters),'montage');
    
    % Index transducer locations for simulation selection (and flip if necessary)
    transducers = [left_trans_pos right_trans_pos];
    targets = [left_amygdala_pos right_amygdala_pos];
    target_names = {'left_amygdala', 'right_amygdala'};
    %{
    % Simulations for left amygdala
    % Loading parameters
    parameters = load_parameters(config_left_transducer);
    parameters.overwrite_files = overwrite_option;
    
    % Select 'layered' when simulating the transmission in a skull
    parameters.simulation_medium = 'layered';
    reference_to_transducer_distance = -(parameters.transducer.curv_radius_mm - parameters.transducer.dist_to_plane_mm);
    
    target_id = 1;
    parameters.transducer.pos_t1_grid = transducers(:,target_id)';
    parameters.focus_pos_t1_grid = targets(:,target_id)';
    parameters.results_filename_affix = sprintf('_target_%s', target_names{target_id});
    parameters.interactive = 0;
    single_subject_pipeline_with_qsub(subject_id, parameters, timelimit);
    %}
    % Simulations for right amygdala
    parameters = load_parameters(config_right_transducer);
    parameters.overwrite_files = overwrite_option;
    
    % Select 'layered' when simulating the transmission in a skull
    parameters.simulation_medium = 'layered';
    reference_to_transducer_distance = -(parameters.transducer.curv_radius_mm - parameters.transducer.dist_to_plane_mm);
    
    target_id = 2;
    parameters.transducer.pos_t1_grid = transducers(:,target_id)';
    parameters.focus_pos_t1_grid = targets(:,target_id)';
    parameters.results_filename_affix = sprintf('_target_%s', target_names{target_id});
    parameters.interactive = 0;
    %single_subject_pipeline_with_qsub(subject_id, parameters, timelimit);

end