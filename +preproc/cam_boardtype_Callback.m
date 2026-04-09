function cam_boardtype_Callback(~, ~, ~)
%CAM_BOARDTYPE_CALLBACK Update board-type dependent UI state.

handles = gui.gethand;
board_type = preproc.cam_get_board_type(handles);

is_charuco = strcmp(board_type, 'charuco');
is_checkerboard = strcmp(board_type, 'checkerboard');
is_custom3d = strcmp(board_type, 'custom3d');

set(handles.calib_origincolor, 'Enable', ternary_state(is_charuco));
set(handles.calib_markersize, 'Enable', ternary_state(is_charuco));

if is_charuco
	set(handles.calib_find_params, 'Enable', 'on', 'TooltipString', ...
		'Read the ChArUco QR code or estimate ChArUco layout from one image.');
	set(handles.calib_generateboard, 'Enable', 'on', 'String', 'Generate Charuco board', ...
		'TooltipString', 'Generate a printable ChArUco board.');
elseif is_checkerboard
	set(handles.calib_find_params, 'Enable', 'on', 'TooltipString', ...
		'Detect checkerboard size from one image. DIY square size stays user-defined.');
	set(handles.calib_generateboard, 'Enable', 'on', 'String', 'Generate checkerboard', ...
		'TooltipString', 'Generate a printable checkerboard with the specified inner-corner counts and square size.');
else
	set(handles.calib_find_params, 'Enable', 'off', 'TooltipString', ...
		'Custom 3D plates are imported from MAT or CSV instead of auto-detected.');
	set(handles.calib_generateboard, 'Enable', 'off', 'String', 'Generate board', ...
		'TooltipString', 'Board generation is only available for planar checkerboard and ChArUco targets.');
end

if isfield(handles, 'calib_load_custom_plate')
	set(handles.calib_load_custom_plate, 'Enable', ternary_state(is_custom3d));
end
if isfield(handles, 'calib_custom_plate_info')
	custom_plate_file = gui.retr('calib_custom_plate_file');
	if is_custom3d
		if isempty(custom_plate_file)
			info = 'No custom 3D plate loaded';
		else
			[~, name, ext] = fileparts(custom_plate_file);
			info = ['Loaded: ' name ext];
		end
		set(handles.calib_custom_plate_info, 'Visible', 'on', 'String', info);
	else
		set(handles.calib_custom_plate_info, 'Visible', 'off');
	end
end
end

function value = ternary_state(tf)
if tf
	value = 'on';
else
	value = 'off';
end
end
