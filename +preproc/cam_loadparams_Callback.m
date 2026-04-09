function cam_loadparams_Callback(~,~,~)
handles=gui.gethand;
[filen, pathn] = uigetfile('*.mat','Load camera calibration',fullfile(gui.retr('pathname'),'camera_calibration.mat'));
if filen ~=0
    data = load(fullfile(pathn,filen));
    current_cam_nr = stereo.get_current_camera_index();
    if isfield(data,'stereo_calibration') && ~isempty(data.stereo_calibration)
        gui.put('stereo_calibration',data.stereo_calibration);
        stereo.apply_camera_state(current_cam_nr);
    else
        if isfield(data,'cameraParams')
            gui.put('cameraParams',data.cameraParams);
        end
        if isfield(data,'cameraStats')
            gui.put('cameraStats',data.cameraStats);
        else
            gui.put('cameraStats',[]);
        end
        if isfield(data,'cam_selected_target_images')
            gui.put('cam_selected_target_images',data.cam_selected_target_images);
        else
            gui.put('cam_selected_target_images',[]);
        end
        if isfield(data,'cam_selected_rectification_image')
            gui.put('cam_selected_rectification_image',data.cam_selected_rectification_image);
        else
            gui.put('cam_selected_rectification_image',[]);
        end
        if isfield(data,'rectification_tform')
            gui.put('rectification_tform',data.rectification_tform);
        else
            gui.put('rectification_tform',[]);
        end
        % Tilted model parameters (absent in files saved before this feature)
        if isfield(data, 'cam_use_tilted_model')
            gui.put('cam_use_tilted_model', data.cam_use_tilted_model);
            gui.put('cam_tilted_D',         data.cam_tilted_D);
            gui.put('cam_K_opencv',         data.cam_K_opencv);
            handles.calib_use_tilted_model.Value = data.cam_use_tilted_model;
        else
            gui.put('cam_use_tilted_model', false);
            gui.put('cam_tilted_D',         []);
            gui.put('cam_K_opencv',         []);
            handles.calib_use_tilted_model.Value = 0;
        end
        if gui.retr('stereomode') == 1
            stereo.store_current_camera_state(current_cam_nr);
        end
    end
    handles.calib_usecalibration.Value = 0;
    gui.put('cam_use_calibration',0);
    handles.calib_userectification.Value = 0;
    gui.put('cam_use_rectification',0);
    if gui.retr('stereomode') == 1
        stereo.store_current_camera_state(current_cam_nr);
    end
end
