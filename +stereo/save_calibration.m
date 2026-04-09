function save_calibration(calibration_file, stereo_calibration)
%SAVE_CALIBRATION Save a Stereo-PIV calibration struct to disk.

if nargin < 2 || isempty(stereo_calibration)
	stereo_calibration = struct();
end
if ~isfield(stereo_calibration, 'schema_version')
	stereo_calibration.schema_version = 1;
end

save(calibration_file, 'stereo_calibration');
end
