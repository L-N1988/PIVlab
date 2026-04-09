function state = capture_loaded_image_state(camera_index)
%CAPTURE_LOADED_IMAGE_STATE Snapshot the current GUI-backed image stream.

if nargin < 1
	camera_index = [];
end

handles = gui.gethand;
state = struct();
state.camera_index = camera_index;
state.pathname = gui.retr('pathname');
state.filename = gui.retr('filename');
state.filepath = gui.retr('filepath');
state.framenum = gui.retr('framenum');
state.framepart = gui.retr('framepart');
state.expected_image_size = gui.retr('expected_image_size');
state.multitiff = gui.retr('multitiff');
state.pcopanda_dbl_image = gui.retr('pcopanda_dbl_image');
state.filenamebox_string = get(handles.filenamebox, 'String');
state.filenamebox_value = get(handles.filenamebox, 'Value');
state.filenamebox_background = get(handles.filenamebox, 'BackgroundColor');
state.fileselector_value = get(handles.fileselector, 'Value');
state.window_name = get(getappdata(0,'hgui'), 'Name');
state.has_files = ~isempty(state.filepath) && numel(state.filepath) > 0;

if state.has_files
	state.pair_count = floor(size(state.filepath,1)/2);
else
	state.pair_count = 0;
end
end
