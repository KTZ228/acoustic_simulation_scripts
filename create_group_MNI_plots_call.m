% Change path to tuSIM folder
cd /home/affneu/kenvdzee/Documents/PRESTUS

% add paths
addpath('functions')
addpath(genpath('toolboxes')) 
addpath('/home/common/matlab/fieldtrip/qsub')
masks_location = '/project/3023001.06/Simulations/kenneth_test/simulations/ROI_masks/';
config_location = '/home/affneu/kenvdzee/Documents/acoustic_simulation_scripts/configs/';

plotting_target = 'left_amygdala';

if strcmp(plotting_target, 'left_dACC')
    parameters = load_parameters('config_kenneth_phd_1_dACC_exploratory_CTX250-001_203_60.9mm.yaml', config_location);
    parameters.results_filename_affix = '_target_left_dACC';
    maskname = 'dACC_sphere_5mmiso_groupL_bin_MNI152.nii.gz';
    slice_axis = 'x';
elseif strcmp(plotting_target, 'right_dACC')
    parameters = load_parameters('config_kenneth_phd_1_dACC_exploratory_CTX250-026_105_61.5mm.yaml', config_location);
    parameters.results_filename_affix = '_target_right_dACC';
    maskname = 'dACC_sphere_5mmiso_groupR_bin_MNI152.nii.gz';
    slice_axis = 'x';
elseif strcmp(plotting_target, 'left_amygdala')
    parameters = load_parameters('config_kenneth_phd_1_amygdala_exploratory_CTX250-001_203_60.9mm.yaml', config_location);
    parameters.results_filename_affix = '_target_left_amygdala';
    maskname = 'juelich_prob_GM_Amygdala_laterobasal_groupR_thr85_bin.nii.gz';
    slice_axis = 'y';
elseif strcmp(plotting_target, 'right_amygdala')
    parameters = load_parameters('config_kenneth_phd_1_amygdala_exploratory_CTX250-026_105_61.5mm.yaml', config_location);
    parameters.results_filename_affix = '_target_right_amygdala';
    maskname = 'juelich_prob_GM_Amygdala_laterobasal_groupL_thr85_bin.nii.gz';
    slice_axis = 'y';
else
    disp('Please select a plotting_target')
    return
end

% Extract list of participants
files = struct2table(dir(parameters.data_path));
subject_list_table = files(logical(contains(files.name, 'sub') .* ~contains(files.name, 'm2m')),:);
subject_list = str2double((extract(subject_list_table{:,1}, digitsPattern))');
subject_list = 1;

% Load ROI
mask_location = fullfile(masks_location, maskname);
mask = niftiread(mask_location);

create_group_MNI_plots(subject_list, parameters, 'ROI_MNI_mask', mask,...
    'plot_max_intensity', 1, 'outputs_suffix', '_max_intensity',...
    'add_FWHM_boundary', 1, 'brightness_correction', 1,...
    'plot_heating', 0, 'slice_label', slice_axis)