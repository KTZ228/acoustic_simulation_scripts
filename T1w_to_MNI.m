% Change path to tuSIM folder
cd /home/mrphys/kenvdzee/Documents/PRESTUS

% add paths
addpath('functions')
addpath(genpath('toolboxes')) 
addpath('/home/common/matlab/fieldtrip/qsub')
masks_location = '/project/3023001.06/Simulations/';

parameters = load_parameters('sjoerd_config_opt_CTX250-026_105_61.5mm.yaml');
parameters.results_filename_affix = '_target_right_amygdala';

% Create list of files in datafolder (location can be changed in config file)
%subject_list = [1,3,4,5,8,9,10,14,17,18,19];
subject_list = 1;

for subject_id = subject_list
    m2m_folder = fullfile(parameters.data_path, sprintf('m2m_sub-%03d/', subject_id));
    path_to_input_img = fullfile(m2m_folder,'T1.nii.gz');
    path_to_output_img = fullfile(m2m_folder,'toMNI/T1_to_MNI_post-hoc.nii.gz');

    convert_final_to_MNI_simnibs(path_to_input_img, m2m_folder, path_to_output_img, parameters)
end