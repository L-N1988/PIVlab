function labels = prefix_filename_labels(labels_in, camera_index)
%PREFIX_FILENAME_LABELS Prefix display labels with the stereo camera index.

if nargin < 2 || isempty(camera_index)
	camera_index = 1;
end

if isempty(labels_in)
	labels = labels_in;
	return
end

labels = cell(size(labels_in));
prefix = ['C' num2str(camera_index) ' | '];
for i = 1:numel(labels_in)
	labels{i,1} = [prefix labels_in{i}];
end
end
