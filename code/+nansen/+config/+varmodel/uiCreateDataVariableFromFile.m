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
%   The form stays open until its values can be used, or until the dialog
%   is cancelled. The variable name must be a valid MATLAB identifier that
%   no other variable uses.
%
%   The file name expression is pre-filled with the file name without the
%   session ID, or * when nothing else remains. A variable created from a
%   file has to search for it, so the expression cannot be left empty and
%   must match the file.

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
        [fileName, ext], sessionObject.sessionID);
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

    % Open user dialog
    getProblems = @(values) getInputProblems(values, variableModel, [fileName, ext]); % Local function

    [S, wasAborted] = tools.editStruct(S, [], 'Create New Variable', nvPairs{:}, ...
        'ValidationFcn', getProblems);

    if wasAborted
        return
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

function problems = getInputProblems(S, variableModel, fileName)
%getInputProblems - Why the entered values cannot be used for a new variable
%   The result has one element for each checked field, which is empty
%   text when the value of that field can be used.

    arguments
        S (1,1) struct
        variableModel
        fileName
    end

    problems = [getNameProblem(S, variableModel), ...
        string(getExpressionProblem(S, variableModel, fileName))];
end

function problem = getNameProblem(S, variableModel)
%getNameProblem - Why the entered name cannot be used for a new variable
%   Session objects expose each variable as a dynamic property, so a name
%   has to be a valid MATLAB identifier. The result is "" when the name
%   is absent from the form, or when it is valid and no other variable
%   uses it.

    arguments
        S (1,1) struct
        variableModel
    end

    problem = "";

    if ~isfield(S, 'VariableName')
        return
    end

    if isempty(S.VariableName)
        problem = "Enter a name for the data variable.";

    elseif ~isvarname(S.VariableName)
        problem = sprintf("'%s' is not a valid data variable name. A name must " + ...
            "start with a letter and contain only letters, numbers and underscores.", S.VariableName);

    elseif any(variableModel.containsItem(S.VariableName))
        problem = sprintf("A data variable named '%s' already exists. Choose another name.", S.VariableName);
    end
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
