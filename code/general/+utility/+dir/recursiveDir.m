function combinedListing = recursiveDir(rootPath, options)
% recursiveDir Recursively lists files and folders under the specified root path.
%
% SYNTAX:
%   combinedListing = recursiveDir(rootPath) will recursively list all
%       files and folders under the folder specified by rootPath.
%
%   combinedListing = recursiveDir(rootPath, name, value, ...) will
%       recursively list contents of a folder using additional options
%       specified as name-value pairs.
%
% INPUTS:
%   rootPath        - Root path from which to start listing files and
%                     folders. Must be a string representing the path name
%                     of a directory. Can be an array of path names.
%
% OPTIONS:
%     IgnoreList         - List of words/substrings to ignore during
%                          listing. Default is an empty string array.
%
%     Expression         - Regular expression to filter files and folders.
%                          Default is an empty string.
%
%     Type               - Type of items to list: 'file', 'folder', or
%                          'any'. Default is 'any'.
%
%     FileType           - File extension for filtering specific files.
%                          Default is an empty string.
%
%     RecursionDepth     - Maximum recursion depth. Default is inf.
%
%     IsCumulative       - Flag to indicate whether to accumulate files
%                          and/or folders as the function goes deeper into
%                          the directory tree. Default is true. If false,
%                          only files and folders from the depth specified
%                          in RecursionDepth will be returned.
%
%     OutputType         - Type of output: 'FilePath' or 'FileAttributes'.
%                          Default is 'FileAttributes' (struct array as
%                          returned by the builtin dir function).
%
%     IncludeHiddenFiles - Flag to include hidden files and folders.
%                          Default is false (only works on Unix).
%
% OUTPUT:
%   combinedListing - A struct array (same as returned by the dir function)
%       of file attributes for all the items found in the directory tree.
%
%   alternatively: If the option 'OutputType' is set to 'FilePath'
%       combinedListing is a cell array of absolute pathnames for all the
%       found items.
%
% EXAMPLES:
%   % List all files and folders under the current directory
%   combinedListing = recursiveDir(pwd());
%
%   % List all MATLAB files under the current directory
%   combinedListing = recursiveDir(pwd(), "FileType", ".m");
%
%   % List all folders under the current directory with depth limit of 2
%   combinedListing = recursiveDir(pwd(), "Type", "folder", "RecursionDepth", 2);
%
%   % List all files and folders under multiple root paths
%   rootPaths = ["path1", "path2", "path3"];
%   combinedListing = recursiveDir(rootPaths);

%   Written by Eivind Hennestad | v1.0.0

%Todo: use this in nansen

    arguments
        rootPath (1,:) string
        options.IgnoreList (1,:) string = string.empty
        options.Expression (1,1) string = ""
        options.Type (1,1) string {mustBeMember(options.Type, {'file', 'folder', 'any'})} = "any"
        options.FileType (1,1) string = "" % File extension, i.e '.m'
        options.RecursionDepth (1,1) double = inf
        options.IsCumulative (1,1) logical = true
        options.OutputType (1,1) string {mustBeMember(options.OutputType, {'FilePath', 'FileAttributes'})} = 'FileAttributes'
        options.IncludeHiddenFiles = false
    end
    
    import utility.dir.recursiveDir

    combinedListing = getEmptyListing(); % Local function
    
    % Get the OutputType from options and change the value to
    % 'FileAttributes'. Any internal (recursive) call to recursiveDir need
    % to return data as FileAttributes.
    outputType = options.OutputType;
    options.OutputType = 'FileAttributes';

    if numel(rootPath) > 1
        for i = 1:numel(rootPath)
            nvpairs = namedargs2cell(options);
            newListing = recursiveDir(rootPath(i), nvpairs{:});
            combinedListing = cat(1, combinedListing, newListing);
        end
    else
        % Find folders in root path
        newListing = dir(fullfile(rootPath));
        
        % 1. Remove current directory and parent directory references
        newListing(strcmp({newListing.name}, '.')) = [];
        newListing(strcmp({newListing.name}, '..')) = [];
        
        if ~options.IncludeHiddenFiles % unix
            newListing(strncmp({newListing.name}, '.', 1)) = [];
        end
        
        % 2. Filter listing by exclusion criteria
        keep = true(1, numel(newListing));

        % Remove items that contain a word from the ignore list.
        if ~isempty(options.IgnoreList)
            ignore = contains({newListing.name}, options.IgnoreList);
            keep = keep & ~ignore;
        end

        filteredListing = newListing(keep);
        keep = true(1, numel(filteredListing));

        % 3. Keep only list items that matches expression
        if options.Expression ~= ""
            isValidName = @(fname) ~isempty(regexp(fname, options.Expression, 'once'));
            isMatch = cellfun(@(name) isValidName(name), {newListing.name} );
            keep = keep & isMatch;
        end

        % 4. Select only files or folders if this is an option
        if options.Type == "file"
            keep = keep & ~[filteredListing.isdir];
        elseif options.Type == "folder"
            keep = keep & [filteredListing.isdir];
        end

        % 5. Filter by filetype if this is an option
        if options.FileType ~= "" && ~strncmp(options.FileType, '.', 1)
            options.FileType = sprintf('.%s', options.FileType);
        end
        
        if options.FileType ~= ""
            [~, ~, ext] = fileparts({filteredListing.name});
            isValidFiletype = strcmp(ext, options.FileType);
            keep = keep & isValidFiletype;
        end
                
        keepListing = filteredListing(keep);
        
        if ~isempty(keepListing)
            if ~options.IsCumulative && options.RecursionDepth > 1 && options.RecursionDepth ~= inf
                % Skip
            else
                combinedListing = cat(1, combinedListing, keepListing);
            end
        end

        options.RecursionDepth = options.RecursionDepth - 1;

        % 6. Recursively search through subfolders
        if options.RecursionDepth > 0 && sum([filteredListing.isdir]) > 0
            % Continue search through subfolders that passed the filter
            newRootPath = arrayfun(@(l) string(fullfile(l.folder, l.name)), filteredListing, 'uni', 1);
            newRootPath(~[filteredListing.isdir])=[];
            
            nvpairs = namedargs2cell(options);
            subListing = recursiveDir(newRootPath, nvpairs{:});
            if ~isempty(subListing)
                if options.IsCumulative
                    combinedListing = cat(1, combinedListing, subListing);
                else
                    combinedListing = subListing;
                end
            end
        end
    end

    if outputType == "FilePath"
        combinedListing = getAbsPathName(combinedListing);  % Local function
    end
end

function emptyListing = getEmptyListing()
%getEmptyListing - Get an empty "file listing" attribute struct.
    emptyListing = struct(...
        'name', {}, ...
        'folder', {}, ...
        'date', {}, ...
        'bytes', {}, ...
        'isdir', {}, ...
        'datenum', {});
    emptyListing = reshape(emptyListing, 0, 1);
end

function absolutePathList = getAbsPathName(folderListing)
%getAbsPathName Combine folder and name for each element in a "folder listing" struct array
    
    absolutePathList = cell(size(folderListing));
    for i = 1:numel(folderListing)
        absolutePathList{i} = fullfile(folderListing(i).folder, ...
            folderListing(i).name);
    end
end
