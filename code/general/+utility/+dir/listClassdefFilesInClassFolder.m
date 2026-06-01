function L = listClassdefFilesInClassFolder(rootPath)
%listClassdefFilesInClassFolder List all classdef files in a folder hierarchy
%
%   This function only finds classdef files and ignores all other class
%   related m-files like methods etc.

    folderList = recursiveDir(rootPath, ...
        'IgnoreList', "private", 'Expression', '@', 'Type', 'folder');
    
    if isempty(folderList)
        L = folderList;
        return
    end
    
    L = cell(size(folderList));    

    for i = 1:numel(folderList)
        folderPath = fullfile(folderList(i).folder, folderList(i).name);
        functionName = strrep(folderList(i).name, '@', '');
        L{i} = recursiveDir(folderPath, ...
            'Type', 'file', 'FileType', '.m', 'Expression', functionName);
    end

    L = cat(1, L{:});
end
