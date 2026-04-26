function warningCleanup = tempDisableJavaComponentWarning()
    warnState = warning('off', 'MATLAB:ui:javacomponent:FunctionToBeRemoved');
    warningCleanup = onCleanup(@() warning(warnState));
end