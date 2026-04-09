function tests = test_stereo_calibration_dataset
tests = functiontests(localfunctions);
end

function test_stereo_calibration_dataset_builds_two_camera_model(testCase)
testCase.assumeFalse(exist('OCTAVE_VERSION','builtin') ~= 0, ...
	'Stereo calibration dataset test requires MATLAB.');
testCase.assumeTrue(exist('detectCharucoBoardPoints','file') > 0, ...
	'detectCharucoBoardPoints is required.');
testCase.assumeTrue(exist('readBarcode','file') > 0, ...
	'readBarcode is required for QR-based board parameter detection.');
testCase.assumeTrue(exist('cameraParameters','class') > 0, ...
	'cameraParameters is required.');
testCase.assumeNotEmpty(meta.class.fromName('vision.calibration.monocular.CharucoBoardDetector'), ...
	'vision.calibration.monocular.CharucoBoardDetector is required.');
testCase.assumeTrue(exist('fitgeotform2d','file') > 0, ...
	'fitgeotform2d is required.');

	left_dir = fullfile(pwd, 'unittests', 'stero-calibration', 'left_calibration_figs');
	right_dir = fullfile(pwd, 'unittests', 'stero-calibration', 'right_calibration_figs');

	left_files = sorted_image_files(left_dir);
	right_files = sorted_image_files(right_dir);

	testCase.verifyEqual(numel(left_files), 7, ...
		'Expected 7 left-camera calibration images.');
	testCase.verifyEqual(numel(right_files), 7, ...
		'Expected 7 right-camera calibration images.');

	board = infer_charuco_board_spec([left_files; right_files]);
	testCase.verifyFalse(isempty(board.markerFamily), ...
		'Could not infer ChArUco board metadata from the calibration images.');

	left_result = estimate_camera_from_charuco_files(left_files, board);
	right_result = estimate_camera_from_charuco_files(right_files, board);

	testCase.verifyGreaterThanOrEqual(nnz(left_result.imagesUsed), 4, ...
		'Too few usable left-camera calibration images.');
	testCase.verifyGreaterThanOrEqual(nnz(right_result.imagesUsed), 4, ...
		'Too few usable right-camera calibration images.');

	testCase.verifyEqual(left_result.cameraParams.ImageSize, right_result.cameraParams.ImageSize);
	testCase.verifyLessThan(left_result.meanReprojectionError, 5.0);
	testCase.verifyLessThan(right_result.meanReprojectionError, 5.0);

	coupled = stereo.default_coupled_calibration();

	left_state = stereo.default_camera_calibration_state(1);
	left_state.cameraParams = left_result.cameraParams;
	left_state.cameraStats = left_result.stats;
	left_state.cam_selected_target_images = left_files;
	left_state.cam_use_calibration = 1;
	coupled = stereo.set_camera_calibration_state(coupled, 1, left_state);

	right_state = stereo.default_camera_calibration_state(2);
	right_state.cameraParams = right_result.cameraParams;
	right_state.cameraStats = right_result.stats;
	right_state.cam_selected_target_images = right_files;
	right_state.cam_use_calibration = 1;
	coupled = stereo.set_camera_calibration_state(coupled, 2, right_state);

	testCase.verifyEqual(coupled.summary.num_calibrated_cameras, 2);
	testCase.verifyTrue(coupled.summary.is_complete);
	testCase.verifyEqual(numel(coupled.cameras(1).cam_selected_target_images), 7);
	testCase.verifyEqual(numel(coupled.cameras(2).cam_selected_target_images), 7);
	testCase.verifyTrue(all(isfinite(coupled.cameras(1).cameraParams.PrincipalPoint)));
	testCase.verifyTrue(all(isfinite(coupled.cameras(2).cameraParams.PrincipalPoint)));
end

function test_stereo_calibration_dataset_builds_two_rectification_models(testCase)
testCase.assumeFalse(exist('OCTAVE_VERSION','builtin') ~= 0, ...
	'Stereo rectification dataset test requires MATLAB.');
testCase.assumeTrue(exist('detectCharucoBoardPoints','file') > 0, ...
	'detectCharucoBoardPoints is required.');
testCase.assumeTrue(exist('readBarcode','file') > 0, ...
	'readBarcode is required for QR-based board parameter detection.');
testCase.assumeTrue(exist('cameraParameters','class') > 0, ...
	'cameraParameters is required.');
testCase.assumeTrue(exist('fitgeotform2d','file') > 0, ...
	'fitgeotform2d is required.');
