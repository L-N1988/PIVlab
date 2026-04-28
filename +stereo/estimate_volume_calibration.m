function result = estimate_volume_calibration(coupled, varargin)
%ESTIMATE_VOLUME_CALIBRATION Stereo / volume calibration from paired 3D-target views.
%
%   result = stereo.estimate_volume_calibration(coupled)
%   result = stereo.estimate_volume_calibration(coupled, 'Verbose', true)
%
% Input:
%   coupled  – coupled calibration struct with both camera states populated.
%              Each camera must have cameraParams, cameraStats, and
%              cam_selected_target_images with at least one image whose
%              points have been manually annotated or loaded from a
%              custom 3D plate definition.
%
% Output (fields stored in coupled.stereo.mapping):
%   result.status              – 'estimated' | 'failed'
%   result.R                   – 3×3 rotation matrix  (camera 1 → camera 2)
%   result.t                   – 3×1 translation vector (camera 1 → camera 2)
%   result.cameraMatrix1       – 3×4 projection matrix for camera 1
%   result.cameraMatrix2       – 3×4 projection matrix for camera 2
%   result.meanReprojError_px  – scalar mean reprojection error
%   result.stereoParams        – stereoParameters object (if available)
%   result.worldPoints         – N×3 world points used
%   result.imagePoints1        – N×2 image points in camera 1
%   result.imagePoints2        – N×2 image points in camera 2

p = inputParser;
p.addParameter('Verbose', true, @islogical);
p.parse(varargin{:});
verbose = p.Results.Verbose;

% ── validate coupled calibration ─────────────────────────────────────
if nargin < 1 || isempty(coupled)
    coupled = stereo.ensure_coupled_calibration();
end

cam1 = stereo.get_camera_calibration_state(coupled, 1);
cam2 = stereo.get_camera_calibration_state(coupled, 2);

if isempty(cam1.cameraParams)
    error('PIVlab:StereoCalibrationMissingMono', ...
        'Camera 1 has no monocular calibration. Calibrate camera 1 first.');
end
if isempty(cam2.cameraParams)
    error('PIVlab:StereoCalibrationMissingMono', ...
        'Camera 2 has no monocular calibration. Calibrate camera 2 first.');
end

% ── collect point correspondences ────────────────────────────────────
% Get worldPoints from the custom plate definition
% Get per-camera imagePoints from the coupled calibration object
%   (stored there by cam_manual_annotate_Callback during annotation)

plate = gui.retr('calib_custom_plate_definition');
if isempty(plate) || ~isstruct(plate) || ~isfield(plate, 'worldPoints')
    error('PIVlab:StereoCalibrationMissingWorldPoints', ...
        'No world points found. Load or generate a calibration plate definition first.');
end
worldPoints = plate.worldPoints;

% Camera 1 image points: from coupled.cameras(1).manual_image_points
imagePoints1_raw = cam1.manual_image_points;
if isempty(imagePoints1_raw)
    % Fall back: try to extract from plate definition (if annotated for cam1)
    if isfield(plate, 'imagePoints') && ~isempty(plate.imagePoints)
        imagePoints1_raw = plate.imagePoints;
    end
end
imagePoints1 = squeeze_2d(imagePoints1_raw);

% Camera 2 image points: from coupled.cameras(2).manual_image_points
imagePoints2_raw = cam2.manual_image_points;
if isempty(imagePoints2_raw)
    % Fall back: try from gui (current camera annotation)
    gui_pts = gui.retr('cam_manual_image_points');
    if ~isempty(gui_pts)
        imagePoints2_raw = gui_pts;
    end
end
imagePoints2 = squeeze_2d(imagePoints2_raw);

% Validate we have everything
if isempty(worldPoints)
    error('PIVlab:StereoCalibrationMissingWorldPoints', ...
        'No world points found. Load or generate a calibration plate definition first.');
end
if isempty(imagePoints1)
    error('PIVlab:StereoCalibrationMissingImagePoints', ...
        'No image points for camera 1. Annotate calibration image first.');
end
if isempty(imagePoints2)
    error('PIVlab:StereoCalibrationMissingImagePoints', ...
        'No image points for camera 2. Annotate calibration image for camera 2 first.');
end

% Align counts: use the minimum of all three
n = min([size(worldPoints,1), size(imagePoints1,1), size(imagePoints2,1)]);
worldPoints  = worldPoints(1:n, :);
imagePoints1 = imagePoints1(1:n, :);
imagePoints2 = imagePoints2(1:n, :);

if verbose
    fprintf('[estimate_volume_calibration] %d point correspondences.\n', n);
end

% ── compute stereo extrinsics ────────────────────────────────────────
try
    mapping = compute_stereo_extrinsics(worldPoints, imagePoints1, imagePoints2, ...
        cam1.cameraParams, cam2.cameraParams, verbose);
    mapping.worldPoints = worldPoints;
    mapping.imagePoints1 = imagePoints1;
    mapping.imagePoints2 = imagePoints2;
