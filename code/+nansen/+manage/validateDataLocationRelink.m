function report = validateDataLocationRelink(sessionTable, dataLocationModel)
%validateDataLocationRelink Validate in-place datalocation relinking.
%
%   report = validateDataLocationRelink(sessionTable, dataLocationModel)
%   verifies that session ids extracted with the given DataLocationModel
%   overlap with the immutable session ids in the existing session table.

    import nansen.dataio.session.listSessionFolders
    import nansen.dataio.session.matchSessionFolders

    assertSessionIDColumnExists(sessionTable)

    detectedSessionFolders = listSessionFolders(dataLocationModel, 'all');
    try
        [sessionFolders, sessionIDs] = matchSessionFolders(...
            dataLocationModel, detectedSessionFolders);
    catch exception
        switch exception.identifier
            case 'NANSEN:DataIO:NoMatchingSessionFolders'
                error('NANSEN:DataLocations:NoMatchingSessionFolders', ...
                    ['No session folders were detected using the current ', ...
                    'DataLocationModel. Please check the DataLocationModel configuration.'])
            otherwise
                rethrow(exception)
        end
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
