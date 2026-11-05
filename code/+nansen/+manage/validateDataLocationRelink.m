function report = validateDataLocationRelink(sessionTable, dataLocationModel)
%validateDataLocationRelink Check session IDs before a session table is relinked.
%
%   report = validateDataLocationRelink(sessionTable, dataLocationModel)
%   lists the session folders of every data location in dataLocationModel,
%   extracts a session ID from each folder and compares these IDs with the
%   sessionID column of sessionTable. nansen.manage.updateSessionDatalocations
%   relinks a table row to the session folders with the same session ID, so
%   the extracted IDs must include IDs that are in the table.
%
%   Errors:
%       NANSEN:DataLocations:MissingSessionIDColumn - sessionTable has no
%           sessionID column.
%       NANSEN:DataLocations:SessionIdentityMismatch - session IDs were
%           extracted, sessionTable has session IDs, and no ID is in both.
%
%   When no session ID is extracted, for example because the root folder of
%   each data location is missing on this computer, there are no IDs to
%   compare. The function then returns without an error, and
%   report.ExtractedSessionIDs is empty.
%
%   Output:
%       report - struct with the fields
%           DetectedSessionFolders : struct with one field per data
%               location, holding a cell array of session folder paths
%           MatchedSessionFolders : 1xN struct of session folders matched
%               across data locations, one element per extracted session ID
%           ExtractedSessionIDs : 1xN cell array of the session IDs that
%               were extracted from the session folders
%           TableSessionIDs : cell array of the session IDs in sessionTable
%           MatchingSessionIDs : extracted session IDs that are in
%               sessionTable
%           NumMatchingSessionIDs : number of MatchingSessionIDs
%
%   See also nansen.manage.updateSessionDatalocations,
%   nansen.dataio.session.matchSessionFolders

    arguments
        sessionTable (1,1) nansen.metadata.MetaTable
        dataLocationModel (1,1) nansen.config.dloc.DataLocationModel
    end

    import nansen.dataio.session.listSessionFolders
    import nansen.dataio.session.matchSessionFolders

    assertSessionIDColumnExists(sessionTable)

    detectedSessionFolders = listSessionFolders(dataLocationModel, 'all');
    try
        [sessionFolders, sessionIDs] = matchSessionFolders(...
            dataLocationModel, detectedSessionFolders);
    catch exception
        % matchSessionFolders throws this error when it extracts no session
        % ID, which includes the case where no session folders are found.
        if exception.identifier ~= "NANSEN:DataIO:NoMatchingSessionFolders"
            rethrow(exception)
        end
        sessionFolders = struct.empty(1, 0);
        sessionIDs = {};
    end

    sessionIDs = normalizeSessionIDList(sessionIDs);
    tableSessionIDs = getTableSessionIDs(sessionTable);
    matchingSessionIDs = intersect(sessionIDs, tableSessionIDs, 'stable');

    report = struct();
    report.DetectedSessionFolders = detectedSessionFolders;
    report.MatchedSessionFolders = sessionFolders;
    report.ExtractedSessionIDs = sessionIDs;
    report.TableSessionIDs = tableSessionIDs;
    report.MatchingSessionIDs = matchingSessionIDs;
    report.NumMatchingSessionIDs = numel(matchingSessionIDs);

    if ~isempty(sessionIDs) && ~isempty(tableSessionIDs) ...
            && isempty(matchingSessionIDs)
        error('NANSEN:DataLocations:SessionIdentityMismatch', '%s', ...
            createSessionIdentityMismatchError(...
                dataLocationModel, detectedSessionFolders, sessionIDs, tableSessionIDs))
    end
end

function assertSessionIDColumnExists(sessionTable)
    tableVariableNames = sessionTable.entries.Properties.VariableNames;
    if ~any(strcmp(tableVariableNames, 'sessionID'))
        error('NANSEN:DataLocations:MissingSessionIDColumn', ...
            ['Can not update data locations because the session table ', ...
            'does not have a sessionID column.'])
    end
