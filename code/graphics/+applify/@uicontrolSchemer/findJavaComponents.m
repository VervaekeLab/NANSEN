function jhUic = findJavaComponents(hUic, hParent)
%findUicJobj Find java objects of uicontrols in a figure panel
%
%    jhUic = findUicJobj(hUic, hParent) return a cell array of java objects
%    given an array og uicontrol objects and a panel they belong to.

    if nansen.util.isJavaFrameSupported()
        jhUic = nansen.ui.legacy.findJavaComponents(hUic, hParent);
    else
        error('NANSEN:UIControlStyled:Unsupported', ...
            "This function is unsupported and should have a modern " + ...
            "replacement. If you see this error, please report.")
    end
end
