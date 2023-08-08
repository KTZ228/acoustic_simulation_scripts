cd /home/mrphys/kenvdzee/Documents/PRESTUS/
addpath('functions')

parameters = load_parameters('sjoerd_config_opt_CTX250-001_203_60.9mm.yaml');
reference_to_transducer_distance = -(parameters.transducer.curv_radius_mm - parameters.transducer.dist_to_plane_mm);
outputs_path = parameters.temp_output_dir;

files = struct2table(dir(parameters.data_path));
subject_list_table = files(logical(contains(files.name, 'sub') .* ~contains(files.name, 'm2m')),:);
subject_list = str2double((extract(subject_list_table{:,1}, digitsPattern))');
subject_list = [1,3,4,5,8,9,10,14,17,18,19];
subject_list = 1;

for subject_i = 1:length(subject_list)
    subject_id = subject_list(subject_i);
    
    if isfield(parameters,'subject_subfolder') && parameters.subject_subfolder == 1
        results_prefix = sprintf('sub-%1$03d/sub-%1$03d', subject_id);
    else
        results_prefix = sprintf('sub-%1$03d', subject_id);
    end

    % Load segmented file
    parameters.results_filename_affix = '_target_left_amygdala'; %temporary, for testing
    segmented_image_mni_file = fullfile(outputs_path, sprintf('%s_final_medium_masks_MNI%s.nii.gz', results_prefix, parameters.results_filename_affix));
    segmented_image_mni = niftiread(segmented_image_mni_file);
    segmented_header = niftiinfo(segmented_image_mni_file);

    % Load transducer localite file
    trig_mark_files = dir(sprintf('%ssub-%03d/localite_sub%03d_ses01_right*.xml',parameters.data_path, subject_id, subject_id));
    % Sort by datetime to pick the most recent file
    extract_dt = @(x) datetime(x.name(29:end-4),'InputFormat','yyyyMMddHHmmssSSS');
    [~,idx] = sort([arrayfun(extract_dt,trig_mark_files)],'descend');
    trig_mark_files = trig_mark_files(idx);
    % Translate transducer trigger markers to raster positions
    [transducer_ras_position, transducer_axis_orientation_ras_position] = get_trans_pos_from_trigger_markers(fullfile(trig_mark_files(1).folder, trig_mark_files(1).name), 5, ...
        reference_to_transducer_distance, parameters.expected_focal_distance_mm);
    transducer_position = ras_to_grid(transducer_ras_position, segmented_header);
    transducer_axis_orientation_position = ras_to_grid(transducer_axis_orientation_ras_position, segmented_header);

    % Preview transducer location in segmented image
    imshow(plot_t1_with_transducer(segmented_image_mni, segmented_header.PixelDimensions(1), transducer_position, transducer_axis_orientation_position, parameters));

    % Determine grid size of transducer and size of entire grid
    grid_step_mm = parameters.grid_step_mm;
    transducer_outer_radius = max(floor(parameters.transducer.Elements_OD_mm / grid_step_mm / 2) + 1);
    grid_size = size(segmented_image_mni);

    % Determine coordinates around which a cylinder has to be made
    center_transducer = (transducer_position + transducer_axis_orientation_position) / 2;
    height_transducer = norm(transducer_axis_orientation_position - transducer_position);

    % Create and fill the cylinder
    [x, y, z] = ndgrid(1:grid_size(1), 1:grid_size(2), 1:grid_size(3));
    cylinder_mask = (x - center_transducer(1)).^2 + (y - center_transducer(2)).^2 <= transducer_outer_radius^2 & ...
        z >= center_transducer(3) - height_transducer/2 & z <= center_transducer(3) + height_transducer/2;

    % Replace values outside cylinder with 0
    segmented_image_mni(~cylinder_mask) = 0;

    % Save new segmented image with novel extension
    [path, filename, extension_1] = fileparts(segmented_image_mni_file);
    [~, filename, extension_2] = fileparts(filename);
    cut_moniker = 'cutout';
    segmented_image_mni_cut_file = sprintf('%s/%s_%s%s%s', path, filename, cut_moniker, extension_2, extension_1);
    niftiwrite(segmented_image_mni, segmented_image_mni_cut_file, segmented_header, 'Compressed', true);
end