function setUserpathFromFolder(enteredFolder, confirmCreateFolder)
%setUserpathFromFolder - Set MATLAB's userpath from a folder given by the user
%   setUserpathFromFolder(enteredFolder, confirmCreateFolder) sets MATLAB's
%   userpath to <enteredFolder>/MATLAB and creates the folder
%   <enteredFolder>/MATLAB/Nansen if it does not exist. enteredFolder must
%   be an absolute path. MATLAB adds the new userpath to the search path
%   and keeps it as a saved setting for later sessions.
%
%   confirmCreateFolder is a function handle that takes the path of the
%   missing folder and returns true if the folder may be created. It is
%   not called when the folder exists.
%
%   Call this function only when userpath is empty: it detects a userpath
%   that MATLAB did not accept by reading back an empty value.
%
%   See also nansen.internal.setup.resolveEmptyUserpath, userpath

    arguments
        enteredFolder (1,1) string
        confirmCreateFolder (1,1) function_handle
    end

    enteredFolder = strip(enteredFolder);
    if strlength(enteredFolder) == 0
        error('NANSEN:SetUserpathAborted', 'Please enter a directory for userdata.')
    end
    if ~isAbsolutePath(enteredFolder)
        error('NANSEN:Setup:UserpathFolderNotAbsolute', ...
            '"%s" is not an absolute path. Enter the full path of a folder.', enteredFolder)
    end

    userpathFolder = fullfile(enteredFolder, "MATLAB");
    nansenFolder = fullfile(userpathFolder, "Nansen");

    if ~isfolder(nansenFolder)
        if ~confirmCreateFolder(nansenFolder)
            error('NANSEN:SetUserpathAborted', 'A directory for userdata is required.')
        end
        mkdir(nansenFolder)
    end

    userpath(userpathFolder)

    % MATLAB leaves the userpath unchanged, with only a warning, if it can
    % not add the folder to the search path
    newUserpath = userpath();
    if isempty(newUserpath)
        error('NANSEN:Setup:UserpathNotSet', ...
            ['MATLAB did not accept "%s" as userpath. Check that the folder ', ...
             'can be added to the search path, then run nansen_install again.'], userpathFolder)
    end

    fprintf('Set MATLAB''s userpath to: "%s"\n\n', newUserpath)
end

function isAbsolute = isAbsolutePath(folder)
%isAbsolutePath - True for a full path, on the current platform
    if ispc
        driveRoot = lettersPattern(1) + ":" + characterListPattern("\/");
        isAbsolute = startsWith(folder, driveRoot) || startsWith(folder, ["\\", "//"]);
    else
        isAbsolute = startsWith(folder, "/");
    end
end
