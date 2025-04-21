function varItem = uiCreateDataVariableFromFile(filePath, dataLocationName, sessionObject)
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
%       varItem          : Structure with specifications for new data variable

%   Todo:
%       [ ] Make dataLocationName and sessionObject optional inputs?

    varItem = struct.empty;

    [folder, fileName, ext] = fileparts(filePath);

    % Get variable model from the sessionobject / dataiomodel
    variableModel = sessionObject.VariableModel;

    fileAdapterList = nansen.dataio.listFileAdapters(ext);

    % Remove session ID from filename
    fileName = strrep(fileName, sessionObject.sessionID, '');
    
    % Create a struct with fields that are required from user
    S = struct();
    S.VariableName = '';
    S.FileNameExpression = fileName;
    S.FileAdapter = fileAdapterList(1).FileAdapterName;
    S.FileAdapter_ = {fileAdapterList.FileAdapterName};
    S.Favorite = false;
    
    % Open user dialog:
    [S, wasAborted] = tools.editStruct(S, [], 'Create New Variable');
    S = rmfield(S, 'FileAdapter_');
    if wasAborted; return; end
    
    % Add other fields that are required for the variable model.

    % Create a new data variable item
    varItem = variableModel.getDefaultItem(S.VariableName);
    varItem.IsCustom = true;
    varItem.IsFavorite = S.Favorite;
    varItem.DataLocation = dataLocationName;
    varItem.FileNameExpression = S.FileNameExpression;
    varItem.FileType = ext;
    varItem.FileAdapter = S.FileAdapter;
    
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
    varItem.DataType = fileAdapterList(fileAdapterIdx).DataType;
end
