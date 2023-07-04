function [file_location] = Kplan_localite_to_h5(t1_location, prestus_location, parameters_name_without_extension, subject_id)
    
    arguments
        t1_location (1,1) string
        prestus_location (1,1) string
        parameters_name_without_extension (1,1) string
        subject_id (1,1) {mustBeNumeric}
    end

    cd(prestus_location)
    addpath('functions')
    parameters = load_parameters(sprintf('%s.yaml', parameters_name_without_extension));

    % Loads the localite file, decide whether to enforce naming convention or not
    trig_mark_files = dir(sprintf('%ssub-%03d/localite_sub%03d_ses01_left*.xml',parameters.data_path, subject_id, subject_id));

    % Choses the olders trigger mark file
    extract_dt = @(x) datetime(x.name(28:end-4),'InputFormat','yyyyMMddHHmmssSSS');
    [~,idx] = sort([arrayfun(extract_dt,trig_mark_files)],'descend');
    trigger_markers_file = trig_mark_files(idx);

    xml = xml2struct(fullfile(trigger_markers_file(1).folder, trigger_markers_file(1).name));

    % Arbitrarily takes the 5th trigger marker
    trigger_index = 5;

    % Find 'trigger_index'-th marker
    trigger_counter = 0;
    for i = 1:length(xml.Children)
        cur_child = xml.Children(i);
        if strcmp(cur_child.Name, 'TriggerMarker')
            trigger_counter=trigger_counter+1;
        end
        if trigger_counter==trigger_index
            break
        end
    end

    reference_to_target_distance = 0;

    coord_matrix = str2double({cur_child.Children(4).Attributes.Value});
    coord_matrix = reshape(coord_matrix',[4,4])';

    reference_pos = coord_matrix(:,4); % Position of the reference
    reference_center_to_head = coord_matrix(:,1); % From the center of the coil towards head

    transducer_pos = reference_pos + reference_to_transducer_distance*reference_center_to_head ;
    transducer_pos = transducer_pos(1:3);
    
    target_pos = reference_pos + reference_to_target_distance*reference_center_to_head ;
    target_pos = target_pos(1:3);
end