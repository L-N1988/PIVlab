function stereo_calibration = load_calibration(calibration_file)
%LOAD_CALIBRATION Load a saved Stereo-PIV calibration struct from disk.

data = load(calibration_file);
if isfield(data, 'stereo_calibration')
	stereo_calibration = data.stereo_calibration;
else
	stereo_calibration = data;
end

if ~isfield(stereo_calibration, 'schema_version')
	stereo_calibration.schema_version = 1;
end
if ~isfield(stereo_calibration, 'status')
	stereo_calibration.status = 'loaded';
end
end
