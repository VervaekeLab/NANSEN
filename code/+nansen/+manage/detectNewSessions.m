function sessionArray = detectNewSessions(metaTable, dataLocationType)


    filePath = nansen.localpath('DataLocationSettings');
    dlModel = nansen.setup.model.DataLocations(filePath);

    if nargin < 2 || isempty(dataLocationType)
        dataLocationType = dlModel.Data(1).Name;
    end
    
    msg = sprintf('Data location type (%s) is not configured', dataLocationType);
    assert(contains(dataLocationType, {dlModel.Data.Name}), msg)
    
    
    % % Use the folder structure to detect session folders.
    sessionFolders = nansen.dataio.session.listSessionFolders(dlModel, dataLocationType);
    sessionFolders = sessionFolders.(dataLocationType);
    
    existingDataLocs = arrayfun(@(s) s.Rawdata, metaTable.entries.DataLocation, 'uni', 0);
    existingSessionFolders = existingDataLocs;
    
    newSessionFolders = setdiff(sessionFolders, existingSessionFolders);
    
    % Convert to struct array. Todo: Make it work for multiple data
    % location types.
    newSessionFolders = cell2struct(newSessionFolders, ...
        dataLocationType, 1);
    
    % Todo: Create method for matching session folders from
    % different data location types.
    %dataLocations = app.DataLocationModel.listSessionFolders();

% % %     if isempty(newSessionFolders)
% % %         title = 'No session folders were found';
% % %         msg = 'No session folders were found';
% % % 
% % %         uialert(app.NansenSetupUIFigure, msg, title)
% % %         return
% % %     end

  % % Create and save a MetaTable for detected sessions in the 
    % current project

    % Todo: Get schema based on selection
    sessionSchema = @nansen.metadata.schema.vlab.TwoPhotonSession;

% % % % % % TODO: Make this into a function (Initialize meta table)
    % Create a list of session metadata objects

    dataLocations = {dlModel.Data.Name};
    numDataLocations = numel(dataLocations);

    numSessions = numel(newSessionFolders);
    sessionArray = cell(numSessions, 1);
    for i = 1:numSessions
        sessionArray{i} = sessionSchema(newSessionFolders(i));
        for j = 2:numDataLocations % Skip first
            sessionArray{i}.createSessionFolder(dataLocations{j})
        end
    end
    sessionArray = cat(1, sessionArray{:});

end
