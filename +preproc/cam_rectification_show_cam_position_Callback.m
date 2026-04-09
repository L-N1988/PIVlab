function cam_rectification_show_cam_position_Callback (~,~,~)
handles=gui.gethand;
cameraParams=gui.retr('cameraParams');
target = preproc.cam_get_target_definition(handles);

if isempty(cameraParams)
	gui.custom_msgbox('error',getappdata(0,'hgui'),'Error','"Estimate cam parameters" or "Load parameters" needs to be performed first','modal');
	handles.calib_userectification.Value = 0;
	return
end

switch target.type
	case {'charuco', 'checkerboard'}
		show_planar_target_pose(cameraParams, target, handles);
	case 'custom3d'
		show_custom_plate_pose(cameraParams, target);
	otherwise
		gui.custom_msgbox('error',getappdata(0,'hgui'),'Error','Unsupported calibration target type.','modal');
end
end

function show_planar_target_pose(cameraParams, target, handles)
cam_selected_rectification_image = gui.retr('cam_selected_rectification_image');
if isempty(cam_selected_rectification_image)
	gui.custom_msgbox('error',getappdata(0,'hgui'),'Error','No target image selected.','modal');
	return
end

gui.toolsavailable(0,'Detecting markers...');drawnow;
[imagePoints1, target] = preproc.cam_detect_target_points(cam_selected_rectification_image, target, 'rectification');
if isempty(imagePoints1)
	gui.toolsavailable(1)
	gui.custom_msgbox('error',getappdata(0,'hgui'),'Error',['No ' target.name ' points detected.'],'modal');
	return
end

switch target.type
	case 'charuco'
		worldPoints = patternWorldPoints('charuco-board',target.patternDims,target.checkerSize);
	case 'checkerboard'
		worldPoints = patternWorldPoints('checkerboard',target.patternDims,target.checkerSize);
end

worldPoints(isnan(imagePoints1))=NaN;
imagePoints1 = rmmissing(imagePoints1);
worldPoints = rmmissing(worldPoints);

if target.patternDims(1) > target.patternDims(2)
	worldPoints = worldPoints(:, [2 1]);
	worldPoints(:,2) = -worldPoints(:,2);
end
gui.toolsavailable(1)

camExtrinsics1 = estimateExtrinsics(imagePoints1,worldPoints,cameraParams.Intrinsics);
[labelText, absPose1] = build_camera_pose_label(camExtrinsics1, 'Cam1');
preproc.cam_plot_camera_pose([worldPoints zeros(size(worldPoints,1),1)], absPose1, labelText);
end

function show_custom_plate_pose(cameraParams, target)
plate = target.customPlate;
if isempty(plate) || ~isfield(plate, 'worldPoints') || isempty(plate.worldPoints)
	gui.custom_msgbox('error',getappdata(0,'hgui'),'Error','No custom 3D plate definition is loaded.','modal');
	return
end
if isempty(cameraParams.RotationVectors) || isempty(cameraParams.TranslationVectors)
	gui.custom_msgbox('error',getappdata(0,'hgui'),'Error','Camera pose is not available in the loaded camera parameters.','modal');
	return
end

camExtrinsics1 = rigidtform3d(rotationVectorToMatrix(cameraParams.RotationVectors(1,:)), cameraParams.TranslationVectors(1,:));
[labelText, absPose1] = build_camera_pose_label(camExtrinsics1, 'Cam1');
preproc.cam_plot_camera_pose(plate.worldPoints, absPose1, labelText);
end

function [labelText, absPose1] = build_camera_pose_label(camExtrinsics1, labelPrefix)
R1=camExtrinsics1.R;
z_cam = [0; 0; 1];
z_world1 = R1 * z_cam;
alpha1 = atan2(z_world1(1), z_world1(3));
beta1  = atan2(z_world1(2), z_world1(3));
alpha_deg = rad2deg(alpha1);
beta_deg  = rad2deg(beta1);

R_wc = R1.';
x_cam_w = R_wc(:,1);
x_proj = x_cam_w;
x_proj(3) = 0;
x_proj = x_proj / norm(x_proj);
roll = atan2(x_proj(2), x_proj(1));
roll_deg = rad2deg(roll);
orientation_message=['Yaw: ' num2str(round(alpha_deg)) ' ; Pitch: ' num2str(round(beta_deg)) ' ; Roll: ' num2str(round(roll_deg,1))];
labelText = [labelPrefix newline orientation_message];
absPose1 = extr2pose(camExtrinsics1);
end
