function mapping = default_stereo_mapping()
%DEFAULT_STEREO_MAPPING Create default stereo extrinsics mapping struct.
%
% Fields populated by estimate_volume_calibration.

mapping = struct();
mapping.status = 'not_estimated';
mapping.method = '';
mapping.R = [];
mapping.t = [];
mapping.cameraMatrix1 = [];
mapping.cameraMatrix2 = [];
mapping.stereoParams = [];
mapping.meanReprojError_px = [];
mapping.worldPoints = [];
mapping.imagePoints1 = [];
mapping.imagePoints2 = [];
mapping.timestamp = [];
end
