function cam_clearparams_Callback(~,~,~)
handles=gui.gethand;
handles.calib_usecalibration.Value = 0;
preproc.cam_enable_cam_calib_Callback('')
gui.put('cameraParams',[]);
gui.put('cameraStats',[]);
gui.put('cam_selected_target_images',[]);
gui.put('rectification_tform',[]);
gui.put('cam_selected_rectification_image',[]);
gui.put('cam_use_rectification',0);
handles.calib_userectification.Value = 0;
if gui.retr('stereomode') == 1
    stereo.store_current_camera_state();
end
