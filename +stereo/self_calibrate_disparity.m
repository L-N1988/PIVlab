function disparity_state = self_calibrate_disparity(view1_results, view2_results, stereo_calibration, stereo_settings)
%SELF_CALIBRATE_DISPARITY Placeholder for stereo disparity correction.

if nargin < 4 || isempty(stereo_settings)
	stereo_settings = stereo.default_settings();
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

disparity_state = struct();
disparity_state.status = 'not_implemented';
disparity_state.enabled = stereo_settings.disparity.enable;
disparity_state.model = stereo_settings.disparity.model;
disparity_state.message = ['TODO: estimate a disparity correction model from matched left/right ' ...
	'vector fields and update the stereo calibration mapping.'];
disparity_state.input_summary = struct( ...
	'has_view1_results', ~isempty(view1_results), ...
	'has_view2_results', ~isempty(view2_results), ...
	'has_calibration', ~isempty(stereo_calibration));
end
