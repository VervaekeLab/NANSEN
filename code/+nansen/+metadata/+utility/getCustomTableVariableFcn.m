function funcHandles = getCustomTableVariableFcn(varNames)

    %rename: varname2tablevarfunc

    if nargin < 1
        varNames = nansen.metadata.utility.getCustomTableVariableNames();
    end
    
    varname2fcn = @(name) str2func(strjoin({'tablevar', 'session', name}, '.'));
    
    if iscell(varNames)
        funcHandles = cellfun(@(name) varname2fcn(name), varNames, 'uni', false);
    else
        funcHandles = varname2fcn(varNames);
    end
        
    if iscell(funcHandles) && numel(funcHandles) == 1
        funcHandles = funcHandles{1}; 
    end
end