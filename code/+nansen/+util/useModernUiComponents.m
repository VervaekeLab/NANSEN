function tf = useModernUiComponents()
%useModernUiComponents True when NANSEN should use MATLAB web UI components.
%
%   MATLAB R2025a and newer no longer support NANSEN's Java UI stack. Use
%   this function as the single release gate for choosing native
%   uifigure/webwindow-compatible components over legacy Java/Widgets UI.

    if exist('isMATLABReleaseOlderThan', 'file') == 2
        tf = ~isMATLABReleaseOlderThan("R2025a");
    else % function missing, older matlab release
        tf = false;
    end
end
