clear

% Delete if you have rights to add paths to Matlab
cd /home/mrphys/kenvdzee/Documents/MATLAB/
addpath(genpath('SimNIBS-3.2'))
addpath(genpath('k-wave'))

% simnibs world coordinates
% add paths
addpath /home/mrphys/kenvdzee/Documents/MATLAB/SimNIBS-3.2/simnibs_env/lib/python3.7/site-packages/simnibs/matlab
cd /home/mrphys/kenvdzee/orca-lab/project/tuSIM/ % change path here
addpath('functions')
addpath(genpath('toolboxes')) 
addpath('/home/common/matlab/fieldtrip/qsub') % uncomment if you are using Donders HPC

mni_targets = struct('amygdala',[-26 -4 -20]);
all_targets = fieldnames(mni_targets);
parameters = load_parameters('sjoerd_config_opt_CTX250-011_64.5mm.yaml');
out_folder = parameters.data_path+'/sim_outputs/';

all_subjs = [1,3,4];
for subject_id = all_subjs
    fprintf('Current subject: %03i\n', subject_id)

    headreco_folder = fullfile(parameters.data_path, sprintf('m2m_sub-%03d', subject_id));
    filename_segmented_headreco = fullfile(headreco_folder, sprintf('sub-%03d_masks_contr.nii.gz', subject_id));

    segmented_img_orig = niftiread(filename_segmented_headreco);
    segmented_img_head = niftiinfo(filename_segmented_headreco);        
    pixel_size = mean(segmented_img_head.PixelDimensions);
    
    im_center = round(size(segmented_img_orig)/2);

    target_name = all_targets{1};

    simnibs_coords = mni2subject_coords(mni_targets.(target_name), sprintf('%s/m2m_sub-%03i', parameters.data_path, subject_id))
    target = round(transformPointsInverse(segmented_img_head.Transform, simnibs_coords))

    figure
    montage({squeeze(segmented_img_orig(im_center(1),:,:)),...
        squeeze(segmented_img_orig(:,im_center(2),:)),...
        squeeze(segmented_img_orig(:,:,im_center(3)))}, viridis(8), 'Size',[1 3])

    [t1_x, t1_y, t1_z] = ndgrid(1:size(segmented_img_orig, 1),1:size(segmented_img_orig, 2),1:size(segmented_img_orig, 3));

    coord_mesh = struct;
    coord_mesh.x = gpuArray(t1_x);
    coord_mesh.y = gpuArray(t1_y);
    coord_mesh.z = gpuArray(t1_z);

    coord_mesh.xyz = gpuArray([reshape(t1_x,[],1) reshape(t1_y,[],1) reshape(t1_z,[],1)]);
    %{
    norm_v = gpuArray((trans_pos_coords-target)./repmat(sqrt(sum((trans_pos_coords-target).^2,2)),[1, 3]));

    max_od_mm = max(parameters.transducer.Elements_OD_mm);
    dist_gf_to_ep_mm = 0.5*sqrt(4*parameters.transducer.curv_radius_mm^2-max_od_mm^2);
    dist_tp_to_ep_mm = parameters.transducer.curv_radius_mm - dist_gf_to_ep_mm;
    pos_shift_mm = 5 + dist_tp_to_ep_mm;

    shifted_trans_pos_coords = trans_pos_coords + norm_v*pos_shift_mm/pixel_size;

    show_3d_scalp(segmented_img_orig, target, shifted_trans_pos_coords(i,:), parameters, pixel_size, coord_mesh.xyz, [-1 1 0])
    %}
end