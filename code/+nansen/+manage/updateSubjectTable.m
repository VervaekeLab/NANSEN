function updateSubjectTable(metatableCatalog, subjectSchema)
%updateSubjectTable Add the subjects of the session table that the subject table lacks
%
%   updateSubjectTable(metatableCatalog) adds a row to the master subject
%   table for each subject ID in the master session table that the subject
%   table does not have. The new subjects are of the subject table's class,
%   so that their columns match the existing rows.
%
%   updateSubjectTable(metatableCatalog, subjectSchema) creates the new
%   subjects with the class named by subjectSchema.

    % Find master session table from metatable catalog
    sessionTable = metatableCatalog.getMasterMetaTable('session');
    subjectTable = metatableCatalog.getMasterMetaTable('subject');

    if nargin < 2
        subjectSchema = subjectTable.MetaTableClass;
    end

    try
        uniqueSubjectIds = unique( sessionTable.entries.subjectID );

        existingSubjectIds = unique( subjectTable.entries.SubjectID );

        newSubjectIds = setdiff(uniqueSubjectIds, existingSubjectIds);

        numSubjects = numel(newSubjectIds);
        if numSubjects == 0; return; end

        % Create subjects.
        subjectArray(numSubjects) = feval(subjectSchema); %#ok<FVAL>
        for i = 1:numSubjects
            subjectArray(i).SubjectID = newSubjectIds{i};
        end
    catch
        return
    end

    % Initialize a MetaTable using the given session schema and the
    % detected session folders.
    newSubjectTable = nansen.metadata.MetaTable.new(subjectArray);
    currentProject = nansen.getCurrentProject();
    currentProject.synchronizeMetaTableVariables(newSubjectTable);

    % Find all that are not part of existing metatable
    subjectTable.addTable(newSubjectTable.entries)
    subjectTable.save()
end
