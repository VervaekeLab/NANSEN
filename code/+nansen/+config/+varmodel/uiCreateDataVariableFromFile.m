function varItem = uiCreateDataVariableFromFile(filePath, dataLocationName, sessionObject, options)
% uiCreateDataVariableFromFile - Open form where user can create new variable
%
%   Syntax
%       varItem = uiCreateDataVariableFromFile(filePath, dataLocationName, sessionObject)
%
%   Input Arguments:
%       filePath         : Absolute pathname for a file to create variable for
%       dataLocationName : Name (char) of data location the file belongs to
%       sessionObject    : Session object for the session which the given file
%                          belongs to
%
%   Output Arguments:
%       varItem          : Structure with specifications for new data variable.
%                          Empty if the dialog was cancelled.
%
%   The variable name must be a valid MATLAB identifier. If it is not, an
%   error dialog is shown and the form reopens with the entered values.
%
%   The file name expression is pre-filled with the file name without the
%   session ID, or * when nothing else remains. A variable created from a
%   file has to search for it, so the expression cannot be left empty and
%   must match the file. Otherwise the form reopens as well.

%   Todo:
%       [ ] Make dataLocationName and sessionObject optional inputs?

    arguments
        filePath
        dataLocationName
        sessionObject
        options.SkipFields (1,:) string = string.empty
        options.Prompt (1,1) string = missing
    end

    varItem = struct.empty;

    [folder, fileName, ext] = fileparts(filePath);

    % Get variable model from the sessionobject / dataiomodel
    variableModel = sessionObject.VariableModel;

    fileAdapterList = nansen.dataio.listFileAdapters(ext);

    % Create a struct with fields that are required from user
    S = struct();
    S.VariableName = '';
    S.FileNameExpression = variableModel.suggestFileNameExpression( ...
        fileName, sessionObject.sessionID);
    S.FileAdapter = fileAdapterList(1).FileAdapterName;
    S.FileAdapter_ = {fileAdapterList.FileAdapterName};
    S.Favorite = false;

    if ~isempty(options.SkipFields)
        S = rmfield(S, options.SkipFields);
    end

    if ismissing(options.Prompt)
        nvPairs = {};
    else
        nvPairs = {'Prompt', options.Prompt};
    end

    % Open user dialog. A name that is not a valid MATLAB identifier can
    % not become a data variable, and a variable created from a file has
    % to find that file, so the dialog reopens with the entered values
    % until both are valid or the dialog is cancelled.
    isInputValid = false;
    while ~isInputValid
        [S, wasAborted] = tools.editStruct(S, [], 'Create New Variable', nvPairs{:});
        if wasAborted; return; end

        isNameValid = ~isfield(S, 'VariableName') || isvarname(S.VariableName);
        if ~isNameValid
            message = sprintf(['"%s" is not a valid data variable name. ', ...
                'A name must start with a letter and contain only letters, ', ...
                'numbers and underscores.'], S.VariableName);
            uiwait( errordlg(message, 'Invalid Variable Name', 'modal') )
            continue
        end

        expressionProblem = getExpressionProblem(S, variableModel, [fileName, ext]); % Local function
        if ~isempty(expressionProblem)
            uiwait( errordlg(expressionProblem, 'Invalid File Name Expression', 'modal') )
            continue
        end

        isInputValid = true;
    end
    S = rmfield(S, 'FileAdapter_');

    % Add other fields that are required for the variable model.

    % Create a new data variable item
    if isfield(S, 'VariableName')
        varItem = variableModel.getDefaultItem(S.VariableName);
    else
        varItem = variableModel.getDefaultItem('Dummy');
    end
    varItem.IsCustom = true;
    varItem.DataLocation = dataLocationName;
    if isfield(S, 'FileNameExpression')
        varItem.FileNameExpression = S.FileNameExpression;
    end
    varItem.FileType = ext;
    if isfield(S, 'FileAdapter')
        varItem.FileAdapter = S.FileAdapter;
    end
    if isfield(S, 'Favorite')
        varItem.IsFavorite = S.Favorite;
    end

    % Get the data location uuid for the given data location
    dloc = sessionObject.getDataLocation(dataLocationName);
    varItem.DataLocationUuid = dloc.Uuid;

    % Determine if file is located in a session subfolder
    sessionFolder = sessionObject.getSessionFolder(dataLocationName);
    varItem.Subfolder = strrep(folder, sessionFolder, '');
    if strncmp(varItem.Subfolder, filesep, 1)
        varItem.Subfolder = varItem.Subfolder(2:end);
    end

    % Get data type from file adapter
    fileAdapterIdx = strcmp({fileAdapterList.FileAdapterName}, S.FileAdapter);

    % Normalize to char. Todo: Should support string type
    varItem.DataType = char( fileAdapterList(fileAdapterIdx).DataType );
end

function problem = getExpressionProblem(S, variableModel, fileName)
%getExpressionProblem - Why the entered expression cannot find the file
%   The result is empty when the expression is absent from the form, or
%   when it is non-empty and matches the file.
    problem = '';
    if ~isfield(S, 'FileNameExpression'); return; end

    [~, ~, fileType] = fileparts(fileName);

    if isempty(S.FileNameExpression)
        problem = ['Enter a file name expression. A variable created from a ', ...
            'file has to search for it, so the expression cannot be empty. ', ...
            'Use * to match any file of this type.'];
    elseif ~variableModel.isFileNameMatch(fileName, S.FileNameExpression, fileType)
        problem = sprintf(['The file name expression "%s" does not match the ', ...
            'file "%s". Enter a part of the file name, or * to match any ', ...
            'file of this type.'], S.FileNameExpression, fileName);
    end
end
