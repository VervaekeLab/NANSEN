function sessionArray = excludeSameFolderDuplicates(sessionArray)
%excludeSameFolderDuplicates - Remove duplicate sessions in the same folder
%   sessionArray = excludeSameFolderDuplicates(sessionArray) removes every
%   session that has the same sessionID and the same session folder in
%   every data location as an earlier session in sessionArray. Sessions
%   with the same sessionID and different session folders are kept.
%
%   Sessions of this kind are created when the session level of a data
%   location is a file and one folder holds several files with the same
%   session ID. The session folder of each of these sessions is the
%   folder that holds the files, so only the first session is kept.
%
%   See also excludeDuplicateSessions, buildDuplicateSessionTable

    arguments
        sessionArray
    end

    duplicateTable = nansen.manage.buildDuplicateSessionTable(sessionArray);

    numDuplicates = height(duplicateTable);
    sessionFolderKeys = strings(numDuplicates, 1);
    for i = 1:numDuplicates
        sessionObject = sessionArray(duplicateTable.SessionIndex(i));
        sessionFolderKeys(i) = strjoin(getSessionFolders(sessionObject), newline);
    end

    % duplicateTable is sorted by session ID and then by the order of
    % sessionArray, so the first row with a given key is the session to keep.
    sessionKeys = duplicateTable.SessionID + newline + sessionFolderKeys;
    [~, keptRows] = unique(sessionKeys, "stable");
    isExcluded = true(numDuplicates, 1);
    isExcluded(keptRows) = false;

    sessionArray(duplicateTable.SessionIndex(isExcluded)) = [];
end

function sessionFolders = getSessionFolders(sessionObject)
%getSessionFolders - Get the session folder in each data location

    numDataLocations = numel(sessionObject.DataLocation);
    sessionFolders = strings(1, numDataLocations);

    for i = 1:numDataLocations
        dataLocation = sessionObject.DataLocation(i);
        if ~isempty(dataLocation.Subfolders)
            sessionFolder = fullfile(dataLocation.RootPath, dataLocation.Subfolders);

            % Subfolders ends with a file name when the session level of the
            % data location is a file. The session folder is then the folder
            % that holds the file, as in Session.getSessionFolder.
            if isfile(sessionFolder)
                sessionFolder = fileparts(sessionFolder);
            end
            sessionFolders(i) = sessionFolder;
        end
    end
end
