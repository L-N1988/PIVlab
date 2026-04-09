function metadata = generate_stereo_test_figures(output_root)
%GENERATE_STEREO_TEST_FIGURES Build synthetic stereo calibration and particle datasets.
% This generator writes reproducible figures into unittests/stero-calibration:
%   - left_calibration_figs / right_calibration_figs
%   - left_particle_figs / right_particle_figs
%
% The calibration figures are synthetic ChArUco-board views with embedded
% QR metadata, meant for the stereo calibration and rectification tests.
% The particle figures are synchronized left/right particle images with a
% known disparity, meant for stereo self-calibration tests.

if nargin < 1 || isempty(output_root)
	output_root = fileparts(mfilename('fullpath'));
end

rng(7);
ensure_folder(output_root);

left_calibration_dir = fullfile(output_root, 'left_calibration_figs');
right_calibration_dir = fullfile(output_root, 'right_calibration_figs');
left_particle_dir = fullfile(output_root, 'left_particle_figs');
right_particle_dir = fullfile(output_root, 'right_particle_figs');

reset_folder(left_calibration_dir);
reset_folder(right_calibration_dir);
reset_folder(left_particle_dir);
reset_folder(right_particle_dir);

board_spec = default_board_spec();
board_image = render_charuco_master(board_spec);
imwrite(board_image, fullfile(output_root, 'charuco_master.png'));

calibration_pose_spec = default_calibration_pose_spec();
generate_calibration_views(board_image, board_spec, calibration_pose_spec, left_calibration_dir, right_calibration_dir);

particle_spec = default_particle_spec();
generate_particle_views(particle_spec, left_particle_dir, right_particle_dir);

metadata = struct();
metadata.output_root = output_root;
metadata.board_spec = board_spec;
metadata.calibration_pose_spec = calibration_pose_spec;
metadata.particle_spec = particle_spec;
save(fullfile(output_root, 'stereo_test_figure_metadata.mat'), '-struct', 'metadata');
end

function spec = default_board_spec()
spec = struct();
spec.markerFamily = 'DICT_4X4_1000';
spec.originCheckerColor = 'Black';
spec.patternDims = [8 11];
spec.checkerSize = 10;
spec.markerSize = 7;
spec.dpi = 200;
spec.marginCheckers = 3;
end

function spec = default_calibration_pose_spec()
spec = struct();
spec.outputSize = [1200 1600];
spec.imageCount = 7;
spec.backgroundLevel = 245;
spec.gaussianBlurSigma = 0.6;
spec.noiseSigma = 2.0;

spec.leftQuads = {
	[280 210; 1260 180; 1320 1010; 240 1040]
	[190 280; 1150 170; 1310 980; 290 1080]
	[360 170; 1320 260; 1190 1010; 250 950]
	[240 140; 1360 190; 1260 1020; 200 990]
	[340 260; 1230 170; 1330 910; 300 1030]
	[210 210; 1200 240; 1250 1030; 180 980]
	[300 150; 1380 230; 1240 950; 260 1010]
	};
spec.rightQuads = {
	[330 200; 1320 220; 1260 1040; 300 980]
	[250 260; 1220 230; 1290 1010; 320 980]
	[420 180; 1380 280; 1150 980; 350 930]
	[300 160; 1420 230; 1220 1040; 260 960]
	[390 250; 1290 220; 1290 930; 360 980]
	[260 220; 1280 270; 1210 1040; 240 950]
	[350 170; 1450 260; 1200 980; 310 950]
	};
end

function spec = default_particle_spec()
spec = struct();
spec.imageSize = [192 224];
spec.imageCount = 6;
spec.particleCount = 550;
spec.particleSigma = 1.2;
spec.noiseSigma = 0.03;
spec.disparityShiftXY = [4 -3];
end

function board_image = render_charuco_master(board_spec)
pattern_dims = board_spec.patternDims;
checker_size = board_spec.checkerSize;
dpi = board_spec.dpi;
margin_size = round(checker_size * dpi / 25.4 * board_spec.marginCheckers);
image_size = [ ...
	ceil(pattern_dims(1) * checker_size * dpi / 25.4) + 2 * margin_size, ...
	ceil(pattern_dims(2) * checker_size * dpi / 25.4) + 2 * margin_size];

board_image = generateCharucoBoard( ...
	image_size, ...
	pattern_dims, ...
	board_spec.markerFamily, ...
	checker_size, ...
	board_spec.markerSize, ...
	"OriginCheckerColor", board_spec.originCheckerColor, ...
	"MinMarkerID", 0, ...
	"MarginSize", margin_size);

board_image = ensure_uint8(board_image);
board_image = add_charuco_qr_metadata(board_image, board_spec, margin_size);
end

function board_image = add_charuco_qr_metadata(board_image, board_spec, qr_size)
if strcmpi(board_spec.originCheckerColor, 'white')
	qr_origin = 'w';
else
	qr_origin = 'b';
end

if strcmp(board_spec.markerFamily, 'DICT_4X4_1000')
	qr_family = 1;
else
	error('PIVlab:UnsupportedCharucoFamily', 'Only DICT_4X4_1000 is supported in the dataset generator.');
end

payload = sprintf('F:%d,O:%s,R:%d,C:%d,S:%g,M:%g', ...
	qr_family, qr_origin, board_spec.patternDims(1), board_spec.patternDims(2), ...
	board_spec.checkerSize, board_spec.markerSize);
