function plate = generate_lavision_plate(plate_type, grid_dims)
%GENERATE_LAVISION_PLATE Generate LaVision double-sided two-level calibration plate.
%
%   plate = stereo.generate_lavision_plate(plate_type)
%   plate = stereo.generate_lavision_plate(plate_type, grid_dims)
%
% Predefined plate types (dot spacing in mm, level separation in mm):
%   '025-3.3-1'   dot distance 3.3,  level separation 1.0,  ~25 points
%   '058-5-1'     dot distance 5.0,  level separation 1.0,  ~58 points
%   '106-10-2'    dot distance 10.0, level separation 2.0,  ~106 points
%   '204-15-3'    dot distance 15.0, level separation 3.0,  ~204 points
%   '309-15-3'    dot distance 15.0, level separation 3.0,  ~309 points
%
%   grid_dims: optional [rows, cols] override for the dot grid.
%
% Output plate struct is compatible with preproc.cam_load_custom_plate_definition.
%
% The plate has a regular grid of dots alternating between two levels
% (front at Z=0, back at Z=+level_separation). Position marks at the
% four corners are on the front level and carry markers at the two
% remaining top corners to break symmetry.

if nargin < 1 || isempty(plate_type)
    error('PIVlab:MissingPlateType', 'A LaVision plate type is required.');
end

persistent plate_specs;
if isempty(plate_specs)
    plate_specs = define_plate_specs();
end

if ~isfield(plate_specs, plate_type)
    valid = strjoin(fieldnames(plate_specs)', ', ');
    error('PIVlab:UnknownPlateType', ...
        'Unknown plate type "%s". Valid types: %s', plate_type, valid);
end

spec = plate_specs.(plate_type);

% Allow grid dimensions override
if nargin >= 2 && ~isempty(grid_dims)
    spec.grid_rows = grid_dims(1);
    spec.grid_cols = grid_dims(2);
end

% Build the plate world points
[worldPoints, position_mark_indices, front_indices, back_indices] = ...
    build_plate_geometry(spec);

% Assemble plate struct compatible with custom-plate conventions
plate = struct();
plate.name = sprintf('LaVision-%s', plate_type);
plate.type = plate_type;
plate.units = 'mm';
plate.worldPoints = worldPoints;
plate.imagePoints = [];
plate.imageSize = [];
plate.imageFileNames = {};
plate.source_file = '';
plate.hasImagePoints = false;
plate.isPlanar = false;
plate.position_mark_indices = position_mark_indices;
plate.front_indices = front_indices;
plate.back_indices = back_indices;
plate.pt_distance = spec.pt_distance;
plate.level_separation = spec.level_separation;

end

function specs = define_plate_specs()
%Define known LaVision plate specifications.

specs = struct();

specs.(genvarname('025-3.3-1')) = struct( ...
    'pt_distance', 3.3, 'level_separation', 1.0, ...
    'grid_rows', 5, 'grid_cols', 5);

specs.(genvarname('058-5-1')) = struct( ...
    'pt_distance', 5.0, 'level_separation', 1.0, ...
    'grid_rows', 7, 'grid_cols', 8);

specs.(genvarname('106-10-2')) = struct( ...
    'pt_distance', 10.0, 'level_separation', 2.0, ...
    'grid_rows', 10, 'grid_cols', 10);

specs.(genvarname('204-15-3')) = struct( ...
    'pt_distance', 15.0, 'level_separation', 3.0, ...
    'grid_rows', 14, 'grid_cols', 14);

specs.(genvarname('309-15-3')) = struct( ...
    'pt_distance', 15.0, 'level_separation', 3.0, ...
    'grid_rows', 17, 'grid_cols', 18);

end

function [worldPoints, position_mark_indices, front_indices, back_indices] = ...
    build_plate_geometry(spec)

rows = spec.grid_rows;
cols = spec.grid_cols;
d = spec.pt_distance;
dz = spec.level_separation;

% Generate grid coordinates centred on origin
x = ((0:cols-1) - (cols-1)/2) * d;
y = ((0:rows-1) - (rows-1)/2) * d;

[xx, yy] = meshgrid(x, y);

% Alternating levels: checkerboard pattern
%  Front (Z=0) for (row+col) even, Back (Z=dz) for (row+col) odd
is_front = false(rows, cols);
for r = 1:rows
    for c = 1:cols
        is_front(r, c) = mod(r + c, 2) == 0;
    end
end

zz = zeros(rows, cols);
zz(~is_front) = dz;

% Collect all grid points
grid_x = xx(:);
grid_y = yy(:);
grid_z = zz(:);
is_front_vec = is_front(:);

worldPoints = [grid_x, grid_y, grid_z];

% Identify position marks: four corners are always on front level
position_mark_indices = [];
corner_rc = [1 1; 1 cols; rows 1; rows cols];
for i = 1:4
    r = corner_rc(i, 1);
    c = corner_rc(i, 2);
    idx = (c-1)*rows + r;
    position_mark_indices(end+1) = idx; %#ok<AGROW>
end

% Corner dots are position marks; the two top corners (row=1) have
% slightly distinct roles in LaVision plates to break symmetry.
front_indices = find(is_front_vec);
back_indices = find(~is_front_vec);

end

function varname = genvarname(str)
%Generate a valid MATLAB struct field name from a string with hyphens.
varname = strrep(str, '-', '_');
end
