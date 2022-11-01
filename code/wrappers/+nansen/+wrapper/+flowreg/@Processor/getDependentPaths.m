function pathList = getDependentPaths()
%getDependentPaths Get paths that are needed for running flowreg

    toolboxInfo.ToolboxName = 'FlowRegistration';
    toolboxInfo.FunctionName = 'OF_options';
    toolboxInfo.FolderExcludeTokens = {'.git', 'demos'};
    
    pathList = nansen.toolbox.getToolboxDependencyList(toolboxInfo);
    % Todo: need normcorre functions as well..
end