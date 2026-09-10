function moveFolderContents(sourceDirectory, targetDirectory)
%moveFolderContents Move every entry of one folder into another
%
%   moveFolderContents(sourceDirectory, targetDirectory) moves the contents
%   of sourceDirectory into targetDirectory, creating targetDirectory if it
%   does not exist. A missing sourceDirectory is treated as empty.
%
%   The entries are moved one by one, because movefile places the source
%   folder inside the target when the target already exists. Every target
%   is resolved before anything moves, so a name collision is reported
%   before the folder is touched, and a move that fails partway puts back
%   what it already moved.
%
%   Throws:
%       NANSEN:MoveFolder:TargetExists - an entry of that name is already
%           present in targetDirectory
%       NANSEN:MoveFolder:MoveFailed - the move failed and was undone
%
%   See also movefile, nansen.util.path.isSamePath

    arguments
        sourceDirectory (1,:) char
        targetDirectory (1,:) char
    end

    listing = dir(sourceDirectory);
    listing = listing( ~ismember({listing.name}, {'.', '..'}) );

    if isempty(listing)
        if ~isfolder(targetDirectory); mkdir(targetDirectory); end
        return
    end

    sourcePaths = strings(1, numel(listing));
    targetPaths = strings(1, numel(listing));

    for i = 1:numel(listing)
        sourcePaths(i) = fullfile(sourceDirectory, listing(i).name);
        targetPaths(i) = fullfile(targetDirectory, listing(i).name);

        if isfolder(targetPaths(i)) || isfile(targetPaths(i))
            error('NANSEN:MoveFolder:TargetExists', ...
                ['"%s" already exists. Select a directory that does not ' ...
                 'contain an entry named "%s".'], targetPaths(i), listing(i).name)
        end
    end

    if ~isfolder(targetDirectory); mkdir(targetDirectory); end

    numMoved = 0;

    try
        for i = 1:numel(sourcePaths)
            movefile(sourcePaths(i), targetPaths(i))
            numMoved = i;
        end
    catch MECause
        for i = numMoved:-1:1
            movefile(targetPaths(i), sourcePaths(i))
        end

        ME = MException('NANSEN:MoveFolder:MoveFailed', ...
            ['Failed to move the contents of "%s" to "%s", so they were ' ...
             'left in place. Check that the target directory is writable.'], ...
            sourceDirectory, targetDirectory);
        ME = ME.addCause(MECause);
        throw(ME)
    end
end