end

function sessionIDs = getTableSessionIDs(sessionTable)
    sessionIDs = sessionTable.entries{:, 'sessionID'};
    sessionIDs = normalizeSessionIDList(sessionIDs);
end

function sessionIDs = normalizeSessionIDList(sessionIDs)
    if iscell(sessionIDs)
        sessionIDs = sessionIDs(:);
        for i = 1:numel(sessionIDs)
            sessionIDs{i} = convertSessionIDToChar(sessionIDs{i});
        end
    elseif isstring(sessionIDs)
        sessionIDs = cellstr(sessionIDs(:));
    elseif ischar(sessionIDs)
        sessionIDs = cellstr(sessionIDs);
    else
        sessionIDs = arrayfun(@convertSessionIDToChar, sessionIDs(:), ...
            'UniformOutput', false);
    end

    sessionIDs = sessionIDs(:)';
end

function sessionID = convertSessionIDToChar(sessionID)
    if iscell(sessionID)
        if isempty(sessionID)
            sessionID = '';
        else
            sessionID = convertSessionIDToChar(sessionID{1});
        end
    elseif isstring(sessionID)
        if isempty(sessionID)
            sessionID = '';
        else
            sessionID = char(sessionID);
        end
    elseif ischar(sessionID)
        return
    elseif isnumeric(sessionID)
        sessionID = num2str(sessionID);
    else
        sessionID = char(string(sessionID));
    end
end

function message = createSessionIdentityMismatchError(...
        dataLocationModel, sessionFolderList, sessionIDs, tableSessionIDs)

    header = createDetectedFoldersMessage(dataLocationModel, sessionFolderList);
    instruction = ['Session IDs are immutable for in-place data location ', ...
        'updates. If the Session ID definition was changed intentionally, ', ...
        'run nansen.configureProject to rebuild the session table.'];

    message = sprintf('%s\n\nFirst extracted IDs:\n%s\n\nFirst table IDs:\n%s\n\n%s', ...
        header, formatSessionIDPreview(sessionIDs), ...
        formatSessionIDPreview(tableSessionIDs), instruction);
end

function message = createDetectedFoldersMessage(dataLocationModel, sessionFolderList)
    dataLocationNames = {dataLocationModel.Data.Name};
    folderCounts = zeros(1, numel(dataLocationNames));

    for i = 1:numel(dataLocationNames)
        if isfield(sessionFolderList, dataLocationNames{i})
            folderCounts(i) = numel(sessionFolderList.(dataLocationNames{i}));
        end
    end

    detectedDataLocationIdx = find(folderCounts > 0);
    if numel(detectedDataLocationIdx) == 1
        idx = detectedDataLocationIdx;
        message = sprintf(['Detected %d session folders for "%s", ', ...
            'but none matched the table session IDs.'], ...
            folderCounts(idx), dataLocationNames{idx});
    else
        message = sprintf(['Detected session folders, but none matched ', ...
            'the table session IDs.\n\nDetected folder counts:\n%s'], ...
            formatDetectedFolderCounts(dataLocationNames, folderCounts));
    end
end

function countList = formatDetectedFolderCounts(dataLocationNames, folderCounts)
    countLines = cell(1, numel(dataLocationNames));
    for i = 1:numel(dataLocationNames)
        countLines{i} = sprintf('  %s: %d', ...
            dataLocationNames{i}, folderCounts(i));
    end
    countList = strjoin(countLines, sprintf('\n'));
end

function preview = formatSessionIDPreview(sessionIDs)
    numPreview = min(2, numel(sessionIDs));
    if numPreview == 0
        preview = '  <none>';
        return
    end

    previewLines = cell(1, numPreview);
    for i = 1:numPreview
        previewLines{i} = sprintf('  %s', sessionIDs{i});
    end
    preview = strjoin(previewLines, sprintf('\n'));
end
