function export_results(output_file, world_results, stereo_session)
%EXPORT_RESULTS Save reconstructed Stereo-PIV results to a MAT file.

if nargin < 3
	stereo_session = [];
end
if nargin < 2 || isempty(world_results)
	world_results = struct('status', 'empty');
end

save(output_file, 'world_results', 'stereo_session');
end
