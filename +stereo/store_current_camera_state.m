function coupled = store_current_camera_state(camera_index)
%STORE_CURRENT_CAMERA_STATE Copy the GUI/global calibration keys into the coupled object.

if nargin < 1 || isempty(camera_index)
	camera_index = stereo.get_current_camera_index();
end

coupled = stereo.ensure_coupled_calibration();
state = stereo.get_camera_calibration_state(coupled, camera_index);
state.cameraParams = gui.retr('cameraParams');
state.cameraStats = gui.retr('cameraStats');
state.cam_selected_target_images = gui.retr('cam_selected_target_images');
state.cam_selected_rectification_image = gui.retr('cam_selected_rectification_image');
state.rectification_tform = gui.retr('rectification_tform');
state.cam_use_calibration = gui.retr('cam_use_calibration');
state.cam_use_rectification = gui.retr('cam_use_rectification');

handles = gui.gethand;
if isfield(handles, 'calib_usecalibration') && isgraphics(handles.calib_usecalibration)
	state.cam_use_calibration = handles.calib_usecalibration.Value;
end
if isfield(handles, 'calib_userectification') && isgraphics(handles.calib_userectification)
	state.cam_use_rectification = handles.calib_userectification.Value;
end

coupled = stereo.set_camera_calibration_state(coupled, camera_index, state);
gui.put('stereo_calibration', coupled);

stereo_session = gui.retr('stereo_session');
if ~isempty(stereo_session) && isfield(stereo_session, 'calibration')
	stereo_session.calibration.stereo = coupled;
	stereo_session.calibration.coupled = coupled;
	gui.put('stereo_session', stereo_session);
end
end
