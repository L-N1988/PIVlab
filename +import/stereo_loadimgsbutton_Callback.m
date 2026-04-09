function stereo_loadimgsbutton_Callback()
%STEREO_LOADIMGSBUTTON_CALLBACK Load paired left/right image streams.

handles = gui.gethand;
restore_state = import.capture_loaded_image_state();
stereo_session = stereo.init_gui_state();

if ispc==1
	pathname = [gui.retr('pathname') '\'];
else
	pathname = [gui.retr('pathname') '/'];
end

gui.toolsavailable(0);
drawnow;

[view1_path, view1_multitiff] = import.select_image_files(pathname, ...
	'Select images for camera 1. Use the same sequencing rule you would use for standard 2D PIV.');
if isequal(view1_path, 0)
	gui.toolsavailable(1);
	import.update_stereo_import_controls();
	return
end

	gui.put('multitiff', view1_multitiff);
	import.loadimgsbutton_Callback([], [], 0, view1_path);
	view1_state = import.capture_loaded_image_state(1);
	view1_state.multitiff = gui.retr('multitiff');
	view1_state.pcopanda_dbl_image = gui.retr('pcopanda_dbl_image');
	view1_state.display_filename = import.prefix_filename_labels(view1_state.filename, 1);

	if isempty(view1_state.pathname)
		next_path = pathname;
	else
		next_path = view1_state.pathname;
	end

	[view2_path, view2_multitiff] = import.select_image_files(next_path, ...
		'Select images for camera 2. The number of logical image pairs must match camera 1.');
	if isequal(view2_path, 0)
		gui.toolsavailable(1);
		import.apply_loaded_image_state(restore_state);
		return
	end

	gui.put('multitiff', view2_multitiff);
	import.loadimgsbutton_Callback([], [], 0, view2_path);
	view2_state = import.capture_loaded_image_state(2);
	view2_state.multitiff = gui.retr('multitiff');
	view2_state.pcopanda_dbl_image = gui.retr('pcopanda_dbl_image');
	view2_state.display_filename = import.prefix_filename_labels(view2_state.filename, 2);

	if view1_state.pair_count ~= view2_state.pair_count
		gui.toolsavailable(1);
		import.apply_loaded_image_state(restore_state);
		gui.custom_msgbox('error', getappdata(0,'hgui'), 'Stereo import failed', ...
			{'Camera 1 and camera 2 do not contain the same number of logical image pairs.'; ...
			['Camera 1 pairs: ' num2str(view1_state.pair_count)]; ...
			['Camera 2 pairs: ' num2str(view2_state.pair_count)]}, 'modal');
		return
	end

	if ~isempty(view1_state.expected_image_size) && ~isempty(view2_state.expected_image_size)
		if any(view1_state.expected_image_size ~= view2_state.expected_image_size)
			gui.toolsavailable(1);
			import.apply_loaded_image_state(restore_state);
			gui.custom_msgbox('error', getappdata(0,'hgui'), 'Stereo import failed', ...
				{'Camera 1 and camera 2 images must have identical dimensions.'; ...
				['Camera 1 size: ' num2str(view1_state.expected_image_size(2)) 'x' num2str(view1_state.expected_image_size(1)) ' px']; ...
				['Camera 2 size: ' num2str(view2_state.expected_image_size(2)) 'x' num2str(view2_state.expected_image_size(1)) ' px']}, 'modal');
			return
		end
	end

	stereo_session.inputs.view1_files = view1_state.filepath;
	stereo_session.inputs.view2_files = view2_state.filepath;
	stereo_session.inputs.pairs = stereo.build_pair_summary(view1_state, view2_state);
	stereo_session.gui.active_view = 1;
	stereo_session.gui.pair_count = view1_state.pair_count;
	stereo_session.gui.views = cell(1,2);
	stereo_session.gui.views{1} = view1_state;
	stereo_session.gui.views{2} = view2_state;
	stereo_session.status = 'dual_view_loaded';
	gui.put('stereo_session', stereo_session);

	import.apply_loaded_image_state(view1_state, 1);
	gui.toolsavailable(1);
	gui.custom_msgbox('success', getappdata(0,'hgui'), 'Stereo views loaded', ...
		{['Loaded ' num2str(view1_state.pair_count) ' synchronized pairs for each camera.']; ...
		'Use the preview selector to switch between camera 1 and camera 2.'}, 'modal');
end
