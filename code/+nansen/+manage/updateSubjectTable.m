function updateSubjectTable(metatableCatalog, subjectSchema)

    if nargin < 2
        subjectSchema = 'nansen.metadata.type.Subject';
    end

    % Find master session table from metatable catalog
    sessionTable = metatableCatalog.getMasterMetaTable('session');
    subjectTable = metatableCatalog.getMasterMetaTable('subject');
    
    try
        uniqueSubjectIds = unique( sessionTable.entries.subjectID );

        existingSubjectIds = unique( subjectTable.entries.SubjectID );

        newSubjectIds = setdiff(uniqueSubjectIds, existingSubjectIds);

        numSubjects = numel(newSubjectIds);
        if numSubjects == 0; return; end

        % Create subjects.
        subjectArray(numSubjects) = feval(subjectSchema); %#ok<FVAL>
        for i = 1:numel(uniqueSubjectIds)
            subjectArray(i).SubjectID = uniqueSubjectIds{i};
        end
    catch
        return
    end

    % Initialize a MetaTable using the given session schema and the
    % detected session folders.
    newSubjectTable = nansen.metadata.MetaTable.new(subjectArray);
    newSubjectTable.addMissingVarsToMetaTable('subject');
    
    % Find all that are not part of existing metatable
    subjectTable.appendTable(newSubjectTable.entries)
    subjectTable.save()
end