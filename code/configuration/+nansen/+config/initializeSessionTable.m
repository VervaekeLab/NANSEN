function initializeSessionTable(dataLocationModel, sessionSchema)


    import nansen.dataio.session.listSessionFolders
    import nansen.dataio.session.matchSessionFolders
    
    %sessionSchema = @nansen.metadata.schema.vlab.TwoPhotonSession;


    % % Use the folder structure to detect session folders.
    sessionFolders = listSessionFolders(dataLocationModel, 'all');
    sessionFolders = matchSessionFolders(dataLocationModel, sessionFolders);
    
    if isempty(sessionFolders)
        % Todo: Get exception
        errorID = 'Nansen:Configuration:NoSessionFoldersDetected';
        errorMsg = 'Can not proceed because no session folders were detected.';
        throwAsCaller(MException(errorID, errorMsg))
    end

    
    % Create a list of session metadata objects
    numSessions = numel(sessionFolders);
    sessionArray = cell(numSessions, 1);
    for i = 1:numSessions
        sessionArray{i} = sessionSchema(sessionFolders(i));
    end
    
    sessionArray = cat(1, sessionArray{:});
    

    
    % Initialize a MetaTable using the given session schema and the
    % detected session folders.
    metaTable = nansen.metadata.MetaTable.new(sessionArray);

    % Add default information for saving the metatable to a struct
    S = struct();
    S.MetaTableName = metaTable.createDefaultName;
    S.SavePath = nansen.config.project.ProjectManager.getProjectSubPath('MetaTable');
    S.IsDefault = true;
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
    
    
    % Get user defined (project) variables...
    varNames = nansen.metadata.utility.getCustomTableVariableNames();
    
    for i = 1:numel(varNames)
        
        thisName = varNames{i};
        
        if metaTable.isVariable(thisName)
            continue
        end
        
        thisFcn = str2func(strjoin({'tablevar', 'session', thisName}, '.'));
        
        initValue = thisFcn();
        
        if isa(initValue, 'nansen.metadata.abstract.TableVariable')
            initValue = initValue.DEFAULT_VALUE;
        end
        
        metaTable.addTableVariable(thisName, initValue)
    end
    
    metaTable.save()
   
    
end