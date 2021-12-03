function completeSetup(app)
%completeSetup Finish the setup based on user configurations

    % Todo: Save the Data Location model and the filepath settings.


% % Save changes from data location and folder organization pages. 
    % Save the data location model
    app.DataLocationModel.refreshFilePath()
    app.DataLocationModel.save()

    % Set data location model to global
    global dataLocationModel
    dataLocationModel = app.DataLocationModel;
    

% % Save changes from data variables page 
    S = app.FPSUiTable.getUpdatedTableData();
    app.FPSEditor.setVariableList(S)
    app.FPSEditor.save()

    global dataFilePathModel
    dataFilePathModel = nansen.setup.model.FilePathSettingsEditor;


% % Use the folder structure to detect session folders.
    dataLocType = app.DataLocationModel.Data(1).Name; % select first. todo: generalize
    sessionFolders = nansen.dataio.session.listSessionFolders(app.DataLocationModel, dataLocType);


    % Convert to struct array. Todo: Make it work for multiple data
    % location types.
    sessionFolders = cell2struct(sessionFolders.(dataLocType), dataLocType, 1);

    % Todo: Create method for matching session folders from
    % different data location types.
    %dataLocations = app.DataLocationModel.listSessionFolders();

    if isempty(sessionFolders)
        title = 'No session folders were found';
        msg = 'No session folders were found';

        uialert(app.NansenSetupUIFigure, msg, title) % Todo: app gui needs a method, so that this works no matter what app.
        return
    end

  % % Create and save a MetaTable for detected sessions in the 
    % current project

    % Todo: Get schema based on selection
    sessionSchema = @nansen.metadata.schema.vlab.TwoPhotonSession;


% % % % % % TODO: Make this into a function (Initialize meta table)
    % Create a list of session metadata objects

    numSessions = numel(sessionFolders);
    sessionArray = cell(numSessions, 1);
    for i = 1:numSessions
        sessionArray{i} = sessionSchema(sessionFolders(i));
    end
    sessionArray = cat(1, sessionArray{:});

    % Initialize a MetaTable using the given session schema and the
    % detected session folders.
    metaTable = nansen.metadata.MetaTable.new(sessionArray);

    % Add default information for saving the metatable to a struct
    S = struct();
    S.MetaTableName = metaTable.createDefaultName;
    S.SavePath = nansen.ProjectManager.getProjectSubPath('MetaTable');
    S.IsDefault = true;
    S.IsMaster = true;

    % Save the metatable in the current project
    try
        metaTable.archive(S);
    catch ME
        % Todo: have some error handling here.
% %                 title = 'Could not save metadata table';
% %                 uialert(app.NansenSetupUIFigure, ME.message, title) 
    end

    %close(app.NansenSetupUIFigure)

    nansen


end