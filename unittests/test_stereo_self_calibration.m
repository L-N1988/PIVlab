function tests = test_stereo_self_calibration
tests = functiontests(localfunctions);
end

function test_self_calibrate_disparity_estimates_translation_model(testCase)
rng(0);
settings = stereo.default_settings();
settings.disparity.enable = true;
settings.disparity.model = 'translation';
settings.disparity.window_size = 48;
settings.disparity.step = 24;
settings.disparity.search_radius = 8;
settings.disparity.min_correlation = 0.10;
settings.disparity.min_valid_vectors = 4;
settings.disparity.max_iterations = 2;

[left_images, right_images, true_shift] = load_or_build_particle_dataset([192 224], [5 -4], 3);

coupled = stereo.default_coupled_calibration();
disparity_state = stereo.self_calibrate_disparity(left_images, right_images, coupled, settings);

testCase.verifyEqual(disparity_state.status, 'completed');
testCase.verifyGreaterThan(disparity_state.statistics.num_valid_vectors, 4);
testCase.verifyLessThan(abs(disparity_state.models.total_disparity.coeff_x(1) - true_shift(1)), 0.75);
testCase.verifyLessThan(abs(disparity_state.models.total_disparity.coeff_y(1) - true_shift(2)), 0.75);
testCase.verifyLessThan(disparity_state.statistics.rms_corrected_residual_px, 0.5);
testCase.verifyEqual(disparity_state.calibration.stereo.status, 'self_calibrated');
testCase.verifyTrue(isfield(disparity_state.calibration.stereo, 'disparity_model'));
end

function test_self_calibrate_disparity_accepts_pair_summary_samples(testCase)
rng(1);
settings = stereo.default_settings();
settings.disparity.enable = true;
settings.disparity.model = 'translation';
settings.disparity.window_size = 40;
settings.disparity.step = 20;
settings.disparity.search_radius = 7;
settings.disparity.min_correlation = 0.10;
settings.disparity.min_valid_vectors = 4;

[left_images, right_images, true_shift] = load_or_build_particle_dataset([176 208], [3 2], 2);

pairs = struct( ...
	'index', 1, ...
	'view1_a', left_images{1}, ...
	'view1_b', left_images{2}, ...
	'view2_a', right_images{1}, ...
	'view2_b', right_images{2});

disparity_state = stereo.self_calibrate_disparity(pairs, [], stereo.default_coupled_calibration(), settings);

testCase.verifyEqual(disparity_state.status, 'completed');
testCase.verifyEqual(disparity_state.sample_count, 2);
testCase.verifyLessThan(abs(disparity_state.models.total_disparity.coeff_x(1) - true_shift(1)), 0.75);
testCase.verifyLessThan(abs(disparity_state.models.total_disparity.coeff_y(1) - true_shift(2)), 0.75);
end

function [left_images, right_images, true_shift] = load_or_build_particle_dataset(default_image_size, default_shift, default_count)
dataset_root = fullfile(pwd, 'unittests', 'stero-calibration');
left_dir = fullfile(dataset_root, 'left_particle_figs');
right_dir = fullfile(dataset_root, 'right_particle_figs');
metadata_file = fullfile(dataset_root, 'particle_metadata.mat');

if exist(left_dir, 'dir') && exist(right_dir, 'dir')
	left_files = sorted_png_files(left_dir);
	right_files = sorted_png_files(right_dir);
	if ~isempty(left_files) && numel(left_files) == numel(right_files)
		left_images = cellfun(@(file) im2double(imread(file)), left_files, 'UniformOutput', false);
		right_images = cellfun(@(file) im2double(imread(file)), right_files, 'UniformOutput', false);
		true_shift = default_shift;
		if exist(metadata_file, 'file')
			data = load(metadata_file);
			if isfield(data, 'known_shift_xy')
				true_shift = data.known_shift_xy;
			end
		end
		return
	end
end

true_shift = default_shift;
[left_images, right_images] = build_shifted_particle_images(default_image_size, true_shift, default_count);
end

function files = sorted_png_files(folder_path)
listing = dir(fullfile(folder_path, '*.png'));
if isempty(listing)
	files = {};
	return
end

[~, idx] = sort({listing.name});
listing = listing(idx);
files = fullfile({listing.folder}', {listing.name}');
end

function [left_images, right_images] = build_shifted_particle_images(image_size, shift_xy, count)
left_images = cell(count, 1);
right_images = cell(count, 1);
for i = 1:count
	left = synthetic_particle_frame(image_size, 550, 1.2);
	right = translate_image(left, shift_xy);
	left_images{i} = left;
	right_images{i} = right;
end
end

function image = synthetic_particle_frame(image_size, particle_count, sigma)
impulses = zeros(image_size);
x_positions = randi([6 image_size(2)-5], particle_count, 1);
y_positions = randi([6 image_size(1)-5], particle_count, 1);
indices = sub2ind(image_size, y_positions, x_positions);
impulses(indices) = 1;

kernel = gaussian_kernel(9, sigma);
image = conv2(impulses, kernel, 'same');
image = image + 0.03 * randn(image_size);
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
