function [imagePoints, target, debug_image] = cam_detect_target_points(image_source, target, purpose)
%CAM_DETECT_TARGET_POINTS Detect calibration points for the selected target type.

if nargin < 3 || isempty(purpose)
	purpose = 'calibration';
end

debug_image = [];
if strcmp(target.type, 'custom3d')
	error('PIVlab:CustomPlateAutoDetectionUnsupported', ...
		'Custom 3D plates do not support automatic image detection in this workflow.');
end

raw_image = read_image_source(image_source);
debug_image = preprocess_detection_image(raw_image, purpose);

switch target.type
	case 'charuco'
		imagePoints = detect_charuco_points(debug_image, target, strcmpi(purpose, 'rectification'));
	case 'checkerboard'
		[imagePoints, detected_board_size] = detect_checkerboard_points(raw_image);
		if isempty(imagePoints)
			return
		end
		target.patternDims = detected_board_size;
	otherwise
		error('PIVlab:UnsupportedBoardType', 'Unsupported target type "%s".', target.type);
end
end

function image = read_image_source(image_source)
if isnumeric(image_source) || islogical(image_source)
	image = image_source;
elseif ischar(image_source) || (isstring(image_source) && isscalar(image_source))
	image = imread(char(image_source));
else
	error('PIVlab:InvalidCalibrationImage', 'Calibration image source must be a file name or numeric image array.');
end

if ndims(image) == 3
	image = image(:,:,1);
end
end

function debug_image = preprocess_detection_image(image, purpose)
debug_image = image;
if ~isfloat(debug_image)
	debug_image = imadjust(debug_image);
end
if strcmpi(purpose, 'rectification')
	debug_image = imsharpen(debug_image);
end
end

function imagePoints = detect_charuco_points(image, target, refine_corners)
marker_size_range = [0.005 1];
if refine_corners
	imagePoints = detectCharucoBoardPoints( ...
		image, target.patternDims, target.markerFamily, target.checkerSize, target.markerSize, ...
		'MinMarkerID', 0, ...
		'OriginCheckerColor', target.originCheckerColor, ...
		'RefineCorners', true, ...
		'ResolutionPerBit', 16, ...
		'MarkerSizeRange', marker_size_range);
else
	imagePoints = detectCharucoBoardPoints( ...
		image, target.patternDims, target.markerFamily, target.checkerSize, target.markerSize, ...
		'MinMarkerID', 0, ...
		'OriginCheckerColor', target.originCheckerColor, ...
		'ResolutionPerBit', 16, ...
		'MarkerSizeRange', marker_size_range);
end
end

function [imagePoints, board_size] = detect_checkerboard_points(raw_image)
candidates = cell(0, 2);

try
	[pts, board_size] = detectCheckerboardPoints(raw_image, 'HighDistortion', false);
	candidates(end+1, :) = {pts, board_size}; %#ok<AGROW>
catch
end

gray_image = mat2gray(raw_image);
try
	[pts, board_size] = detectCheckerboardPoints(imadjust(gray_image), 'HighDistortion', false);
	candidates(end+1, :) = {pts, board_size}; %#ok<AGROW>
catch
end

try
	[pts, board_size] = detectCheckerboardPoints(histeq(gray_image), 'HighDistortion', false);
	candidates(end+1, :) = {pts, board_size}; %#ok<AGROW>
catch
end

best_count = -1;
imagePoints = [];
board_size = [];
for i = 1:size(candidates, 1)
	pts = candidates{i, 1};
	if ~isempty(pts) && size(pts, 1) > best_count
		best_count = size(pts, 1);
		imagePoints = pts;
		board_size = candidates{i, 2};
	end
end
end
