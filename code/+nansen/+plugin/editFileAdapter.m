function editFileAdapter(fileAdapterName)

    arguments
        fileAdapterName (1,1) string
    end
    
    fileAdapterList = nansen.dataio.listFileAdapters();

    if contains(fileAdapterName, 'fileadapter.')
        isMatch = strcmp(fileAdapterName, {fileAdapterList.FunctionName});
    elseif ~contains(fileAdapterName, '.')
        isMatch = strcmp(fileAdapterName, {fileAdapterList.FileAdapterName});
    else
        error('"%s" is not the name of a file adapter', fileAdapterName)
    end

    if ~any(isMatch)
        error('Did not find any file adapters matching name "%s"', fileAdapterName)
    elseif sum(isMatch) > 1
        error('Multiple file adapters matched name "%s"', fileAdapterName)
    end
    
    fileAdapterInfo = fileAdapterList(isMatch);
    fileAdapterName = fileAdapterInfo.FunctionName;

    % Todo: locate folder.
    if fileAdapterInfo.IsDynamic
        pathStr = which( fileAdapterName + ".read" );
    else
        pathStr = which( fileAdapterName );
    end
    
    if isfile(pathStr)
        pathStr = fileparts(pathStr);
    end

    cd(pathStr)
end
