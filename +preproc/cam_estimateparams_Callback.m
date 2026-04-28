function cam_estimateparams_Callback(~, ~, ~)
warning off 'MATLAB:imagesci:imfinfo:unknownXMPpacket'
handles = gui.gethand;
target = preproc.cam_get_target_definition(handles);
cam_selected_target_images = gui.retr('cam_selected_target_images');

try
	% For custom3d without pre-loaded imagePoints, offer manual annotation
	if strcmp(target.type, 'custom3d') ...
			&& (~isfield(target.customPlate, 'hasImagePoints') || ~target.customPlate.hasImagePoints)
		if isempty(cam_selected_target_images) || ~iscell(cam_selected_target_images)
			gui.custom_msgbox('error', getappdata(0,'hgui'), 'Error', ...
				'Load calibration images first, then annotate the plate points.', 'modal');
			return
		end
		preproc.cam_manual_annotate_Callback();
		% Re-fetch target with updated plate definition
		target = preproc.cam_get_target_definition(handles);
	end

	validate_target_inputs(target, cam_selected_target_images);
	[imagePoints, worldPoints, imageFileNames, imageSize, detectionSummary] = ...
		collect_calibration_observations(target, cam_selected_target_images, handles);
catch ME
	gui.custom_msgbox('error', getappdata(0,'hgui'), 'Error', ME.message, 'modal');
	return
end

if isempty(imagePoints)
	gui.custom_msgbox('error',getappdata(0,'hgui'),'Error','No calibration target points detected or loaded.','modal');
	return
end

gui.toolsavailable(1)
gui.toolsavailable(0,'Calculating camera parameters...');drawnow;

try
	[cameraParams, imagesUsed, stats] = opencv.pivlab_estimateCameraParameters(imagePoints, worldPoints, imageSize);
	[cameraParams, imagesUsed, stats, imagePoints, imageFileNames] = ...
		refine_camera_solution(cameraParams, stats, imagePoints, worldPoints, imageSize, imageFileNames);

	gui.put('cameraParams', cameraParams);
	gui.put('cameraStats', stats);
	if gui.retr('stereomode') == 1
		stereo.store_current_camera_state();
	end

	show_calibration_preview(imageFileNames, imagesUsed, imagePoints, stats);
	show_calibration_success_message(target, imagePoints, imagesUsed, detectionSummary, stats);
catch ME
	gui.custom_msgbox('error',getappdata(0,'hgui'),'Error',{'Problem with camera calibration: ';' '; ME.message},'modal');
end
gui.toolsavailable(1)
end

function validate_target_inputs(target, image_files)
switch target.type
	case 'charuco'
		if strcmpi(target.originCheckerColor,'white') && mod(target.patternDims(1),2) ~= 0
			error('PIVlab:InvalidCharucoRows', ...
				'Number of rows of the ChArUco board must be even when OriginCheckerColor is white.');
		end
		if any(target.patternDims < 3)
			error('PIVlab:InvalidCharucoSize', ...
				'Number of rows and columns of the ChArUco board must be >= 3.');
		end
		if target.markerSize >= target.checkerSize
			error('PIVlab:InvalidMarkerSize', ...
				'Marker size must be smaller than checker size.');
		end
		if isempty(image_files) || ~iscell(image_files) || numel(image_files) <= 1
			error('PIVlab:NotEnoughCalibrationImages', ...
				'Not enough marker board images selected.');
		end
	case 'checkerboard'
		if any(target.patternDims < 3)
			error('PIVlab:InvalidCheckerboardSize', ...
				'Checkerboard rows and columns must both be >= 3.');
		end
		if isempty(image_files) || ~iscell(image_files) || numel(image_files) <= 1
			error('PIVlab:NotEnoughCalibrationImages', ...
				'Not enough checkerboard images selected.');
		end
	case 'custom3d'
		if isempty(target.customPlate) || ~isstruct(target.customPlate)
			error('PIVlab:MissingCustomPlate', ...
				'Load a custom 3D plate MAT or CSV file first.');
		end
		if ~isfield(target.customPlate, 'hasImagePoints') || ~target.customPlate.hasImagePoints
			error('PIVlab:MissingCustomPlateImagePoints', ...
				['Custom 3D plate calibration requires annotated imagePoints. ' ...
				'Use the manual annotation tool to mark points on the calibration image.']);
		end
	otherwise
		error('PIVlab:UnsupportedBoardType', 'Unsupported board type.');
end
end

function [imagePoints, worldPoints, imageFileNames, imageSize, detectionSummary] = collect_calibration_observations(target, image_files, handles)
switch target.type
	case 'custom3d'
		[imagePoints, worldPoints, imageFileNames, imageSize] = collect_custom_plate_observations(target, image_files);
		detectionSummary = struct('target_type', target.type, 'detected_layout', [], 'used_qr', false);
	otherwise
		[imagePoints, imageFileNames, target, detectionSummary] = collect_planar_target_observations(target, image_files, handles);
		if strcmp(target.type, 'charuco')
			detector = vision.calibration.monocular.CharucoBoardDetector();
			worldPoints = generateWorldPoints(detector, 'PatternDims', target.patternDims, 'CheckerSize', target.checkerSize);
		else
			worldPoints = patternWorldPoints('checkerboard', target.patternDims, target.checkerSize);
		end
		first_image = imread(image_files{1});
		imageSize = size(first_image);
		imageSize = imageSize(1:2);
