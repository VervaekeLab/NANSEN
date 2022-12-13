function newSessionArray = detectNewSessions(metaTable, dataLocationName)
%detectNewSessions Detect new sessions associated with a metatable
%
%   newSessionArray = detectNewSessions(metaTable, dataLocationName)
%   look for session folders based on the current datalocation model 
%   (i.e current project) and make a list of session objects based on
%   folders. Session objects for all sessions that are not present in the
%   table is returned.
%   
%   INPUTS:
%       metaTable : a session metatable
%       dataLocationName : (Optional) Name of datalocation. Default is 'all'

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

    newSessionArray = sessionArray(iA);
    
    % todo: deprecated?
    sessionArray = validateDataLocationStruct(metaTable, ...
        sessionArray, dataLocationModel); % local function
    
    % Check for duplicate session IDs
    sessionIDs = {newSessionArray.sessionID};
    if numel(sessionIDs) ~= numel(unique(sessionIDs))
        [newSessionArray, wasCanceled] = nansen.manage.uiresolveDuplicateSessions(newSessionArray, []);
        % Todo: Rerun detection from here if sessions were resolved
        if wasCanceled
            newSessionArray = [];
            return
        end
    end       
end

function sessionArray = validateDataLocationStruct(metaTable, sessionArray, dataLocationModel)
    
    % Make sure data location format is the same for the new sessions
    % Todo: This should not be necessary, just make sure from the get-go
    % that all datalocations structs are "extended"
    dataLocationOriginal = metaTable.entries{1, 'DataLocation'};
    if iscell(dataLocationOriginal)
        dataLocationOriginal = dataLocationOriginal{1};
    end

    fieldsOriginal = fieldnames(dataLocationOriginal);
    dataLocationNew = sessionArray(1).DataLocation;
    fieldNamesNew = fieldnames(dataLocationNew);
    
    if numel(fieldsOriginal) ~= numel(fieldNamesNew)
        if numel(fieldNamesNew) > numel(fieldsOriginal)
            for i = 1:numel(sessionArray)
                sessionArray(i).DataLocation = ...
                    dataLocationModel.reduceDataLocationInfo(...
                    sessionArray(i).DataLocation);
            end
        else
            error('Not implemented yet. Please report')
        end
    end
end
