% Change path to tuSIM folder
cd /home/mrphys/kenvdzee/Documents/PRESTUS

% add paths
addpath('functions')
addpath(genpath('toolboxes')) 
addpath('/home/common/matlab/fieldtrip/qsub')
masks_location = '/project/3023001.06/Simulations/';

parameters = load_parameters('sjoerd_config_opt_CTX250-026_105_61.5mm.yaml');
parameters.results_filename_affix = '_target_right_amygdala';

% Extract list of participants
%files = struct2table(dir(parameters.data_path));
%subject_list_table = files(logical(contains(files.name, 'sub') .* ~contains(files.name, 'm2m')),:);
%subject_list = str2double((extract(subject_list_table{:,1}, digitsPattern))');
subject_list = [1,3,4,5,8,9,10,14,17,18,19];
%subject_list = 19;

% Load ROI
maskname = 'juelich_prob_GM_Amygdala_laterobasal_groupL_thr75_bin.nii.gz';
mask_location = fullfile(masks_location, maskname);
mask = niftiread(mask_location);

create_group_MNI_plots(subject_list, parameters, 'ROI_MNI_mask', mask, 'outputs_suffix', '_max_intensity', 'plot_max_intensity', 1, 'add_FWHM_boundary', 1, 'plot_heating', 0, 'brightness_correction', 1)
