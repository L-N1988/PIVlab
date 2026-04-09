% Example scaffold for a future Stereo-PIV command-line workflow.
% This script currently prepares the contracts and returns a TODO result.
clc; clear

addpath(fileparts(fileparts(which('PIVlab_stereo_commandline.m'))));

stereo_settings = stereo.default_settings();
stereo_settings.enabled = true;
stereo_settings.disparity.enable = true;

% Reuse the existing 2D settings contracts from PIVlab_commandline.m.
piv_settings = [];
preproc_settings = [];

% TODO: replace these with real paired image lists from camera 1 and camera 2.
view1_files = { ...
	'cam1_frame_0001_a.tif'; ...
	'cam1_frame_0002_a.tif'};
view2_files = { ...
	'cam2_frame_0001_a.tif'; ...
	'cam2_frame_0002_a.tif'};

[results, stereo_session] = stereo.run_analysis( ...
	view1_files, view2_files, piv_settings, preproc_settings, stereo_settings);

disp(results.status)
disp(results.message)
disp(['Prepared stereo pairs: ' num2str(numel(stereo_session.inputs.pairs))])
