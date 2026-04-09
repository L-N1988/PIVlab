function state = get_camera_calibration_state(coupled, camera_index)
%GET_CAMERA_CALIBRATION_STATE Return one camera slot from a coupled object.

if nargin < 2 || isempty(camera_index)
	camera_index = 1;
end

if nargin == 0 || isempty(coupled) || ~isfield(coupled, 'cameras') || numel(coupled.cameras) < camera_index
	state = stereo.default_camera_calibration_state(camera_index);
	return
end

state = coupled.cameras(camera_index);
if isempty(state)
	state = stereo.default_camera_calibration_state(camera_index);
end
end
