function createNewSessionMethod(app)
%createNewSessionMethod Let user interactively create a new session method template    


    % Parameters to open in a dialog
    S = struct();
    S.MethodName = '';
    S.BatchMode = 'serial';
    S.BatchMode_ = {'serial', 'batch'};
    S.IsQueueable = true;
    S.TemplateType = 'Function';
    S.TemplateType_ = {'Function', 'SessionMethod Class'};
    
    menuNames = app.SessionMethodsMenu.getTopMenuNames();
    S.MenuLocation = menuNames{1};
    S.MenuLocation_ = menuNames;
    
    S.MenuSubLocation = '';
    
    [S, wasAborted] = tools.editStruct(S, '', 'new session method configuration', ...
                'ReferencePosition', app.Figure.Position);
    
    if wasAborted; return; end
    if isempty(S.MethodName); return; end
    
    
    switch S.TemplateType
        case 'Function'
            mFilename = 'sessionMethodFunctionTemplate';
        case 'SessionMethod Class'
            mFilename = 'sessionMethodClassTemplate';
    end
    
    templateFolderDir = fullfile(nansen.rootpath, '+session', '+methods', ...
        '+template');
    

    fcnSourcePath = fullfile(templateFolderDir, [mFilename, '.m']);
    
    
    % Modify the template function by adding the variable name
    fcnContentStr = fileread(fcnSourcePath);
    fcnContentStr = strrep(fcnContentStr, mFilename, S.MethodName);
    fcnContentStr = strrep(fcnContentStr, upper(mFilename), upper(S.MethodName));
    
    % Add attributes
    switch S.TemplateType
        case 'Function'
            expression = 'ATTRIBUTES = {''serial'', ''queueable''}';
            replacement = expression;

            if strcmp(S.BatchMode, 'batch')
                replacement = strrep(replacement, 'serial', 'batch');
            end
            if ~S.IsQueueable
                replacement = strrep(replacement, 'queueable', 'unqueueable');
            end
            fcnContentStr = strrep(fcnContentStr, expression, replacement);
            
        case 'SessionMethod Class'
            fcnContentStr = strrep(fcnContentStr, 'MethodName = ''', sprintf('MethodName = ''%s''', S.MethodName));
            switch S.BatchMode
                case 'serial'
                    % This is the default
                case 'batch'
                    expression = 'BatchMode = ''serial''';
                    replacement = 'BatchMode = ''batch''';
                    fcnContentStr = strrep(fcnContentStr, expression, replacement);
            end
            
            if ~S.IsQueueable
                expression = 'IsQueueable = true';
                replacement = 'IsQueueable = false';
                fcnContentStr = strrep(fcnContentStr, expression, replacement);
            end
            
    end
    
    % Save template
    projectDir = nansen.localpath('project');
    projectName = getpref('Nansen', 'CurrentProject');
    sMethodDir = fullfile(projectDir, 'Session Methods', ['+',projectName]);
    
    if ~isempty(S.MenuSubLocation)
        S.MenuLocation = [S.MenuLocation, strsplit(S.MenuSubLocation, ', ')];
    else
        S.MenuLocation = {S.MenuLocation};
    end
    
    subfolderNames = cellfun(@(c) ['+', c], S.MenuLocation, 'uni', 0);
    fcnTargetPath = fullfile(sMethodDir, subfolderNames{:});
    fcnFilename = [ S.MethodName, '.m' ];
        
        
    if ~exist(fcnTargetPath, 'dir'); mkdir(fcnTargetPath); end
    
    % Create a new m-file and add the function template to the file.
    fid = fopen(fullfile(fcnTargetPath, fcnFilename), 'w');
    fwrite(fid, fcnContentStr);
    fclose(fid);
    
    % Finally, open the function in the matlab editor.
    edit(fullfile(fcnTargetPath, fcnFilename))
    
    
    
end