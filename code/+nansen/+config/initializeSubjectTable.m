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

    currentProject = nansen.getCurrentProject();

    % Add default information for saving the metatable to a struct
    S = struct();
    S.MetaTableName = metaTable.createDefaultName;
    S.MetaTableClass = subjectClassName;
    S.SavePath = currentProject.getProjectPackagePath('Metadata Tables');
    S.IsDefault = false;
    S.IsMaster = true;
    
    % Save the metatable in the current project
    try
        metaTable.archive(S);
    catch ME
        throwAsCaller(ME)
        % Todo: have some error handling here.
% %                 title = 'Could not save metadata table';
% %                 uialert(app.NansenSetupUIFigure, ME.message, title)
    end
end
