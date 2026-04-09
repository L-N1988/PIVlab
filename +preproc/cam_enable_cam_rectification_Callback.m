function cam_enable_cam_rectification_Callback(caller,~,~)
handles=gui.gethand;
filepath=gui.retr('filepath');
filename=gui.retr('filename');
cameraParams=gui.retr('cameraParams');
cam_selected_rectification_image = gui.retr('cam_selected_rectification_image');
target = preproc.cam_get_target_definition(handles);

if size(filepath,1) <= 1 && handles.calib_userectification.Value == 1
	gui.custom_msgbox('error',getappdata(0,'hgui'),'Error','No PIV images were loaded.','modal');
	handles.calib_userectification.Value = 0;
	return
end
if isempty(cameraParams)
	gui.custom_msgbox('error',getappdata(0,'hgui'),'Error','"Estimate cam parameters" or "Load parameters" needs to be performed first','modal');
	handles.calib_userectification.Value = 0;
	return
end
if isempty(cam_selected_rectification_image)
	gui.custom_msgbox('error',getappdata(0,'hgui'),'Error','No target image selected.','modal');
	handles.calib_userectification.Value = 0;
	return
end
if strcmp(target.type, 'custom3d')
	gui.custom_msgbox('error',getappdata(0,'hgui'),'Error', ...
		'Image rectification is only supported for planar ChArUco and checkerboard targets.','modal');
	handles.calib_userectification.Value = 0;
	gui.put('cam_use_rectification',0);
	return
end

if ~strcmpi(caller,'calib_viewtype')
	res=gui.custom_msgbox('quest',getappdata(0,'hgui'),'Warning','Masks, ROI, background images, and results will be reset when changing this setting. Continue?','modal',{'OK','Cancel'},'OK');
else
	res='OK';
end
if ~strcmpi(res,'OK')
	handles.calib_userectification.Value = 1 - handles.calib_userectification.Value;
	return
end

if ~isempty(cameraParams) && ~isempty(cam_selected_rectification_image)
	gui.put ('resultslist', []);
	gui.put ('derived',[]);
	gui.put('displaywhat',1);
	gui.put('framemanualdeletion',[]);
	gui.put('manualdeletion',[]);
	gui.put('streamlinesX',[]);
	gui.put('streamlinesY',[]);
	gui.put('bg_img_A',[]);
	gui.put('bg_img_B',[]);
	set(handles.bg_subtract,'Value',1);
	set(handles.fileselector, 'value',1);
	set(handles.minintens, 'string', 0);
	set(handles.maxintens, 'string', 1);
	roi.clear_roi_Callback
	gui.put('masks_in_frame',[]);
	ismean=gui.retr('ismean');
	for i=size(ismean,1):-1:1
		if ismean(i,1)==1
			filepath(i*2,:)=[];
			filename(i*2,:)=[];
			filepath(i*2-1,:)=[];
			filename(i*2-1,:)=[];
		end
	end
	gui.put('filepath',filepath);
	gui.put('filename',filename);
	gui.put('ismean',[]);
end

if handles.calib_userectification.Value == 1
	gui.put('cam_use_rectification',1);
else
	gui.put('cam_use_rectification',0);
end

[imagePoints1, target, detectionImage] = preproc.cam_detect_target_points(cam_selected_rectification_image, target, 'rectification');
if isempty(imagePoints1)
	gui.custom_msgbox('error',getappdata(0,'hgui'),'Error',['No ' target.name ' points detected.'],'modal');
	gui.toolsavailable(1)
	return
end

gui.toolsavailable(0,'Detecting markers...');drawnow;
[worldPoints, target] = preproc.cam_get_rectification_world_points(target, imagePoints1, detectionImage, handles.calib_upscale.Value);
worldPoints(isnan(imagePoints1))=NaN;
imagePoints1 = rmmissing(imagePoints1);
worldPoints = rmmissing(worldPoints);
undistortedPoints = undistortPoints(imagePoints1,cameraParams.Intrinsics);
rectification_tform = fitgeotform2d(undistortedPoints,worldPoints,'projective');
gui.put('rectification_tform',rectification_tform);
gui.toolsavailable(1)

if handles.calib_userectification.Value ==1
	gui.put('expected_image_size',[]);
	gui.put('cam_use_rectification',1);
	[currentimage,~] = import.get_img(1);
	expected_image_size_after_rectification = size(currentimage(:,:,1));
	gui.put('expected_image_size',expected_image_size_after_rectification);
	gui.sliderdisp(gui.retr('pivlab_axis'));
else
	if ~isempty(gui.retr('filepath'))
		gui.put('cam_use_rectification',0);
		gui.put('expected_image_size',[]);
		[currentimage,~] = import.get_img(1);
		expected_image_size = size(currentimage);
		expected_image_size=expected_image_size(1:2);
		gui.put('expected_image_size',expected_image_size);
	end
end

if handles.calib_userectification.Value == 1
	view_raw=handles.calib_viewtype.Value;
	if view_raw==1
		view='valid';
	elseif view_raw==2
		view='same';
	else
		view='full';
	end
	caliimg = preproc.cam_undistort(detectionImage,'cubic',view,1,1,cameraParams,rectification_tform);
	[rectifiedPoints, target] = preproc.cam_detect_target_points(caliimg, target, 'rectification');
	[metricWorldPoints, target] = get_metric_world_points(target, rectifiedPoints);

	metricWorldPoints(isnan(rectifiedPoints))=NaN;
	rectifiedPoints = rmmissing(rectifiedPoints);
	metricWorldPoints = rmmissing(metricWorldPoints);

	x = rectifiedPoints(:,1);
	y = rectifiedPoints(:,2);
	[~, idx] = min(x + y);
	topLeft_image = rectifiedPoints(idx,:);
	topLeft_world = metricWorldPoints(idx,:);
	[~, idx] = max(x + y);
	bottomRight_image = rectifiedPoints(idx,:);
	bottomRight_world = metricWorldPoints(idx,:);
	dx_mm = bottomRight_world(1) - topLeft_world(1);
	dy_mm = bottomRight_world(2) - topLeft_world(2);
	distance_mm = sqrt(dx_mm^2 + dy_mm^2);
	set(handles.realdist, 'string',num2str(distance_mm));
	gui.put('caliimg', caliimg);
	gui.put('pointscali',[[topLeft_image(1) ; bottomRight_image(1)] [topLeft_image(2) ; bottomRight_image(2)]]);
	calibrate.pixeldist_changed_Callback()
end

if gui.retr('stereomode') == 1
	stereo.store_current_camera_state();
end
end

function [metricWorldPoints, target] = get_metric_world_points(target, rectifiedPoints)
switch target.type
	case 'charuco'
		metricWorldPoints = patternWorldPoints('charuco-board',target.patternDims,target.checkerSize);
	case 'checkerboard'
		metricWorldPoints = patternWorldPoints('checkerboard',target.patternDims,target.checkerSize);
	otherwise
		error('PIVlab:RectificationRequiresPlanarTarget', ...
			'Image rectification is only supported for planar ChArUco and checkerboard targets.');
end

if target.patternDims(1) > target.patternDims(2)
	metricWorldPoints = metricWorldPoints(:, [2 1]);
	metricWorldPoints(:,2) = -metricWorldPoints(:,2);
end
metricWorldPoints(isnan(rectifiedPoints)) = NaN;
end
