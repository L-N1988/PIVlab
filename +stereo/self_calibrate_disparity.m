function disparity_state = self_calibrate_disparity(view1_results, view2_results, stereo_calibration, stereo_settings)
%SELF_CALIBRATE_DISPARITY Estimate a residual stereo disparity model on particle images.
% The implementation follows the practical Wieneke-2005 idea available in
% the current code base: dewarp both views to a common plane, ensemble-sum
% local cross-correlations, fit a low-order residual disparity model, and
% store the correction on the coupled stereo calibration object.

if nargin < 4 || isempty(stereo_settings)
	stereo_settings = stereo.default_settings();
end
if nargin < 3 || isempty(stereo_calibration)
	stereo_calibration = stereo.default_coupled_calibration();
end
if nargin < 2
	view2_results = [];
end
if nargin < 1
	view1_results = [];
end

stereo_calibration = normalize_coupled_calibration(stereo_calibration);
params = resolve_disparity_settings(stereo_settings);

disparity_state = initialize_disparity_state(stereo_settings, stereo_calibration, params);
disparity_state.input_summary.has_view1_results = ~isempty(view1_results);
disparity_state.input_summary.has_view2_results = ~isempty(view2_results);
if ~params.enable
	disparity_state.status = 'disabled';
	disparity_state.message = 'Stereo self-calibration is disabled in settings.disparity.enable.';
	return
end

sample_pairs = collect_sample_pairs(view1_results, view2_results);
sample_pairs = limit_sample_pairs(sample_pairs, params.max_samples);
disparity_state.sample_count = numel(sample_pairs);

if isempty(sample_pairs)
	disparity_state.status = 'missing_input';
	disparity_state.message = ['No synchronized particle-image samples were provided. Pass paired image ' ...
		'files, GUI view states, or stereo pair summaries.'];
	return
end

camera1_state = stereo.get_camera_calibration_state(stereo_calibration, 1);
camera2_state = stereo.get_camera_calibration_state(stereo_calibration, 2);

	[reference_size, reference_info] = determine_reference_geometry(sample_pairs{1}, camera1_state, camera2_state);
	disparity_state.reference = reference_info;
	if any(reference_size < params.window_size + 2*params.search_radius)
		disparity_state.status = 'image_too_small';
		disparity_state.message = ['Particle images are too small for the requested self-calibration ' ...
			'window and search radius.'];
		return
	end

	grid = build_interrogation_grid(reference_size, params.window_size, params.step, params.search_radius);
	disparity_state.grid = grid;
	if isempty(grid.x)
		disparity_state.status = 'empty_grid';
		disparity_state.message = 'No valid interrogation windows fit inside the common particle-image area.';
		return
	end

	total_model = [];
	iteration_history = cell(max(1, params.max_iterations), 1);
	for iteration = 1:max(1, params.max_iterations)
		field = measure_disparity_field(sample_pairs, camera1_state, camera2_state, grid, params, total_model);
		iteration_history{iteration} = summarize_iteration(field, total_model, iteration);
		if nnz(field.valid) < params.min_valid_vectors
			break
		end

		total_model = fit_disparity_model(field, params.model);
		total_model.iteration = iteration;
	end

	iteration_history = iteration_history(1:max(1, numel(find(~cellfun(@isempty, iteration_history)))));
	disparity_state.history = iteration_history;
	disparity_state.iterations_requested = params.max_iterations;
	disparity_state.iterations_completed = numel(iteration_history);

	if isempty(total_model) || nnz(field.valid) < params.min_valid_vectors
		disparity_state.status = 'insufficient_vectors';
		disparity_state.field = field;
		disparity_state.message = sprintf([ ...
			'Stereo self-calibration found only %d valid disparity vectors; at least %d are required.'], ...
			nnz(field.valid), params.min_valid_vectors);
		return
	end

	models = build_midpoint_models(field, total_model, params.model);
	statistics = compute_field_statistics(field, models);
	updated_calibration = update_calibration_with_disparity(stereo_calibration, models, statistics, params);

	disparity_state.status = 'completed';
	disparity_state.field = field;
	disparity_state.models = models;
	disparity_state.statistics = statistics;
	disparity_state.calibration = updated_calibration;
	disparity_state.message = sprintf([ ...
		'Stereo self-calibration completed with %d valid vectors over %d image samples. ' ...
		'RMS disparity %.3f px, corrected residual %.3f px.'], ...
		statistics.num_valid_vectors, numel(sample_pairs), statistics.rms_disparity_px, statistics.rms_corrected_residual_px);
