function movedNames = moveFolderContents(sourceDirectory, targetDirectory, options)
%moveFolderContents Move the entries of one folder into another
%
%   movedNames = moveFolderContents(sourceDirectory, targetDirectory) moves
%   every entry of sourceDirectory into targetDirectory, creating
%   targetDirectory if it does not exist, and returns the names of the
%   moved entries as a string array. A missing sourceDirectory is treated
%   as empty.
%
%   movedNames = moveFolderContents(..., EntryNames=names) moves only the
%   named entries. To undo an earlier call, pass the names it returned with
%   the two directories swapped: only the entries that call moved go back,
%   whatever else targetDirectory holds by then.
%
%   The entries are moved one by one, because movefile places the source
%   folder inside the target when the target already exists. Every target
%   is checked before anything moves, so a name collision is reported
%   before either folder is touched. If a move fails partway, the entries
%   already moved go back to sourceDirectory, and a targetDirectory created
%   by this call is removed again, before the error is thrown.
%
%   Throws:
%       NANSEN:MoveFolder:TargetExists - an entry of that name is already
%           present in targetDirectory. Nothing was moved.
%       NANSEN:MoveFolder:MoveFailed - a move failed, and every entry that
%           had moved was moved back.
%       NANSEN:MoveFolder:RestoreFailed - a move failed, and the entries
%           that the message names could not be moved back.
%
%   See also movefile, nansen.internal.user.moveUserDataFolders

    arguments
        sourceDirectory (1,1) string
        targetDirectory (1,1) string
        options.EntryNames (1,:) string = listEntryNames(sourceDirectory)
    end

    entryNames = options.EntryNames;
    sourcePaths = fullfile(sourceDirectory, entryNames);
    targetPaths = fullfile(targetDirectory, entryNames);

    isTaken = isfile(targetPaths) | isfolder(targetPaths);
    if any(isTaken)
        error('NANSEN:MoveFolder:TargetExists', ...
            '"%s" already exists, so nothing was moved from "%s".', ...
            targetPaths(find(isTaken, 1)), sourceDirectory)
    end

    isTargetCreated = ~isfolder(targetDirectory);
    if isTargetCreated; mkdir(targetDirectory); end

    numMoved = 0;

    try
        for i = 1:numel(entryNames)
            movefile(sourcePaths(i), targetPaths(i))
            numMoved = i;
        end
    catch MECause
        isRestored = true(1, numMoved);

        for i = numMoved:-1:1
            try
                movefile(targetPaths(i), sourcePaths(i))
            catch
                % The error thrown below names every entry left behind
                isRestored(i) = false;
            end
        end

        if all(isRestored)
            if isTargetCreated
                [~] = rmdir(targetDirectory); % Removed only if empty; the output keeps rmdir from throwing
            end
            ME = MException('NANSEN:MoveFolder:MoveFailed', ...
                ['Failed to move the contents of "%s" to "%s", so they were ' ...
                 'left in place.'], sourceDirectory, targetDirectory);
        else
            ME = MException('NANSEN:MoveFolder:RestoreFailed', ...
                ['Failed to move the contents of "%s" to "%s", and failed to ' ...
                 'move these entries back, so they are still in "%s": %s.'], ...
                sourceDirectory, targetDirectory, targetDirectory, ...
                strjoin(entryNames(~isRestored), ', '));
        end

        ME = ME.addCause(MECause);
        throw(ME)
    end

    movedNames = entryNames;
end

function entryNames = listEntryNames(folderPath)
%listEntryNames List the names of the entries of a folder, hidden ones included

    listing = dir(folderPath);
    entryNames = setdiff(string({listing.name}), [".", ".."], 'stable');
    entryNames = reshape(entryNames, 1, []);
end
