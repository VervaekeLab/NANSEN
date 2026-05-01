function tf = isJavaFrameSupported()
%isJavaFrameSupported True when MATLAB's legacy JavaFrame API can be used.
%
%   This is a capability check for code paths that call the undocumented
%   JavaFrame API directly or indirectly. It is intentionally narrower than
%   useModernUiComponents, which describes NANSEN's preferred UI policy.
%
%   See also nansen.util.useModernUiComponents

    if exist('isMATLABReleaseOlderThan', 'file') == 2
        tf = isMATLABReleaseOlderThan("R2025a");
    else % function missing, older matlab release
        tf = true;
    end
end
