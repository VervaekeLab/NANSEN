function S = getMetaTableVariableAttributes(tableClassName)
%getMetaTableVariableAttributes Get attributes of variables of metatable
%
%   S = getMetaTableVariableAttributes(tableClassName) returns a struct 
%   with attributes for the tablevariables that exists for a metatable of 
%   the given class.
%
%   Note: This function works on the current project


    % Todo:
    %   Add default value?
    %   Add list values for variables with list?
    %   Modify hasFunction attribute if classes are implemented with getValue method

    import nansen.metadata.utility.getCustomTableVariableNames
    import nansen.metadata.utility.getCustomTableVariableFcn

    if nargin < 1
        tableClassName = 'Session';
    end
    
    
    % Initialize output
    S = struct('Name', {}, 'IsCustom', {}, 'IsEditable', {}, 'HasFunction', {});

    
    % Get variables that are predefined in the given tableClass
    switch lower( tableClassName )
        case 'session'
            % Todo: This is temporary. Retrieve project template
            className = 'nansen.metadata.type.Session';
            mc = meta.class.fromName(className);
            isStatic = [mc.PropertyList.Constant];
            isTransient = [mc.PropertyList.Transient];
            varNamesSchema = {mc.PropertyList(~isStatic & ~isTransient).Name};
            varNamesCustom = getCustomTableVariableNames();

        otherwise
            error('The table class %s is not implemented yet', tableClassName)
    end
    
    varNames = union(varNamesSchema, varNamesCustom, 'stable');    
    
    % Loop through pre-defined variables for table class
    for iVar = 1:numel(varNames)
        
        S(iVar).Name = varNames{iVar};
        S(iVar).IsCustom = ~contains(varNames{iVar}, varNamesSchema);
        S(iVar).IsEditable = false; % Default assumption
        S(iVar).HasFunction = false; % Default assumption
        
        % Note: Custom variables takes precedence!
        % Check the custom variable definition for attribute values
        if any( strcmp(S(iVar).Name, varNamesCustom) )
            varFunction = getCustomTableVariableFcn(S(iVar).Name);
            fcnResult = varFunction();
            if isa(fcnResult, 'nansen.metadata.abstract.TableVariable')
                if fcnResult.IS_EDITABLE
                    S(iVar).IsEditable = true;
                end
% % %                 if isprop(fcnResult, 'LIST_ALTERNATIVES')
% % %                     S(iVar).List = {fcnResult.LIST_ALTERNATIVES};
% % %                 end
                
                if ismethod(fcnResult, 'update')
                	S(iVar).HasFunction = true;
                    S(iVar).FunctionName = func2str(varFunction);
                end
                
            else
                S(iVar).HasFunction = true;
                S(iVar).FunctionName = func2str(varFunction);
            end
        else % Fall back, and test for preset variable function
            functionName = ['nansen.metadata.tablevar.', S(iVar).Name];
            mc = meta.class.fromName(functionName);
            if ~isempty(mc)
                if any( strcmp({mc.MethodList.Name}, 'update') )
                    S(iVar).HasFunction = true;
                    S(iVar).FunctionName = sprintf('%s.update', functionName);
                end
            end
        end
    end
    
end
        