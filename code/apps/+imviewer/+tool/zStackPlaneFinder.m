function frameNumbers = zStackPlaneFinder(hImviewer)
%zStackPlaneFinder Tools for getting framenumbers of each corner
%
%   framenum = zStackPlaneFinder(hImviewer) opens an interactive "corner
%   selection" tool in the imviewer object imviewerH. Output is a list of
%   framenumbers, starting in the upper left corner, moving
%   counterclockwise to the upper right corner.

% Set color of box to plot in corners
color = ones(1,3) .* 0.5;

% Set size of boxes to plot in corners
boxSize = [25, 25];

% Get size of image
[nRows, nCols, ~] = size(hImviewer.image);

% Get initial position of each of the boxes that goes to the corners
cornersX = [1, 1, nCols-boxSize(1), nCols-boxSize(1)];
cornersY = [1, nRows-boxSize(2), nRows-boxSize(2), 1];

% Create rectangular coordinates for the box to plot in the corners
xData = [1, 1, boxSize(1), boxSize(1)];
yData = [1, boxSize(2), boxSize(2), 1];

% Plot each of the boxes and assign a press callback to register the
% framenumber for the click
hCorners = gobjects(4,1);
for i = 1:4
    hCorners(i) = patch(hImviewer.axes, xData + cornersX(i), yData+cornersY(i), color);
    hCorners(i).UserData.FrameNum = nan;
    hCorners(i).ButtonDownFcn = {@cornerPressed, hImviewer};
end

% Set some transparency and outline for the corner boxes
set(hCorners, 'EdgeColor', ones(1,3)*0.7, 'FaceAlpha', 0.6)

% Wait for imviewer (When user presses enter in imviewer, ui continues.)
uiwait(hImviewer.fig)

% Retrieve framenubers from the boxes.
frameNumbers = arrayfun(@(hc) hc.UserData.FrameNum, hCorners);

% Delete corners.
delete(hCorners)

end

% Callback for buttonpress in cornerboxes.
function cornerPressed(src, ~, hImviewer)

    src.UserData.FrameNum = hImviewer.currentFrameNo;
    
    src.LineWidth = 2;
    src.FaceColor = ones(1,3)*0.2;
    
end
