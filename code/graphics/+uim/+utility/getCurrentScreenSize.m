function [screenSize, screenNumber] = getCurrentScreenSize(hFig)
%GETCURRENTSCREENSIZE Summary of this function goes here
%
%   [screenSize, screenNumber] = getCurrentScreenSize(hFig) returns the
%   posision coordinates (screenSize) and number of the monitor where a 
%   figure is located.
    
    MP = get(0, 'MonitorPosition');
    if size(MP, 1) == 1
        screenSize = MP;
        screenNumber = 1;
        return
    end
    
    % Get coordinates for upper left corner of figure
    xPos = hFig.Position(1);
    yPos = hFig.Position(2) + hFig.Position(4);
    
    screenNumber = getMonitorIdx([xPos, yPos], MP); % Check upper left 

    if isnan(screenNumber)                          % Check upper right 
        % Get x-coordinate for upper right corner
        xPos = hFig.Position(1) + hFig.Position(3);
        screenNumber = getMonitorIdx([xPos, yPos], MP);
    end
    
    if ~isnan(screenNumber)
        screenSize = MP(screenNumber, :);
    else
        screenSize = get(0, 'ScreenSize');
        screenNumber = 1;
        warning('Could not resolve which screen figure is on, using main screen...')
        %screenSize = [];
    end

    if nargout == 1
        clear screenNumber
    end

end

function monitorIdx = getMonitorIdx(point, monitorPositionArray)
%getMonitorIdx Find index of the monitor where point is located.
%
%   monitorIdx = getMonitorIdx(point, monitorPositionArray) returns the
%   index for the monitor where the given point is located. point is a
%   1x2 vector with x- and y-coordinate and monitorPositionArra is an
%   nMonitor x 4 matrix of monitorPositions for each monitor.

    monitorIdx = nan;
    numMonitors = size(monitorPositionArray, 1);
    
    % Find monitor where point is located
    for iMonitor = 1:numMonitors
         if isPointInPosition( point, monitorPositionArray(iMonitor, :) )
            monitorIdx = iMonitor;
            break
        end
    end
    
end

function tf = isPointInPosition(point, position)
%isPointInPosition Check if point is inside limits of position
    tf = false;

    if point(1) >= position(1) && point(1) <= sum( position([1,3]) - 1 )
        if point(2) >= position(2) && point(2) <= sum( position([2,4]) - 1 )
            tf = true;
        end
    end

end


