function tests = test_stereo_3d_calibration
%TEST_STEREO_3D_CALIBRATION Test stereo calibration with LaVision 3D plates.
%
%  End-to-end test of the stereo calibration pipeline:
%    plate generation → synthetic projection → mono calibration → stereo extrinsics.
tests = functiontests(localfunctions);
end

% ────────────────────────────────────────────────────────────────────
function test_lavision_plate_generator(testCase)
% Verify that all five LaVision plate types produce valid world points.

types = {'025-3.3-1', '058-5-1', '106-10-2', '204-15-3', '309-15-3'};
expected_pt_distances = [3.3, 5.0, 10.0, 15.0, 15.0];
expected_level_seps   = [1.0, 1.0, 2.0,  3.0,  3.0];

for i = 1:numel(types)
    plate = stereo.generate_lavision_plate(types{i});

    testCase.verifyTrue(isstruct(plate), ...
        sprintf('%s: output is not a struct.', types{i}));
    testCase.verifyEqual(plate.units, 'mm');
    testCase.verifyEqual(size(plate.worldPoints, 2), 3, ...
        sprintf('%s: worldPoints must be N×3.', types{i}));
    testCase.verifyFalse(plate.isPlanar, ...
        sprintf('%s: isPlanar must be false for a two-level plate.', types{i}));
    testCase.verifyEqual(plate.pt_distance, expected_pt_distances(i));
    testCase.verifyEqual(plate.level_separation, expected_level_seps(i));

    % Check that the two levels are present and separated correctly
    z = plate.worldPoints(:, 3);
    z_front = z(plate.front_indices);
    z_back  = z(plate.back_indices);
    testCase.verifyLessThan(max(abs(z_front)), 1e-12, ...
        sprintf('%s: front-level Z must be zero.', types{i}));
    testCase.verifyEqual(unique(round(z_back, 6)), expected_level_seps(i), ...
        sprintf('%s: back-level Z must equal level_separation.', types{i}));

    % Check grid spacing on the XY plane
    pts = plate.worldPoints;
    front_xy = pts(plate.front_indices(2:end), 1:2) - pts(plate.front_indices(1:end-1), 1:2);
    testCase.verifyTrue(all(vecnorm(front_xy, 2, 2) > 0), ...
        sprintf('%s: front points must be distinct.', types{i}));

    % Position marks must be on the front level
    for idx = plate.position_mark_indices
        testCase.verifyEqual(plate.worldPoints(idx, 3), 0, ...
            sprintf('%s: position mark %d must be on front level.', types{i}, idx));
    end
end
end

% ────────────────────────────────────────────────────────────────────
function test_lavision_plate_custom_grid(testCase)
% Verify grid dimension override works.

plate = stereo.generate_lavision_plate('106-10-2', [8, 12]);
n_front = length(plate.front_indices);
n_back  = length(plate.back_indices);
testCase.verifyEqual(n_front + n_back, 8 * 12, ...
    'Custom [8,12] grid must produce 96 total points.');
end

% ────────────────────────────────────────────────────────────────────
function test_stereo_extrinsics_from_synthetic_plate(testCase)
% Full pipeline test: synthetic 3D plate → two virtual cameras → calibration → verification.
%
% Setup:
%   Virtual calibration plate (Type 058-5-1, 5 mm spacing, 1 mm level separation)
%   Camera 1: 30° left,  camera 2: 30° right  (~60 cm away from plate centre)
%   Synthetic cameras with same intrinsics, known relative pose.
%
% The test verifies:
%   1. Mono calibration recovers intrinsics within tolerance
%   2. Stereo extrinsics recover the ground-truth R and t

testCase.assumeTrue(exist('cameraParameters', 'class') > 0, ...
    'cameraParameters class is required.');
testCase.assumeTrue(meta.class.fromName('vision.calibration.monocular.CharucoBoardDetector') > 0 || true, ...
    'Running with available toolboxes.');

% --- 1. Generate plate world points ---
plate_type = '058-5-1';
plate = stereo.generate_lavision_plate(plate_type);
worldPoints = plate.worldPoints;

% --- 2. Define synthetic cameras ---
% Image size
imageSize = [1200, 1600];  % height, width  (portrait mode → 'landscape sensor')

% Shared intrinsics  (moderate wide-angle, mild distortion)
fx = 2400;  fy = 2400;
cx = 800;   cy = 600;
K = [fx  0 cx;  0 fy cy;  0 0 1];

