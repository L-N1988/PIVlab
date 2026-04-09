function world_results = reconstruct_velocity(view1_results, view2_results, stereo_calibration, disparity_state, stereo_settings)
%RECONSTRUCT_VELOCITY Placeholder for 2D3C world-space reconstruction.

if nargin < 5 || isempty(stereo_settings)
	stereo_settings = stereo.default_settings();
end
if nargin < 4
	disparity_state = [];
end
if nargin < 3
	stereo_calibration = [];
end
if nargin < 2
	view2_results = [];
end
if nargin < 1
	view1_results = [];
end

world_results = struct();
world_results.status = 'not_implemented';
world_results.method = stereo_settings.reconstruction.method;
world_results.velocity_unit = stereo_settings.reconstruction.velocity_unit;
world_results.message = ['TODO: triangulate or ray-intersect matched left/right vectors ' ...
	'to produce world-space u, v, w fields.'];
world_results.input_summary = struct( ...
	'has_view1_results', ~isempty(view1_results), ...
	'has_view2_results', ~isempty(view2_results), ...
	'has_calibration', ~isempty(stereo_calibration), ...
	'has_disparity_state', ~isempty(disparity_state));
end
