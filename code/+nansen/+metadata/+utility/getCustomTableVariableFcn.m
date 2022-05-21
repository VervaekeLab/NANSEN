function funcHandles = getCustomTableVariableFcn(varNames, projectName)

    %rename: varname2tablevarfunc

    if nargin < 1
        varNames = nansen.metadata.utility.getCustomTableVariableNames();
    end
    
    if nargin < 2
        projectName = getpref('Nansen', 'CurrentProject');
    end
    
    packageList = {projectName, 'tablevar', 'session'};
    
    varname2fcn = @(name) str2func(strjoin([ packageList, name], '.'));
    
    if iscell(varNames)
        funcHandles = cellfun(@(name) varname2fcn(name), varNames, 'uni', false);
    else
        funcHandles = varname2fcn(varNames);
    end
        
    if iscell(funcHandles) && numel(funcHandles) == 1
        funcHandles = funcHandles{1}; 
    end
end