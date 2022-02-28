function pathList = getDependentPaths()
%getDependentPaths Get paths that are needed for running normcorre
    
    toolboxInfo.ToolboxName = 'EXTRACT';
    toolboxInfo.FunctionName = 'extractor';
    toolboxInfo.FolderExcludeTokens = {'.git', 'tutorials'};
    
    pathList = nansen.toolbox.getToolboxDependencyList(toolboxInfo);
    
end