function attributeTable = buildTableVariableTable(fileList)
%buildTableVariableTable Build table variable info table from list of files.
%
%   attributeTable = buildTableVariableTable(fileList) returns a
%   table where each row represents information for a table variable.
%   fileList is a list (struct array) of file attributes as
%   returned by the dir function. If elements in the list does not
%   represent a table variable, they are ignored.
%
%   The attributeTable contains the following variables:
%       - Name : Name of the table variable 
%       - IsCustom : Whether table variable is custom. Consider removing
%       - IsEditable: Whether table variable is editable
%       - HasFunction: Whether table variable has function. Consider making this always true
%       - FunctionName: Full name, including package prefix

    % Table variables as they are implemented now:
    %
    % A session has public properties. These are default table variables,
    % i.e not custom. 
    %
    % IsEditable is an attribute. Default table variables are not editable.
    % A table variable becomes editable if the class definition has a
    % constant IsEditable=true property.
    
    % Todo:
    % Generalize so this is not session only.
    
    import nansen.metadata.abstract.TableVariable.getDefaultSessionVariables

    S = struct(...
        'Name', {},...
        'IsCustom', {}, ...
        'IsEditable', {}, ...
        'HasFunction', {}, ...
        'FunctionName', {});

    count = 1;

    defaultVariables = getDefaultSessionVariables();

    % Loop through pre-defined variables for table class
    for iFile = 1:numel(fileList)

        thisFilePath = utility.dir.abspath(fileList(iFile));
        thisFcnName = utility.path.abspath2funcname(thisFilePath);
        [~, thisName] = fileparts(fileList(iFile).name);

        S(count).Name = thisName;
        S(count).IsCustom = ~any(strcmp(defaultVariables, thisName));
        S(count).IsEditable = false; % Default assumption
        S(count).HasFunction = false; % Default assumption

        try
            fcnResult = feval(thisFcnName);
        catch
            % Not a valid table variable
            warning('File %s is located in a table variable package, but does not appear to be a valid table variable', thisFilePath)
            continue
        end

        if isa(fcnResult, 'nansen.metadata.abstract.TableVariable')
            if fcnResult.IS_EDITABLE
                S(count).IsEditable = true;
            end
% % %             if isprop(fcnResult, 'LIST_ALTERNATIVES')
% % %                 S(iVar).List = {fcnResult.LIST_ALTERNATIVES};
% % %             end
            
            if ismethod(fcnResult, 'update')
            	S(count).HasFunction = true;
                S(count).FunctionName = func2str(varFunction);
            end
            
        else
            S(count).HasFunction = true;
            S(count).FunctionName = thisFcnName;
        end

        count = count+1;
    end

    % Add all default variables that are not part of the table.
    remainingDefaultVariables = setdiff(defaultVariables, {S.Name});
    for i = 1:numel(remainingDefaultVariables)
        S(count).Name = remainingDefaultVariables{i};
        S(count).IsCustom = false;
        S(count).IsEditable = false; % Default assumption
        S(count).HasFunction = false; % Default assumption
        count = count + 1;
    end
    
    % Order fields by placing default variables first.
    isCustom = [S.IsCustom];
    fieldOrder = [defaultVariables, setdiff({S(isCustom).Name}, defaultVariables)];
    [~, fieldOrderInd] = ismember(fieldOrder, {S.Name});
    S = S(fieldOrderInd);
    
    attributeTable = struct2table(S);
end
