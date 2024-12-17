function createClassForCustomTableVar(S, targetFolderPath)
%createClassForCustomTableVar Create class template for custom var
    
    % Todo: third input that signals if the template file should be opened
    % in the editor.
    
    if nargin < 2 || isempty(targetFolderPath)
        project = nansen.getCurrentProject();
        targetFolderPath = project.getProjectPackagePath('Table Variables');
    end

    variableName = S.VariableName;
    tableClass = S.MetadataClass;
    dataType = S.DataType;
    
    % Make sure the variable name is valid
    assert(isvarname(variableName), '%s is not a valid variable name', variableName)
    
    % Get the path for the template function
    folderPathSource = nansen.common.constant.TableVariableTemplateDirectory();
    switch S.InputMode
        case 'Enter values manually'
            templateName = 'TemplateVariable';
            isEditable = true;
        case 'Get values from list'
            templateName = 'TemplateListVariable';
            isEditable = true;
        otherwise
            templateName = 'TemplateVariable';
            isEditable = false;
            % Unknown
    end

    fcnSourcePath = fullfile(folderPathSource, [templateName, '.m']);

    % Modify the template function by adding the variable name
    fcnContentStr = fileread(fcnSourcePath);
    fcnContentStr = strrep(fcnContentStr, templateName, variableName);
    fcnContentStr = strrep(fcnContentStr, upper(templateName), upper(variableName));
    %fcnContentStr = strrep(fcnContentStr, 'metadata', lower(tableClass));

    % Edit initialization of output (default value)
    defaultValue = nansen.metadata.utility.getDefaultValueAsChar(dataType);
    valueExpr = sprintf('DEFAULT_VALUE = %s', defaultValue);
    fcnContentStr = strrep(fcnContentStr, 'DEFAULT_VALUE = []', valueExpr);
    
    % Edit attribute for whether variable is editable or not
    if isEditable
        fcnContentStr = strrep(fcnContentStr, ...
            'IS_EDITABLE = false', 'IS_EDITABLE = true');
    end
    
    if strcmp( S.InputMode, 'Get values from list')
        oldExpr = 'LIST_ALTERNATIVES = {}';
        newExpr = sprintf('LIST_ALTERNATIVES = %s', cellarray2char(S.SelectionList));
        fcnContentStr = strrep(fcnContentStr, oldExpr, newExpr);
    end
    
    % Create a target path for the function. Place it in the current
    % project folder.
    fcnTargetPath = fullfile(targetFolderPath, ['+', lower(tableClass)] );
    fcnFilename = [variableName, '.m'];
    
    if ~isfolder(fcnTargetPath); mkdir(fcnTargetPath); end
    
    % Create a new m-file and add the function template to the file.
    fid = fopen(fullfile(fcnTargetPath, fcnFilename), 'w');
    fwrite(fid, fcnContentStr);
    fclose(fid);
    
    % Finally, open the function in the matlab editor.
    % edit(fullfile(fcnTargetPath, fcnFilename))
end

function charVector = cellarray2char(cellArray)
    cellArray = cellfun(@(c) sprintf('''%s''', c), cellArray, 'uni', 0);
    charVector = sprintf('{%s}', strjoin(cellArray, ','));
end
