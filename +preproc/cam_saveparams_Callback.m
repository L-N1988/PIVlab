function cam_saveparams_Callback(~,~,~)
cameraParams=gui.retr('cameraParams');
cameraStats=gui.retr('cameraStats');
cam_selected_target_images = gui.retr('cam_selected_target_images');
cam_selected_rectification_image = gui.retr('cam_selected_rectification_image');
rectification_tform = gui.retr('rectification_tform');
cam_use_tilted_model       = gui.retr('cam_use_tilted_model');
cam_tilted_D               = gui.retr('cam_tilted_D');
cam_K_opencv               = gui.retr('cam_K_opencv');
if ~isempty(cameraParams) && ~isempty(cam_selected_target_images)
    [filen, pathn] = uiputfile('*.mat','Save camera calibration as...',fullfile(gui.retr('pathname'),'camera_calibration.mat'));
    if filen ~=0
        current_cam_nr = stereo.get_current_camera_index();
        if gui.retr('stereomode') == 1
            stereo_calibration = stereo.store_current_camera_state(current_cam_nr);
        else
            stereo_calibration = [];
        end
        save(fullfile(pathn,filen),"cameraParams","cameraStats","cam_selected_target_images","cam_selected_rectification_image","rectification_tform","current_cam_nr","stereo_calibration","cam_use_tilted_model","cam_tilted_D","cam_K_opencv");
    end
end
