% Delete if you have rights to add paths to Matlab
cd /home/mrphys/kenvdzee/SimNIBS-4.0/
addpath(genpath('simnibs_env'))

cd /home/mrphys/kenvdzee/Documents/PRESTUS/
addpath('functions')
addpath(genpath('toolboxes')) 
addpath('/home/common/matlab/fieldtrip/qsub')
timelimit = 60*60*24; %for thermal simulations

config = 'to be decided.yaml';

parameters = load_parameters(config);
parameters.overwrite_files = 'always';
parameters.simulation_medium = 'layered';
parameters.results_filename_affix = '';
parameters.interactive = 0;
reference_to_transducer_distance = -(parameters.transducer.curv_radius_mm - parameters.transducer.dist_to_plane_mm);

% Create list of files in datafolder (location can be changed in config file)
files = struct2table(dir(parameters.data_path));
subject_list_table = files(logical(contains(files.name, 'sub') .* ~contains(files.name, 'm2m')),:);
subject_list = str2double((extract(subject_list_table{:,1}, digitsPattern))');

subject_list = [1]; % Test

for subject_id = subject_list

    % Setting folder locations
    subj_folder = fullfile(parameters.data_path,sprintf('sub-%1$03d/', subject_id));
    filename_t1 = dir(sprintf(fullfile(parameters.data_path,parameters.t1_path_template), subject_id));
    t1_header = niftiinfo(fullfile(filename_t1.folder,filename_t1.name));    t1_image = niftiread(fullfile(filename_t1.folder,filename_t1.name));

    single_subject_pipeline_with_qsub(subject_id, parameters, timelimit);

end