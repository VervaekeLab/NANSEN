function pathStr = getTableVariableUserFunctionPath(variableName, tableClass)

    % Create a target path for the function in the current project folder.
    rootPathTarget = nansen.ProjectManager().getCurrentProject().getTableVariableFolder();
    fcnTargetPath = fullfile(rootPathTarget, ['+', lower(tableClass)] );
    fcnFilename = [variableName, '.m'];
    
    pathStr = fullfile(fcnTargetPath, fcnFilename);
end
