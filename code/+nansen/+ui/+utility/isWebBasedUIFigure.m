function tf = isWebBasedUIFigure(fig)
    tf = ~isempty(fig) ...
        && isvalid(fig) ...
        && isgraphics(fig, 'figure') ...
        && (isprop(fig, 'isUIFigure') || isMATLABRelease2025aOrNewer());
end

function tf = isMATLABRelease2025aOrNewer()
    try
        tf = ~isMATLABReleaseOlderThan("R2025a");
    catch % isMATLABReleaseOlderThan was introduced in R2020b
        tf = false;
    end
end