end
end

function [imagePoints, imageFileNames, target, summary] = collect_planar_target_observations(target, image_files, handles)
gui.toolsavailable(0, 'Detecting markers...');drawnow;

imagePoints = [];
imageFileNames = {};
summary = struct('target_type', target.type, 'detected_layout', target.patternDims, 'used_qr', false);

if strcmp(target.type, 'charuco')
	target = maybe_override_charuco_from_qr(target, image_files, handles);
	summary.detected_layout = target.patternDims;
	summary.used_qr = true;
end

if strcmp(target.type, 'charuco')
	fig = [];
	if isMATLABReleaseOlderThan("R2025b")
		fig = uifigure;
		progress = uiprogressdlg(fig,'Title','Calibration pattern detection...','Message','Starting pattern detection...');
	else
		progress = uiprogressdlg(gcf,'Title','Calibration pattern detection...','Message','Starting pattern detection...');
	end
end

try
	imagesUsed = false(numel(image_files), 1);
	for i = 1:numel(image_files)
		[points, detected_target] = preproc.cam_detect_target_points(image_files{i}, target, 'calibration');
		if strcmp(target.type, 'checkerboard') && ~isempty(points)
			target = maybe_update_checkerboard_layout(target, detected_target, handles);
			summary.detected_layout = target.patternDims;
		end

		if ~isempty(points)
			if isempty(imagePoints)
				imagePoints(:,:,1) = points;
			else
				imagePoints(:,:,end+1) = points; %#ok<AGROW>
			end
			imageFileNames{end+1,1} = image_files{i}; %#ok<AGROW>
			imagesUsed(i) = true;
		end

		if strcmp(target.type, 'charuco')
			[~,name,ext] = fileparts(image_files{i});
			percentage_detected=round(numel(find(~isnan(points))) / max(numel(points),1) * 100);
			progress.Message = [name ext '  -->  '  num2str(percentage_detected) ' % valid markers.' ];
			progress.Value = i / numel(image_files);
		end
	end
catch ME
	if exist('progress', 'var') && ~isempty(progress)
		close(progress)
	end
	if exist('fig', 'var') && ~isempty(fig)
		close(fig)
	end
	rethrow(ME)
end

if exist('progress', 'var') && ~isempty(progress)
	close(progress)
end
if exist('fig', 'var') && ~isempty(fig)
	close(fig)
end
end

function target = maybe_override_charuco_from_qr(target, image_files, handles)
for i = 1:numel(image_files)
	tmp_img = imread(image_files{i});
	tmp_img = tmp_img(:,:,1);
	tmp_img = imadjust(tmp_img);
	[detectionOK, qr_markerFamily, qr_originCheckerColor, qr_patternDims, qr_checkerSize, qr_markerSize, ~] = ...
		preproc.cam_get_charuco_info_from_QRcode(tmp_img);
	if detectionOK
		mismatch = ~strcmp(target.markerFamily, qr_markerFamily) || ...
			~strcmp(target.originCheckerColor, qr_originCheckerColor) || ...
			any(target.patternDims ~= qr_patternDims) || ...
			target.checkerSize ~= qr_checkerSize || ...
			target.markerSize ~= qr_markerSize;
		if mismatch
			button = gui.custom_msgbox('quest',getappdata(0,'hgui'),'Warning', ...
				['User supplied information for ChArUco board differs from the information found in the QR code on the board.' newline newline ...
				'Use the information from the QR code on the board?'], ...
				'modal',{'Yes','No'},'Yes');
			if strmatch(button,'Yes')==1 %#ok<*MATCH2>
				target.markerFamily = qr_markerFamily;
				target.originCheckerColor = qr_originCheckerColor;
				target.patternDims = qr_patternDims;
				target.checkerSize = qr_checkerSize;
				target.markerSize = qr_markerSize;
				if strcmp(target.originCheckerColor,'Black')
					handles.calib_origincolor.Value = 1;
				else
					handles.calib_origincolor.Value = 2;
				end
				handles.calib_rows.String = num2str(target.patternDims(1));
				handles.calib_columns.String = num2str(target.patternDims(2));
				handles.calib_checkersize.String = num2str(target.checkerSize);
				handles.calib_markersize.String = num2str(target.markerSize);
			end
		end
		break
	end
end
end

function target = maybe_update_checkerboard_layout(target, detected_target, handles)
if isempty(detected_target.patternDims) || any(detected_target.patternDims <= 0)
	return
end
if any(target.patternDims ~= detected_target.patternDims)
	target.patternDims = detected_target.patternDims;
	handles.calib_rows.String = num2str(target.patternDims(1));
	handles.calib_columns.String = num2str(target.patternDims(2));
end
end