catch ME
    result = struct();
    result.status = 'failed';
    result.message = ME.message;
    if verbose
        warning('PIVlab:StereoCalibrationFailed', ...
            'Stereo calibration failed: %s', ME.message);
    end
    return
end

% ── assemble result ──────────────────────────────────────────────────
result = mapping;
result.status = 'estimated';
result.schema_version = 1;
result.method = 'LaVision-3D-plate';
result.timestamp = now;

if verbose
    fprintf('[estimate_volume_calibration] Stereo calibration complete.\n');
    fprintf('  Mean reprojection error: %.3f px\n', result.meanReprojError_px);
end

end

function mapping = compute_stereo_extrinsics(worldPoints, imagePoints1, ...
    imagePoints2, cameraParams1, cameraParams2, verbose)
%Compute stereo extrinsics from matched point sets and known intrinsics.
%
% Strategy: estimate the pose of each camera w.r.t. the calibration plate,
% then compute the relative transform from camera 1 to camera 2.

% Estimate camera 1 pose in world (plate) frame
try
    [R1, t1] = estimateWorldCameraPose(imagePoints1, worldPoints, cameraParams1, ...
        'MaxReprojectionError', 5);
catch
    % Fall back to extrinsic estimation via extrinsics function
    [R1, t1] = estimateWorldCameraPose(imagePoints1, worldPoints, cameraParams1);
end

% Estimate camera 2 pose in world (plate) frame
try
    [R2, t2] = estimateWorldCameraPose(imagePoints2, worldPoints, cameraParams2, ...
        'MaxReprojectionError', 5);
catch
    [R2, t2] = estimateWorldCameraPose(imagePoints2, worldPoints, cameraParams2);
end

if verbose
    fprintf('  Camera 1 pose: t = [%.1f %.1f %.1f] mm\n', t1);
    fprintf('  Camera 2 pose: t = [%.1f %.1f %.1f] mm\n', t2);
end

% Compute relative transform: cam1 → world → cam2
% R: rotation that maps camera 1 orientation to camera 2 orientation
% t: translation from camera 1 origin to camera 2 origin, expressed in camera 2 frame
%
% Given:  X_cam1 = R1 * X_world + t1
%         X_cam2 = R2 * X_world + t2
% So:     X_world = R1' * (X_cam1 - t1)
%         X_cam2  = R2 * R1' * (X_cam1 - t1) + t2
%         X_cam2  = R2*R1' * X_cam1 + (t2 - R2*R1'*t1)
%
%         R = R2 * R1'
%         t = t2 - R * t1

R_rel = R2 * R1';
t_rel = t2' - R_rel * t1';

% Build camera matrices: P = K * [R | t]
K1 = cameraParams1.IntrinsicMatrix';  % MATLAB stores as [fx 0 cx; 0 fy cy; 0 0 1]'
cameraMatrix1 = K1 * [R1, t1'];

K2 = cameraParams2.IntrinsicMatrix';
cameraMatrix2 = K2 * [R2, t2'];

% Reprojection error check
proj1 = worldToImage(cameraParams1, R1, t1, worldPoints);
proj2 = worldToImage(cameraParams2, R2, t2, worldPoints);
err1 = sqrt(sum((imagePoints1 - proj1).^2, 2));
err2 = sqrt(sum((imagePoints2 - proj2).^2, 2));
meanReprojError_px = mean([err1; err2]);

% ── optionally try stereoParameters for refinement ───────────────────
stereoParams = [];
try
    stereoParams = stereoParameters(cameraParams1, cameraParams2, R_rel, t_rel');
    mapping.stereoParams = stereoParams;
catch
    % stereoParameters may not be available in older MATLAB
end

% Assemble mapping
mapping = struct();
mapping.R = R_rel;
mapping.t = t_rel;
mapping.cameraMatrix1 = cameraMatrix1;
mapping.cameraMatrix2 = cameraMatrix2;
mapping.meanReprojError_px = meanReprojError_px;
mapping.stereoParams = stereoParams;
mapping.worldPoints = worldPoints;
mapping.imagePoints1 = imagePoints1;
mapping.imagePoints2 = imagePoints2;

end

function pts_2d = squeeze_2d(imagePoints)
%Normalise imagePoints to N×2 regardless of input dimensionality.
if isempty(imagePoints)
    pts_2d = [];
    return
end
if ndims(imagePoints) == 3
    % N×2×M → take first image plane, squeeze to N×2
    pts_2d = squeeze(imagePoints(:, :, 1));
    if size(pts_2d, 2) ~= 2 && size(pts_2d, 1) == 2
        pts_2d = pts_2d';
    end
elseif ismatrix(imagePoints) && size(imagePoints, 2) == 2
    pts_2d = imagePoints;
else
    pts_2d = [];
end
end