end

function disparity_state = initialize_disparity_state(~, stereo_calibration, params)
disparity_state = struct();
disparity_state.status = 'not_run';
disparity_state.enabled = params.enable;
disparity_state.model = params.model;
disparity_state.message = '';
disparity_state.sample_count = 0;
disparity_state.iterations_requested = params.max_iterations;
disparity_state.iterations_completed = 0;
disparity_state.reference = struct();
disparity_state.grid = struct();
disparity_state.field = struct();
disparity_state.models = struct();
disparity_state.statistics = struct();
disparity_state.history = {};
disparity_state.calibration = stereo_calibration;
disparity_state.input_summary = struct( ...
	'has_view1_results', false, ...
	'has_calibration', ~isempty(stereo_calibration));
end

function coupled = normalize_coupled_calibration(coupled)
if nargin == 0 || isempty(coupled) || ~isstruct(coupled) || ~isfield(coupled, 'cameras')
	coupled = stereo.default_coupled_calibration();
	return
end

coupled = stereo.update_coupled_calibration_status(coupled);
if ~isfield(coupled, 'stereo') || ~isstruct(coupled.stereo)
	coupled.stereo = struct();
end
if ~isfield(coupled.stereo, 'status')
	coupled.stereo.status = 'not_estimated';
end
if ~isfield(coupled.stereo, 'mapping')
	coupled.stereo.mapping = [];
end
if ~isfield(coupled.stereo, 'disparity_model')
	coupled.stereo.disparity_model = [];
end
if ~isfield(coupled.stereo, 'notes')
	coupled.stereo.notes = {};
end
end

function params = resolve_disparity_settings(stereo_settings)
params = struct();
params.enable = get_nested_field(stereo_settings, {'disparity', 'enable'}, false);
params.model = lower(get_nested_field(stereo_settings, {'disparity', 'model'}, 'affine'));
params.max_iterations = max(1, round(get_nested_field(stereo_settings, {'disparity', 'max_iterations'}, 1)));
params.window_size = max(16, round(get_nested_field(stereo_settings, {'disparity', 'window_size'}, 128)));
params.overlap = get_nested_field(stereo_settings, {'disparity', 'overlap'}, 0.5);
params.step = max(4, round(get_nested_field(stereo_settings, {'disparity', 'step'}, ...
	max(4, params.window_size * (1 - params.overlap)))));
params.search_radius = get_nested_field(stereo_settings, {'disparity', 'search_radius'}, 24);
if isscalar(params.search_radius)
	params.search_radius = [params.search_radius params.search_radius];
else
	params.search_radius = params.search_radius(:)';
	params.search_radius = params.search_radius(1:min(2, numel(params.search_radius)));
	if numel(params.search_radius) == 1
		params.search_radius = [params.search_radius params.search_radius];
	end
end
params.search_radius = max(1, round(params.search_radius));
params.min_correlation = get_nested_field(stereo_settings, {'disparity', 'min_correlation'}, 0.25);
params.min_valid_vectors = max(3, round(get_nested_field(stereo_settings, {'disparity', 'min_valid_vectors'}, 6)));
params.max_samples = get_nested_field(stereo_settings, {'disparity', 'max_samples'}, inf);
params.min_patch_std = get_nested_field(stereo_settings, {'disparity', 'min_patch_std'}, 1e-6);
end

