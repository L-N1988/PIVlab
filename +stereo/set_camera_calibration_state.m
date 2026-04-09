function coupled = set_camera_calibration_state(coupled, camera_index, state)
%SET_CAMERA_CALIBRATION_STATE Replace one camera slot in a coupled object.

if nargin < 3 || isempty(state)
	state = stereo.default_camera_calibration_state(camera_index);
end
if nargin < 2 || isempty(camera_index)
	camera_index = 1;
end
if nargin < 1 || isempty(coupled)
	coupled = stereo.default_coupled_calibration();
end

if ~isfield(coupled, 'cameras') || numel(coupled.cameras) < 2
	coupled = stereo.default_coupled_calibration();
end

state.camera_index = camera_index;
state.last_updated = now;
coupled.cameras(camera_index) = state;
coupled.current_cam_nr = camera_index;
coupled = stereo.update_coupled_calibration_status(coupled);
end
