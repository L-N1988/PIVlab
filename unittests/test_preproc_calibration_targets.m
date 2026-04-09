function tests = test_preproc_calibration_targets
tests = functiontests(localfunctions);
end

function test_load_custom_plate_definition_from_single_struct_mat(testCase)
temp_file = [tempname '.mat'];
cleanup = onCleanup(@() delete_if_exists(temp_file));

plate.name = 'unit-demo';
plate.units = 'mm';
plate.worldPoints = [ ...
	0 0 0; ...
	10 0 0; ...
	0 10 4; ...
	10 10 4];
plate.imagePoints = cat(3, ...
	[12 15; 30 15; 14 33; 32 35], ...
	[13 16; 31 16; 15 34; 33 36]);
plate.imageSize = [480 640];
save(temp_file, 'plate');

loaded = preproc.cam_load_custom_plate_definition(temp_file);

testCase.verifyEqual(loaded.name, 'unit-demo');
testCase.verifyEqual(size(loaded.worldPoints), [4 3]);
testCase.verifyEqual(size(loaded.imagePoints), [4 2 2]);
testCase.verifyTrue(loaded.hasImagePoints);
testCase.verifyFalse(loaded.isPlanar);
testCase.verifyEqual(loaded.imageSize, [480 640]);
end

function test_load_custom_plate_definition_normalizes_planar_points(testCase)
temp_file = [tempname '.mat'];
cleanup = onCleanup(@() delete_if_exists(temp_file)); %#ok<NASGU>

customPlate.worldPoints = [0 0; 20 0; 0 20; 20 20];
customPlate.imagePoints = cat(3, ...
	[11 21; 31 21; 11 41; 31 41], ...
	[12 22; 32 22; 12 42; 32 42]);
customPlate.imageSize = [256 320];
save(temp_file, 'customPlate');

loaded = preproc.cam_load_custom_plate_definition(temp_file);

testCase.verifyEqual(size(loaded.worldPoints), [4 3]);
testCase.verifyEqual(loaded.worldPoints(:,3), zeros(4,1));
testCase.verifyTrue(loaded.isPlanar);
testCase.verifyTrue(loaded.hasImagePoints);
end

function test_load_custom_plate_definition_accepts_planar_csv(testCase)
temp_file = [tempname '.csv'];
cleanup = onCleanup(@() delete_if_exists(temp_file)); %#ok<NASGU>

fid = fopen(temp_file, 'w');
fprintf(fid, 'x,y\n');
fprintf(fid, '0,0\n');
fprintf(fid, '20,0\n');
fprintf(fid, '0,20\n');
fprintf(fid, '20,20\n');
fclose(fid);

loaded = preproc.cam_load_custom_plate_definition(temp_file);

testCase.verifyEqual(size(loaded.worldPoints), [4 3]);
testCase.verifyEqual(loaded.worldPoints(:,3), zeros(4,1));
testCase.verifyTrue(loaded.isPlanar);
testCase.verifyFalse(loaded.hasImagePoints);
end

function test_mean_checkerboard_spacing_returns_adjacent_spacing(testCase)
imagePoints = [ ...
	10 10; ...
	20 10; ...
	30 10; ...
	60 10];

[avg_vert, avg_horiz] = preproc.cam_meanCheckerboardSpacing(imagePoints);

testCase.verifyEqual(avg_vert, 10, 'AbsTol', 1e-9);
testCase.verifyEqual(avg_horiz, 10, 'AbsTol', 1e-9);
end

function delete_if_exists(filename)
if exist(filename, 'file')
	delete(filename);
end
end
