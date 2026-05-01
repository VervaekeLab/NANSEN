function toggleJavaWindowAlwaysOnTop(figureHandle, newState)
% toggleJavaWindowAlwaysOnTop - Toggle AlwaysOnTop state of Java window
    arguments
        figureHandle
        newState (1,1) logical
    end

    if ~nansen.util.isJavaFrameSupported()
        % MATLAB R2025a removed JavaFrame support, abort.
        return
    end

    warningCleanup = nansen.ui.legacy.tempDisableJavaFrameWarnings(); %#ok<NASGU>

    jFrame = get(figureHandle, 'JavaFrame'); %#ok<JAVFM>
    jClient = jFrame.fHG2Client;
    jWindow = jClient.getWindow;

    jWindow.setAlwaysOnTop(newState)
end
