function wasSuccess = createNewSessionMethod(app)
%createNewSessionMethod Let user interactively create a new session method template    

    wasSuccess = false;
    
    % Parameters to open in a dialog
    S = struct();
    S.MethodName = '';
% %     S.BatchMode = 'serial';
% %     S.BatchMode_ = {'serial', 'batch'};
    S.Input = 'Single session';
    S.Input_ = {'Single session', 'Multiple sessions'};    
    S.Queueable = true;
    S.Type = 'Function'; % (Template type, i.e use function template or sessionmethod template)
    S.Type_ = {'Function', 'SessionMethod Class'};
    
    menuNames = app.SessionTaskMenu.getTopMenuNames();
    S.MenuLocation = menuNames{1};
    S.MenuLocation_ = menuNames;
    
    S.MenuSubLocation = '';
    
    [S, wasAborted] = tools.editStruct(S, '', 'Create Session Method', ...
                'Prompt', 'Configure new session method:', ...
                'ReferencePosition', app.Figure.Position, ...
                'ValueChangedFcn', @onValueChanged );
    
    if wasAborted; return; end
    if isempty(S.MethodName); return; end
    wasSuccess = true;

    
    switch S.Type
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
    switch S.Type
        case 'Function'
            expression = 'ATTRIBUTES = {''serial'', ''queueable''}';
            replacement = expression;

            if strcmpi(S.Input, 'single session')
                replacement = strrep(replacement, 'serial', 'batch');
            end
            if ~S.Queueable
                replacement = strrep(replacement, 'queueable', 'unqueueable');
            end
            fcnContentStr = strrep(fcnContentStr, expression, replacement);
            
        case 'SessionMethod Class'
            fcnContentStr = strrep(fcnContentStr, 'MethodName = ''''', sprintf('MethodName = ''%s''', S.MethodName));
            switch lower( S.Input )
                case 'single session'
                    % This is the default
                case 'multiple sessions'
                    expression = 'BatchMode = ''serial''';
                    replacement = 'BatchMode = ''batch''';
                    fcnContentStr = strrep(fcnContentStr, expression, replacement);
            end
            
            if ~S.Queueable
                expression = 'IsQueueable = true';
                replacement = 'IsQueueable = false';
                fcnContentStr = strrep(fcnContentStr, expression, replacement);
                
                % Todo: This is redeundant. Remove of fix according to
                % intention.
                expression = 'IsManual = false';
                replacement = 'IsManual = true';
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

function onValueChanged(~, evt)

    switch evt.Name
        case {'MethodName', 'MenuSubLocation'}
            if ~isvarname(evt.NewValue)
                msg = sprintf('%s must be a valid matlab variable name', evt.Name);
                formattedMsg = strcat('\fontsize{12}', msg);
                opts = struct('WindowStyle', 'modal', 'Interpreter', 'tex');
                errordlg(formattedMsg, 'Invalid Value', opts)
                evt.UIControls.(evt.Name).String = evt.OldValue;
            end
    end
end