function stereo_session = init_gui_state()
%INIT_GUI_STATE Ensure Stereo-PIV GUI appdata exists.

stereo_session = gui.retr('stereo_session');
if isempty(stereo_session)
	stereo_session = stereo.default_session();
	gui.put('stereo_session', stereo_session);
end

stereomode = gui.retr('stereomode');
if isempty(stereomode)
	gui.put('stereomode', 0);
end
end
