function validateUserDataTarget(targetDirectory, currentDirectory, folderNames)
%validateUserDataTarget Check that a directory can receive a user's NANSEN data
%
%   validateUserDataTarget(targetDirectory, currentDirectory, folderNames)
%   throws an error when the folders in folderNames can not be moved from
%   currentDirectory to targetDirectory:
%
%   - targetDirectory is inside currentDirectory, or contains it. Between
%     nested directories a folder can be moved into itself: choosing
%     <current>/local would move the local folder to <current>/local/local.
%
%   - targetDirectory already contains an entry with the name of one of
%     folderNames. The user data would be merged into a folder that is not
%     part of it, and a later move would carry that folder's other files
%     along. A directory that another profile has moved its data to holds
%     that profile's projects folder, so a second profile can not move its
%     data there as well.
%
%   Throws:
%       NANSEN:UserSession:NestedUserDataDirectory
%       NANSEN:UserSession:UserDataDirectoryInUse
%
%   See also nansen.internal.user.moveUserDataFolders

    arguments
        targetDirectory (1,1) string
        currentDirectory (1,1) string
        folderNames (1,:) string
    end

    import nansen.util.path.isSubPath

    if isSubPath(char(targetDirectory), char(currentDirectory))
        error('NANSEN:UserSession:NestedUserDataDirectory', ...
            ['"%s" is inside the current NANSEN user data directory, "%s". ' ...
             'Choose a folder outside it.'], targetDirectory, currentDirectory)
    end

    if isSubPath(char(currentDirectory), char(targetDirectory))
        error('NANSEN:UserSession:NestedUserDataDirectory', ...
            ['"%s" contains the current NANSEN user data directory, "%s". ' ...
             'Choose a folder that does not contain it.'], ...
            targetDirectory, currentDirectory)
    end

    entryPaths = fullfile(targetDirectory, folderNames);
    isTaken = isfile(entryPaths) | isfolder(entryPaths);

    if any(isTaken)
        error('NANSEN:UserSession:UserDataDirectoryInUse', ...
            ['"%s" already contains "%s". Choose an empty folder, or a new ' ...
             'subfolder, for the NANSEN user data.'], ...
            targetDirectory, folderNames(find(isTaken, 1)))
    end
end
