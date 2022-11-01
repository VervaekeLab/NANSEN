function pathListOut = excludeItemsFromPathList(pathListIn, expr)
%excludeItemsFromPathList Exclude items containing expression from list
%

    if ischar(pathListIn)
        if strcmp(pathListIn(end), pathsep)
            pathListIn(end) = [];
        end
        pathList = strsplit(pathListIn, pathsep);
    end
    
    keep = ~contains(pathList, expr);
    pathListOut = pathList(keep);
    
    if ischar(pathListIn)
        pathListOut = strjoin(pathListOut, pathsep);
    end

end