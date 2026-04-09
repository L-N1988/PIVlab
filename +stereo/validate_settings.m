function [is_valid, issues] = validate_settings(settings)
%VALIDATE_SETTINGS Validate a Stereo-PIV settings struct.

issues = {};

if nargin == 0 || isempty(settings)
	settings = stereo.default_settings();
end

required_fields = {'enabled', 'pairing', 'views', 'calibration', 'disparity', 'reconstruction', 'validation', 'export'};
for i = 1:numel(required_fields)
	if ~isfield(settings, required_fields{i})
		issues{end+1} = ['Missing field: settings.' required_fields{i}]; %#ok<AGROW>
	end
end

if isfield(settings, 'views')
	if numel(settings.views) ~= 2
		issues{end+1} = 'settings.views must contain exactly two camera views.'; %#ok<AGROW>
	end
end

if isfield(settings, 'pairing') && isfield(settings.pairing, 'strategy')
	valid_pairing_strategies = {'index', 'filename'};
	if ~any(strcmpi(settings.pairing.strategy, valid_pairing_strategies))
		issues{end+1} = 'settings.pairing.strategy must be ''index'' or ''filename''.'; %#ok<AGROW>
	end
end

if isfield(settings, 'reconstruction') && isfield(settings.reconstruction, 'method')
	if isempty(settings.reconstruction.method)
		issues{end+1} = 'settings.reconstruction.method must not be empty.'; %#ok<AGROW>
	end
end

is_valid = isempty(issues);
end
