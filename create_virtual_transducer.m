% Change path to tuSIM folder
cd /home/affneu/kenvdzee/Documents/PRESTUS

% add paths
addpath('functions')
addpath(genpath('toolboxes')) 
addpath('/home/common/matlab/fieldtrip/qsub')
folder_locations.axial_profiles_location_csv = '/home/affneu/kenvdzee/Documents/axial_profiles/'; % link to attached csv folder location
folder_locations.config_location = '/home/affneu/kenvdzee/Documents/acoustic_simulation_scripts/configs/';
folder_locations.output_location = '/home/affneu/kenvdzee/Documents/acoustic_simulation_scripts/'; % For figure output

% Should match the name of the axial profile csv
transducer.name = 'CTX-250-001_250KHz_4-channel';

% Requested transducer behaviour
transducer.desired_peak_intensity_Isppa = 30;
transducer.desired_steering_depth_cm = 54.8;

% Technical input (normally specified in config)
transducer.n_elements: 4 # number of elements in the transducer
transducer.Elements_ID_mm: [0, 30.1788, 42.1388, 51.1088]
transducer.Elements_OD_mm: [29.62, 41.58, 50.55, 57.94]
transducer.curv_radius_mm: 62.94 # radius of curvature of the bowl 
transducer.dist_to_plane_mm: 52.38 # distance to the transducer plane from the geometric focus

[source_phase_deg, source_amp] = create_virtual_transducer(transducer, folder_locations, 'run_water_simulations', 1)

% Desired output:
source_phase_deg % Array of 4 phase angles [degrees] such as: [0, 0, 358.0546, 272.2390] (first is always 0)
source_amp % 198300 [Pa] for example
output figures (see example folder)
csv with output:
    desired_steering_depth_cm
    max intensity at desired steering depth
    simulated steering depth_cm
    max intensity at simulated steering depth
    FLHM center intensity of measured axial profile
    FLHM center intensity of simulated axial profile