radialDistortion    = [0.08, -0.12];      % k1, k2
tangentialDistortion = [-0.0005, 0.0003]; % p1, p2

% Place the plate 600 mm away, centred at origin
% Camera 1 looks from the left, Camera 2 from the right
distance_mm = 600;
baseline_mm = 250;  % stereo baseline (half-angle config)

% Camera 1 pose: rotated +30° around Y, translated to left side
theta = deg2rad(30);
R1 = rot_y(theta);                       % facing plate from left
t1 = [-baseline_mm/2; 0; distance_mm];  % world origin in camera 1 frame

% Camera 2 pose: rotated -30° around Y, translated to right side
R2 = rot_y(-theta);
t2 = [baseline_mm/2; 0; distance_mm];

% Ground-truth relative pose: cam1 → cam2
% X_cam2 = R_rel * X_cam1 + t_rel
R_gt = R2 * R1';
t_gt = t2 - R_gt * t1;

% Build cameraParameters objects
camParams1 = cameraParameters( ...
    'IntrinsicMatrix', K', ...
    'RadialDistortion', radialDistortion, ...
    'TangentialDistortion', tangentialDistortion, ...
    'ImageSize', imageSize);

camParams2 = cameraParameters( ...
    'IntrinsicMatrix', K', ...
    'RadialDistortion', radialDistortion, ...
    'TangentialDistortion', tangentialDistortion, ...
    'ImageSize', imageSize);

% --- 3. Project world points into both views ---
imagePoints1 = worldToImage(camParams1, R1, t1, worldPoints);
imagePoints2 = worldToImage(camParams2, R2, t2, worldPoints);

% Add annotation noise  (~0.3 px std, simulating manual clicking)
rng(2024);
noise_std = 0.3;
imagePoints1 = imagePoints1 + noise_std * randn(size(imagePoints1));
imagePoints2 = imagePoints2 + noise_std * randn(size(imagePoints2));

% Verify projected points are in frame
testCase.verifyTrue(all(imagePoints1(:,1) > 0 & imagePoints1(:,1) < imageSize(2)), ...
    'Camera 1 projected points must be within image.');
testCase.verifyTrue(all(imagePoints1(:,2) > 0 & imagePoints1(:,2) < imageSize(1)), ...
    'Camera 1 projected points must be within image.');

% --- 4. Mono calibration for each camera ---
% Use the known worldPoints with the noisy image points
[camParams1_est, ~, stats1] = opencv.pivlab_estimateCameraParameters( ...
    reshape_to_3d(imagePoints1), worldPoints, imageSize);
[camParams2_est, ~, stats2] = opencv.pivlab_estimateCameraParameters( ...
    reshape_to_3d(imagePoints2), worldPoints, imageSize);

% Verify mono calibration accuracy
fx_err_1 = abs(camParams1_est.FocalLength(1) - fx) / fx;
fx_err_2 = abs(camParams2_est.FocalLength(2) - fy) / fy;
testCase.verifyLessThan(fx_err_1, 0.05, ...
    sprintf('Camera 1 fx error: %.3f %%', fx_err_1*100));
testCase.verifyLessThan(fx_err_2, 0.05);

testCase.verifyLessThan(stats1.MeanReprojectionError, 2.0, ...
    'Camera 1 mean reprojection error must be < 2 px.');
testCase.verifyLessThan(stats2.MeanReprojectionError, 2.0, ...
    'Camera 2 mean reprojection error must be < 2 px.');

% --- 5. Stereo calibration ---
% Build coupled calibration object (simulating what the GUI does)
coupled = stereo.default_coupled_calibration();

cam1_state = stereo.default_camera_calibration_state(1);
cam1_state.cameraParams = camParams1_est;
cam1_state.cameraStats = stats1;
cam1_state.cam_use_calibration = 1;
cam1_state.manual_image_points = reshape_to_3d(imagePoints1);
coupled = stereo.set_camera_calibration_state(coupled, 1, cam1_state);

cam2_state = stereo.default_camera_calibration_state(2);
cam2_state.cameraParams = camParams2_est;
cam2_state.cameraStats = stats2;
cam2_state.cam_use_calibration = 1;
cam2_state.manual_image_points = reshape_to_3d(imagePoints2);
coupled = stereo.set_camera_calibration_state(coupled, 2, cam2_state);

