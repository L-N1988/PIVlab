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
        if isfield(data,'calib_boardtype')
            handles.calib_boardtype.Value = data.calib_boardtype;
        end
        if isfield(data,'calib_origincolor')
            handles.calib_origincolor.Value = data.calib_origincolor;
        end
        if isfield(data,'calib_rows')
            handles.calib_rows.String = data.calib_rows;
        end
        if isfield(data,'calib_columns')
            handles.calib_columns.String = data.calib_columns;
        end
        if isfield(data,'calib_checkersize')
            handles.calib_checkersize.String = data.calib_checkersize;
        end
        if isfield(data,'calib_markersize')
            handles.calib_markersize.String = data.calib_markersize;
        end
        if isfield(data,'calib_custom_plate_file')
            gui.put('calib_custom_plate_file',data.calib_custom_plate_file);
        else
            gui.put('calib_custom_plate_file',[]);
        end
        if isfield(data,'calib_custom_plate_definition')
            gui.put('calib_custom_plate_definition',data.calib_custom_plate_definition);
        else
            gui.put('calib_custom_plate_definition',[]);
        end
        preproc.cam_boardtype_Callback();
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
