% Change path to tuSIM folder
cd /home/mrphys/kenvdzee/Documents/PRESTUS

% add paths
addpath('functions')
addpath(genpath('toolboxes')) 
addpath('/home/common/matlab/fieldtrip/qsub')
masks_location = '/project/3023001.06/Simulations/kenneth_test/simulations/ROI_masks/';

parameters = load_parameters('config_kenneth_phd_1_amygdala_posthoc_CTX250-001_203_60.9mm.yaml');
parameters.results_filename_affix = '_target_left_amygdala';

% Extract list of participants
files = struct2table(dir(parameters.data_path));
subject_list_table = files(logical(contains(files.name, 'sub') .* ~contains(files.name, 'm2m')),:);
subject_list = str2double((extract(subject_list_table{:,1}, digitsPattern))');

% Load ROI
maskname = 'juelich_prob_GM_Amygdala_laterobasal_groupR_thr75_bin.nii.gz';
mask_location = fullfile(masks_location, maskname);
mask = niftiread(mask_location);

create_group_MNI_plots(subject_list, parameters, 'ROI_MNI_mask', mask,...
    'plot_max_intensity', 1, 'outputs_suffix', '_max_intensity',...
    'add_FWHM_boundary', 1, 'brightness_correction', 1,...
    'plot_heating', 0)