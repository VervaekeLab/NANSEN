function [absPath, dirName] = listSubDir(rootPath, expression, ignoreList, nRecurse)
%listSubDir List sub directories based on different rules
%
%   [absPath, dirName] = listSubDir(rootPath)
%
%   [absPath, dirName] = listSubDir(rootPath, expression)
%
%   [absPath, dirName] = listSubDir(rootPath, expression, ignoreList)
%
%   [absPath, dirName] = listSubDir(rootPath, expression, ignoreList, nRecurse)



    if nargin < 2; expression = ''; end
    if nargin < 3; ignoreList = {}; end
    if nargin < 4; nRecurse = 0; end
    %if nRecurse ~= 0; error('Not implemented yet'); end

    [absPath, dirName] = deal(cell(1, 0));

    if isa(rootPath, 'cell')
        for i = 1:numel(rootPath)
            [absPathIter, dirNameIter] = utility.path.listSubDir(rootPath{i}, expression, ignoreList, nRecurse);
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
        
        if nRecurse > 0 && sum(keep) > 0 % Todo:
            [absPathRec, dirNameRec] = utility.path.listSubDir(absPath, expression, ignoreList, nRecurse-1);
            if ~isempty(absPathRec)
                absPath = cat(2, absPath, absPathRec);
                dirName = cat(2, dirName, dirNameRec);
            end

        end

    end

end