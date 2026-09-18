function [regions, wasAborted] = selectRectangularRegions(imageStack, options)
%selectRectangularRegions - Select rectangular image regions interactively
%
%   regions = nansen.stack.selectRectangularRegions(imageStack) opens the
%   nansen.stack.ImageStack object imageStack in imviewer and lets the user
%   place rectangular regions on the image by clicking. Pressing enter
%   finishes the selection and returns the regions as an N-by-4 array of
%   rectangles [xmin, ymin, width, height] of pixel indices, in the order
%   the regions were created.
%
%   Interaction:
%       click         : Add a region centered on the point that is clicked
%       g / h         : Grow / shrink the region in both directions
%       shift + g / h : Grow / shrink the region in the y-direction only
%       s             : Switch between placing and selecting regions.
%                       A selected region is moved with the arrow keys and
%                       deleted with the backspace key
%       enter         : Finish and return the regions
%       escape        : Abort and return no regions
%
%   regions = selectRectangularRegions(imageStack,RegionSize=SIZE) sets the
%   initial size of the region that is placed. SIZE is a scalar for a
%   square region or a two-element vector [WIDTH, HEIGHT]. By default, the
%   region is one sixth of the image size.
%
%   regions = selectRectangularRegions(imageStack,Regions=REGIONS) starts
%   the selection with the regions in REGIONS already placed, so that an
%   earlier selection can be adjusted.
%
%   [regions, wasAborted] = selectRectangularRegions(...) also returns
%   whether the user aborted the selection, either by pressing escape or by
%   closing the window. regions is empty when the selection is aborted.
%
%   See also nansen.stack.crop, imviewer.plugin.RegionSelector, imviewer

    arguments
        imageStack {mustBeA(imageStack, "nansen.stack.ImageStack"), ...
            mustBeScalarOrEmpty, mustBeNonempty}
        options.RegionSize (1,:) {mustBeNumeric, mustBeReal, mustBePositive} = []
        options.Regions (:,4) {mustBeNumeric, mustBeReal} = zeros(0, 4)
    end

    regionSize = resolveRegionSize(options.RegionSize, imageStack);

    % Caching makes browsing the stack in imviewer responsive while the
    % regions are placed. Only a virtual stack has a dynamic cache.
    useDynamicCache = imageStack.IsVirtual;
    if useDynamicCache
        initialCacheState = imageStack.DynamicCacheEnabled;
        imageStack.DynamicCacheEnabled = 'on';
    end

    hImviewer = imviewer(imageStack);
    hImviewer.ImageDragAndDropEnabled = false;

    hRegionSelector = hImviewer.openPlugin(@imviewer.plugin.RegionSelector, ...
        [], 'RegionSize', regionSize, 'Regions', options.Regions);

    message = ['Click to add a region. Press g/h to resize, s to select ', ...
        'and move or delete a region, enter to finish and escape to abort.'];
    hImviewer.displayMessage(message, [], 8)

    wasAborted = waitForUser(hImviewer, hRegionSelector);

    if wasAborted
        regions = zeros(0, 4);
    else
        regions = hRegionSelector.getRegions();
    end

    delete(hRegionSelector)
    if isvalid(hImviewer)
        hImviewer.quit()
    end
    if useDynamicCache && isvalid(imageStack)
        imageStack.DynamicCacheEnabled = initialCacheState;
    end
end

function regionSize = resolveRegionSize(regionSize, imageStack)
%resolveRegionSize Get the initial region size as [width, height]

    if isempty(regionSize)
        % One sixth of the image in each direction is large enough to hold
        % structures for registration and small enough that several regions
        % fit in the field of view.
        regionSize = round( [imageStack.ImageWidth, imageStack.ImageHeight] ./ 6 );
    elseif isscalar(regionSize)
        regionSize = [regionSize, regionSize];
    elseif numel(regionSize) > 2
        error('NANSEN:Stack:SelectRegions:InvalidRegionSize', ...
            ['RegionSize must be a scalar or a two-element vector ', ...
            '[width, height].'])
    end

    regionSize = min(regionSize, [imageStack.ImageWidth, imageStack.ImageHeight]);
end

function wasAborted = waitForUser(hImviewer, hRegionSelector)
%waitForUser Block until the user finishes or aborts the selection

    hFigure = hImviewer.Figure;
    hFigure.UserData.lastKey = '';

    while true
        uiwait(hFigure) % Resumes on enter or escape

        if ~ishghandle(hFigure)
            wasAborted = true;
            break
        elseif strcmp(hFigure.UserData.lastKey, 'escape')
            wasAborted = true;
            break
        elseif strcmp(hFigure.UserData.lastKey, 'return')
            if hRegionSelector.RegionCount == 0
                hImviewer.displayMessage( ...
                    'Add at least one region before pressing enter.', [], 4)
            else
                wasAborted = false;
                break
            end
        end
    end
end
