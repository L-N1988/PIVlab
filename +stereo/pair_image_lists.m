function pairs = pair_image_lists(view1_files, view2_files, pairing_settings)
%PAIR_IMAGE_LISTS Pair camera-1 and camera-2 file lists into a stereo sequence.

if nargin < 3 || isempty(pairing_settings)
	pairing_settings = stereo.default_settings();
	pairing_settings = pairing_settings.pairing;
end

view1_files = normalize_file_list(view1_files);
view2_files = normalize_file_list(view2_files);

if pairing_settings.require_equal_counts && numel(view1_files) ~= numel(view2_files)
	error('PIVlab:StereoPairingMismatch', ...
		'Camera 1 and camera 2 must contain the same number of files.');
end

pair_count = min(numel(view1_files), numel(view2_files));
if pair_count == 0
	pairs = struct('index', {}, 'view1', {}, 'view2', {});
	return
end

pairs = repmat(struct('index', 0, 'view1', '', 'view2', ''), pair_count, 1);
for i = 1:pair_count
	pairs(i).index = pairing_settings.start_index + i - 1;
	pairs(i).view1 = view1_files{i};
	pairs(i).view2 = view2_files{i};
end
end

function files = normalize_file_list(files)
if nargin == 0 || isempty(files)
	files = {};
	return
end

if ischar(files)
	files = {files};
elseif isstring(files)
	files = cellstr(files(:));
elseif iscell(files)
	files = files(:);
else
	error('PIVlab:StereoInvalidFileList', ...
		'File list must be char, string, or cell array.');
end
end
