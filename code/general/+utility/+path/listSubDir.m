function [absPath, dirName] = listSubDir(rootPath, expression, ignoreList, depth, isCumulative)
%listSubDir List sub directories based on different rules
%
%   [absPath, dirName] = listSubDir(rootPath)
%
%   [absPath, dirName] = listSubDir(rootPath, expression)
%
%   [absPath, dirName] = listSubDir(rootPath, expression, ignoreList)
%
%   [absPath, dirName] = listSubDir(rootPath, expression, ignoreList,
%   depth) where depth specifies how many levels into to folder hierarchy
%   to go (default = 1)
%
%   isCumulative - Boolean flag, whether to keep all folders, or only
%   collect folders from the specified depth. Default = false

    if nargin < 2; expression = ''; end
    if nargin < 3; ignoreList = {}; end
    if nargin < 4; depth = 1; end
    if nargin < 5; isCumulative = false; end

    %if nRecurse ~= 0; error('Not implemented yet'); end

    validateattributes(depth, 'numeric', {'scalar', 'positive'}, 4);

    [absPath, dirName] = deal(cell(1, 0));

    if isa(rootPath, 'cell')
        for i = 1:numel(rootPath)
            [absPathIter, dirNameIter] = utility.path.listSubDir(rootPath{i}, expression, ignoreList, depth, isCumulative);
            absPath = cat(2, absPath, absPathIter);
            dirName = cat(2, dirName, dirNameIter);
        end
    else
        % Find folders in raw data path
        listing = dir(fullfile(rootPath));

        %keep = cellfun(@(pstr) ~strncmp(pstr, '.', 1), {listing.name});
        keep = ~strncmp({listing.name}, '.', 1) & [listing.isdir];
        
        % Find only foldernames that matches expression
        if isempty(expression)
            isMatch = keep;
        else
            subdirFilterFun = @(fname) ~isempty(regexp(fname, expression, 'once'));
            isMatch = cellfun(@(name) subdirFilterFun(name), {listing.name} );
        end
        
        % Remove folders that contain a word from the ignore list.
        if ~isempty(ignoreList)
            ignore = contains({listing.name}, ignoreList);
            isMatch = isMatch & ~ignore;
        end
        
        keep = keep & isMatch;
        
        dirName = {listing(keep).name};
        absPath = fullfile(rootPath, dirName);
        
        if depth > 1 && sum(keep) > 0 % Todo:
            [absPathRec, dirNameRec] = utility.path.listSubDir(absPath, expression, ignoreList, depth-1, isCumulative);
            if ~isempty(absPathRec)
                %absPath = cat(2, absPath, absPathRec);
                %dirName = cat(2, dirName, dirNameRec);
                absPath = absPathRec;
                dirName = dirNameRec;
            end
        end

        if isCumulative % Add top level directory if it is not part of list.
            if ~any(strcmp(absPath, rootPath))
                absPath = cat(2, absPath, rootPath);
                [~, thisDirName] = fileparts(absPath);
                dirName = cat(2, dirName, thisDirName);
            end
        end
    end
end
