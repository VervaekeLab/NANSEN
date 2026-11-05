function duplicateTable = buildDuplicateSessionTable(sessionArray)
%buildDuplicateSessionTable Build display data for duplicate session folders.
    arguments
        sessionArray
    end

    sessionIDs = string({sessionArray.sessionID}');
    uniqueSessionIDs = unique(sessionIDs, 'stable');
    occurrenceCount = arrayfun(@(id) nnz(sessionIDs == id), uniqueSessionIDs);
    duplicateSessionIDs = uniqueSessionIDs(occurrenceCount > 1);
    isDuplicate = ismember(sessionIDs, duplicateSessionIDs);

    duplicateIndices = find(isDuplicate);
    numDuplicates = numel(duplicateIndices);

    sessionID = strings(numDuplicates, 1);
    duplicateNumber = zeros(numDuplicates, 1);
    dataLocation = strings(numDuplicates, 1);
    folderPath = strings(numDuplicates, 1);

    for i = 1:numDuplicates
        sessionIndex = duplicateIndices(i);
        sessionObject = sessionArray(sessionIndex);

        sessionID(i) = string(sessionObject.sessionID);
        duplicateNumber(i) = nnz(sessionIDs(duplicateIndices(1:i)) == sessionID(i));

        [dataLocation(i), folderPath(i)] = getPrimarySessionFolder(sessionObject);
    end

    duplicateTable = table(sessionID, duplicateNumber, dataLocation, ...
        folderPath, duplicateIndices, ...
        'VariableNames', {'SessionID', 'DuplicateNumber', ...
        'DataLocation', 'FolderPath', 'SessionIndex'});

    duplicateTable = sortrows(duplicateTable, {'SessionID', 'DuplicateNumber'});
end

function [dataLocationName, folderPath] = getPrimarySessionFolder(sessionObject)
%getPrimarySessionFolder Return the same primary folder used by the UI.

    dataLocationName = string(sessionObject.DataLocation(1).Name);

    try
        folderPath = string(sessionObject.getSessionFolder(dataLocationName));
    catch
        dataLocationInfo = sessionObject.DataLocation(1);
        folderPath = string(fullfile(dataLocationInfo.RootPath, ...
            dataLocationInfo.Subfolders));
    end
end
