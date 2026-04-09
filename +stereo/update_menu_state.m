function update_menu_state()
%UPDATE_MENU_STATE Enable stereo calibration menu items when stereo mode is active.

stereomode = gui.retr('stereomode');
if isempty(stereomode)
	stereomode = 0;
end

cam2_calib_menu = findall(getappdata(0,'hgui'), 'Type', 'uimenu', 'Tag', 'menu_cam_calib_2');
cam2_rect_menu = findall(getappdata(0,'hgui'), 'Type', 'uimenu', 'Tag', 'menu_cam_rect_2');

if stereomode == 1
	set(cam2_calib_menu, 'Enable', 'on');
	set(cam2_rect_menu, 'Enable', 'on');
else
	set(cam2_calib_menu, 'Enable', 'off');
	set(cam2_rect_menu, 'Enable', 'off');
end
end
