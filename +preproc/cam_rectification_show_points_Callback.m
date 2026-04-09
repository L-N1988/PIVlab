function cam_rectification_show_points_Callback (~,~,~)
handles=gui.gethand;
cameraParams=gui.retr('cameraParams');
cam_selected_rectification_image = gui.retr('cam_selected_rectification_image');
target = preproc.cam_get_target_definition(handles);

if isempty(cameraParams) || isempty(cam_selected_rectification_image)
	gui.custom_msgbox('error',getappdata(0,'hgui'),'Error','Camera calibration not activated or no images for camera rectification loaded.','modal');
	return
end
if strcmp(target.type, 'custom3d')
	gui.custom_msgbox('error',getappdata(0,'hgui'),'Error','Point preview for rectification is only supported for planar ChArUco or checkerboard targets.','modal');
	return
end

[imagePoints, target] = preproc.cam_detect_target_points(cam_selected_rectification_image, target, 'rectification');
if isempty(imagePoints)
	gui.custom_msgbox('error',getappdata(0,'hgui'),'Error',['No ' target.name ' points detected.'],'modal');
	return
end

imshow(imread(cam_selected_rectification_image),'Parent',gui.retr('pivlab_axis'))
hold on
plot(imagePoints(:,1),imagePoints(:,2),'yo','MarkerFaceColor','y','Markersize',10)
plot(imagePoints(:,1),imagePoints(:,2),'rx','MarkerSize',20,'LineWidth',2)
hold off
