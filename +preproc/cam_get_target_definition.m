function target = cam_get_target_definition(handles)
%CAM_GET_TARGET_DEFINITION Collect calibration-target settings from the GUI.

if nargin < 1 || isempty(handles)
	handles = gui.gethand;
end

target = struct();
target.type = preproc.cam_get_board_type(handles);
target.patternDims = [str2double(handles.calib_rows.String), str2double(handles.calib_columns.String)];
target.checkerSize = str2double(handles.calib_checkersize.String);
target.markerSize = str2double(handles.calib_markersize.String);
target.originCheckerColor = handles.calib_origincolor.String{handles.calib_origincolor.Value};
target.markerFamily = '';
target.name = target.type;
target.isPlanar = true;
target.customPlate = [];
target.customPlateFile = gui.retr('calib_custom_plate_file');

if strcmp(target.type, 'charuco')
	if contains(handles.calib_boardtype.String{handles.calib_boardtype.Value}, 'DICT_4X4_1000')
		target.markerFamily = 'DICT_4X4_1000';
	end
	target.name = ['ChArUco ' target.markerFamily];
elseif strcmp(target.type, 'checkerboard')
	target.markerSize = [];
	target.originCheckerColor = '';
	target.name = 'Checkerboard';
else
	target.customPlate = gui.retr('calib_custom_plate_definition');
	if isstruct(target.customPlate) && isfield(target.customPlate, 'name') && ~isempty(target.customPlate.name)
		target.name = target.customPlate.name;
	else
		target.name = 'Custom 3D plate';
	end
	if isstruct(target.customPlate) && isfield(target.customPlate, 'isPlanar')
		target.isPlanar = logical(target.customPlate.isPlanar);
	else
		target.isPlanar = false;
	end
end
end
