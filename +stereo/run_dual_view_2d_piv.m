function view_results = run_dual_view_2d_piv(image_pairs, piv_settings, preproc_settings, nr_of_cores)
%RUN_DUAL_VIEW_2D_PIV Placeholder wrapper for per-view 2D PIV processing.

if nargin < 4 || isempty(nr_of_cores)
	nr_of_cores = 1;
end
if nargin < 3
	preproc_settings = [];
end
if nargin < 2
	piv_settings = [];
end
if nargin < 1
	image_pairs = struct('index', {}, 'view1', {}, 'view2', {});
end

view_results = struct();
view_results.status = 'not_implemented';
view_results.num_pairs = numel(image_pairs);
view_results.nr_of_cores = nr_of_cores;
view_results.piv_settings = piv_settings;
view_results.preproc_settings = preproc_settings;
view_results.message = ['TODO: call the existing 2D pipeline once per camera view, ' ...
	'using shared or per-view preprocessing and interrogation settings.'];
end