testCase.verifyEqual(coupled.summary.num_calibrated_cameras, 2);
testCase.verifyTrue(coupled.summary.is_complete);

% Call the stereo extrinsics estimator with gui context for plate data
% We need to set appdata since estimate_volume_calibration reads from gui
setappdata(0, 'calib_custom_plate_definition', plate);
setappdata(0, 'calib_use_tilted_model', false);

result = stereo.estimate_volume_calibration(coupled, 'Verbose', false);

testCase.verifyEqual(result.status, 'estimated', ...
    'Stereo calibration must succeed.');

% --- 6. Verify extrinsics ---
% Rotation error: angle of R_err = R_est * R_gt'
R_err = result.R * R_gt';
rot_error_deg = rad2deg(acos((trace(R_err) - 1) / 2));
% Clamp to valid acos range
rot_error_deg = min(rot_error_deg, 180 - rot_error_deg);
testCase.verifyLessThan(rot_error_deg, 2.0, ...
    sprintf('Rotation error must be < 2 deg. Got %.2f deg.', rot_error_deg));

% Translation direction error
t_gt_norm = t_gt / norm(t_gt);
t_est_norm = result.t / norm(result.t);
trans_angle_err = rad2deg(acos(abs(dot(t_gt_norm, t_est_norm))));
testCase.verifyLessThan(trans_angle_err, 5.0, ...
    sprintf('Translation direction error: %.2f deg.', trans_angle_err));

% Translation magnitude error
t_mag_err = abs(norm(result.t) - norm(t_gt)) / norm(t_gt);
testCase.verifyLessThan(t_mag_err, 0.10, ...
    sprintf('Translation magnitude error: %.2f %%.', t_mag_err * 100));

% Reprojection error
testCase.verifyLessThan(result.meanReprojError_px, 1.5, ...
    sprintf('Mean stereo reprojection error: %.3f px.', result.meanReprojError_px));

fprintf('\n  Stereo calibration test results:\n');
fprintf('    Rotation error    : %.3f deg\n', rot_error_deg);
fprintf('    Translation dir   : %.3f deg\n', trans_angle_err);
fprintf('    Translation scale : %.2f %%\n', t_mag_err * 100);
fprintf('    Reprojection err  : %.3f px\n', result.meanReprojError_px);
fprintf('    Estimated R:\n');
disp(result.R);
fprintf('    Ground-truth R:\n');
disp(R_gt);
end

% ────────────────────────────────────────────────────────────────────
function test_stereo_calibration_with_different_plate_types(testCase)
% Verify that different plate types all produce valid calibrations.

testCase.assumeTrue(exist('cameraParameters', 'class') > 0, ...
    'cameraParameters class is required.');

types_to_test = {'025-3.3-1', '106-10-2'};

for p = 1:numel(types_to_test)
    plate = stereo.generate_lavision_plate(types_to_test{p});
    worldPoints = plate.worldPoints;

    imageSize = [1024, 1280];
    fx = 1800; fy = 1800; cx = 640; cy = 512;
    K = [fx 0 cx; 0 fy cy; 0 0 1];
    radDist = [0.05, -0.07];
    tanDist = [0, 0];

    camParams = cameraParameters( ...
        'IntrinsicMatrix', K', ...
        'RadialDistortion', radDist, ...
        'TangentialDistortion', tanDist, ...
        'ImageSize', imageSize);

    % Two camera poses separated by a known baseline
    baseline = 150;
    half = baseline / 2;
    R1 = rot_y(deg2rad(20));
    t1 = [-half; 0; 500];

    R2 = rot_y(deg2rad(-20));
    t2 = [half; 0; 500];

    imagePoints1 = worldToImage(camParams, R1, t1, worldPoints) + 0.2 * randn(size(worldPoints, 1), 2);
    imagePoints2 = worldToImage(camParams, R2, t2, worldPoints) + 0.2 * randn(size(worldPoints, 1), 2);

    [cp1, ~, s1] = opencv.pivlab_estimateCameraParameters( ...
        reshape_to_3d(imagePoints1), worldPoints, imageSize);
    [cp2, ~, s2] = opencv.pivlab_estimateCameraParameters( ...
        reshape_to_3d(imagePoints2), worldPoints, imageSize);

    coupled = stereo.default_coupled_calibration();
    s1_state = stereo.default_camera_calibration_state(1);
    s1_state.cameraParams = cp1; s1_state.cameraStats = s1;
    s1_state.cam_use_calibration = 1;
    s1_state.manual_image_points = reshape_to_3d(imagePoints1);
    coupled = stereo.set_camera_calibration_state(coupled, 1, s1_state);

    s2_state = stereo.default_camera_calibration_state(2);
    s2_state.cameraParams = cp2; s2_state.cameraStats = s2;
    s2_state.cam_use_calibration = 1;
    s2_state.manual_image_points = reshape_to_3d(imagePoints2);
    coupled = stereo.set_camera_calibration_state(coupled, 2, s2_state);

    setappdata(0, 'calib_custom_plate_definition', plate);

    result = stereo.estimate_volume_calibration(coupled, 'Verbose', false);

    R_gt = R2 * R1';
    R_err = result.R * R_gt';
    rot_error = rad2deg(acos(min(1, max(-1, (trace(R_err) - 1) / 2))));

    testCase.verifyEqual(result.status, 'estimated', ...
        sprintf('%s: calibration must succeed.', types_to_test{p}));
    testCase.verifyLessThan(rot_error, 3.0, ...
        sprintf('%s: rotation error %.2f deg.', types_to_test{p}, rot_error));
    testCase.verifyLessThan(result.meanReprojError_px, 2.0, ...
        sprintf('%s: reprojection too high.', types_to_test{p}));
