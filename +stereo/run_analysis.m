function [results, session] = run_analysis(view1_files, view2_files, piv_settings, preproc_settings, stereo_settings)
%RUN_ANALYSIS Top-level Stereo-PIV orchestration entry point.
% view1_files/view2_files are paired image lists for camera 1 and camera 2.
% piv_settings and preproc_settings reuse the current 2D PIVlab contracts.

if nargin < 5 || isempty(stereo_settings)
	stereo_settings = stereo.default_settings();
end
if nargin < 4
	preproc_settings = [];
end
if nargin < 3
	piv_settings = [];
end
if nargin < 2
	view2_files = {};
end
if nargin < 1
	view1_files = {};
end

[is_valid, issues] = stereo.validate_settings(stereo_settings);
if ~is_valid
	error('PIVlab:StereoInvalidSettings', '%s', strjoin(issues, newline));
end

session = stereo.default_session();
session.settings = stereo_settings;
session.inputs.view1_files = view1_files;
session.inputs.view2_files = view2_files;
session.inputs.pairs = stereo.pair_image_lists(view1_files, view2_files, stereo_settings.pairing);
session.twod.piv_settings = piv_settings;
session.twod.preproc_settings = preproc_settings;
session.status = 'scaffold_ready';

results = struct();
results.status = 'not_implemented';
results.message = ['TODO: implement stereo.run_dual_view_2d_piv, ' ...
	'stereo.estimate_volume_calibration, stereo.self_calibrate_disparity, ' ...
	'and stereo.reconstruct_velocity in this orchestration function.'];
results.pairs = session.inputs.pairs;
results.next_steps = { ...
	'Run 2D PIV for both rectified camera views.'; ...
	'Load or estimate a stereo calibration / mapping model.'; ...
	'Apply disparity self-calibration if enabled.'; ...
	'Reconstruct world-space u, v, w on the target plane.'};
end
