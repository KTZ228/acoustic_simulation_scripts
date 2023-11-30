function simnibs_mni2subject_coords(m2m_folder, coordinates_list_mni, coordinates_list_subject)
    arguments
        coordinates_list_mni double
        coordinates_list_subject double
        m2m_folder string
        parameters struct
    end
    
    if isfield(parameters,'ld_library_path')
        ld_command = sprintf('export LD_LIBRARY_PATH="%s"; ', parameters.ld_library_path);
    else
        ld_command = '';
    end
    system(sprintf('%s%s/mni2subject_coords -m %s -s %s -o %s;', ld_command, parameters.simnibs_bin_path, m2m_folder, coordinates_list_mni, coordinates_list_subject))

    system(sprintf('mv %s %s', simnibs_name, path_to_output_img));

end