testCase.assumeNotEmpty(meta.class.fromName('vision.calibration.monocular.CharucoBoardDetector'), ...
	'vision.calibration.monocular.CharucoBoardDetector is required.');

	left_dir = fullfile(pwd, 'unittests', 'stero-calibration', 'left_calibration_figs');
	right_dir = fullfile(pwd, 'unittests', 'stero-calibration', 'right_calibration_figs');

	left_files = sorted_image_files(left_dir);
	right_files = sorted_image_files(right_dir);

	board = infer_charuco_board_spec([left_files; right_files]);
	testCase.verifyFalse(isempty(board.markerFamily), ...
		'Could not infer ChArUco board metadata from the calibration images.');

	left_result = estimate_camera_from_charuco_files(left_files, board);
	right_result = estimate_camera_from_charuco_files(right_files, board);

	left_rect = estimate_rectification_from_charuco_image(left_result.cameraParams, left_files{1}, board, 1);
	right_rect = estimate_rectification_from_charuco_image(right_result.cameraParams, right_files{1}, board, 1);

	testCase.verifyClass(left_rect.rectification_tform, 'projtform2d');
	testCase.verifyClass(right_rect.rectification_tform, 'projtform2d');
	testCase.verifyLessThan(left_rect.rmsRectificationError, 10.0);
	testCase.verifyLessThan(right_rect.rmsRectificationError, 10.0);

	coupled = stereo.default_coupled_calibration();

	left_state = stereo.default_camera_calibration_state(1);
	left_state.cameraParams = left_result.cameraParams;
	left_state.cam_selected_target_images = left_files;
	left_state.cam_selected_rectification_image = left_files{1};
	left_state.rectification_tform = left_rect.rectification_tform;
	left_state.cam_use_calibration = 1;
	left_state.cam_use_rectification = 1;
	coupled = stereo.set_camera_calibration_state(coupled, 1, left_state);

	right_state = stereo.default_camera_calibration_state(2);
	right_state.cameraParams = right_result.cameraParams;
	right_state.cam_selected_target_images = right_files;
	right_state.cam_selected_rectification_image = right_files{1};
	right_state.rectification_tform = right_rect.rectification_tform;
	right_state.cam_use_calibration = 1;
	right_state.cam_use_rectification = 1;
	coupled = stereo.set_camera_calibration_state(coupled, 2, right_state);

	testCase.verifyEqual(coupled.summary.num_rectified_cameras, 2);
	testCase.verifyEqual(coupled.cameras(1).cam_selected_rectification_image, left_files{1});
	testCase.verifyEqual(coupled.cameras(2).cam_selected_rectification_image, right_files{1});
	testCase.verifyTrue(coupled.cameras(1).cam_use_rectification == 1);
	testCase.verifyTrue(coupled.cameras(2).cam_use_rectification == 1);

	left_rectified = preproc.cam_undistort(imread(left_files{1}), 'cubic', 'same', 1, 1, ...
		left_result.cameraParams, left_rect.rectification_tform);
	right_rectified = preproc.cam_undistort(imread(right_files{1}), 'cubic', 'same', 1, 1, ...
		right_result.cameraParams, right_rect.rectification_tform);

	testCase.verifyGreaterThan(size(left_rectified,1), 0);
	testCase.verifyGreaterThan(size(left_rectified,2), 0);
	testCase.verifyGreaterThan(size(right_rectified,1), 0);
	testCase.verifyGreaterThan(size(right_rectified,2), 0);
end

function files = sorted_image_files(folder_path)
listing = dir(fullfile(folder_path, '*.jpg'));
if isempty(listing)
	files = {};
	return
end

[~, idx] = sort({listing.name});
listing = listing(idx);
files = fullfile({listing.folder}', {listing.name}');
end

function board = infer_charuco_board_spec(image_files)
board = struct( ...
	'markerFamily', [], ...
	'originCheckerColor', [], ...
	'patternDims', [], ...
	'checkerSize', [], ...
	'markerSize', []);

for i = 1:numel(image_files)
	img = imread(image_files{i});
	if size(img, 3) == 1
		img = repmat(img, [1 1 3]);
	end

	[detectionOK, markerFamily, originCheckerColor, patternDims, checkerSize, markerSize] = ...
		preproc.cam_get_charuco_info_from_QRcode(img);
	if detectionOK
		board.markerFamily = markerFamily;
		board.originCheckerColor = originCheckerColor;
		board.patternDims = patternDims;
		board.checkerSize = checkerSize;
		board.markerSize = markerSize;
		return
	end
