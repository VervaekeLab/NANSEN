function pathStr = getTableVariableUserFunctionPath(variableName, tableClass)
% getTableVariableUserFunctionPath - Get path for table variable from current project
    arguments
        variableName (1,1) string
        tableClass (1,1) string
    end

    % Create a target path for the function in the current project folder.
    rootPathTarget = nansen.ProjectManager().getCurrentProject().getTableVariableFolder();
    fcnTargetPath = fullfile(rootPathTarget, strcat("+", lower(tableClass)) );
    fcnFilename = variableName + ".m";
    
    pathStr = fullfile(fcnTargetPath, fcnFilename);
    assert(isscalar(pathStr), ...
        "NANSEN:InternalError", "Expected output to be scalar")
end
