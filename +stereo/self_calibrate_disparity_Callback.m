function self_calibrate_disparity_Callback(~, ~, ~)
%SELF_CALIBRATE_DISPARITY_CALLBACK Run stereo self-calibration on the loaded particle images.

stereo_session = stereo.init_gui_state();
if isfield(stereo_session, 'gui') && isfield(stereo_session.gui, 'views') && numel(stereo_session.gui.views) >= 2
	view1_input = stereo_session.gui.views{1};
	view2_input = stereo_session.gui.views{2};
else
	view1_input = stereo_session.inputs.view1_files;
	view2_input = stereo_session.inputs.view2_files;
end

if isfield(stereo_session, 'calibration') && isfield(stereo_session.calibration, 'coupled') && ~isempty(stereo_session.calibration.coupled)
	calibration = stereo_session.calibration.coupled;
else
	calibration = stereo_session.calibration.stereo;
end

stereo_session.disparity = stereo.self_calibrate_disparity(view1_input, view2_input, calibration, stereo_session.settings);
if isfield(stereo_session.disparity, 'calibration') && ~isempty(stereo_session.disparity.calibration)
	stereo_session.calibration.stereo = stereo_session.disparity.calibration;
	stereo_session.calibration.coupled = stereo_session.disparity.calibration;
	gui.put('stereo_calibration', stereo_session.disparity.calibration);
end
gui.put('stereo_session', stereo_session);

gui.custom_msgbox('msg', getappdata(0, 'hgui'), 'Stereo PIV', ...
	{stereo_session.disparity.message}, ...
	'modal', {'OK'}, 'OK');
end
