function coupled = apply_camera_state(camera_index)
%APPLY_CAMERA_STATE Push one camera slot from the coupled object into GUI/global keys.

if nargin < 1 || isempty(camera_index)
	camera_index = stereo.get_current_camera_index();
end

coupled = stereo.ensure_coupled_calibration();
state = stereo.get_camera_calibration_state(coupled, camera_index);

gui.put('current_cam_nr', camera_index);
gui.put('cameraParams', state.cameraParams);
gui.put('cameraStats', state.cameraStats);
gui.put('cam_selected_target_images', state.cam_selected_target_images);
gui.put('cam_selected_rectification_image', state.cam_selected_rectification_image);
gui.put('rectification_tform', state.rectification_tform);
gui.put('cam_use_calibration', state.cam_use_calibration);
gui.put('cam_use_rectification', state.cam_use_rectification);
% Restore manual annotation data for this camera
gui.put('cam_manual_image_points', state.manual_image_points);
gui.put('cam_manual_image_file',   state.manual_image_file);

handles = gui.gethand;
if isfield(handles, 'calib_usecalibration') && isgraphics(handles.calib_usecalibration)
	handles.calib_usecalibration.Value = logical(state.cam_use_calibration);
end
if isfield(handles, 'calib_userectification') && isgraphics(handles.calib_userectification)
	handles.calib_userectification.Value = logical(state.cam_use_rectification);
end
if isfield(handles, 'calib_undist_cam_label') && isgraphics(handles.calib_undist_cam_label)
	handles.calib_undist_cam_label.String = ['Current camera: CAMERA ' num2str(camera_index)];
end
if isfield(handles, 'calib_rect_cam_label') && isgraphics(handles.calib_rect_cam_label)
	handles.calib_rect_cam_label.String = ['Current camera: CAMERA ' num2str(camera_index)];
end

coupled.current_cam_nr = camera_index;
gui.put('stereo_calibration', coupled);
end
