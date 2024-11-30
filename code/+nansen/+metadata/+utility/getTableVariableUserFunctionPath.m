function pathStr = getTableVariableUserFunctionPath(variableName, tableClass)

% Create a target path for the function. Place it in the current
    % project folder.
    %rootPathTarget = nansen.localpath('Custom Metatable Variable', 'current');
    rootPathTarget = nansen.ProjectManager().getCurrentProject().getTableVariableFolder();
    fcnTargetPath = fullfile(rootPathTarget, ['+', lower(tableClass)] );
    fcnFilename = [variableName, '.m'];
    
    pathStr = fullfile(fcnTargetPath, fcnFilename);
    
end
