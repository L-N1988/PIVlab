function camera_index = get_current_camera_index()
%GET_CURRENT_CAMERA_INDEX Return the currently selected camera slot.

camera_index = gui.retr('current_cam_nr');
if isempty(camera_index)
	coupled = gui.retr('stereo_calibration');
	if ~isempty(coupled) && isfield(coupled, 'current_cam_nr')
		camera_index = coupled.current_cam_nr;
	else
		camera_index = 1;
	end
	gui.put('current_cam_nr', camera_index);
end
end
