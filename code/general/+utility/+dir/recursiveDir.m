function combinedListing = recursiveDir(rootPath, options)

    arguments
        rootPath (1,:) string
        options.IgnoreList (1,:) string = string.empty
        options.Expression (1,1) string = ""
        options.Type (1,1) string {validatestring(options.Type, {'file', 'folder', 'all'})} = "all"
        options.FileType (1,1) string = ""
        options.RecursionDepth (1,1) double = inf
        options.IsCumulative (1,1) logical = true
        options.OutputType (1,1) string {mustBeMember(options.OutputType, {'FilePath', 'FileAttributes'})} = 'FileAttributes'
    end
    
    import utility.dir.recursiveDir

    combinedListing = utility.dir.empty();
    
    % Get the OutputType and change to FileAttributes. Any internal 
    % (recursive) call to recursiveDir need to return data as
    % FileAttributes.
    outputType = options.OutputType;
    options.OutputType = 'FileAttributes';

    if numel(rootPath) > 1
        for i = 1:numel(rootPath)
            nvpairs = utility.struct2nvpairs(options);
            newListing = recursiveDir(rootPath(i), nvpairs{:});
            combinedListing = cat(1, combinedListing, newListing);
        end
    else
        % Find folders in root path
        newListing = dir(fullfile(rootPath));
        
        % 1. Remove "shadow" files / hidden files
        newListing(strncmp({newListing.name}, '.', 1)) = [];
        
        % 2. Filter listing by exclusion criteria
        keep = true(1, numel(newListing));

        % Remove folders that contain a word from the ignore list.
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
        
        if options.Type == "file" && options.FileType ~= ""
            [~, ~, ext] = fileparts({filteredListing.name});
            isValidFiletype = strcmp(ext, options.FileType);
            keep = keep & isValidFiletype;
        end
                
        keepListing = filteredListing(keep);
        combinedListing = cat(1, combinedListing, keepListing);

        options.RecursionDepth = options.RecursionDepth - 1;

        if options.RecursionDepth > 0 && sum([filteredListing.isdir]) > 0
            % Continue search through subfolders that passed the filter
            newRootPath = arrayfun(@(l) string(fullfile(l.folder, l.name)), filteredListing, 'uni', 1);
            newRootPath(~[newListing.isdir])=[];
            
            nvpairs = utility.struct2nvpairs(options);
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
        combinedListing = utility.dir.abspath(combinedListing);
    end
end
