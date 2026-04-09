function tests = test_stereo_scaffold
tests = functiontests(localfunctions);
end

function test_default_settings_contract(testCase)
settings = stereo.default_settings();

testCase.verifyTrue(isfield(settings, 'pairing'));
testCase.verifyTrue(isfield(settings, 'views'));
testCase.verifyEqual(numel(settings.views), 2);
testCase.verifyEqual(settings.reconstruction.method, 'pinhole-least-squares');
end

function test_default_session_contract(testCase)
session = stereo.default_session();

testCase.verifyEqual(session.status, 'initialized');
testCase.verifyTrue(isfield(session.inputs, 'pairs'));
testCase.verifyEqual(numel(session.calibration.mono), 2);
end

function test_pair_image_lists_by_index(testCase)
pairs = stereo.pair_image_lists( ...
	{'cam1_0001.tif', 'cam1_0002.tif'}, ...
	{'cam2_0001.tif', 'cam2_0002.tif'});

testCase.verifyEqual(numel(pairs), 2);
testCase.verifyEqual(pairs(2).index, 2);
testCase.verifyEqual(pairs(1).view1, 'cam1_0001.tif');
testCase.verifyEqual(pairs(2).view2, 'cam2_0002.tif');
end

function test_validate_default_settings(testCase)
[is_valid, issues] = stereo.validate_settings(stereo.default_settings());

testCase.verifyTrue(is_valid);
testCase.verifyEmpty(issues);
end
