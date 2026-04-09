function [worldPoints, target] = cam_get_rectification_world_points(target, imagePoints, detectionImage, upscale)
%CAM_GET_RECTIFICATION_WORLD_POINTS Build planar rectification coordinates.

if nargin < 4 || isempty(upscale)
	upscale = 1;
end

switch target.type
	case 'charuco'
		[mean_x, mean_y] = preproc.cam_meanCharucoSize(detectionImage, target.markerFamily, target.checkerSize, target.markerSize);
		checker_size_px = (mean_x + mean_y) / 2 * upscale;
		worldPoints = patternWorldPoints('charuco-board', target.patternDims, checker_size_px);
	case 'checkerboard'
		[mean_x, mean_y] = preproc.cam_meanCheckerboardSpacing(imagePoints);
		checker_size_px = (mean_x + mean_y) / 2 * upscale;
		if ~isfinite(checker_size_px) || checker_size_px <= 0
			checker_size_px = target.checkerSize * upscale;
		end
		worldPoints = patternWorldPoints('checkerboard', target.patternDims, checker_size_px);
	otherwise
		error('PIVlab:RectificationRequiresPlanarTarget', ...
			'Image rectification is only supported for planar ChArUco and checkerboard targets.');
end

if target.patternDims(1) > target.patternDims(2)
	worldPoints = worldPoints(:, [2 1]);
	worldPoints(:,2) = -worldPoints(:,2);
end
end
