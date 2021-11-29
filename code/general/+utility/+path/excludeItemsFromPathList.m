function pathListOut = excludeItemsFromPathList(pathListIn, expr)
%excludeItemsFromPathList Exclude items containing expression from list
%

    if ischar(pathListIn)
        if strcmp(pathListIn(end), ':')
            pathListIn(end) = [];
        end
        pathList = strsplit(pathListIn, ':');
    end
    
    keep = ~contains(pathList, expr);
    pathListOut = pathList(keep);
    
    if ischar(pathListIn)
        pathListOut = strjoin(pathListOut, ':');
    end

end