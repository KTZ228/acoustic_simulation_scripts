% create affine transform matrix to translate 10 cm in x
translate_x = eye(4);
translate_x(1:3, 4) = [0.1, 0, 0];
translate_x_label = 'Translate X';

% create affine transform matrix to translate 10 cm in y
translate_y = eye(4);
translate_y(1:3, 4) = [0, 0.1, 0];
translate_y_label = 'Translate Y';

% save transform matrices to HDF5 file
h5create('transform.h5', '/1/position_transform', [4, 4, 1], 'DataType', 'single');
h5write('transform.h5', '/1/position_transform', single(translate_x));
h5writeatt('transform.h5', '/1', 'transform_label', translate_x_label, 'TextEncoding', 'system');

h5create('transform.h5', '/2/position_transform', [4, 4, 1], 'DataType', 'single');
h5write('transform.h5', '/2/position_transform', single(translate_y));
h5writeatt('transform.h5', '/2', 'transform_label', translate_y_label, 'TextEncoding', 'system');

% set required file attributes
h5writeatt('transform.h5', '/', 'application_name', 'k-Plan', 'TextEncoding', 'system');
h5writeatt('transform.h5', '/', 'file_type', 'k-Plan Transducer Position', 'TextEncoding', 'system');
h5writeatt('transform.h5', '/', 'number_transforms', uint64(2));

%h5disp('/home/mrphys/kenvdzee/Documents/Project shortcuts/3023001.06/Simulations/kenneth_test/position-file.h5','/position_transform')