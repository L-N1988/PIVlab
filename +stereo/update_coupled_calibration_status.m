function coupled = update_coupled_calibration_status(coupled)
%UPDATE_COUPLED_CALIBRATION_STATUS Refresh summary fields on the coupled object.

if nargin == 0 || isempty(coupled)
	coupled = stereo.default_coupled_calibration();
	return
end

num_calibrated = 0;
num_rectified = 0;
for i = 1:numel(coupled.cameras)
	state = coupled.cameras(i);
	if isfield(state, 'cameraParams') && ~isempty(state.cameraParams)
		num_calibrated = num_calibrated + 1;
	end
	if isfield(state, 'rectification_tform') && ~isempty(state.rectification_tform)
		num_rectified = num_rectified + 1;
	end
end

coupled.summary.num_calibrated_cameras = num_calibrated;
coupled.summary.num_rectified_cameras = num_rectified;
coupled.summary.is_complete = num_calibrated == 2;
end
