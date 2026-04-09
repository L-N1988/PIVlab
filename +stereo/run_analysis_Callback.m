function run_analysis_Callback(~, ~, ~)
%RUN_ANALYSIS_CALLBACK GUI stub for Stereo-PIV analysis.

stereo_session = stereo.init_gui_state();
[results, stereo_session] = stereo.run_analysis({}, {}, [], [], stereo_session.settings);
gui.put('stereo_session', stereo_session);

message = { ...
	'Stereo analysis scaffold executed.'; ...
	['Paired inputs detected: ' num2str(numel(stereo_session.inputs.pairs))]; ...
	results.message};
gui.custom_msgbox('msg', getappdata(0, 'hgui'), 'Stereo PIV', message, 'modal', {'OK'}, 'OK');
end
