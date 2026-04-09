function cam_rectification_show_rectified_Callback (~,~,~)
handles=gui.gethand;
cameraParams=gui.retr('cameraParams');
cam_selected_rectification_image = gui.retr('cam_selected_rectification_image');
target = preproc.cam_get_target_definition(handles);

if isempty(cameraParams) || isempty(cam_selected_rectification_image)
	gui.custom_msgbox('error',getappdata(0,'hgui'),'Error','Camera calibration not activated or no images for camera rectification loaded.','modal');
	return
end
if strcmp(target.type, 'custom3d')
	gui.custom_msgbox('error',getappdata(0,'hgui'),'Error','Image rectification is only supported for planar ChArUco or checkerboard targets.','modal');
	return
end

[imagePoints, target, detectionImage] = preproc.cam_detect_target_points(cam_selected_rectification_image, target, 'rectification');
if isempty(imagePoints)
	gui.custom_msgbox('error',getappdata(0,'hgui'),'Error',['No ' target.name ' points detected.'],'modal');
	return
end

[worldPoints, target] = preproc.cam_get_rectification_world_points(target, imagePoints, detectionImage, handles.calib_upscale.Value);
worldPoints(isnan(imagePoints))=NaN;
imagePoints = rmmissing(imagePoints);
worldPoints = rmmissing(worldPoints);
undistortedPoints = undistortPoints(imagePoints,cameraParams.Intrinsics);
rectification_tform = fitgeotform2d(undistortedPoints,worldPoints,'projective');

view_raw=handles.calib_viewtype.Value;
if view_raw==1
	view='valid';
elseif view_raw==2
	view='same';
else
	view='full';
end
img_out = preproc.cam_undistort(imread(cam_selected_rectification_image),'cubic',view,1,1,cameraParams,rectification_tform);
imshow(img_out,'Parent',gui.retr('pivlab_axis'))
