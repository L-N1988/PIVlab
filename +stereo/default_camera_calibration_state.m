function state = default_camera_calibration_state(camera_index)
%DEFAULT_CAMERA_CALIBRATION_STATE Create an empty per-camera calibration state.

if nargin < 1 || isempty(camera_index)
	camera_index = 1;
end

state = struct();
state.camera_index = camera_index;
state.label = ['camera' num2str(camera_index)];
state.cameraParams = [];
state.cameraStats = [];
state.cam_selected_target_images = [];
state.cam_selected_rectification_image = [];
state.rectification_tform = [];
state.cam_use_calibration = 0;
state.cam_use_rectification = 0;
state.last_updated = [];
end
