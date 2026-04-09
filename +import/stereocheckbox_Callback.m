function stereocheckbox_Callback (~,caller,~)
stereomode=gui.retr('stereomode');
if isempty(stereomode)
    stereomode=0;
end
button = gui.custom_msgbox('quest',getappdata(0,'hgui'),'Warning','Switching mode will reset current results and settings. Continue?','modal',{'Yes','No'},'No');
if strcmpi(button,'Yes')
    gui.put('stereomode',caller.Source.Value); % enable or disable stereo PIV mode, write to GUI variables.
    if caller.Source.Value == 1
        stereo.init_gui_state();
        stereo.ensure_coupled_calibration();
        stereo.apply_camera_state(1);
    else
        gui.put('stereo_session',[]);
    end
    import.update_stereo_import_controls();
    stereo.update_menu_state();
else % omit changing the box value
    caller.Source.Value = stereomode;
end

