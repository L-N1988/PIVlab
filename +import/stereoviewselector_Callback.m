function stereoviewselector_Callback(caller, ~, ~)
%STEREOVIEWSELECTOR_CALLBACK Switch preview between stereo camera views.

stereo_session = gui.retr('stereo_session');
if isempty(stereo_session) || ~isfield(stereo_session, 'gui') || ...
		~isfield(stereo_session.gui, 'views') || numel(stereo_session.gui.views) < 2
	return
end

requested_pair = 1;
handles = gui.gethand;
try
	requested_pair = round(get(handles.fileselector, 'Value'));
catch
	end

	view_index = get(caller, 'Value');
	stereo_session.gui.active_view = view_index;
	gui.put('stereo_session', stereo_session);
	import.apply_loaded_image_state(stereo_session.gui.views{view_index}, requested_pair);
end
