function cam_load_custom_plate_Callback(~, ~, ~)
%CAM_LOAD_CUSTOM_PLATE_CALLBACK Load a generic custom 3D plate definition.

[file_name, path_name] = uigetfile( ...
	{'*.mat;*.csv;*.txt', 'Custom plate definitions'; ...
	'*.mat', 'MAT files'; ...
	'*.csv;*.txt', 'CSV/TXT files'}, ...
	'Load custom 3D plate definition', gui.retr('pathname'));

if isequal(file_name, 0)
	return
end

full_name = fullfile(path_name, file_name);
try
	plate = preproc.cam_load_custom_plate_definition(full_name);
	gui.put('calib_custom_plate_file', full_name);
	gui.put('calib_custom_plate_definition', plate);
	preproc.cam_boardtype_Callback();
	gui.custom_msgbox('msg', getappdata(0,'hgui'), 'Custom plate loaded', ...
		{['Loaded ' plate.name '.']; ...
		['World points: ' num2str(size(plate.worldPoints, 1))]; ...
		['Image points included: ' logical_string(plate.hasImagePoints)]}, ...
		'modal', {'OK'}, 'OK');
catch ME
	gui.custom_msgbox('error', getappdata(0,'hgui'), 'Custom plate load failed', ME.message, 'modal');
end
end

function out = logical_string(tf)
if tf
	out = 'yes';
else
	out = 'no';
end
end
