function updateSubjectTable(metatableCatalog, subjectSchema)
%updateSubjectTable Add the subjects of the session table that the subject table lacks
%
%   updateSubjectTable(metatableCatalog) adds a row to the master subject
%   table for each subject ID in the master session table that the subject
%   table does not have. The new subjects are of the class that the subject
%   table creates its entries with: its ItemClassName, or its
%   MetaTableClass when ItemClassName is empty. Their columns then match
%   the existing rows.
%
%   updateSubjectTable(metatableCatalog, subjectSchema) creates the new
%   subjects with the class named by subjectSchema.
%
%   The class of the new subjects must be nansen.metadata.type.Subject or
%   a subclass of it. It is checked only when there are new subjects.

    % Find master session table from metatable catalog
    sessionTable = metatableCatalog.getMasterMetaTable('session');
    subjectTable = metatableCatalog.getMasterMetaTable('subject');

    if nargin < 2
        subjectSchema = subjectTable.ItemClassName;
        if isempty(subjectSchema)
            subjectSchema = subjectTable.MetaTableClass;
        end
    end
    try
        uniqueSubjectIds = unique( sessionTable.entries.subjectID );

        existingSubjectIds = unique( subjectTable.entries.SubjectID );

        newSubjectIds = setdiff(uniqueSubjectIds, existingSubjectIds);
    catch
        return
    end

    numSubjects = numel(newSubjectIds);
    if numSubjects == 0; return; end

    % The class is checked only when there are subjects to create, so a
    % subject table whose subjects all exist is left alone
    validateSubjectClass(subjectSchema, subjectTable)

    try
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

function validateSubjectClass(className, subjectTable)
%validateSubjectClass Error unless a class is nansen.metadata.type.Subject or a subclass of it
%
%   updateSubjectTable calls the class constructor without inputs and sets
%   the SubjectID property of each new object, which
%   nansen.metadata.type.Subject defines. The class must therefore be
%   nansen.metadata.type.Subject or a subclass of it, and it must be on
%   the MATLAB path.

    arguments
        className {mustBeTextScalar}
        subjectTable (1,1) nansen.metadata.MetaTable
    end

    subjectClass = meta.class.fromName(className);
    if isempty(subjectClass) || ~(subjectClass <= ?nansen.metadata.type.Subject)
        error("NANSEN:UpdateSubjectTable:InvalidSubjectClass", ...
            "Cannot add subjects to the metatable ""%s"" because the subject class ""%s"" " + ...
            "is not nansen.metadata.type.Subject or a subclass of it on the MATLAB path. " + ...
            "Add the folder that defines the class to the MATLAB path, or use a subject " + ...
            "class that derives from nansen.metadata.type.Subject.", ...
            subjectTable.MetaTableName, className)
    end
end
