function items = scanFolderForFileAdapters(folderPath)
%scanFolderForFileAdapters Scan a directory for class- and folder-based file adapters
%
%   items = scanFolderForFileAdapters(folderPath) returns a struct array
%   with fields:
%       sourcePath : absolute path to the source file or folder
%       destName   : target name (MATLAB package prefix added if needed)
%
%   If folderPath is itself a file adapter folder it is returned as a single
%   item. Otherwise the top level of folderPath is scanned: .m files are
%   treated as class-based adapters, and subfolders are included when they
%   are a file adapter folder. Plain folder names (no + or @ prefix) are
%   prefixed with +.

    items = struct('sourcePath', {}, 'destName', {});

    % A user importing a single adapter will select the adapter folder
    % itself. Import it as one item rather than scanning into it, which
    % would split a class folder into its unusable individual m-files.
    if isFileAdapterFolder(folderPath)
        items(1).sourcePath = folderPath;
        items(1).destName = getDestinationName(folderPath);
        return
    end

    listing = dir(folderPath);
    for i = 1:numel(listing)
        name = listing(i).name;
        if startsWith(name, '.'); continue; end

        itemPath = fullfile(folderPath, name);

        if ~listing(i).isdir && endsWith(name, '.m')
            items(end+1).sourcePath = itemPath; %#ok<AGROW>
            items(end).destName = name;
        elseif listing(i).isdir && isFileAdapterFolder(itemPath)
            items(end+1).sourcePath = itemPath; %#ok<AGROW>
            items(end).destName = getDestinationName(itemPath);
        end
    end
end

function tf = isFileAdapterFolder(folderPath)
%isFileAdapterFolder Determine whether a folder holds one file adapter definition

    folderName = getFolderName(folderPath);

    if startsWith(folderName, '@')
        % Class folder. The classdef file shares the name of the folder,
        % while methods may live in the classdef file or in separate files.
        classFileName = [extractAfter(folderName, '@'), '.m'];
        tf = isfile(fullfile(folderPath, classFileName));
    else
        hasJson = isfile(fullfile(folderPath, 'fileadapter.json'));
        hasFunctions = any(isfile(fullfile(folderPath, {'read.m', 'write.m', 'view.m'})));
        tf = hasJson || hasFunctions;
    end
end

function destName = getDestinationName(folderPath)
%getDestinationName Get the name to import a file adapter folder as

    destName = getFolderName(folderPath);
    if ~startsWith(destName, '+') && ~startsWith(destName, '@')
        destName = ['+', destName];
    end
end

function folderName = getFolderName(folderPath)
%getFolderName Get the last name of a folder path, allowing a trailing filesep

    [parentPath, folderName, extensionPart] = fileparts(char(folderPath));
    if isempty(folderName) % Path ended with a file separator
        [~, folderName, extensionPart] = fileparts(parentPath);
    end
    folderName = [folderName, extensionPart];
end
