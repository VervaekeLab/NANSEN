function warningCleanup = tempDisableJavaFrameWarnings()
    warnState(1) = warning('off', 'MATLAB:ui:javaframe:PropertyToBeRemoved');
    warningCleanup(1) = onCleanup(@() warning(warnState(1)));

    warnState(2) = warning('off', 'MATLAB:HandleGraphics:ObsoletedProperty:JavaFrame');
    warningCleanup(2) = onCleanup(@() warning(warnState(2)));
end