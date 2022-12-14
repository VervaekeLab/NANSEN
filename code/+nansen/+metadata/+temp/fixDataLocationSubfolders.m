function metaTable = fixDataLocationSubfolders(metaTable)
%fixDataLocationSubfolders Fix DataLocation subfolders

% This function should ensure
%   All datalocation items has all the datalocations
%   All datalocation items has all the 6 fields (see below)
    
    dataLocationStructs = metaTable.entries.DataLocation;
    
    for iSession = 1:size(dataLocationStructs, 1)
        for jDataLoc = 1:size(dataLocationStructs, 2)
            thisRoot = dataLocationStructs(iSession, jDataLoc);
            if isa(thisRoot.Subfolders, 'char') && isa(thisRoot.RootPath, 'char')
                if contains(thisRoot.Subfolders, thisRoot.RootPath)
                    thisRoot.Subfolders = strrep(thisRoot.Subfolders, thisRoot.RootPath, '');
                    dataLocationStructs(iSession, jDataLoc) = thisRoot;
                end
            end
        end
    end
    dataLocationStructs = mat2cell(dataLocationStructs, ones(1,size(dataLocationStructs, 1)), 2);
    
    %dataLocationStructs = app.DataLocationModel.validateDataLocationPaths(dataLocationStructs);
    metaTable.replaceDataColumn('DataLocation', dataLocationStructs );
    %metaTable.entries.DataLocation = dataLocationStructs;
    metaTable.markClean() 
end
