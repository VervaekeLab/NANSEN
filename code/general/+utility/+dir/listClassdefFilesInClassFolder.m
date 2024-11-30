function L = listClassdefFilesInClassFolder(rootPath)
%listClassdefFilesInClassFolder List all classdef files in a folder hierarchy
%
%   This function only finds classdef files and ignores all other class
%   related m-files like methods etc.

    folderList = utility.dir.recursiveDir(rootPath, ...
        'Expression', '@', 'Type', 'folder');
    
    L = cell(size(folderList));

    for i = 1:numel(folderList)
        folderPath = fullfile(folderList(i).folder, folderList(i).name);
        functionName = strrep(folderList(i).name, '@', '');
        L{i} = utility.dir.recursiveDir(folderPath, ...
            'Type', 'file', 'FileType', '.m', 'Expression', functionName);
    end

    L = cat(1, L{:});
    if isempty(L)
        L = utility.dir.empty();
    end
end
