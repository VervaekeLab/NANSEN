function items = scanFolderForFileAdapters(folderPath)
%scanFolderForFileAdapters Scan a directory for class- and folder-based file adapters
%
%   items = scanFolderForFileAdapters(folderPath) scans the top level of
%   folderPath and returns a struct array with fields:
%       sourcePath : absolute path to the source file or folder
%       destName   : target name (MATLAB package prefix added if needed)
%
%   .m files are treated as class-based adapters. Subfolders are included
%   when they contain fileadapter.json or at least one of read.m / write.m
%   / view.m. Plain folder names (no + or @ prefix) are prefixed with +.

    items = struct('sourcePath', {}, 'destName', {});

    listing = dir(folderPath);
    for i = 1:numel(listing)
        name = listing(i).name;
        if startsWith(name, '.'); continue; end

        itemPath = fullfile(folderPath, name);

        if ~listing(i).isdir && endsWith(name, '.m')
            items(end+1).sourcePath = itemPath; %#ok<AGROW>
            items(end).destName     = name;
        elseif listing(i).isdir
            hasJson      = isfile(fullfile(itemPath, 'fileadapter.json'));
            hasFunctions = any(isfile(fullfile(itemPath, {'read.m', 'write.m', 'view.m'})));
            if hasJson || hasFunctions
                destName = name;
                if ~startsWith(destName, '+') && ~startsWith(destName, '@')
                    destName = ['+', destName];
                end
                items(end+1).sourcePath = itemPath; %#ok<AGROW>
                items(end).destName     = destName;
            end
        end
    end
end
