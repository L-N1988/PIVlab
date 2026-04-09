function cam_calibration_Callback(caller, ~, ~)
handles=gui.gethand;
if strcmpi(caller.Text, 'camera 1')
    gui.put('current_cam_nr',1);
    handles.calib_undist_cam_label.String = 'Current camera: CAMERA 1';
elseif strcmpi(caller.Text, 'camera 2')
    gui.put('current_cam_nr',2);
    handles.calib_undist_cam_label.String = 'Current camera: CAMERA 2';
end
if gui.retr('stereomode') == 1
    stereo.apply_camera_state(gui.retr('current_cam_nr'));
end
gui.switchui('multip26')
