function newSessionObjects = detectNewSessions(metaTable, dataLocationType)


    import nansen.dataio.session.listSessionFolders
    import nansen.dataio.session.matchSessionFolders
    
    global dataLocationModel

    filePath = nansen.localpath('DataLocationSettings');
    dataLocationModel = nansen.setup.model.DataLocations(filePath);

    
    
% %     if nargin < 2 || isempty(dataLocationType)
% %         dataLocationType = dlModel.Data(1).Name;
% %     end
% %     
% %     msg = sprintf('Data location type (%s) is not configured', dataLocationType);
% %     assert(contains(dataLocationType, {dlModel.Data.Name}), msg)

    %sessionSchema = @nansen.metadata.schema.vlab.TwoPhotonSession;
            
    % % Use the folder structure to detect session folders.
    sessionFolders = listSessionFolders(dataLocationModel, 'all');
    sessionFolders = matchSessionFolders(dataLocationModel, sessionFolders);

    
    if isempty(sessionFolders)
        return
    end

    % Todo: Get schema based on selection
    sessionSchema = @nansen.metadata.schema.vlab.TwoPhotonSession;

    
    % Create a list of session metadata objects
    numSessions = numel(sessionFolders);
    sessionArray = cell(numSessions, 1);
    for i = 1:numSessions
        sessionArray{i} = sessionSchema(sessionFolders(i));
    end

    sessionArray = cat(1, sessionArray{:});

    foundSessionIds = {sessionArray.sessionID};
    currentSessionIds = metaTable.entries{:, 'sessionID'};

    [~, iA] = setdiff( foundSessionIds, currentSessionIds, 'stable' );

    newSessionObjects = sessionArray(iA);
            
end
