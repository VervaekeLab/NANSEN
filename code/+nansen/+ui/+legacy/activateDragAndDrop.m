function dndObject = activateDragAndDrop(figureHandle, callbackFunction)
    dndObject = [];

    if ~nansen.util.isJavaFrameSupported()
        % MATLAB R2025a removed JavaFrame support, abort.
        return
    end

    warningCleanup = nansen.ui.legacy.tempDisableJavaFrameWarnings(); %#ok<NASGU>

    jFrame = get(figureHandle, 'JavaFrame'); %#ok<JAVFM>
    jWindow = jFrame.getFigurePanelContainer.getTopLevelAncestor;

    % The initJava static method will try to overwrite the dynamic
    % javaclasspath so we don't use this method.
    % % dndcontrol.initJava();

    % Adding dndcontrol only if it does not already exist on the
    % dynamic java classpath
    dpathOrig = javaclasspath('-dynamic');
    dndcontrolPath = fileparts( which("dndcontrol") );
    if isempty(dpathOrig) || ~any(strcmp(dpathOrig, dndcontrolPath))
        % Suppress warning sometimes happens after installation of NANSEN
        % on systems where the javaclasspath has not been properly cleaned
        % up. It is unrelated to adding this class to the javapath, so we
        % suppress the warning to spare users from the noise.
        warnState = warning('off', 'MATLAB:Java:DuplicateClass');
        warnCleanup = onCleanup(@(ws) warning(warnState));
        javaclasspath(dpathOrig, dndcontrolPath)
    end

    % Create dndcontrol for the JTextArea object
    dndObject = dndcontrol(jWindow);

    % Set Drop callback functions
    dndObject.DropFileFcn = callbackFunction;
end
