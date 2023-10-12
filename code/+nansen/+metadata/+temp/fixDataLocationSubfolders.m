function metaTable = fixDataLocationSubfolders(metaTable)
%fixDataLocationSubfolders Fix DataLocation subfolders

% This function should ensure
%   All datalocation items has all the datalocations
%   All datalocation items has all the 6 fields (see below)
    
    if ~contains('DataLocation', metaTable.entries.Properties.VariableNames )
        return
    end

    dataLocationStructArray = metaTable.entries.DataLocation;
    
    if isa(dataLocationStructArray, 'cell')
        dataLocationStructArray = utility.struct.structcat(1, dataLocationStructArray{:});
    end

    [numSessions, numDataLocations] = size(dataLocationStructArray);

    for iSession = 1:numSessions
        for jDataLoc = 1:numDataLocations
            thisRoot = dataLocationStructArray(iSession, jDataLoc);
            if isa(thisRoot.Subfolders, 'char') && isa(thisRoot.RootPath, 'char')
                if contains(thisRoot.Subfolders, thisRoot.RootPath)
                    thisRoot.Subfolders = strrep(thisRoot.Subfolders, thisRoot.RootPath, '');
                    dataLocationStructArray(iSession, jDataLoc) = thisRoot;
                end
            end
        end
    end
    dataLocationStructArray = mat2cell(dataLocationStructArray, ones(1, numSessions), numDataLocations);
    
    %dataLocationStructs = app.DataLocationModel.validateDataLocationPaths(dataLocationStructs);
    metaTable.replaceDataColumn('DataLocation', dataLocationStructArray );
    %metaTable.entries.DataLocation = dataLocationStructs;
    metaTable.markClean() 
end
