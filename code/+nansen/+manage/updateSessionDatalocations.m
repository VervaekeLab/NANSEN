function sessionTable = updateSessionDatalocations(sessionTable, dataLocationModel)
%updateSessionDatalocations Update session data locations by rescanning
%file system and detecting folders matching the data location model.

    import nansen.dataio.session.listSessionFolders
    import nansen.dataio.session.matchSessionFolders
    
    % % Use the folder structure to detect session folders.
    sessionFolders = listSessionFolders(dataLocationModel, 'all');
    [sessionFolders, sessionIDs] = matchSessionFolders(dataLocationModel, sessionFolders);

    % Match sessions in table with sessionFolder (data locations)
    unresolvedIdx = [];
    
    sessionStructArray = table2struct(sessionTable.entries);
    
    for i = 1:size(sessionTable.entries, 1)
        
        thisSessionID = sessionTable.entries{i, 'sessionID'};
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

    sessionTable = nansen.metadata.temp.fixMetaTableDataLocations(...
        sessionTable, dataLocationModel);
    
end