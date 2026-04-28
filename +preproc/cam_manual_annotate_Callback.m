function cam_manual_annotate_Callback(~, ~, ~)
%CAM_MANUAL_ANNOTATE_CALLBACK Interactive manual calibration point annotation.
%
% Annotate calibration target points by clicking on the image. Each click
% registers the next world point in sequence. Use this when automatic
% detection is unavailable (e.g. LaVision 3D two-level calibration plates).
%
% Mouse controls:
%   Left click  – place / advance to next point
%   Right click – undo last point
%   Middle click / press 'q' – finish annotation
%   Press 'r' – reset all points
%   Press 's' – save current annotation to file
%   Press 'l' – load previous annotation from file
%
% The annotated imagePoints are stored as an N×2 array in gui data under
% 'cam_manual_image_points', and the reference image path under
% 'cam_manual_image_file'.

handles = gui.gethand;
hMain = getappdata(0, 'hgui');

% ── get the calibration target world points ──────────────────────────
target = preproc.cam_get_target_definition(handles);
if ~strcmp(target.type, 'custom3d')
    gui.custom_msgbox('error', hMain, 'Manual annotation', ...
        'Manual annotation is only supported for custom 3D calibration plates.', 'modal');
    return
end
if isempty(target.customPlate) || ~isstruct(target.customPlate)
    gui.custom_msgbox('error', hMain, 'Manual annotation', ...
        'Load a calibration plate definition first.', 'modal');
    return
end

worldPoints = target.customPlate.worldPoints;
n_world = size(worldPoints, 1);

% ── get the current calibration image ────────────────────────────────
cam_images = gui.retr('cam_selected_target_images');
if isempty(cam_images) || ~iscell(cam_images)
    gui.custom_msgbox('error', hMain, 'Manual annotation', ...
        'Load calibration images first.', 'modal');
    return
end
% If multiple images loaded, annotate only the first one
image_file = cam_images{1};
img = imread(image_file);

% ── restore previous annotation if available ─────────────────────────
prev_points = gui.retr('cam_manual_image_points');
prev_file   = gui.retr('cam_manual_image_file');
if ~isempty(prev_points) && strcmp(prev_file, image_file)
    reuse = gui.custom_msgbox('quest', hMain, 'Existing annotation', ...
        ['Found existing annotation with ' num2str(size(prev_points,1)) ...
         ' points for this image. Continue from saved state?'], ...
        'modal', {'Continue', 'Start fresh'}, 'Continue');
    if strcmp(reuse, 'Continue')
        imagePoints = prev_points;
        i = size(imagePoints, 1) + 1;
    else
        imagePoints = nan(n_world, 2);
        i = 1;
    end
else
    imagePoints = nan(n_world, 2);
    i = 1;
end

% ── display the calibration image ────────────────────────────────────
ax = gui.retr('pivlab_axis');
cla(ax);
imshow(img, 'Parent', ax);
hold(ax, 'on');
title(ax, 'Left-click: place point | Right-click: undo | Middle-click/q: finish | r: reset | s: save | l: load');

% Redraw any existing points
for k = 1:(i-1)
    if ~isnan(imagePoints(k,1))
        plot(ax, imagePoints(k,1), imagePoints(k,2), 'g+', 'MarkerSize', 10, 'LineWidth', 1.5);
        text(ax, imagePoints(k,1)+3, imagePoints(k,2)+3, num2str(k), ...
            'Color', 'g', 'FontSize', 8, 'FontWeight', 'bold');
    end
end

% Point index text
idx_text = text(ax, 10, 20, sprintf('Point %d / %d', i, n_world), ...
    'Color', 'y', 'FontSize', 12, 'FontWeight', 'bold', ...
    'BackgroundColor', [0 0 0 0.5]);

