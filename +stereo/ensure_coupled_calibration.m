function coupled = ensure_coupled_calibration()
%ENSURE_COUPLED_CALIBRATION Ensure a stereo calibration object exists in appdata.

coupled = gui.retr('stereo_calibration');
if isempty(coupled) || ~isstruct(coupled) || ~isfield(coupled, 'cameras')
	coupled = stereo.default_coupled_calibration();
	gui.put('stereo_calibration', coupled);
end

stereo_session = gui.retr('stereo_session');
if ~isempty(stereo_session) && isfield(stereo_session, 'calibration')
	stereo_session.calibration.stereo = coupled;
	stereo_session.calibration.coupled = coupled;
	gui.put('stereo_session', stereo_session);
end
end