function value = get_nested_field(source, fields, default_value)
value = default_value;
current = source;
for i = 1:numel(fields)
	if ~isstruct(current) || ~isfield(current, fields{i})
		return
	end
	current = current.(fields{i});
end
if ~isempty(current)
	value = current;
end
end

function sample_pairs = limit_sample_pairs(sample_pairs, max_samples)
if isempty(sample_pairs) || isempty(max_samples) || ~isfinite(max_samples)
	return
end
sample_pairs = sample_pairs(1:min(numel(sample_pairs), max_samples));
end

function sample_pairs = collect_sample_pairs(view1_results, view2_results)
sample_pairs = {};

if isstruct(view1_results) && isscalar(view1_results) && isfield(view1_results, 'pairs') && isempty(view2_results)
	view1_results = view1_results.pairs;
end

if is_pair_summary(view1_results) && isempty(view2_results)
	for i = 1:numel(view1_results)
		pair = view1_results(i);
		if isfield(pair, 'view1') && isfield(pair, 'view2') && ~isempty(pair.view1) && ~isempty(pair.view2)
			sample_pairs{end+1} = struct('left', pair.view1, 'right', pair.view2, ... %#ok<AGROW>
				'label', ['pair_' num2str(i)]); %#ok<AGROW>
		end
		if isfield(pair, 'view1_a') && isfield(pair, 'view2_a') && ~isempty(pair.view1_a) && ~isempty(pair.view2_a)
			sample_pairs{end+1} = struct('left', pair.view1_a, 'right', pair.view2_a, ... %#ok<AGROW>
				'label', ['pair_' num2str(i) '_A']); %#ok<AGROW>
		end
		if isfield(pair, 'view1_b') && isfield(pair, 'view2_b') && ~isempty(pair.view1_b) && ~isempty(pair.view2_b)
			sample_pairs{end+1} = struct('left', pair.view1_b, 'right', pair.view2_b, ... %#ok<AGROW>
				'label', ['pair_' num2str(i) '_B']); %#ok<AGROW>
		end
	end
	return
end

if is_view_state(view1_results) && is_view_state(view2_results)
	pair_count = min(floor(numel(view1_results.filepath)/2), floor(numel(view2_results.filepath)/2));
	for i = 1:pair_count
		idx_a = 2*i - 1;
		idx_b = 2*i;
		sample_pairs{end+1} = struct('left', build_state_frame_source(view1_results, idx_a), ... %#ok<AGROW>
			'right', build_state_frame_source(view2_results, idx_a), 'label', ['pair_' num2str(i) '_A']); %#ok<AGROW>
		sample_pairs{end+1} = struct('left', build_state_frame_source(view1_results, idx_b), ... %#ok<AGROW>
			'right', build_state_frame_source(view2_results, idx_b), 'label', ['pair_' num2str(i) '_B']); %#ok<AGROW>
	end
	return
end

	left_samples = normalize_view_samples(view1_results);
	right_samples = normalize_view_samples(view2_results);
	pair_count = min(numel(left_samples), numel(right_samples));
	for i = 1:pair_count
		sample_pairs{end+1} = struct('left', left_samples{i}, 'right', right_samples{i}, ... %#ok<AGROW>
			'label', ['sample_' num2str(i)]); %#ok<AGROW>
	end
end

function tf = is_pair_summary(value)
tf = isstruct(value) && ~isempty(value) && ...
	(any(isfield(value, {'view1', 'view2'})) || any(isfield(value, {'view1_a', 'view2_a'})));
end

function tf = is_view_state(value)
tf = isstruct(value) && isscalar(value) && isfield(value, 'filepath') && isfield(value, 'framenum') && isfield(value, 'framepart');
end

function source = build_state_frame_source(view_state, index)
source = struct();
source.filepath = view_state.filepath{index};
source.framenum = resolve_state_entry(view_state.framenum, index, 1);
source.framepart = resolve_state_entry(view_state.framepart, index, []);
end

function value = resolve_state_entry(array_value, index, default_value)
value = default_value;
if isempty(array_value)
	return