end
end

function result = estimate_camera_from_charuco_files(image_files, board)
warning off 'MATLAB:imagesci:imfinfo:unknownXMPpacket'

imagePoints = [];
imagesUsed = false(numel(image_files), 1);
for i = 1:numel(image_files)
	tmp_img = imread(image_files{i});
	tmp_img = tmp_img(:,:,1);
	tmp_img = imadjust(tmp_img);

	points = detectCharucoBoardPoints( ...
		tmp_img, ...
		board.patternDims, ...
		board.markerFamily, ...
		board.checkerSize, ...
		board.markerSize, ...
		'MinMarkerID', 0, ...
		'OriginCheckerColor', board.originCheckerColor, ...
		'ResolutionPerBit', 16, ...
		'MarkerSizeRange', [0.005 1]);

	if ~isempty(points)
		if isempty(imagePoints)
			imagePoints(:,:,1) = points;
		else
			imagePoints(:,:,end+1) = points; %#ok<AGROW>
		end
		imagesUsed(i) = true;
	end
end

	if isempty(imagePoints)
		error('PIVlab:StereoTestNoMarkers', ...
			'No ChArUco markers were detected in the provided calibration images.');
	end

	detector = vision.calibration.monocular.CharucoBoardDetector();
	worldPoints = generateWorldPoints(detector, ...
		'PatternDims', board.patternDims, ...
		'CheckerSize', board.checkerSize);

	originalImage = imread(image_files{1});
	[mrows, ncols, ~] = size(originalImage);

	[cameraParams, usedSubset, stats] = opencv.pivlab_estimateCameraParameters( ...
		imagePoints, worldPoints, [mrows, ncols]);

	filteredImagesUsed = false(size(imagesUsed));
	filteredImagesUsed(find(imagesUsed)) = usedSubset;

	err = stats.ReprojectionErrors;
	errNorm = sqrt(err(:,1,:).^2 + err(:,2,:).^2);

	result = struct();
	result.cameraParams = cameraParams;
	result.stats = stats;
	result.imagesUsed = filteredImagesUsed;
	result.meanReprojectionError = mean(errNorm(:), 'omitnan');
end

function result = estimate_rectification_from_charuco_image(cameraParams, image_file, board, upscale)
if nargin < 4 || isempty(upscale)
	upscale = 1;
end

tmp_img = imread(image_file);
tmp_img = imadjust(tmp_img);
tmp_img = imsharpen(tmp_img);

imagePoints = detectCharucoBoardPoints( ...
	tmp_img, ...
	board.patternDims, ...
	board.markerFamily, ...
	board.checkerSize, ...
	board.markerSize, ...
	'MinMarkerID', 0, ...
	'OriginCheckerColor', board.originCheckerColor, ...
	'RefineCorners', true, ...
	'ResolutionPerBit', 16, ...
	'MarkerSizeRange', [0.005 1]);

if isempty(imagePoints)
	error('PIVlab:StereoRectificationNoMarkers', ...
		'No ChArUco markers were detected in the rectification image %s.', image_file);
end

[mean_checker_size_x, mean_checker_size_y] = preproc.cam_meanCharucoSize( ...
	tmp_img, board.markerFamily, board.checkerSize, board.markerSize);
checker_size_px = (mean_checker_size_y + mean_checker_size_x) / 2 * upscale;
worldPoints = patternWorldPoints('charuco-board', board.patternDims, checker_size_px);

if board.patternDims(1) > board.patternDims(2)
	worldPoints = worldPoints(:, [2 1]);
	worldPoints(:,2) = -worldPoints(:,2);
end

worldPoints(isnan(imagePoints)) = NaN;
imagePoints = rmmissing(imagePoints);
worldPoints = rmmissing(worldPoints);

undistortedPoints = undistortPoints(imagePoints, cameraParams.Intrinsics);
rectification_tform = fitgeotform2d(undistortedPoints, worldPoints, 'projective');
mappedPoints = transformPointsForward(rectification_tform, undistortedPoints);
rmsRectificationError = sqrt(mean(sum((mappedPoints - worldPoints).^2, 2), 'omitnan'));

result = struct();
result.rectification_tform = rectification_tform;
result.imagePoints = imagePoints;
result.worldPoints = worldPoints;
result.undistortedPoints = undistortedPoints;
result.rmsRectificationError = rmsRectificationError;
end
