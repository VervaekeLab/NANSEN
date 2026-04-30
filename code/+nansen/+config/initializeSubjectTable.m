function initializeSubjectTable(metatableCatalog, subjectClassName)

    if nargin < 2
        subjectClassName = 'nansen.metadata.type.Subject';
    end

    % Find master session table from metatable catalog
    sessionTable = metatableCatalog.getMasterMetaTable('session');

    try
        uniqueSubjectIds = unique( sessionTable.entries.subjectID );
        numSubjects = numel(uniqueSubjectIds);

        % Create subjects.
        subjectArray(numSubjects) = feval(subjectClassName); %#ok<FVAL>
        for i = 1:numel(uniqueSubjectIds)
            subjectArray(i).SubjectID = uniqueSubjectIds{i};
        end
    catch
        return
    end

    % Initialize a MetaTable
    metaTable = nansen.metadata.MetaTable.new(subjectArray);

    % Add default information for saving the metatable to a struct
    S = struct();
    S.MetaTableName = metaTable.createDefaultName;
    S.MetaTableClass = subjectClassName;
    S.IsDefault = false;
    S.IsMaster = true;
    
    % Register the metatable in the catalog and save to disk
    try
        catalog = nansen.metadata.MetaTableCatalog();
        catalog.registerMetaTable(metaTable, S);
    catch ME
        throwAsCaller(ME)
    end
end