end
if iscell(array_value)
	if numel(array_value) >= index
		value = array_value{index};
	end
	return
end
if size(array_value, 1) >= index
	value = array_value(index, :);
end
end

function samples = normalize_view_samples(view_data)
samples = {};
if isempty(view_data)
	return
end
if isnumeric(view_data) || islogical(view_data)
	samples = {view_data};
	return
end
if ischar(view_data) || (isstring(view_data) && isscalar(view_data))
	samples = {char(view_data)};
	return
end
if isstring(view_data)
	view_data = cellstr(view_data(:));
end
if iscell(view_data)
	samples = view_data(:);
	return
end
if isstruct(view_data)
	if isscalar(view_data) && isfield(view_data, 'image')
		samples = {view_data};
		return
	end
	for i = 1:numel(view_data)
		if isfield(view_data(i), 'image')
			samples{end+1} = view_data(i); %#ok<AGROW>
		elseif isfield(view_data(i), 'filepath')
			samples{end+1} = view_data(i); %#ok<AGROW>
		elseif isfield(view_data(i), 'file')
			samples{end+1} = view_data(i).file; %#ok<AGROW>
		elseif isfield(view_data(i), 'filename')
			samples{end+1} = view_data(i).filename; %#ok<AGROW>
		end
	end
end
end

function [reference_size, info] = determine_reference_geometry(sample_pair, camera1_state, camera2_state)
left_img = prepare_particle_image(sample_pair.left, camera1_state);
right_img = prepare_particle_image(sample_pair.right, camera2_state);
[left_img, right_img, crop_info] = crop_to_common_area(left_img, right_img);
reference_size = size(left_img);
reference_size = reference_size(1:2);
info = struct();
info.label = sample_pair.label;
info.crop = crop_info;
info.image_size = reference_size;
end

function grid = build_interrogation_grid(image_size, window_size, step, search_radius)
half_before = floor((window_size - 1) / 2);
half_after = window_size - half_before - 1;

min_x = half_before + 1 + search_radius(2);
max_x = image_size(2) - half_after - search_radius(2);
min_y = half_before + 1 + search_radius(1);
max_y = image_size(1) - half_after - search_radius(1);

if min_x > max_x || min_y > max_y
	[grid.x, grid.y] = deal([]);
	grid.window_size = window_size;
	grid.step = step;
	grid.search_radius = search_radius;
	return
end

x_centers = min_x:step:max_x;
y_centers = min_y:step:max_y;
[X, Y] = meshgrid(x_centers, y_centers);

grid = struct();
grid.x = X;
grid.y = Y;
grid.window_size = window_size;
grid.step = step;
grid.search_radius = search_radius;
grid.x_centers = x_centers;
grid.y_centers = y_centers;
end

function field = measure_disparity_field(sample_pairs, camera1_state, camera2_state, grid, params, prior_model)
num_rows = size(grid.y, 1);
num_cols = size(grid.x, 2);
offsets_y = -params.search_radius(1):params.search_radius(1);
offsets_x = -params.search_radius(2):params.search_radius(2);
correlation_sums = zeros(num_rows, num_cols, numel(offsets_y), numel(offsets_x), 'single');

for sample_index = 1:numel(sample_pairs)
		left_img = prepare_particle_image(sample_pairs{sample_index}.left, camera1_state);
		right_img = prepare_particle_image(sample_pairs{sample_index}.right, camera2_state);
		[left_img, right_img] = crop_to_common_area(left_img, right_img);

		for row = 1:num_rows
			for col = 1:num_cols
				center_x = grid.x(row, col);
				center_y = grid.y(row, col);
				predicted_shift = predict_disparity(prior_model, center_x, center_y);
				base_shift = round(predicted_shift);
				corr_map = local_correlation_map(left_img, right_img, center_x, center_y, ...
					grid.window_size, offsets_y, offsets_x, base_shift, params.min_patch_std);
				correlation_sums(row, col, :, :) = correlation_sums(row, col, :, :) + ...
					reshape(single(corr_map), [1 1 size(corr_map, 1) size(corr_map, 2)]);
			end
		end
