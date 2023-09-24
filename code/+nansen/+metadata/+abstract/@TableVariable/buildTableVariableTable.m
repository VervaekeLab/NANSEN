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
%       - Name : Name of the table variable. (Todo: Should this be of the form TableType.Name, see next line). 
%       - TableType : Name of table type this variable is defined for (Todo: Is this needed?) I.e do we ever want the same name for variables from different tables? 
%       - IsCustom : Whether table variable is custom. Consider removing
%       - IsEditable: Whether table variable is editable
%       - HasUpdateFunction: Whether table variable has update function.
%       - UpdateFunctionName: Full name, including package prefix
%       - HasRendererFunction: Whether table variable has renderer function.
%       - RendererFunctionName: Full name, including package prefix

    
    % Todo:
    %   [ ] Generalize so this is not session only.

    % Table variables as they are implemented now:
    %
    % A session has public properties. These are default table variables,
    % i.e not custom. 
    %
    % IsEditable is an attribute. Default table variables are not editable.
    % A table variable becomes editable if the class definition has a
    % constant IsEditable=true property.
    

    
    import nansen.metadata.abstract.TableVariable.getDefaultSessionVariables
    import nansen.metadata.abstract.TableVariable.getDefaultTableVariableAttribute;

    defaultAttributes = getDefaultTableVariableAttribute();
    
    numFiles = numel(fileList);
    S = repmat(defaultAttributes, 1, numFiles);
    
    count = 1;

    defaultVariables = getDefaultSessionVariables();

    % Loop through pre-defined variables for table class
    for iFile = 1:numFiles

        thisFilePath = utility.dir.abspath(fileList(iFile));
        thisFilePath = thisFilePath{1};
        thisFcnName = utility.path.abspath2funcname(thisFilePath);
        fcnNameSplit = strsplit(thisFcnName, '.');
        
        S(count).Name = fcnNameSplit{end};
        S(count).TableType = fcnNameSplit{end-1};
        S(count).IsCustom = ~any(strcmp(defaultVariables, fcnNameSplit{end}));

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

            if isprop(fcnResult, 'LIST_ALTERNATIVES')
                S(count).HasOptions = true;
                S(count).OptionsList = {fcnResult.LIST_ALTERNATIVES};
            end
            
            if ismethod(fcnResult, 'update')
            	S(count).HasUpdateFunction = true;
                S(count).UpdateFunctionName = func2str(varFunction);
            end
        else
            S(count).HasUpdateFunction = true;
            S(count).UpdateFunctionName = thisFcnName;
        end

        if isa(fcnResult, 'nansen.metadata.abstract.TableColumnFormatter')
            S(count).HasRendererFunction = true;
            S(count).RendererFunctionName = thisFcnName;
        end

        count = count+1;
    end

    % Trim in case not all files yielded valid table variables
    S = S(1:count-1);

    % Add all default variables that are not part of the table.
    remainingDefaultVariables = setdiff(defaultVariables, {S.Name});
    
    % Expand S.
    S = [S, repmat(defaultAttributes, 1, numel(remainingDefaultVariables))];
    
    for i = 1:numel(remainingDefaultVariables)
        S(count).Name = remainingDefaultVariables{i};
        S(count).TableType = 'session';
        S(count).IsCustom = false;
        count = count + 1;
    end
    
    % Order fields by placing default variables first.
    isCustom = [S.IsCustom];
    fieldOrder = [defaultVariables, setdiff({S(isCustom).Name}, defaultVariables)];
    [~, fieldOrderInd] = ismember(fieldOrder, {S.Name});
    S = S(fieldOrderInd);
    
    attributeTable = struct2table(S);
    attributeTable.TableType = string(attributeTable.TableType);
end
