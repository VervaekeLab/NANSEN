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

    
    % Initialize output
    S = struct('Name', {}, 'IsCustom', {}, 'IsEditable', {}, 'HasFunction', {});

    
    % Get variables that are predefined in the given tableClass
    switch tableClassName
        case 'session'
            % Todo: This is temporary. Retrieve project template
            className = 'nansen.metadata.schema.vlab.TwoPhotonSession';

            mc = meta.class.fromName(className);
            isStatic = [mc.PropertyList.Constant];
            varNamesSchema = {mc.PropertyList(~isStatic).Name};
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
        
        
        % Check the custom variable definition for attribute values
        if contains(S(iVar).Name, varNamesCustom)
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
                end
                
            else
                S(iVar).HasFunction = true;
            end
        else
            functionName = ['nansen.metadata.tablevar.', S(iVar).Name];
            mc = meta.class.fromName(functionName);
            if ~isempty(mc)
                if any( strcmp({mc.MethodList.Name}, 'update') )
                    S(iVar).HasFunction = true;
                end
            end
        end
         
    end
    
end
        
        