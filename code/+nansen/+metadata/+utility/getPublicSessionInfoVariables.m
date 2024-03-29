function varNames = getPublicSessionInfoVariables(metaTable)
%getPublicSessionInfoVariables Get public session info variables
%
%   varNames = getPublicSessionInfoVariables(metaTable) returns only those 
%   variables in a session metatable that are public, meaning either 
%   user-defined or editable by the user
%

    % Todo: remove this? use getMetaTableVariableAttributes instead

    % All variable names
    columnVariables = metaTable.entries.Properties.VariableNames;
    
    % Remove those that are internal according to the session schema definition.
    %columnVariableIgnore = nansen.metadata.schema.generic.Session.InternalVariables;
    %columnVariables = setdiff(columnVariables, columnVariableIgnore, 'stable');
    
    
    varNamesUser = nansen.metadata.utility.getCustomTableVariableNames();
    columnVariables = intersect(columnVariables, varNamesUser, 'stable');
    
    % Remove those that are editable...
    funcHandles = nansen.metadata.utility.getCustomTableVariableFcn();

    columnVariableIgnore = {};
    
    if ~iscell(funcHandles); funcHandles = {funcHandles}; end
    for i = 1:numel(funcHandles)
        result = funcHandles{i}();
        if isa(result, 'nansen.metadata.abstract.TableVariable')
            if result.IS_EDITABLE
                thisName = result.getVariableName();
                columnVariableIgnore = [columnVariableIgnore, thisName];
            end
        end
    end
    
    varNames = setdiff(columnVariables, columnVariableIgnore, 'stable');

end