% ── interactive annotation loop ──────────────────────────────────────
gui.toolsavailable(0)
try
    while i <= n_world
        set(idx_text, 'String', sprintf('Point %d / %d  [left=place, right=undo, q=finish]', i, n_world));

        [x, y, button] = ginput(1);

        if isempty(button)
            break
        end

        switch button
            case 1  % left click → place point
                imagePoints(i, :) = [x, y];
                plot(ax, x, y, 'g+', 'MarkerSize', 10, 'LineWidth', 1.5);
                text(ax, x+3, y+3, num2str(i), ...
                    'Color', 'g', 'FontSize', 8, 'FontWeight', 'bold');
                i = i + 1;

            case 3  % right click → undo
                if i > 1
                    i = i - 1;
                    imagePoints(i, :) = nan;
                end
                % clear all annotations and redraw
                delete(findobj(ax, 'Type', 'text'));
                delete(findobj(ax, 'Type', 'line'));
                imshow(img, 'Parent', ax);
                hold(ax, 'on');
                for k = 1:(i-1)
                    if ~isnan(imagePoints(k,1))
                        plot(ax, imagePoints(k,1), imagePoints(k,2), 'g+', 'MarkerSize', 10, 'LineWidth', 1.5);
                        text(ax, imagePoints(k,1)+3, imagePoints(k,2)+3, num2str(k), ...
                            'Color', 'g', 'FontSize', 8, 'FontWeight', 'bold');
                    end
                end
                idx_text = text(ax, 10, 20, '', 'Color', 'y', 'FontSize', 12, ...
                    'FontWeight', 'bold', 'BackgroundColor', [0 0 0 0.5]);
            case 2  % middle click → finish
                break

            otherwise
                % keyboard input via ginput → check for single char
                if ischar(button) || (isnumeric(button) && button > 3)
                    key = char(button);
                    switch lower(key)
                        case 'q'
                            break
                        case 'r'
                            % reset all
                            imagePoints = nan(n_world, 2);
                            i = 1;
                            delete(findobj(ax, 'Type', 'text'));
                            cla(ax);
                            imshow(img, 'Parent', ax);
                            hold(ax, 'on');
                            idx_text = text(ax, 10, 20, '', 'Color', 'y', 'FontSize', 12, ...
                                'FontWeight', 'bold', 'BackgroundColor', [0 0 0 0.5]);
                        case 's'
                            % quick save current state
                            save_annotation(imagePoints, image_file);
                        case 'l'
                            % quick load
                            loaded = load_annotation(image_file);
                            if ~isempty(loaded) && size(loaded,1) == n_world
                                imagePoints = loaded;
                                i = find(isnan(imagePoints(:,1)), 1);
                                if isempty(i), i = n_world + 1; end
                                % redraw
                                delete(findobj(ax, 'Type', 'text'));
                                cla(ax);
                                imshow(img, 'Parent', ax);
                                hold(ax, 'on');
                                for k = 1:(i-1)
                                    if ~isnan(imagePoints(k,1))
                                        plot(ax, imagePoints(k,1), imagePoints(k,2), 'g+', 'MarkerSize', 10, 'LineWidth', 1.5);
                                        text(ax, imagePoints(k,1)+3, imagePoints(k,2)+3, num2str(k), ...
                                            'Color', 'g', 'FontSize', 8, 'FontWeight', 'bold');
                                    end
                                end
                                idx_text = text(ax, 10, 20, '', 'Color', 'y', 'FontSize', 12, ...
                                    'FontWeight', 'bold', 'BackgroundColor', [0 0 0 0.5]);
                            end
                    end
                end
        end
    end
catch ME
    gui.toolsavailable(1)
    rethrow(ME)
end
gui.toolsavailable(1)

% ── store completed annotation ───────────────────────────────────────
% Trim to actual annotated count
if i > 1
    n_annotated = i - 1;
    imagePoints = imagePoints(1:n_annotated, :);
else
    n_annotated = 0;
end

if n_annotated == 0
    gui.custom_msgbox('warn', hMain, 'No points', ...
        'No points were annotated. Calibration aborted.', 'modal');
    return
