function self_calibrate_disparity_Callback(~, ~, ~)
%SELF_CALIBRATE_DISPARITY_CALLBACK GUI stub for disparity correction.

stereo_session = stereo.init_gui_state();
stereo_session.disparity = stereo.self_calibrate_disparity([], [], stereo_session.calibration.stereo, stereo_session.settings);
gui.put('stereo_session', stereo_session);

gui.custom_msgbox('msg', getappdata(0, 'hgui'), 'Stereo PIV', ...
	{'Disparity correction scaffold executed.'; stereo_session.disparity.message}, ...
	'modal', {'OK'}, 'OK');
end