end

disparity_u = nan(num_rows, num_cols);
disparity_v = nan(num_rows, num_cols);
peak_corr = nan(num_rows, num_cols);
valid = false(num_rows, num_cols);
raw_peak_x = nan(num_rows, num_cols);
raw_peak_y = nan(num_rows, num_cols);

for row = 1:num_rows
	for col = 1:num_cols
		center_x = grid.x(row, col);
		center_y = grid.y(row, col);
		predicted_shift = predict_disparity(prior_model, center_x, center_y);
		base_shift = round(predicted_shift);
		corr_map = squeeze(double(correlation_sums(row, col, :, :)));
		[peak_value, peak_row, peak_col] = find_map_peak(corr_map);
		[sub_y, sub_x] = subpixel_peak_offset(corr_map, peak_row, peak_col);
		residual_shift_x = offsets_x(peak_col) + sub_x;
		residual_shift_y = offsets_y(peak_row) + sub_y;
		total_shift_x = base_shift(1) + residual_shift_x;
		total_shift_y = base_shift(2) + residual_shift_y;

		raw_peak_x(row, col) = peak_col;
		raw_peak_y(row, col) = peak_row;
		peak_corr(row, col) = peak_value / max(1, numel(sample_pairs));
		if isfinite(peak_corr(row, col)) && peak_corr(row, col) >= params.min_correlation
			valid(row, col) = true;
			disparity_u(row, col) = total_shift_x;
			disparity_v(row, col) = total_shift_y;
		end
	end
end

field = struct();
field.x = grid.x;
field.y = grid.y;
field.u = disparity_u;
field.v = disparity_v;
field.valid = valid;
field.correlation = peak_corr;
field.raw_peak_x = raw_peak_x;
field.raw_peak_y = raw_peak_y;
field.window_size = grid.window_size;
field.step = grid.step;
field.search_radius = grid.search_radius;
field.num_samples = numel(sample_pairs);
end

function corr_map = local_correlation_map(left_img, right_img, center_x, center_y, window_size, offsets_y, offsets_x, base_shift, min_patch_std)
half_before = floor((window_size - 1) / 2);
half_after = window_size - half_before - 1;
y_range = (center_y-half_before):(center_y+half_after);
x_range = (center_x-half_before):(center_x+half_after);
template = left_img(y_range, x_range);
template = double(template);
if std(template(:)) < min_patch_std
	corr_map = zeros(numel(offsets_y), numel(offsets_x));
	return
end

corr_map = zeros(numel(offsets_y), numel(offsets_x));
for iy = 1:numel(offsets_y)
	for ix = 1:numel(offsets_x)
		shift_y = base_shift(2) + offsets_y(iy);
		shift_x = base_shift(1) + offsets_x(ix);
		y_idx = y_range + shift_y;
		x_idx = x_range + shift_x;
		if y_idx(1) < 1 || x_idx(1) < 1 || y_idx(end) > size(right_img,1) || x_idx(end) > size(right_img,2)
			corr_map(iy, ix) = -Inf;
			continue
		end
		search_patch = right_img(y_idx, x_idx);
		corr_map(iy, ix) = normalized_patch_correlation(template, search_patch);
	end
end
end

function value = normalized_patch_correlation(template, search_patch)
template = double(template);
search_patch = double(search_patch);
template = template - mean(template(:));
search_patch = search_patch - mean(search_patch(:));
denominator = sqrt(sum(template(:).^2) * sum(search_patch(:).^2));
if denominator <= eps
	value = -Inf;
else
	value = sum(template(:) .* search_patch(:)) / denominator;
end
end

function [peak_value, peak_row, peak_col] = find_map_peak(corr_map)
[peak_value, linear_index] = max(corr_map(:));
[peak_row, peak_col] = ind2sub(size(corr_map), linear_index);
end