function [imagePoints, worldPoints, imageFileNames, imageSize] = collect_custom_plate_observations(target, image_files)
plate = target.customPlate;
imagePoints = plate.imagePoints;
% Normalise single-image N×2 to N×2×1 required by the estimation pipeline
if ismatrix(imagePoints) && size(imagePoints, 2) == 2
    ip_norm = zeros(size(imagePoints, 1), 2, 1);
    ip_norm(:, :, 1) = imagePoints;
    imagePoints = ip_norm;
end
worldPoints = plate.worldPoints;
imageFileNames = plate.imageFileNames;
imageSize = plate.imageSize;

if isempty(imageSize)
	if ~isempty(image_files)
		first_image = imread(image_files{1});
		imageSize = size(first_image);
		imageSize = imageSize(1:2);
	elseif ~isempty(imageFileNames) && exist(imageFileNames{1}, 'file')
		first_image = imread(imageFileNames{1});
		imageSize = size(first_image);
		imageSize = imageSize(1:2);
	else
		error('PIVlab:MissingCustomPlateImageSize', ...
			'Custom 3D plate calibration needs imageSize in the MAT file or loaded calibration images.');
	end
end

if isempty(imageFileNames) && ~isempty(image_files)
	imageFileNames = image_files(:);
end
end

function [cameraParams, imagesUsed, stats, imagePoints, imageFileNames] = refine_camera_solution(cameraParams, stats, imagePoints, worldPoints, imageSize, imageFileNames)
imagesUsed = true(size(imagePoints,3),1);
errors = stats.ReprojectionErrors;
numImages = size(errors, 3);
meanErrorPerImage = zeros(numImages, 1);
for i = 1:numImages
	e = errors(:, :, i);
	meanErrorPerImage(i) = mean(sqrt(sum(e.^2, 2)),'omitnan');
end
threshold = mean(meanErrorPerImage) + 1.5*std(meanErrorPerImage);
badImages = find(meanErrorPerImage > threshold);
goodImages = find(meanErrorPerImage <= threshold);

if numel(badImages) > 0 && numel(goodImages) > 3
	disp(['Skipping ' num2str(numel(badImages)) ' image(s) due to high reprojection errors.'])
	imagePoints = imagePoints(:, :, goodImages);
	if ~isempty(imageFileNames)
		imageFileNames = imageFileNames(goodImages);
	end
	[cameraParams, imagesUsed, stats] = opencv.pivlab_estimateCameraParameters(imagePoints, worldPoints, imageSize, cameraParams);
	if ~isempty(imageFileNames)
		imageFileNames = imageFileNames(imagesUsed);
	end
end
end

function show_calibration_preview(imageFileNames, imagesUsed, imagePoints, stats)
used_index = find(imagesUsed, 1);
if isempty(used_index)
	used_index = 1;
end

if ~isempty(imageFileNames) && numel(imageFileNames) >= used_index && exist(imageFileNames{used_index}, 'file')
	imshow(imread(imageFileNames{used_index}),'Parent',gui.retr('pivlab_axis'));
	hold on;
	plot(imagePoints(:,1,used_index), imagePoints(:,2,used_index),'go');
	plot(stats.ReprojectedPoints(:,1,used_index),stats.ReprojectedPoints(:,2,used_index),'r+');
	legend('Detected Points','ReprojectedPoints');
	hold off;
else
	cla(gui.retr('pivlab_axis'));
	axes(gui.retr('pivlab_axis')); %#ok<LAXES>
	plot(imagePoints(:,1,used_index), imagePoints(:,2,used_index),'go');
	hold on;
	plot(stats.ReprojectedPoints(:,1,used_index),stats.ReprojectedPoints(:,2,used_index),'r+');
	legend('Detected Points','ReprojectedPoints');
	hold off;
end
end

function show_calibration_success_message(target, imagePoints, imagesUsed, detectionSummary, stats)
possible_grid_points = size(imagePoints,1) * sum(imagesUsed);
detected_grid_points = sum(~isnan(imagePoints(:))) / 2;
percentage_detected = round(detected_grid_points / max(possible_grid_points, 1) * 100, 1);

err = stats.ReprojectionErrors;
errNorm = sqrt(err(:,1,:).^2 + err(:,2,:).^2);
meanReprojError = mean(errNorm(:), 'omitnan');

message = {'Success.'; ...
	['Target type: ' target.name]; ...
	['Detected ' num2str(percentage_detected) '% of calibration points.']; ...
	['Mean reprojection error: ' num2str(round(meanReprojError,2)) ' px']};
if strcmp(target.type, 'checkerboard')
	message{end+1} = ['Detected inner-corner layout: ' num2str(detectionSummary.detected_layout(1)) ' x ' num2str(detectionSummary.detected_layout(2))];
elseif strcmp(target.type, 'custom3d')
	message{end+1} = ['Imported world points: ' num2str(size(target.customPlate.worldPoints,1))];
end

gui.custom_msgbox('msg',getappdata(0,'hgui'),'Success',message,'modal',{'OK'},'OK');
end
