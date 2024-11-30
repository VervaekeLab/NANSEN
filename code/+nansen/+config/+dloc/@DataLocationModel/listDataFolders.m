function dataFolders = listDataFolders(obj, dataLocationName, options)

    arguments
        obj (1,1) nansen.config.dloc.DataLocationModel
        dataLocationName (1,:) string = "all"
        options.FolderType (1,1) nansen.config.dloc.enum.FolderType = "Session"
        options.Identifier (1,1) string = missing
        options.GroupByDataLocation (1,1) logical = false
    end

    allDataLocationNames = string( {obj.Data.Name} );

    % Get indices for datalocation items to list session folders for
    if dataLocationName == "all"
        ind = 1:numel(obj.Data);
    else
        [~, ind] = intersect(allDataLocationNames, dataLocationName);
    end

    dataFolders = struct; % Initialize output
    
    for i = ind
        rootPath = {obj.Data(i).RootPath.Value};
        S = obj.Data(i).SubfolderStructure;

        folderLevel = find( strcmp( {S.Type}, options.FolderType) );

        % % L = utility.dir.recursiveDir(rootPath, "Type", "folder", ...
        % %     "IsCumulative", false, "RecursionDepth", folderLevel, ...
        % %     "OutputType", "FilePath");

        for j = 1:folderLevel % Loop through each subfolder level
            expression = S(j).Expression;
            ignoreList = S(j).IgnoreList;
            [rootPath, ~] = utility.path.listSubDir(rootPath, expression, ignoreList, 1);
        end

        fieldName = obj.Data(i).Name;
        dataFolders.(fieldName) = rootPath;
    end

    if ~options.GroupByDataLocation
        dataFolders = struct2cell(dataFolders);
        dataFolders = unique([dataFolders{:}]);
    end

    if ~ismissing(options.Identifier)
        [~, folderNames] = fileparts(dataFolders);
        keep = contains(folderNames, options.Identifier);
        dataFolders = dataFolders(keep);
    end
end
