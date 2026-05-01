function dndObject = activateDragAndDrop(figureHandle, callbackFunction)
    dndObject = [];

    if nansen.util.useModernUiComponents()
        % MATLAB R2025a removed JAVA support, abort
        return
    end

    warningCleanup = nansen.ui.legacy.tempDisableJavaFrameWarnings(); %#ok<NASGU>

    jFrame = get(figureHandle, 'JavaFrame'); %#ok<JAVFM>
    jWindow = jFrame.getFigurePanelContainer.getTopLevelAncestor;

    % The initJava static method is not reliable, and will trigger
    % warnings.
    % warnState = warning('off', 'MATLAB:Java:DuplicateClass');
    % warnCleanup = onCleanup(@(ws) warning(warnState));
    % % dndcontrol.initJava();

    % Adding dndcontrol only if it does not already exist on the
    % dynamic java classpath
    dpathOrig = javaclasspath('-dynamic');
    dndcontrolPath = fileparts( which("dndcontrol") );
    if isempty(dpathOrig) || ~any(strcmp(dpathOrig, dndcontrolPath))
        javaclasspath(dpathOrig, dndcontrolPath)
    end

    % Create dndcontrol for the JTextArea object
    dndObject = dndcontrol(jWindow);

    % Set Drop callback functions
    dndObject.DropFileFcn = callbackFunction;
end