qr_0 = preproc.cam_encode_qr(payload, qr_size);
qr_180 = rot90(qr_0, 2);

board_mask = true(size(board_image, 1), size(board_image, 2));
board_mask(1:qr_size, 1:qr_size) = qr_0;
board_mask(1:qr_size, end-qr_size+1:end) = qr_0;
board_mask(end-qr_size+1:end, 1:qr_size) = qr_180;
board_mask(end-qr_size+1:end, end-qr_size+1:end) = qr_180;

board_image(~board_mask) = 0;
end

function generate_calibration_views(board_image, board_spec, pose_spec, left_dir, right_dir)
source_corners = [ ...
	1 1; ...
	size(board_image, 2) 1; ...
	size(board_image, 2) size(board_image, 1); ...
	1 size(board_image, 1)];

for i = 1:pose_spec.imageCount
	left_img = warp_board_to_view(board_image, source_corners, pose_spec.leftQuads{i}, pose_spec);
	right_img = warp_board_to_view(board_image, source_corners, pose_spec.rightQuads{i}, pose_spec);

	left_img = decorate_calibration_image(left_img, i, board_spec, 'L');
	right_img = decorate_calibration_image(right_img, i, board_spec, 'R');

	imwrite(left_img, fullfile(left_dir, sprintf('%02d.jpg', i)), 'Quality', 95);
	imwrite(right_img, fullfile(right_dir, sprintf('%02d.jpg', i)), 'Quality', 95);
end
end

function warped = warp_board_to_view(board_image, source_corners, dest_corners, pose_spec)
tform = estimate_projective_transform(source_corners, dest_corners);
warped = imwarp(board_image, tform, 'OutputView', imref2d(pose_spec.outputSize), 'FillValues', pose_spec.backgroundLevel);
warped = ensure_uint8(warped);
end

function image = decorate_calibration_image(image, index, board_spec, camera_label)
image = double(image);
if exist('imgaussfilt', 'file') > 0
	image = imgaussfilt(image, 0.6);
end
image = image + board_spec.dpi * 0 + randn(size(image)) * 2.0;
image = uint8(min(max(image, 0), 255));

if exist('insertText', 'file') > 0
	label = sprintf('Stereo dataset %s%02d', camera_label, index);
	image = insertText(image, [30 30], label, ...
		'FontSize', 22, 'BoxColor', 'white', 'BoxOpacity', 0.4, ...
		'TextColor', 'black');
	end
end

function generate_particle_views(spec, left_dir, right_dir)
metadata = struct();
metadata.imageCount = spec.imageCount;
metadata.known_shift_xy = spec.disparityShiftXY;
metadata.imageSize = spec.imageSize;

for i = 1:spec.imageCount
		left = synthetic_particle_frame(spec.imageSize, spec.particleCount, spec.particleSigma, spec.noiseSigma);
		right = translate_image(left, spec.disparityShiftXY);

		imwrite(im2uint8(left), fullfile(left_dir, sprintf('sample_%02d.png', i)));
		imwrite(im2uint8(right), fullfile(right_dir, sprintf('sample_%02d.png', i)));
end

save(fullfile(fileparts(left_dir), 'particle_metadata.mat'), '-struct', 'metadata');
end

function image = synthetic_particle_frame(image_size, particle_count, sigma, noise_sigma)
impulses = zeros(image_size);
x_positions = randi([6 image_size(2)-5], particle_count, 1);
y_positions = randi([6 image_size(1)-5], particle_count, 1);
indices = sub2ind(image_size, y_positions, x_positions);
impulses(indices) = 1;

kernel = gaussian_kernel(9, sigma);
image = conv2(impulses, kernel, 'same');
image = image + noise_sigma * randn(image_size);
image(image < 0) = 0;
maximum = max(image(:));
if maximum > 0
	image = image / maximum;
end
end

function kernel = gaussian_kernel(kernel_size, sigma)
radius = floor(kernel_size / 2);
[X, Y] = meshgrid(-radius:radius, -radius:radius);
kernel = exp(-(X.^2 + Y.^2) / (2 * sigma^2));
kernel = kernel / sum(kernel(:));
end

function shifted = translate_image(image, shift_xy)
[X, Y] = meshgrid(1:size(image, 2), 1:size(image, 1));
shifted = interp2(X, Y, image, X - shift_xy(1), Y - shift_xy(2), 'linear', 0);
end

function tform = estimate_projective_transform(source_corners, dest_corners)
if exist('fitgeotform2d', 'file') > 0
	tform = fitgeotform2d(source_corners, dest_corners, 'projective');
elseif exist('fitgeotrans', 'file') > 0
	tform = fitgeotrans(source_corners, dest_corners, 'projective');
else
	error('PIVlab:MissingProjectiveTransform', ...
		'fitgeotform2d or fitgeotrans is required to generate synthetic calibration views.');
end
end

function image = ensure_uint8(image)
if isa(image, 'uint8')
	return
end
if islogical(image)
	image = uint8(image) * 255;
	return
end
if max(image(:)) <= 1
	image = uint8(255 * image);
else
	image = uint8(image);
end
end

function reset_folder(folder_path)
if exist(folder_path, 'dir')
	delete(fullfile(folder_path, '*'));
else
	mkdir(folder_path);
end
end

function ensure_folder(folder_path)
if ~exist(folder_path, 'dir')
	mkdir(folder_path);
end
end
