function settings = default_settings()
%DEFAULT_SETTINGS Create the default Stereo-PIV configuration contract.

settings = struct();
settings.enabled = false;
settings.mode = '2D3C';

settings.pairing = struct();
settings.pairing.strategy = 'index';
settings.pairing.require_equal_counts = true;
settings.pairing.start_index = 1;

settings.views = repmat(struct(), 1, 2);
settings.views(1).name = 'camera1';
settings.views(1).tag = 'cam1';
settings.views(1).image_pattern = '';
settings.views(1).calibration_file = '';
settings.views(1).rectification_file = '';

settings.views(2).name = 'camera2';
settings.views(2).tag = 'cam2';
settings.views(2).image_pattern = '';
settings.views(2).calibration_file = '';
settings.views(2).rectification_file = '';

settings.analysis = struct();
settings.analysis.reuse_2d_pipeline = true;
settings.analysis.shared_piv_settings = true;

settings.calibration = struct();
settings.calibration.type = 'volume';
settings.calibration.source = 'file';
settings.calibration.file = '';
settings.calibration.target = 'charuco-plane-stack';

settings.disparity = struct();
settings.disparity.enable = false;
settings.disparity.model = 'affine';
settings.disparity.max_iterations = 2;

settings.reconstruction = struct();
settings.reconstruction.method = 'pinhole-least-squares';
settings.reconstruction.output_plane_z_mm = 0;
settings.reconstruction.velocity_unit = 'mm/s';

settings.validation = struct();
settings.validation.enable = true;
settings.validation.max_condition_number = inf;

settings.export = struct();
settings.export.output_dir = '';
settings.export.save_session = true;
settings.export.save_mat = true;
end
