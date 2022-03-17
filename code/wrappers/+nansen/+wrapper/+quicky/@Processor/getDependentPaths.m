function pathList = getDependentPaths()
%getDependentPaths Get paths that are needed for running normcorre
    
    toolboxInfo.ToolboxName = 'Quicky';
    toolboxInfo.FunctionName = 'roimanager.autosegment.autosegmentSoma';
    toolboxInfo.FolderExcludeTokens = {'.git', 'tutorials'};
    
    pathList = nansen.toolbox.getToolboxDependencyList(toolboxInfo);
    
end