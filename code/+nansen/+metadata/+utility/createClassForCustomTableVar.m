function createClassForCustomTableVar(initializationStruct)
%createClassForCustomTableVar Create class template for custom var
    
    % Todo: second input that signals if the template file should be opened
    % in the editor.
    
    variableName = initializationStruct.VariableName;
    tableClass = initializationStruct.MetadataClass;
    dataType = initializationStruct.DataType;
    
    % Make sure the variable name is valid
    assert(isvarname(variableName), '%s is not a valid variable name', variableName)
    
    % Get the path for the template function
    rootPathSource = nansen.rootpath;
    fcnSourcePath = fullfile(rootPathSource, '+metadata', '+tablevar', 'TemplateVariable.m');
    
    % Modify the template function by adding the variable name
    fcnContentStr = fileread(fcnSourcePath);
    fcnContentStr = strrep(fcnContentStr, 'TemplateVariable', variableName);
    fcnContentStr = strrep(fcnContentStr, 'TEMPLATEVARIABLE', upper(variableName));
    %fcnContentStr = strrep(fcnContentStr, 'metadata', lower(tableClass));

    % Edit initialization of output (default value)
    defaultValue = getDefaultValueAsChar(dataType);
    valueExpr = sprintf('DEFAULT_VALUE = %s', defaultValue);
    fcnContentStr = strrep(fcnContentStr, 'DEFAULT_VALUE = []', valueExpr);
    
    % Edit attribute for whether variable is editable or not
    if strcmp(initializationStruct.InputMode, 'Manual')
        fcnContentStr = strrep(fcnContentStr, 'IS_EDITABLE = false', ...
                                'IS_EDITABLE = true');
    end
    
    % Create a target path for the function. Place it in the current
    % project folder.
    rootPathTarget = nansen.localpath('Custom Metatable Variable', 'current');
    fcnTargetPath = fullfile(rootPathTarget, ['+', lower(tableClass)] );
    fcnFilename = [variableName, '.m'];
    
    if ~exist(fcnTargetPath, 'dir'); mkdir(fcnTargetPath); end
    
    % Create a new m-file and add the function template to the file.
    fid = fopen(fullfile(fcnTargetPath, fcnFilename), 'w');
    fwrite(fid, fcnContentStr);
    fclose(fid);
    
    % Finally, open the function in the matlab editor.
    % edit(fullfile(fcnTargetPath, fcnFilename))
    
end

function defaultValue = getDefaultValueAsChar(dataType)

    switch dataType
        case 'logical (true)'
            defaultValue = 'true';
        case 'logical (false)'
            defaultValue = 'false';
        case 'numeric'
            defaultValue = 'nan';
        case 'char'
            defaultValue = '{''N/A''}'; 
    end
            
end
