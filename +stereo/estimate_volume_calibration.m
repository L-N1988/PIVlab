function stereo_calibration = estimate_volume_calibration(target_image_pairs, mono_camera_models, stereo_settings)
%ESTIMATE_VOLUME_CALIBRATION Placeholder for stereo / volume calibration.

if nargin < 3 || isempty(stereo_settings)
	stereo_settings = stereo.default_settings();
end
if nargin < 2
	mono_camera_models = {};
end
if nargin < 1
	target_image_pairs = struct('index', {}, 'view1', {}, 'view2', {});
end

stereo_calibration = struct();
stereo_calibration.schema_version = 1;
stereo_calibration.status = 'not_implemented';
stereo_calibration.type = stereo_settings.calibration.type;
stereo_calibration.message = ['TODO: estimate stereo geometry / mapping from paired ' ...
	'calibration-target images and monocular camera models.'];
stereo_calibration.num_target_pairs = numel(target_image_pairs);
stereo_calibration.num_mono_models = numel(mono_camera_models);
end
