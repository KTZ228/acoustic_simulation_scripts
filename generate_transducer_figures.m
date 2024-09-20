headreco_folder = fullfile(parameters.data_path, sprintf('m2m_sub-%03d', subject_id));
filename_segmented_headreco = fullfile(headreco_folder, sprintf('sub-%03d_masks_contr.nii.gz', subject_id));

segmented_img_orig = niftiread(filename_segmented_headreco);
segmented_img_head = niftiinfo(filename_segmented_headreco);
pixel_size = segmented_img_head.PixelDimensions(1);


parameters.transducer.pos_t1_grid = round(table2array(best_trans_pos(1,["trans_x","trans_y","trans_z"])));
parameters.focus_pos_t1_grid = round(table2array(best_trans_pos(1,["targ_x","targ_y","targ_z"])));
parameters.expected_focal_distance_mm = best_trans_pos.dist_to_target*pixel_size;
parameters.results_filename_affix = sprintf('_bob_%s_%i',target, best_trans_pos.idx);
[rotated_img, trans_xyz, target_xyz, transformation_matrix, rotation_matrix, angle_x_rad, angle_y_rad, montage_img] = ...
    align_to_focus_axis_and_scale(segmented_img_orig, segmented_img_head, parameters.transducer.pos_t1_grid', parameters.focus_pos_t1_grid', 1, parameters);
        
imagesc(squeeze(rotated_img(:,round(trans_xyz(2)),:)))
        rectangle('Position',[target_xyz([3,1])' - 2, 4 4],...
                  'Curvature',[0,0], 'EdgeColor','r',...
                 'LineWidth',2,'LineStyle','-');

        rectangle('Position',[trans_xyz([3,1])' - 2, 4 4],...
                  'Curvature',[0,0], 'EdgeColor','b',...
                 'LineWidth',2,'LineStyle','-');

        line([trans_xyz(3) target_xyz(3)], [trans_xyz(1) target_xyz(1)], 'Color', 'white')
        get_transducer_box(trans_xyz([1,3]), target_xyz([1,3]), segmented_img_head.PixelDimensions(1), parameters)
        colormap(ax3, [0.3 0.3 0.3; lines(12)])

        export_fig(output_plot, '-native')
        
        
