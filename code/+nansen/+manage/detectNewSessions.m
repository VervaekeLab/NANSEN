function newSessionObjects = detectNewSessions(metaTable, dataLocationName)
%detectNewSessions Detect new sessions associated with a metatable
%
%   newSessionObjects = detectNewSessions(metaTable, dataLocationName)
%   look for session folders based on the current datalocation model 
%   (i.e current project) and make a list of session objects based on
%   folders. Session objects for all sessions that are not present in the
%   table is returned.
%   
%   INPUTS:
%       metaTable : a session metatable
%       dataLocationName : (Optional) Name of datalocation. Default is 'all'
%
    
    import nansen.dataio.session.listSessionFolders
    import nansen.dataio.session.matchSessionFolders
    
    % Get current data location model. Todo: What if there are situations
    % where another datalocation model should be used?
    filePath = nansen.localpath('DataLocationSettings');    
    dataLocationModel = nansen.config.dloc.DataLocationModel(filePath);
    
    
    if nargin < 2 || isempty(dataLocationName)
        %dataLocationName = dataLocationModel.DefaultDataLocation;
        dataLocationName = 'all';
    end
    
    if ~strcmp(dataLocationName, 'all')
        msg = sprintf('Data location (%s) does not exist', dataLocationName);
        assert(any(dataLocationModel.containsItem(dataLocationName)), msg)
    end
    
    % % Use the folder structure to detect session folders.
    sessionFolders = listSessionFolders(dataLocationModel, 'all');
    sessionFolders = matchSessionFolders(dataLocationModel, sessionFolders);
    
    if isempty(sessionFolders)
        return
    end

    % Todo: Get schema based on selection
    sessionSchema = @nansen.metadata.type.Session;
    args = {'DataLocationModel', dataLocationModel};
    
    % Create a list of session metadata objects
    numSessions = numel(sessionFolders);
    sessionArray = cell(numSessions, 1);
    for i = 1:numSessions
        sessionArray{i} = sessionSchema(sessionFolders(i), args{:});
    end

    sessionArray = cat(1, sessionArray{:});

    foundSessionIds = {sessionArray.sessionID};
    currentSessionIds = metaTable.entries{:, 'sessionID'};

    [~, iA] = setdiff( foundSessionIds, currentSessionIds, 'stable' );

    newSessionObjects = sessionArray(iA);
            
end
