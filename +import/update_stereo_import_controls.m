function update_stereo_import_controls()
%UPDATE_STEREO_IMPORT_CONTROLS Refresh stereo import / preview controls.

handles = gui.gethand;
stereomode = gui.retr('stereomode');
stereo_session = gui.retr('stereo_session');

if isempty(stereomode)
	stereomode = 0;
end

if stereomode == 1
	set(handles.loadimgsbutton, 'String', 'Import stereo views');
	set(handles.stereoviewselector, 'Visible', 'on');
	set(handles.stereopairinfo, 'Visible', 'on');
	set(handles.remove_imgs, 'Enable', 'off');
	set(handles.remove_imgs, 'TooltipString', 'Removing images from paired stereo streams is not supported yet. Re-import both views instead.');

	has_session = ~isempty(stereo_session) && isfield(stereo_session, 'gui') && ...
		isfield(stereo_session.gui, 'views') && numel(stereo_session.gui.views) >= 2 && ...
		~isempty(stereo_session.gui.views{1}) && ~isempty(stereo_session.gui.views{2});
	if has_session
		active_view = stereo_session.gui.active_view;
		pair_count = stereo_session.gui.pair_count;
		set(handles.stereoviewselector, ...
			'Enable', 'on', ...
			'String', {'Preview camera 1', 'Preview camera 2'}, ...
			'Value', active_view);
		set(handles.stereopairinfo, 'String', ...
			['Stereo pairs loaded: ' num2str(pair_count) ' | Active preview: Camera ' num2str(active_view)]);
	else
		set(handles.stereoviewselector, ...
			'Enable', 'off', ...
			'String', {'Preview camera 1', 'Preview camera 2'}, ...
			'Value', 1);
		set(handles.stereopairinfo, 'String', 'Stereo pairs loaded: none');
	end
else
	set(handles.loadimgsbutton, 'String', 'Import images');
	set(handles.stereoviewselector, 'Visible', 'off', 'Enable', 'off', 'Value', 1);
	set(handles.stereopairinfo, 'Visible', 'off', 'String', 'Stereo pairs loaded: none');
	set(handles.remove_imgs, 'TooltipString', 'Remove images from the image list');
	filepath = gui.retr('filepath');
	if isempty(filepath)
		set(handles.remove_imgs, 'Enable', 'off');
	else
		set(handles.remove_imgs, 'Enable', 'on');
	end
end
end
