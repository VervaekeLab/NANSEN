function attributeTable = buildTableVariableTable(fileList)
%buildTableVariableTable Build table variable info table from list of files.
%
%   attributeTable = buildTableVariableTable(fileList) returns a table 
%   where each row represents information for a table variable. fileList 
%   is a list (struct array) of file attributes as returned by the dir 
%   function. If elements in the list does not represent a table variable, 
%   they are ignored.
%
%   The attributeTable contains the following variables:
%       - Name : Name of the table variable. (Todo: Should this be of the form TableType.Name, see next line). 
%       - TableType : Name of table type this variable is defined for 
%       - IsCustom : Whether table variable is custom. Consider removing
%       - IsEditable: Whether table variable is editable
%       - HasClassDefinition: Whether table variable is defined by a class.
%       - HasUpdateFunction: Whether table variable has update function.
%       - UpdateFunctionName: Full name, including package prefix
%       - HasRendererFunction: Whether table variable has renderer function.
%       - RendererFunctionName: Full name, including package prefix
%       - HasDoubleClickFunction:  Whether table variable has double click function.
%       - DoubleClickFunctionName: Full name, including package prefix

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

    import nansen.metadata.abstract.TableVariable.getDefaultTableVariables;
    import nansen.metadata.abstract.TableVariable.getDefaultTableVariableAttribute;

    % Todo: Get this from input.
    supportedTypes = [...
        "nansen.metadata.type.Session", ...
        "nansen.metadata.type.Subject" ];

    defaultAttributes = getDefaultTableVariableAttribute();
    

    % Initialize the table based on default variables.
    for i = 1:numel(supportedTypes)
        iDefaultVariables = getDefaultTableVariables(supportedTypes(i));
        if i == 1
            defaultVariables = iDefaultVariables;
        else
            defaultVariables = [defaultVariables, iDefaultVariables]; %#ok<AGROW>
        end
    end

    numDefaultVariables = numel(defaultVariables);
    S = repmat(defaultAttributes, 1, numDefaultVariables);
    [S(:).Name] = deal(defaultVariables.Name);
    [S(:).TableType] = deal(defaultVariables.TableType);
    
    % Loop through the pre-defined / custom table variable file list
    % Loop through pre-defined variables for table class
    numFiles = numel(fileList);
    for iFile = 1:numFiles

        thisFilePath = utility.dir.abspath(fileList(iFile));
        thisFilePath = thisFilePath{1};
        thisFcnName = utility.path.abspath2funcname(thisFilePath);
        fcnNameSplit = strsplit(thisFcnName, '.');
        
        thisName = fcnNameSplit{end};
        thisTableType = fcnNameSplit{end-1};

        isMatch = strcmp({S.Name}, thisName) & strcmp({S.TableType}, thisTableType);
        
        if ~any(isMatch)
            idx = numel(S) + 1;
            S(idx) = defaultAttributes;
            S(idx).Name = thisName;
            S(idx).TableType = thisTableType;
            S(idx).IsCustom = true;
        else
            idx = find(isMatch);
        end


        try
            fcnResult = feval(thisFcnName);
        catch
            % Not a valid table variable
            warning('File %s is located in a table variable package, but does not appear to be a valid table variable', thisFilePath)
            continue
        end

        if isa(fcnResult, 'nansen.metadata.abstract.TableVariable')
            
            S(idx).HasClassDefinition = true;

            if fcnResult.IS_EDITABLE
                S(idx).IsEditable = true;
            end

            if isprop(fcnResult, 'LIST_ALTERNATIVES')
                S(idx).HasOptions = true;
                S(idx).OptionsList = {fcnResult.LIST_ALTERNATIVES};
            end
            
            if ismethod(fcnResult, 'update')
                updateFcnName = strjoin({thisFcnName, 'update'}, '.');
            	S(idx).HasUpdateFunction = true;
                S(idx).UpdateFunctionName = updateFcnName;
            end

            if ismethod(fcnResult, 'onCellDoubleClick')
                doubleClickFcnName = strjoin({thisFcnName, 'onCellDoubleClick'}, '.');
            	S(idx).HasDoubleClickFunction = true;
                S(idx).DoubleClickFunctionName = doubleClickFcnName;
            end
        else
            S(idx).HasUpdateFunction = true;
            S(idx).UpdateFunctionName = thisFcnName;
        end

        if isa(fcnResult, 'nansen.metadata.abstract.TableColumnFormatter')
            S(idx).HasRendererFunction = true;
            S(idx).RendererFunctionName = thisFcnName;
        end
    end
    
    attributeTable = struct2table(S);
    attributeTable.TableType = string(attributeTable.TableType);
end