function [sub_y, sub_x] = subpixel_peak_offset(corr_map, peak_row, peak_col)
sub_y = 0;
sub_x = 0;
if peak_row > 1 && peak_row < size(corr_map, 1)
	sub_y = quadratic_peak(corr_map(peak_row-1, peak_col), corr_map(peak_row, peak_col), corr_map(peak_row+1, peak_col));
end
if peak_col > 1 && peak_col < size(corr_map, 2)
	sub_x = quadratic_peak(corr_map(peak_row, peak_col-1), corr_map(peak_row, peak_col), corr_map(peak_row, peak_col+1));
end
end

function offset = quadratic_peak(value_minus, value_center, value_plus)
denominator = value_minus - 2*value_center + value_plus;
if ~isfinite(denominator) || abs(denominator) <= eps
	offset = 0;
else
	offset = 0.5 * (value_minus - value_plus) / denominator;
		if ~isfinite(offset) || abs(offset) > 1
			offset = 0;
		end
end
end

function predicted_shift = predict_disparity(model, x, y)
predicted_shift = [0 0];
if isempty(model) || ~isstruct(model) || ~isfield(model, 'coeff_x')
	return
end
[basis, ~] = model_basis(x, y, model.fit_type);
predicted_shift(1) = basis * model.coeff_x(:);
predicted_shift(2) = basis * model.coeff_y(:);
end

function model = fit_disparity_model(field, fit_type)
x = field.x(field.valid);
y = field.y(field.valid);
u = field.u(field.valid);
v = field.v(field.valid);
weights = field.correlation(field.valid);

	if isempty(weights)
		weights = ones(size(x));
	end
	weights(~isfinite(weights) | weights <= 0) = min_positive_weight(weights);
	[basis, basis_names] = model_basis(x, y, fit_type);

	coeff_x = weighted_least_squares(basis, u, weights);
	coeff_y = weighted_least_squares(basis, v, weights);

	% One light outlier-rejection pass improves stability on weak particle windows.
	pred_u = basis * coeff_x;
	pred_v = basis * coeff_y;
	residual = hypot(u - pred_u, v - pred_v);
	threshold = median_omitnan(residual) + 3 * mad_compat(residual);
	inliers = residual <= threshold | ~isfinite(threshold);
	if nnz(inliers) >= size(basis, 2)
		coeff_x = weighted_least_squares(basis(inliers, :), u(inliers), weights(inliers));
		coeff_y = weighted_least_squares(basis(inliers, :), v(inliers), weights(inliers));
	else
		inliers = true(size(residual));
	end

	model = struct();
	model.fit_type = fit_type;
	model.basis = basis_names;
	model.coeff_x = coeff_x(:);
	model.coeff_y = coeff_y(:);
	model.num_points = numel(x);
	model.num_inliers = nnz(inliers);
	model.weights_mean = mean_omitnan(weights);
	model.last_updated = now;
end

function [basis, basis_names] = model_basis(x, y, fit_type)
x = x(:);
y = y(:);
switch lower(fit_type)
	case {'translation', 'constant'}
		basis = ones(numel(x), 1);
		basis_names = {'1'};
	case {'quadratic', 'poly2'}
		basis = [ones(numel(x),1) x y x.^2 x.*y y.^2];
		basis_names = {'1', 'x', 'y', 'x2', 'xy', 'y2'};
	otherwise
		basis = [ones(numel(x),1) x y];
		basis_names = {'1', 'x', 'y'};
end
end

function coeff = weighted_least_squares(basis, values, weights)
weights = sqrt(weights(:));
Aw = basis .* weights;
bw = values(:) .* weights;
if rank(Aw) < min(size(Aw))
	coeff = pinv(Aw) * bw;
else
	coeff = Aw \ bw;
end
end

function minimum = min_positive_weight(weights)
positive_weights = weights(isfinite(weights) & weights > 0);
if isempty(positive_weights)
	minimum = 1;
else
	minimum = min(positive_weights);
end
end