end

if n_annotated < n_world
    button_gui = gui.custom_msgbox('quest', hMain, 'Incomplete annotation', ...
        sprintf('Only %d of %d world points were annotated.\nContinue with subset?', ...
        n_annotated, n_world), 'modal', {'Continue', 'Cancel'}, 'Cancel');
    if strcmp(button_gui, 'Cancel')
        return
    end
    % Trim worldPoints to match
    worldPoints = worldPoints(1:n_annotated, :);
end

% Store in gui data
gui.put('cam_manual_image_points', imagePoints);
gui.put('cam_manual_image_file', image_file);
gui.put('cam_manual_world_points', worldPoints);

% ── apply to the current camera's calibration ─────────────────────────
% Store imagePoints into the custom plate definition so that
% collect_custom_plate_observations can pick them up.
% Ensure N×2×1 format expected by the calibration pipeline.
plate = target.customPlate;
if ismatrix(imagePoints) && size(imagePoints, 2) == 2
    imagePoints_3d = zeros(size(imagePoints, 1), 2, 1);
    imagePoints_3d(:, :, 1) = imagePoints;
    plate.imagePoints = imagePoints_3d;
else
    plate.imagePoints = imagePoints;
end
plate.hasImagePoints = true;
plate.imageFileNames = {image_file};

% Also save a copy as a MAT file for persistence
default_path = fullfile(gui.retr('pathname'), ...
    ['manual_annotation_' datestr(now, 'yyyymmdd_HHMMSS') '.mat']);
save_annotation(imagePoints, image_file, default_path);

% Store updated plate back to gui
gui.put('calib_custom_plate_definition', plate);

% Update the current camera's target images to point to the single annotated image
gui.put('cam_selected_target_images', {image_file});

% ── if in stereo mode, store per-camera manual annotation ──────────────
if gui.retr('stereomode') == 1
    coupled = stereo.ensure_coupled_calibration();
    current_cam = stereo.get_current_camera_index();
    cam_state = stereo.get_camera_calibration_state(coupled, current_cam);
    cam_state.manual_image_points = imagePoints_3d;
    cam_state.manual_image_file = image_file;
    coupled = stereo.set_camera_calibration_state(coupled, current_cam, cam_state);
    gui.put('stereo_calibration', coupled);
end

gui.custom_msgbox('msg', hMain, 'Annotation complete', ...
    sprintf('Annotated %d calibration points.\nReady for parameter estimation.', ...
    n_annotated), 'modal', {'OK'}, 'OK');

end

function save_annotation(imagePoints, image_file, save_path)
%Save annotation to a MAT file.
if nargin < 3
    [f, p] = uiputfile('*.mat', 'Save annotation as...', ...
        fullfile(gui.retr('pathname'), 'manual_annotation.mat'));
    if isequal(f, 0), return; end
    save_path = fullfile(p, f);
end
image_file_ref = image_file; %#ok<NASGU>
n_points = size(imagePoints, 1); %#ok<NASGU>
save(save_path, 'imagePoints', 'image_file_ref', 'n_points');
gui.put('cam_manual_image_points', imagePoints);
gui.put('cam_manual_image_file', image_file);
end

function imagePoints = load_annotation(image_file)
%Load annotation from a MAT file, matching the image file reference.
[f, p] = uigetfile('*.mat', 'Load annotation', ...
    fullfile(gui.retr('pathname'), '*.mat'));
if isequal(f, 0)
    imagePoints = [];
    return
end
data = load(fullfile(p, f));
if ~isfield(data, 'imagePoints')
    imagePoints = [];
    return
end
% Warn if image file reference doesn't match
if isfield(data, 'image_file_ref') && ~strcmp(data.image_file_ref, image_file)
    gui.custom_msgbox('warn', getappdata(0, 'hgui'), 'Image mismatch', ...
        'The loaded annotation was created for a different calibration image.', 'modal');
end
imagePoints = data.imagePoints;
end
