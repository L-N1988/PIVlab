function coupled = default_coupled_calibration()
%DEFAULT_COUPLED_CALIBRATION Create the stereo calibration source of truth.

coupled = struct();
coupled.schema_version = 1;
coupled.current_cam_nr = 1;
coupled.cameras = repmat(stereo.default_camera_calibration_state(), 1, 2);
coupled.cameras(1) = stereo.default_camera_calibration_state(1);
coupled.cameras(2) = stereo.default_camera_calibration_state(2);

coupled.stereo = struct();
coupled.stereo.status = 'not_estimated';
coupled.stereo.mapping = [];
coupled.stereo.disparity_model = [];
coupled.stereo.notes = {};

coupled.summary = struct();
coupled.summary.num_calibrated_cameras = 0;
coupled.summary.num_rectified_cameras = 0;
coupled.summary.is_complete = false;
end
