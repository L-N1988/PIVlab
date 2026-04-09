function [avg_vert, avg_horiz] = cam_meanCheckerboardSpacing(imagePoints)
%CAM_MEANCHECKERBOARDSPACING Estimate checker spacing directly in pixels.

if nargin == 0 || isempty(imagePoints) || size(imagePoints, 1) < 2
	avg_vert = NaN;
	avg_horiz = NaN;
	return
end

delta = diff(imagePoints, 1, 1);
distances = sqrt(sum(delta.^2, 2));
distances = distances(isfinite(distances) & distances > 0);

if isempty(distances)
	avg_vert = NaN;
	avg_horiz = NaN;
	return
end

threshold = prctile(distances, 60);
adjacent = distances(distances <= threshold);
if isempty(adjacent)
	adjacent = distances;
end

adjacent = adjacent(isfinite(adjacent));
avg_vert = mean(adjacent);
avg_horiz = avg_vert;
end
