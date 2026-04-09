function plate = cam_load_custom_plate_definition(filename)
%CAM_LOAD_CUSTOM_PLATE_DEFINITION Load a generic custom calibration target definition.
% Supported formats:
%   MAT: worldPoints (Nx3 or Nx2) plus optional imagePoints (Nx2xM), imageSize,
%        imageFileNames, name, units.
%   CSV/TXT: world-point table with columns x,y,z or first 3 numeric columns.

if nargin < 1 || isempty(filename)
	error('PIVlab:MissingCustomPlateFile', 'A custom plate definition file is required.');
end

[~, name, ext] = fileparts(filename);
plate = struct();
plate.name = name;
plate.units = 'mm';
plate.worldPoints = [];
plate.imagePoints = [];
plate.imageSize = [];
plate.imageFileNames = {};
plate.source_file = filename;
plate.hasImagePoints = false;
plate.isPlanar = false;

switch lower(ext)
	case '.mat'
		data = load(filename);
		if isfield(data, 'customPlate')
			data = data.customPlate;
		elseif isstruct(data) && numel(fieldnames(data)) == 1
			field_name = fieldnames(data);
			if isstruct(data.(field_name{1}))
				data = data.(field_name{1});
			end
		end
		plate = merge_loaded_plate(plate, data);
	case {'.csv', '.txt'}
		table_data = load_table_data(filename);
		plate.worldPoints = extract_world_points_from_table(table_data);
	otherwise
		error('PIVlab:UnsupportedCustomPlateFormat', ...
			'Unsupported custom plate file format "%s". Use MAT, CSV, or TXT.', ext);
end

function table_data = load_table_data(filename)
if exist('readtable', 'file') > 0
	table_data = readtable(filename);
	return
end

raw = importdata(filename);
if isstruct(raw)
	if isfield(raw, 'data') && ~isempty(raw.data)
		numeric_data = raw.data;
	else
		numeric_data = [];
	end
	if isfield(raw, 'colheaders') && ~isempty(raw.colheaders)
		headers = raw.colheaders;
	else
		headers = compose("Var%d", 1:size(numeric_data, 2));
	end
else
	numeric_data = raw;
	headers = compose("Var%d", 1:size(numeric_data, 2));
end

if isempty(numeric_data)
	error('PIVlab:InvalidCustomPlateCsv', ...
		'CSV/TXT custom plate definitions could not be parsed.');
end

table_data = struct();
table_data.numeric_data = numeric_data;
table_data.variable_names = cellstr(headers);
end

if isempty(plate.worldPoints) || size(plate.worldPoints, 2) < 2
	error('PIVlab:InvalidCustomPlate', ...
		'Custom plate definition must provide worldPoints with 2 or 3 columns.');
end
if size(plate.worldPoints, 2) == 2
	plate.worldPoints(:, 3) = 0;
end

if ~isempty(plate.imagePoints)
	plate.imagePoints = normalize_image_points_array(plate.imagePoints, size(plate.worldPoints, 1));
	plate.hasImagePoints = true;
end

plate.isPlanar = all(abs(plate.worldPoints(:,3) - plate.worldPoints(1,3)) < 1e-9);
end

function plate = merge_loaded_plate(plate, data)
plate.worldPoints = extract_named_field(data, {'worldPoints', 'points3d', 'platePoints', 'objectPoints'});
plate.imagePoints = extract_named_field(data, {'imagePoints', 'detectedImagePoints'});
plate.imageSize = extract_named_field(data, {'imageSize'});
plate.imageFileNames = extract_named_field(data, {'imageFileNames', 'imageFiles', 'files'}, {});
plate.units = extract_named_field(data, {'units'}, plate.units);
plate.name = extract_named_field(data, {'name', 'plateName'}, plate.name);
end

function value = extract_named_field(data, names, default_value)
if nargin < 3
	default_value = [];
end
value = default_value;
for i = 1:numel(names)
	if isstruct(data) && isfield(data, names{i}) && ~isempty(data.(names{i}))
		value = data.(names{i});
		return
	end
end
end

function world_points = extract_world_points_from_table(table_data)
[variable_names, numeric_data] = unpack_table_like(table_data);
variable_names = lower(cellstr(variable_names));
x_idx = find(strcmp(variable_names, 'x') | strcmp(variable_names, 'worldx'), 1);
y_idx = find(strcmp(variable_names, 'y') | strcmp(variable_names, 'worldy'), 1);
z_idx = find(strcmp(variable_names, 'z') | strcmp(variable_names, 'worldz'), 1);

if ~isempty(x_idx) && ~isempty(y_idx)
	world_points = [numeric_data(:, x_idx), numeric_data(:, y_idx)];
	if ~isempty(z_idx)
		world_points(:,3) = numeric_data(:, z_idx);
	end
	return
end

if size(numeric_data, 2) < 2
	error('PIVlab:InvalidCustomPlateCsv', ...
		'CSV/TXT custom plate definitions need x,y columns or at least two numeric columns.');
end
if size(numeric_data, 2) >= 3
	world_points = numeric_data(:, 1:3);
else
	world_points = numeric_data(:, 1:2);
end
end

function [variable_names, numeric_data] = unpack_table_like(table_data)
if has_table_type() && istable(table_data)
	variable_names = table_data.Properties.VariableNames;
	numeric_columns = varfun(@isnumeric, table_data, 'OutputFormat', 'uniform');
	numeric_data = table_data{:, numeric_columns};
else
	variable_names = table_data.variable_names;
	numeric_data = table_data.numeric_data;
end
end

function tf = has_table_type()
tf = exist('istable', 'builtin') > 0 || exist('istable', 'file') > 0;
end

function image_points = normalize_image_points_array(image_points, expected_count)
if iscell(image_points)
	if isempty(image_points)
		image_points = [];
		return
	end
	stack = nan(expected_count, 2, numel(image_points));
	for i = 1:numel(image_points)
		points = image_points{i};
		if ~isnumeric(points) || size(points, 2) ~= 2
			error('PIVlab:InvalidCustomPlateImagePoints', ...
				'Custom plate imagePoints cell entries must be Nx2 numeric arrays.');
		end
		if size(points, 1) ~= expected_count
			error('PIVlab:InvalidCustomPlateImagePoints', ...
				'Custom plate imagePoints must align row-wise with worldPoints.');
		end
		stack(:,:,i) = points;
	end
	image_points = stack;
end

if ~isnumeric(image_points) || ndims(image_points) ~= 3 || size(image_points, 2) ~= 2
	error('PIVlab:InvalidCustomPlateImagePoints', ...
		'Custom plate imagePoints must be an Nx2xM numeric array.');
end
if size(image_points, 1) ~= expected_count
	error('PIVlab:InvalidCustomPlateImagePoints', ...
		'Custom plate imagePoints must align row-wise with worldPoints.');
end
end
