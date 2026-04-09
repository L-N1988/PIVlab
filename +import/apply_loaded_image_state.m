function apply_loaded_image_state(state, requested_pair)
%APPLY_LOADED_IMAGE_STATE Push a captured image stream back into the GUI.

if nargin < 2 || isempty(requested_pair)
	requested_pair = 1;
end

handles = gui.gethand;
hgui = getappdata(0,'hgui');

if isempty(state) || ~isstruct(state)
	gui.displogo(0);
	import.update_stereo_import_controls();
	return
end

if ~isfield(state, 'has_files') || ~state.has_files
	gui.put('filename', []);
	gui.put('filepath', []);
	gui.put('framenum', []);
	gui.put('framepart', []);
	gui.put('expected_image_size', []);
	gui.put('multitiff', []);
	gui.put('pcopanda_dbl_image', []);
	set(handles.filenamebox, 'String', state.filenamebox_string, 'Value', state.filenamebox_value, 'BackgroundColor', state.filenamebox_background);
	set(handles.fileselector, 'Value', state.fileselector_value);
	set(hgui, 'Name', state.window_name);
	gui.displogo(0);
	import.update_stereo_import_controls();
	return
end

	if isfield(state, 'display_filename') && ~isempty(state.display_filename)
		display_filename = state.display_filename;
	else
		display_filename = state.filename;
	end

	gui.put('pathname', state.pathname);
	gui.put('filename', display_filename);
	gui.put('filepath', state.filepath);
	gui.put('framenum', state.framenum);
	gui.put('framepart', state.framepart);
	gui.put('expected_image_size', state.expected_image_size);
	gui.put('multitiff', state.multitiff);
	gui.put('pcopanda_dbl_image', state.pcopanda_dbl_image);

	gui.put('resultslist', []);
	gui.put('derived', []);
	gui.put('displaywhat', 1);
	gui.put('ismean', []);
	gui.put('framemanualdeletion', []);
	gui.put('manualdeletion', []);
	gui.put('streamlinesX', []);
	gui.put('streamlinesY', []);
	gui.put('bg_img_A', []);
	gui.put('bg_img_B', []);
	gui.put('masks_in_frame', []);
	gui.put('xzoomlimit', []);
	gui.put('yzoomlimit', []);

	set(handles.bg_subtract, 'Value', 1);
	set(handles.minintens, 'String', 0);
	set(handles.maxintens, 'String', 1);
	set(handles.panon, 'Value', 0);
	set(handles.zoomon, 'Value', 0);
	set(handles.filenamebox, 'String', display_filename);
	standard_bg_color = gui.retr('standard_bg_color');
	if isempty(standard_bg_color)
		standard_bg_color = 'w';
	end
	set(handles.filenamebox, 'BackgroundColor', standard_bg_color);

	gui.sliderrange(1);
	max_pair = max(1, floor(size(state.filepath,1)/2));
	requested_pair = min(max(1, round(requested_pair)), max_pair);
	set(handles.fileselector, 'Value', requested_pair);

	toggler = gui.retr('toggler');
	if isempty(toggler)
		toggler = 0;
		gui.put('toggler', toggler);
	end
	filenamebox_index = min(numel(display_filename), 2*requested_pair-(1-toggler));
	set(handles.filenamebox, 'Value', max(1, filenamebox_index));

	if ~isempty(state.pathname)
		if ~isdeployed
			appname='PIVlab';
		else
			appname='PIVlab standalone';
		end
		set(hgui, 'Name', [appname ' ' gui.retr('PIVver') '   [Path: ' state.pathname ']']);
	end

	if gui.retr('stereomode') == 1 && isfield(state, 'camera_index') && ~isempty(state.camera_index)
		stereo.apply_camera_state(state.camera_index);
	end

	gui.sliderdisp(gui.retr('pivlab_axis'));
	import.update_stereo_import_controls();
end