function value = mad_compat(samples)
samples = samples(isfinite(samples));
if isempty(samples)
	value = 0;
	return
end
center = median(samples);
value = median(abs(samples - center));
end

function models = build_midpoint_models(field, total_model, fit_type)
x_left = field.x(field.valid);
y_left = field.y(field.valid);
u = field.u(field.valid);
v = field.v(field.valid);
x_right = x_left + u;
y_right = y_left + v;
weights = field.correlation(field.valid);
weights(~isfinite(weights) | weights <= 0) = min_positive_weight(weights);

	left_model = fit_weighted_target_model(x_left, y_left, 0.5 * u, 0.5 * v, weights, fit_type);
	right_model = fit_weighted_target_model(x_right, y_right, -0.5 * u, -0.5 * v, weights, fit_type);

	models = struct();
	models.reference_plane = 'midpoint';
	models.total_disparity = total_model;
	models.left_to_midpoint = left_model;
	models.right_to_midpoint = right_model;
end

function model = fit_weighted_target_model(x, y, u, v, weights, fit_type)
[basis, basis_names] = model_basis(x, y, fit_type);
model = struct();
model.fit_type = fit_type;
model.basis = basis_names;
model.coeff_x = weighted_least_squares(basis, u, weights);
model.coeff_y = weighted_least_squares(basis, v, weights);
model.last_updated = now;
end

function statistics = compute_field_statistics(field, models)
x_left = field.x(field.valid);
y_left = field.y(field.valid);
u = field.u(field.valid);
v = field.v(field.valid);
x_right = x_left + u;
y_right = y_left + v;

	left_corr = evaluate_model(models.left_to_midpoint, x_left, y_left);
	right_corr = evaluate_model(models.right_to_midpoint, x_right, y_right);
	corrected_residual = hypot((x_right + right_corr(:,1)) - (x_left + left_corr(:,1)), ...
		(y_right + right_corr(:,2)) - (y_left + left_corr(:,2)));

	magnitude = hypot(u, v);
	statistics = struct();
	statistics.num_valid_vectors = numel(magnitude);
	statistics.mean_disparity_px = mean_omitnan(magnitude);
	statistics.rms_disparity_px = sqrt(mean_omitnan(magnitude.^2));
	statistics.mean_u_px = mean_omitnan(u);
	statistics.mean_v_px = mean_omitnan(v);
	statistics.rms_corrected_residual_px = sqrt(mean_omitnan(corrected_residual.^2));
	statistics.max_corrected_residual_px = max_omitnan(corrected_residual);
end

function correction = evaluate_model(model, x, y)
[basis, ~] = model_basis(x, y, model.fit_type);
correction = [basis * model.coeff_x(:), basis * model.coeff_y(:)];
end

function updated_calibration = update_calibration_with_disparity(stereo_calibration, models, statistics, params)
updated_calibration = stereo_calibration;
updated_calibration.stereo.status = 'self_calibrated';
updated_calibration.stereo.disparity_model = struct( ...
	'method', 'particle-image-self-calibration', ...
	'reference', 'Wieneke-2005-inspired planar residual fit', ...
	'fit_type', params.model, ...
	'grid_window_size', params.window_size, ...
	'grid_step', params.step, ...
	'search_radius', params.search_radius, ...
	'models', models, ...
	'statistics', statistics, ...
	'last_updated', now);
updated_calibration.stereo.notes = unique([updated_calibration.stereo.notes(:); ...
	{['Self-calibration fit type: ' params.model]}; ...
	{['Valid disparity vectors: ' num2str(statistics.num_valid_vectors)]}], 'stable');
updated_calibration = stereo.update_coupled_calibration_status(updated_calibration);
end

function entry = summarize_iteration(field, prior_model, iteration)
entry = struct();
entry.iteration = iteration;
entry.num_valid_vectors = nnz(field.valid);
entry.mean_correlation = mean_omitnan(field.correlation(field.valid));
	entry.rms_disparity = sqrt(mean_omitnan(hypot(field.u(field.valid), field.v(field.valid)).^2));
	entry.used_prior_model = ~isempty(prior_model);
