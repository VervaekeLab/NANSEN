function pathList = getToolboxDependencyList(toolboxInfo)
%getToolboxDependencyList Get list of folders required for toolbox
%
%   PATHLIST = nansen.toolbox.getToolboxDependencyList(S) returns a list
%   (PATHLIST, cell array) of absolute folder paths that are necessary to 
%   run a toolbox addon. Input S is a struct containing the following three
%   fields:
%       * ToolboxName           : Name of toolbox
%       * FunctionName          : Name of function that is part of toolbox
%       * FolderExcludeTokens   : A cell array of expressions to exclude
%         from the list. Example: {'.git'} to exclude .git subfolders.
%   
%   Note: This function is used to generate a list of paths when creating a
%   job using the batch function.

    assert(isstruct(toolboxInfo), 'Input must be a struct')
    assert(isfield(toolboxInfo, 'ToolboxName'), 'Input struct must include the field ''toolboxName''')
    assert(isfield(toolboxInfo, 'FunctionName'), 'Input struct must include the field ''toolboxFunctionName''')

    if ~isfield(toolboxInfo, 'FolderExcludeTokens')
        toolboxInfo.FolderExcludeTokens = {};
    end
    
    initPath = nansen.toolboxdir();
    % Get all subfolders in the nansen toolbox directory.
    folderPath = strsplit(genpath(initPath), pathsep);
    nansenPathList = folderPath(1:end-1);
    
    % Find local toolbox location
    S = which(toolboxInfo.FunctionName);
    
    if isempty(S)
        error(['%s was not found on MATLAB''s search path. Please make', ...
            ' sure the %s\ntoolbox is added to MATLAB''s search path'], ...
            toolboxInfo.ToolboxName, toolboxInfo.ToolboxName);
    end
    
    toolboxPath = fileparts(fileparts(S));
    toolboxPathList = genpath(toolboxPath);
    
    for i = 1:numel(toolboxInfo.FolderExcludeTokens)
        iToken = toolboxInfo.FolderExcludeTokens{i};
        toolboxPathList = utility.path.excludeItemsFromPathList(toolboxPathList, iToken);
    end
    
    toolboxPathListCell = strsplit(toolboxPathList, pathsep);
    
    pathList = [nansenPathList, toolboxPathListCell];
    
    if isrow(pathList)
       pathList = transpose(pathList);
    end

    isEmpty = cellfun(@isempty, pathList);
    pathList(isEmpty) = [];
    
end