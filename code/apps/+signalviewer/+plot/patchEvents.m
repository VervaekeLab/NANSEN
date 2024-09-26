function [ patchObj ] = patchEvents( ax, eventMask, color, yLim, xLim, xCoords )
%patchEvents Patch events specified by a logical eventvector
%   patchObj = patchEvents( ax, eventMask, color ) makes patches in ax according to a
%   logical vector. Color specification and yLim is optional. Returns the patch object.
%   NB: it is assumed that the event vector spans the entire x-axis.
%
%   patchObj = patchEvents( ax, eventMask, color, yLim )

% Set default color to red.
if nargin < 3 || isempty(color)
    color = 'r';
end

% Make the default case to patch along entire y-axis
if nargin < 4 || isempty(yLim)
    yLim = get(ax, 'Ylim');
end

if nargin < 5 || isempty(xLim)
    xLim = ax.XLim;
end

if nargin < 6

    % Try to get x coordinates from the axes.
    lines = findobj(ax, 'Type', 'Line');

    if ~isempty(lines)
        % Find length of data that is plotted. Used for patching of all samples
        lineLengths = arrayfun(@(x) length(lines(x).XData), 1:length(lines) );
        
        if any(lineLengths == numel(eventMask))
            lineInd = find(lineLengths == numel(eventMask));
            xCoords = lines(lineInd).XData;
        else
            [~, lineInd] = max(lineLengths); % Find the longest one...
            xCoords = linspace(xLim(1), xLim(2), numel(lines(lineInd).XData));
        end
    else
        xCoords = 1:numel(eventMask);
    end
end

% temp fix when calling this function from a gui where a vertical line
% shows current frame.
if numel(xCoords) == 2
	xCoords = 1:numel(eventMask);
end

% % Raise warning if there is a size mismatch. Good to know about.
% if numel(xCoords) ~= numel(eventMask)
%     warning('length of eventMask does not correspond with the length of at least one of the plotted objects.')
% end

[ eventStart, eventStop ]  = utility.findTransitions( eventMask );

if ~isempty(eventStart)

    % Define the coordinates to patch
    [xData, yData] = deal( zeros(4, numel(eventStart)) );

    xData(1,:) = xCoords(eventStart);
    xData(2,:) = xCoords(eventStop);
    xData(3,:) = xCoords(eventStop);
    xData(4,:) = xCoords(eventStart);

    yData(1:2, :) = yLim(1);
    yData(3:4, :) = yLim(2);

    % Make the patch and tag it
    p = patch(ax, xData, yData, color);
    set(p, 'EdgeColor', 'none', 'FaceAlpha', 0.5, 'Tag', 'eventPatch')
else
    p = gobjects(0);
    disp('Nothing to patch')
end

if nargout
    patchObj = p;
end
end