end

function image = prepare_particle_image(source, camera_state)
image = read_particle_image(source);
image = apply_camera_state_corrections(image, camera_state);
image = ensure_grayscale_double(image);
end

function image = read_particle_image(source)
if isnumeric(source) || islogical(source)
	image = source;
	return
end
if ischar(source) || (isstring(source) && isscalar(source))
	image = feval('import.imread_wrapper', char(source), 1, []);
	return
end
if isstruct(source)
	if isfield(source, 'image') && ~isempty(source.image)
		image = source.image;
		return
	end
	if isfield(source, 'filepath') && ~isempty(source.filepath)
		frame_number = get_struct_field(source, 'framenum', 1);
		frame_part = get_struct_field(source, 'framepart', []);
		image = feval('import.imread_wrapper', source.filepath, frame_number, frame_part);
		return
	end
	if isfield(source, 'file') && ~isempty(source.file)
		image = feval('import.imread_wrapper', source.file, 1, []);
		return
	end
	if isfield(source, 'filename') && ~isempty(source.filename)
		image = feval('import.imread_wrapper', source.filename, 1, []);
		return
	end
end

error('PIVlab:StereoUnsupportedImageSource', ...
	'Unsupported particle-image source type for stereo self-calibration.');
end

function value = get_struct_field(source, field_name, default_value)
value = default_value;
if isstruct(source) && isfield(source, field_name) && ~isempty(source.(field_name))
	value = source.(field_name);
end
end

function image = apply_camera_state_corrections(image, camera_state)
use_calibration = isfield(camera_state, 'cam_use_calibration') && logical(camera_state.cam_use_calibration) && ...
	isfield(camera_state, 'cameraParams') && ~isempty(camera_state.cameraParams);
use_rectification = isfield(camera_state, 'cam_use_rectification') && logical(camera_state.cam_use_rectification) && ...
	isfield(camera_state, 'rectification_tform') && ~isempty(camera_state.rectification_tform);

if use_calibration && exist('undistortImage', 'file') > 0
	image = undistortImage(image, camera_state.cameraParams, 'cubic', 'OutputView', 'same');
end
if use_rectification && exist('imwarp', 'file') > 0
	image = imwarp(image, camera_state.rectification_tform);
end
end

function image = ensure_grayscale_double(image)
if ndims(image) == 3
	if size(image, 3) == 3 && exist('rgb2gray', 'file') > 0
		image = rgb2gray(image);
	else
		image = mean(double(image), 3);
	end
end
image = double(image);
if ~isempty(image)
	image = image - min(image(:));
	maximum = max(image(:));
	if maximum > 0
		image = image / maximum;
	end
end
end

function [left_img, right_img, crop_info] = crop_to_common_area(left_img, right_img)
target_rows = min(size(left_img, 1), size(right_img, 1));
target_cols = min(size(left_img, 2), size(right_img, 2));
left_img = center_crop(left_img, [target_rows target_cols]);
right_img = center_crop(right_img, [target_rows target_cols]);
crop_info = struct('rows', target_rows, 'cols', target_cols);
end

function image = center_crop(image, target_size)
start_row = floor((size(image,1) - target_size(1)) / 2) + 1;
start_col = floor((size(image,2) - target_size(2)) / 2) + 1;
image = image(start_row:(start_row+target_size(1)-1), start_col:(start_col+target_size(2)-1), :);
end

function value = mean_omitnan(samples)
samples = samples(isfinite(samples));
if isempty(samples)
	value = NaN;
else
	value = mean(samples);
end
end

function value = median_omitnan(samples)
samples = samples(isfinite(samples));
if isempty(samples)
	value = NaN;
else
	value = median(samples);
end
end

function value = max_omitnan(samples)
samples = samples(isfinite(samples));
if isempty(samples)
	value = NaN;
else
	value = max(samples);
end
end
