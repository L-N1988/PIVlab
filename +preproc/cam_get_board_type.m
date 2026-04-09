function board_type = cam_get_board_type(handles)
%CAM_GET_BOARD_TYPE Resolve the selected calibration target type.

if nargin < 1 || isempty(handles)
	handles = gui.gethand;
end

items = cellstr(handles.calib_boardtype.String);
index = min(max(1, handles.calib_boardtype.Value), numel(items));
label = lower(strtrim(items{index}));

if contains(label, 'checkerboard')
	board_type = 'checkerboard';
elseif contains(label, 'custom') && contains(label, '3d')
	board_type = 'custom3d';
else
	board_type = 'charuco';
end
end
