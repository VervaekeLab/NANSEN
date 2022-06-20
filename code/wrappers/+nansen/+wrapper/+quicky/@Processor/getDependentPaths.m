function pathList = getDependentPaths()
%getDependentPaths Get paths that are needed for running normcorre
    
    toolboxInfo.ToolboxName = 'Quicky';
    toolboxInfo.FunctionName = 'flufinder.runAutosegmentation';
    toolboxInfo.FolderExcludeTokens = {'.git', 'tutorials'};
    
    pathList = nansen.toolbox.getToolboxDependencyList(toolboxInfo);
    
end