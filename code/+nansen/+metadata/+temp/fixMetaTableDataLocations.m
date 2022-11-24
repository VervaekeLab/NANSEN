function metaTable = fixMetaTableDataLocations(metaTable, dataLocationModel)
%fixMetaTableDataLocations Fix DataLocation of all entries to be in 
% accordance with new specification    


% This function should ensure
%   All datalocation items has all the datalocations
%   All datalocation items has all the 6 fields (see below)

    entries = table2struct(metaTable.entries);
    
    if isempty(metaTable.entries); return; end
    
    if ~isfield(entries(1), 'DataLocation'); return; end
    
    numDataLocations = dataLocationModel.NumDataLocations;
    
    dataLocationCount = arrayfun(@(s) numel(s.DataLocation), entries);
    hasUuid = arrayfun(@(s) isfield(s.DataLocation, 'Uuid'), entries);
    
    if all(dataLocationCount == numDataLocations) && all(hasUuid)
        return
    end
    
    newDataLocation = cell(numel(entries), 1);
    
    for j = 1:numel(entries)
        
        if dataLocationCount(j) == numDataLocations && hasUuid(j)
            S = entries(j).DataLocation;
            
        else
            S = struct('Uuid', {}, 'RootUid', {}, 'Subfolders', {});

            for i = 1:dataLocationModel.NumDataLocations
                dataLocation = dataLocationModel.getItem(i);

                name = dataLocation.Name;
                rootPaths = {dataLocation.RootPath.Value};
                
                % Was a session folder for this entry located in (any of) 
                % the root datalocation directories.
                rootIdx = [];
                for k = 1:numel(rootPaths)
                    if isfield(entries(j).DataLocation, name)
                        tf = contains( entries(j).DataLocation.(name), rootPaths{k} );
                        if ~isempty(tf) && tf
                            thisRootPath = rootPaths{k};
                            rootIdx = k;
                            break
                        end
                    end
                end

                
                S(i).Uuid = dataLocation.Uuid;
                if ~isempty(rootPaths) && ~isempty(rootIdx)
                    S(i).RootUid = dataLocation.RootPath(rootIdx).Key;
                    S(i).Subfolders = strrep(entries(j).DataLocation.(name), thisRootPath, '');
                end
                
                % If not root was assigned, assign the first root directory
                % which is present on current file system
                if isempty( S(i).RootUid )
                    for k = 1:numel(rootPaths)
                        if isfolder( rootPaths{k} )
                            S(i).RootUid = dataLocation.RootPath(k).Key;
                            S(i).Subfolders = '';
                        end
                    end
                end
            end
            
            S = dataLocationModel.expandDataLocationInfo(S);
        end
        
        newDataLocation{j} = S;
    end

    metaTable.replaceDataColumn('DataLocation', newDataLocation );
end
        
    