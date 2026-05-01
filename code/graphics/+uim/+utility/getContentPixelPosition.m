function pixelPosition = getContentPixelPosition(hParent)
%getContentPixelPosition Return the drawable content area of a UI container.
%
%   For most containers, getpixelposition returns the usable content bounds.
%   In web-based uifigure tabs, however, getpixelposition can include the tab
%   header while normalized children are laid out below it. Measure that
%   normalized child area explicitly so pixel-positioned children use the
%   same bounds as normalized children.

    pixelPosition = getpixelposition(hParent);

    if ~isgraphics(hParent)
        return
    end

    if ~isa(hParent, 'matlab.ui.container.Tab')
        return
    end

    if ~isParentInUiFigure(hParent)
        return
    end

    measuredPosition = measureNormalizedChildPosition(hParent);
    if ~isempty(measuredPosition)
        pixelPosition = measuredPosition;
    end
end

function pixelPosition = measureNormalizedChildPosition(hParent)
    pixelPosition = [];
    hProbe = [];

    try
        hProbe = uipanel(hParent, ...
            'Units', 'normalized', ...
            'Position', [0, 0, 1, 1], ...
            'BorderType', 'none', ...
            'Visible', 'off', ...
            'Tag', 'uimContentPixelPositionProbe');

        drawnow limitrate
        measuredPosition = getpixelposition(hProbe);

        if all(measuredPosition(3:4) > 0)
            pixelPosition = measuredPosition;
        end
    catch
        pixelPosition = [];
    end

    if ~isempty(hProbe) && isvalid(hProbe)
        delete(hProbe)
    end
end

function tf = isParentInUiFigure(hParent)
    tf = false;
    hFigure = ancestor(hParent, 'figure');

    if isempty(hFigure)
        return
    end

    try
        tf = matlab.ui.internal.isUIFigure(hFigure);
    catch
        tf = false;
    end
end
