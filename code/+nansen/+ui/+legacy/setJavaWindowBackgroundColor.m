function setJavaWindowBackgroundColor(figureHandle, newColor)
% setJavaWindowBackgroundColor - Set background color of a figure's java window

    arguments
        figureHandle
        newColor (1,3) double
    end

    if nansen.util.useModernUiComponents()
        % MATLAB R2025a removed JAVA support, abort.
        return
    end

    rgb = num2cell(newColor);

    warningCleanup = nansen.ui.legacy.tempDisableJavaFrameWarnings(); %#ok<NASGU>

    jFrame = get(handle(figureHandle), 'JavaFrame'); %#ok<JAVFM>
    jWindow = jFrame.getFigurePanelContainer.getTopLevelAncestor;
    javaColor = javax.swing.plaf.ColorUIResource(rgb{:});
    set(jWindow, 'Background', javaColor)
end
