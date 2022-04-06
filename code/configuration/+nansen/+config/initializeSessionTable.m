function wasAborted = initializeSessionTable(dataLocationModel, sessionSchema, uiWaitbar, hFigure)

    if nargin < 3; uiWaitbar = struct(); end  % create dummy waitbar
    if nargin < 4; hFigure = []; end
    
    import nansen.dataio.session.listSessionFolders
    import nansen.dataio.session.matchSessionFolders
    
    %sessionSchema = @nansen.metadata.schema.vlab.TwoPhotonSession;
    
    uiWaitbar.Message = 'Locating session folders...';
    
    % % Use the folder structure to detect session folders.
    sessionFolders = listSessionFolders(dataLocationModel, 'all');
    sessionFolders = matchSessionFolders(dataLocationModel, sessionFolders);
    
    if isempty(sessionFolders)
        % Todo: Get exception
        errorID = 'Nansen:Configuration:NoSessionFoldersDetected';
        errorMsg = 'Can not proceed because no session folders were detected.';
        throwAsCaller(MException(errorID, errorMsg))
    end

    uiWaitbar.Message = 'Creating session objects...';
    
    % Create a list of session metadata objects
    numSessions = numel(sessionFolders);
    sessionArray = cell(numSessions, 1);
    for i = 1:numSessions
        sessionArray{i} = sessionSchema(sessionFolders(i), 'DataLocationModel', dataLocationModel);
    end
    
    sessionArray = cat(1, sessionArray{:});
    
    % Check for duplicate session IDs
    sessionIDs = {sessionArray.sessionID};
    if numel(sessionIDs) ~= numel(unique(sessionIDs))
        [sessionArray, wasAborted] = nansen.manage.uiresolveDuplicateSessions(sessionArray, hFigure);
        % Todo: Rerun initialization from here if sessions were resolved
        if wasAborted
            return
        end
    end
    
    uiWaitbar.Message = 'Creating session table...';

    
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
    
    uiWaitbar.Message = 'Implementing project specifications...';

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
   
    uiWaitbar.Message = 'Metatable created!'; %#ok<STRNU>
    
    wasAborted = false;
    
    
end