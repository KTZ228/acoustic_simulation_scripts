% Change path to tuSIM folder
cd /home/mrphys/kenvdzee/Documents/PRESTUS

% add paths
addpath('functions')
addpath(genpath('toolboxes')) 
addpath('/home/common/matlab/fieldtrip/qsub')
masks_location = '/project/3023001.06/Simulations/';

parameters = load_parameters('sjoerd_config_opt_CTX250-011_64.5mm.yaml');
parameters.results_filename_affix = '_target_left_amygdala';
parameters.headreco_backup = '/project/3023001.06/Simulations/headreco_backup';

% Extract list of participants
%files = struct2table(dir(parameters.data_path));
%subject_list_table = files(logical(contains(files.name, 'sub') .* ~contains(files.name, 'm2m')),:);
%subject_list = str2double((extract(subject_list_table{:,1}, digitsPattern))');
subject_list = [1,3,4,5,8,9,10,14,17,18,19];
%{
if strcmp(parameters.segmentation_software, 'charm')
    for subject_id = subject_list
        orig_file = fullfile(parameters.data_path, sprintf(parameters.t1_path_template, subject_id));
        m2m_folder = fullfile(parameters.data_path, sprintf('m2m_sub-%03d', subject_id));
        mni_file  = fullfile(m2m_folder, 'toMNI/T1');
        convert_final_to_MNI_simnibs(orig_file, m2m_folder, mni_file, parameters)
    end
end
%}
% Load ROI
maskname = 'juelich_prob_GM_Amygdala_laterobasal_groupL_thr75_bin.nii.gz';
mask_location = fullfile(masks_location, maskname);
mask = niftiread(mask_location);

create_group_MNI_plots(subject_list, parameters, 'ROI_MNI_mask', mask, 'outputs_suffix', '_max_intensity', 'plot_max_intensity', 1, 'add_FWHM_boundary', 1)

%% Test
subject_id = 10;
slice_labels = {'x','y','z'};
options.slice_label = 'y';
if parameters.subject_subfolder
    results_prefix = sprintf('sub-%1$03d/sub-%1$03d', subject_id);
else
    results_prefix = sprintf('sub-%1$03d', subject_id);
end
outputs_path = parameters.temp_output_dir;
headreco_folder = fullfile(parameters.data_path, sprintf('m2m_sub-%03d', subject_id));
isppa_map_mni_file  = fullfile(outputs_path, sprintf('%s_final_isppa_MNI%s.nii.gz', results_prefix, parameters.results_filename_affix));
segmented_image_mni_file = fullfile(outputs_path, sprintf('%s_final_medium_masks_MNI%s.nii.gz', results_prefix, parameters.results_filename_affix));
max_pressure_mni_file = fullfile(outputs_path, sprintf('%s_final_pressure_MNI%s.nii.gz', results_prefix, parameters.results_filename_affix));
output_pressure_file = fullfile(outputs_path,sprintf('%s_%s_isppa%s.csv', results_prefix, parameters.simulation_medium, parameters.results_filename_affix));
t1_mni_file = fullfile(headreco_folder, 'toMNI', 'final_tissues_MNI.nii.gz');

t1_mni = niftiread(t1_mni_file);
t1_mni_hdr = niftiinfo(t1_mni_file);

segmented_image_mni = niftiread(segmented_image_mni_file);
brain_ind = parameters.layer_labels.brain;
new_brain_ind = ones(1, length(brain_ind));
results_mask_original = changem(segmented_image_mni, new_brain_ind, brain_ind);
results_mask_original(results_mask_original > max(brain_ind)) = 0;
results_mask_original = logical(results_mask_original);
results_mask_size = size(results_mask_original);
results_mask_overlay = imresize3(results_mask_original, [(results_mask_size(1) + 20), (results_mask_size(2) + 20), (results_mask_size(3) + 20)]);
results_mask_overlay = results_mask_overlay(11:(end-10), 11:(end-10), 11:(end-10));
results_mask = results_mask_original.*results_mask_overlay;
changed_tissue_index = find(results_mask~=results_mask_original);
segmented_image_mni(changed_tissue_index) = parameters.layer_labels.skin;
t1_mni_file = '/project/3023001.06/Simulations/final_tissues_MNI';
niftiwrite(segmented_image_mni, t1_mni_file, 'Compressed', true);

% apply mask on neural tissue
isppa_map_mni = niftiread(isppa_map_mni_file);
segmented_image_mni = niftiread(segmented_image_mni_file);
brain_ind = parameters.layer_labels.brain;
new_brain_ind = ones(1, length(brain_ind));

results_mask_original = changem(segmented_image_mni, new_brain_ind, brain_ind);
results_mask_original(results_mask_original > max(brain_ind)) = 0;
results_mask_original = logical(results_mask_original);
results_mask_size = size(results_mask_original);

% Results_mask_overlay is a temporary fix for the neural tissue placed in the skin by Charm
results_mask_overlay = imresize3(results_mask_original, [(results_mask_size(1) + 20), (results_mask_size(2) + 20), (results_mask_size(3) + 20)]);
results_mask_overlay = results_mask_overlay(11:(end-10), 11:(end-10), 11:(end-10));
results_mask = results_mask_original.*results_mask_overlay;
changed_tissue_index = find(results_mask~=results_mask_original);
segmented_image_mni(changed_tissue_index) = parameters.layer_labels.skin;

isppa_map_mni = isppa_map_mni.*results_mask;