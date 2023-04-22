% Change path to tuSIM folder
cd /home/mrphys/kenvdzee/Documents/PRESTUS

% add paths
addpath('functions')
addpath(genpath('toolboxes')) 
addpath('/home/common/matlab/fieldtrip/qsub')
masks_location = '/project/3023001.06/Simulations/';

parameters = load_parameters('sjoerd_config_opt_CTX250-001_203_60.9mm.yaml');
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