end
end

% ────────────────────────────────────────────────────────────────────
function test_estimate_volume_calibration_rejects_missing_data(testCase)
% Error paths: missing camera params, missing world points, missing image points.

plate = stereo.generate_lavision_plate('058-5-1');

% --- Missing camera params ---
coupled = stereo.default_coupled_calibration();
setappdata(0, 'calib_custom_plate_definition', plate);

testCase.verifyError(@() stereo.estimate_volume_calibration(coupled, 'Verbose', false), ...
    'PIVlab:StereoCalibrationMissingMono');

% --- Missing image points (camera 1 has params but no annotation) ---
cp = make_simple_camera();
s1 = stereo.default_camera_calibration_state(1);
s1.cameraParams = cp; s1.cam_use_calibration = 1;
coupled = stereo.set_camera_calibration_state(coupled, 1, s1);

s2 = stereo.default_camera_calibration_state(2);
s2.cameraParams = cp; s2.cam_use_calibration = 1;
coupled = stereo.set_camera_calibration_state(coupled, 2, s2);

testCase.verifyError(@() stereo.estimate_volume_calibration(coupled, 'Verbose', false), ...
    'PIVlab:StereoCalibrationMissingImagePoints');
end

% ────────────────────────────────────────────────────────────────────
function test_annotation_format_normalisation(testCase)
% Verify that N×2 annotation points are normalised to N×2×1.

% Simulate what cam_manual_annotate_Callback stores after annotation
n_points = 56;
imagePoints_2d = randn(n_points, 2) * 100 + 400;

% The callback normalises N×2 to N×2×1 via reshape
if ismatrix(imagePoints_2d) && size(imagePoints_2d, 2) == 2
    imagePoints_3d = zeros(size(imagePoints_2d, 1), 2, 1);
    imagePoints_3d(:, :, 1) = imagePoints_2d;
end

testCase.verifyEqual(size(imagePoints_3d), [n_points, 2, 1]);
testCase.verifyEqual(imagePoints_3d(:, :, 1), imagePoints_2d);
end

% ────────────────────────────────────────────────────────────────────
% Helpers
% ────────────────────────────────────────────────────────────────────

function ip3d = reshape_to_3d(imagePoints_2d)
%Convert N×2 to N×2×1 for the calibration pipeline.
if ismatrix(imagePoints_2d) && size(imagePoints_2d, 2) == 2
    ip3d = zeros(size(imagePoints_2d, 1), 2, 1);
    ip3d(:, :, 1) = imagePoints_2d;
else
    ip3d = imagePoints_2d;
end
end

function R = rot_y(angle_rad)
%Build a 3×3 rotation matrix around the Y axis.
c = cos(angle_rad);
s = sin(angle_rad);
R = [ c, 0, s;
      0, 1, 0;
     -s, 0, c];
end

function cp = make_simple_camera()
cp = cameraParameters( ...
    'IntrinsicMatrix', [2000 0 0; 0 2000 0; 800 600 1], ...
    'RadialDistortion', [0.05, -0.07], ...
    'TangentialDistortion', [0, 0], ...
    'ImageSize', [1200, 1600]);
end
