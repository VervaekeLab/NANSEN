function sessionTable = updateSessionDatalocations(sessionTable, dataLocationModel)
%updateSessionDatalocations Update session data locations by rescanning
%file system and detecting folders matching the data location model.

% Todo: Should this be a method of the model?

    import nansen.dataio.session.listSessionFolders
    import nansen.dataio.session.matchSessionFolders
    
    % % Use the folder structure to detect session folders.
    detectedSessionFolders = listSessionFolders(dataLocationModel, 'all');
    try
        [sessionFolders, sessionIDs] = matchSessionFolders(dataLocationModel, detectedSessionFolders);
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
    if ~isempty(sessionIDs) && ~isempty(tableSessionIDs) ...
            && ~any(ismember(sessionIDs, tableSessionIDs))
        error('NANSEN:DataLocations:NoMatchingTableSessionIDs', '%s', ...
            createNoMatchingSessionIDsError(...
                dataLocationModel, detectedSessionFolders, sessionIDs, tableSessionIDs))
    end

    % Match sessions in table with sessionFolder (data locations)
    unresolvedIdx = [];
    
    sessionStructArray = table2struct(sessionTable.entries);
    
    for i = 1:size(sessionTable.entries, 1)
        
        thisSessionID = tableSessionIDs{i};
        matchedIdx = find(strcmp(sessionIDs, thisSessionID));
        
        if isempty(matchedIdx)
            continue
        elseif numel(matchedIdx) == 1
            % pass
        else
            unresolvedIdx = [unresolvedIdx, i];
            continue
        end
        sessionStructArray(i).DataLocation = sessionFolders(matchedIdx);
    end
    
    if ~isempty(unresolvedIdx)
        %Todo
        warning('Some sessions had multiple datalocations')
    end
    
    % Update the session table
    newDataLocation = arrayfun(@(s) s.DataLocation, sessionStructArray, 'uni', 0);
    
    sessionTable.replaceDataColumn('DataLocation', newDataLocation );

    % Post hoc fix: Make sure structs are right format
    sessionTable = nansen.metadata.temp.fixMetaTableDataLocations(...
        sessionTable, dataLocationModel);
    
    % Another post hoc fix that ensures all struct fields are added.
    dataLocationStructs = sessionTable.entries.DataLocation;
    dataLocationStructs = dataLocationModel.validateDataLocationPaths(dataLocationStructs);
    siz_ = size(dataLocationStructs);
    dataLocationStructs_ = mat2cell(dataLocationStructs, ones(siz_(1),1), siz_(2));
    sessionTable.replaceDataColumn('DataLocation', dataLocationStructs_ );
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

function message = createNoMatchingSessionIDsError(...
        dataLocationModel, sessionFolderList, sessionIDs, tableSessionIDs)

    header = createDetectedFoldersMessage(dataLocationModel, sessionFolderList);
    message = sprintf('%s\n\nFirst extracted IDs:\n%s\n\nFirst table IDs:\n%s', ...
        header, formatSessionIDPreview(sessionIDs), ...
        formatSessionIDPreview(tableSessionIDs));
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
