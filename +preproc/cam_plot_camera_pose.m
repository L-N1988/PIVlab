function cam_plot_camera_pose(worldPoints, absPose, labelText)
%CAM_PLOT_CAMERA_POSE Show a simple 3D plot of the calibration target and camera pose.

camfig = figure('Name','Camera position in 3D','DockControls','off','WindowStyle','normal', ...
	'Scrollable','off','MenuBar','figure','Resize','on','ToolBar','none','NumberTitle','off');
camax = axes(camfig);
plot3(worldPoints(:,1), worldPoints(:,2), worldPoints(:,3), '*', 'Parent', camax);
hold(camax, 'on')
plot3(camax, 0, 0, 0, 'g*');
plotCamera(AbsolutePose=absPose, Size=5, Color="red", AxesVisible=true, Label=labelText, Parent=camax);
axis(camax, 'equal')
grid(camax, 'on')
set(camax,'CameraUpVector',[0 -1 0]);
cameratoolbar(camfig,'SetMode','orbit');
cameratoolbar(camfig,"SetCoordSys","y")
xlabel(camax,"X (mm)");
ylabel(camax,"Y (mm)");
zlabel(camax,"Z (mm)");
view(camax,[0 -45]);
camorbit(camax,-45,0,'data',[0 1 0])
camproj(camax,'perspective')
end
