function completeSetup(hApp)
%completeSetup Finish the setup based on user configurations

% Todo: use this function instead of code inside appdesigner file

    % Todo: Save the Data Location model and the filepath settings.


% % Save changes from data location and folder organization pages. 
    % Save the data location model
    hApp.DataLocationModel.refreshFilePath()
    hApp.DataLocationModel.save()

    % Set data location model to global
    global dataLocationModel
    dataLocationModel = hApp.DataLocationModel;
    

% % Save changes from data variables page 
    S = hApp.FPSUiTable.getUpdatedTableData();
    hApp.FPSEditor.setVariableList(S)
    hApp.FPSEditor.save()

    global dataFilePathModel
    dataFilePathModel = nansen.setup.model.FilePathSettingsEditor;


    % Todo: Get schema based on selection
    sessionSchema = @nansen.metadata.schema.vlab.TwoPhotonSession;

    try
        nansen.config.initializeSessionTable(hApp.DataLocationModel, sessionSchema)

        % Open nansen app
        nansen

        % Close configuration app
        %close(app.NansenSetupUIFigure)
    catch ME
        uialert(hApp.NansenSetupUIFigure, ME.message, ME.identifier)
    end    

end