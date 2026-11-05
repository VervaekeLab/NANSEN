function moveUserDataFolders(sourceDirectory, targetDirectory, folderNames)
%moveUserDataFolders Move named folders to another directory, all or nothing
%
%   moveUserDataFolders(sourceDirectory, targetDirectory, folderNames)
%   moves the contents of each folder in folderNames from sourceDirectory
%   into the folder of the same name in targetDirectory, and removes the
%   emptied source folders. A folder that sourceDirectory does not have is
%   skipped. Other entries of either directory are not touched.
%
%   Every entry of every folder is checked against targetDirectory before
%   anything moves, so a name collision in one folder stops the move of
%   all of them. If a move fails partway, exactly the entries that were
%   moved go back, so the folders end up either all in targetDirectory or
%   all in sourceDirectory.
%
%   Throws:
%       NANSEN:MoveFolder:TargetExists - an entry is already present in
%           targetDirectory. Nothing was moved.
%       NANSEN:UserSession:MoveUserDataFailed - a move failed, and
%           everything that had moved was moved back.
%       NANSEN:UserSession:RestoreUserDataFailed - a move failed, and the
%           contents of the folders that the message names could not all
%           be moved back.
%
%   See also nansen.internal.system.moveFolderContents,
%   nansen.internal.user.validateUserDataTarget

    arguments
        sourceDirectory (1,1) string
        targetDirectory (1,1) string
        folderNames (1,:) string
    end

    import nansen.internal.system.moveFolderContents

    sourceFolders = fullfile(sourceDirectory, folderNames);
    targetFolders = fullfile(targetDirectory, folderNames);
    isPresent = isfolder(sourceFolders);

    assertNoNameCollisions(sourceFolders(isPresent), targetFolders(isPresent))

    wasMoved = false(size(folderNames));
    isTargetCreated = false(size(folderNames));
    movedEntryNames = cell(size(folderNames));

    try
        for i = find(isPresent)
            isTargetCreated(i) = ~isfolder(targetFolders(i));
            movedEntryNames{i} = moveFolderContents(sourceFolders(i), targetFolders(i));

            % Marked before the source folder is removed, so that a failure
            % to remove it also moves the entries back.
            wasMoved(i) = true;
            rmdir(sourceFolders(i))
        end
    catch MECause
        isRestored = true(size(folderNames));

        for i = flip( find(wasMoved) )
            try
                moveFolderContents(targetFolders(i), sourceFolders(i), ...
                    EntryNames=movedEntryNames{i});
                if isTargetCreated(i)
                    [~] = rmdir(targetFolders(i)); % Removed only if empty; the output keeps rmdir from throwing
                end
            catch
                % The error thrown below names every folder left behind
                isRestored(i) = false;
            end
        end

        if all(isRestored)
            ME = MException('NANSEN:UserSession:MoveUserDataFailed', ...
                ['Failed to move NANSEN user data from "%s" to "%s", so it ' ...
                 'was left in place.'], sourceDirectory, targetDirectory);
        else
            ME = MException('NANSEN:UserSession:RestoreUserDataFailed', ...
                ['Failed to move NANSEN user data from "%s" to "%s", and ' ...
                 'failed to move the contents of these folders back, so ' ...
                 'their entries can be in either directory: %s.'], ...
                sourceDirectory, targetDirectory, strjoin(folderNames(~isRestored), ', '));
        end

        ME = ME.addCause(MECause);
        throw(ME)
    end
end

function assertNoNameCollisions(sourceFolders, targetFolders)
%assertNoNameCollisions Check that no entry of a source folder exists at its target

    for i = 1:numel(sourceFolders)
        listing = dir(sourceFolders(i));
        entryNames = setdiff(string({listing.name}), [".", ".."]);

        targetPaths = fullfile(targetFolders(i), entryNames);
        isTaken = isfile(targetPaths) | isfolder(targetPaths);

        if any(isTaken)
            error('NANSEN:MoveFolder:TargetExists', ...
                '"%s" already exists, so no NANSEN user data was moved.', ...
                targetPaths(find(isTaken, 1)))
        end
    end
end
