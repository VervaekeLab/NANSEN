function wasSuccess = createNewSessionMethod(itemType, options)
%createNewSessionMethod Let user interactively create a new session method template
%
%   wasSuccess = createNewSessionMethod(itemType) opens a dialog and saves a
%   new method template in the method folder of the current project. The
%   dialog stays open until its values can be used for a new method, or
%   until the dialog is cancelled. wasSuccess is false if it was cancelled.

% Todo: generalize to apply to any item type

    arguments
        itemType (1,1) string = "Session"
        options.GroupNames (1,:) string = ["default"]
        options.WindowReferencePosition (1,4) double = get(0, 'ScreenSize')
    end

    wasSuccess = false;

    % Parameters to open in a dialog
    S = struct();
    S.MethodName = '';
    S.Input_ = {...
        sprintf('Single %s', lower(itemType)), ...  % Ex: Single session
        sprintf('Multiple %ss', lower(itemType)) }; % Ex: Multiple sessions
    S.Input = S.Input_{1};
    S.Queueable = true;
    S.Type = 'Function'; % (Template type, i.e use function template or sessionmethod template)
    S.Type_ = {'Function', 'SessionMethod Class'};

    S.MenuLocation = options.GroupNames{1}; % use {} to ensure char type
    S.MenuLocation_ = cellstr(options.GroupNames); % add as cell array

    S.MenuSubLocation = ''; % Optional. Comma-separated names of nested submenus

    titleStr = sprintf('Create %s Method', itemType);
    messageStr = sprintf('Configure new %s method:', itemType);

    methodsFolder = nansen.session.methods.getProjectsSessionMethodsDirectory(itemType);
    getProblem = @(values) nansen.session.methods.template.internal.getInputProblem(values, methodsFolder);

    [S, wasAborted] = tools.editStruct(S, '', titleStr, ...
                'Prompt', messageStr, ...
                'ReferencePosition', options.WindowReferencePosition, ...
                'ValidationFcn', getProblem);

    if wasAborted; return; end
    wasSuccess = true;

    switch S.Type
        case 'Function'
            mFilename = 'sessionMethodFunctionTemplate';
        case 'SessionMethod Class'
            mFilename = 'sessionMethodClassTemplate';
    end

    templateFolderDir = nansen.localpath('session_method_templates');
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

            if startsWith(S.Input, 'multiple', 'IgnoreCase', true)
                replacement = strrep(replacement, 'serial', 'batch');
            end
            if ~S.Queueable
                replacement = strrep(replacement, 'queueable', 'unqueueable');
            end
            fcnContentStr = strrep(fcnContentStr, expression, replacement);

        case 'SessionMethod Class'
            fcnContentStr = strrep(fcnContentStr, 'MethodName = ''''', sprintf('MethodName = ''%s''', S.MethodName));

            if startsWith(S.Input, 'single', 'IgnoreCase', true)
                expression = 'BatchMode = ''serial''';
                replacement = 'BatchMode = ''batch''';
                fcnContentStr = strrep(fcnContentStr, expression, replacement);

            elseif startsWith(S.Input, 'multiple', 'IgnoreCase', true)
                % This is the default case
            end

            if ~S.Queueable
                expression = 'IsQueueable = true';
                replacement = 'IsQueueable = false';
                fcnContentStr = strrep(fcnContentStr, expression, replacement);

                % Todo: This is redundant. Remove or fix according to intention.
                expression = 'IsManual = false';
                replacement = 'IsManual = true';
                fcnContentStr = strrep(fcnContentStr, expression, replacement);
            end
    end

    if ~strcmpi(itemType, "session")
        fcnContentStr = strrep(fcnContentStr, 'sessionObject', sprintf('%sObject', lower(itemType)));
    end

    % Save template
    filePath = nansen.session.methods.template.internal.getTargetFilePath(S, methodsFolder);

    targetFolder = fileparts(filePath);
    if ~isfolder(targetFolder)
        mkdir(targetFolder)
    end

    % Create a new m-file and add the function template to the file.
    fid = fopen(filePath, 'w');
    fwrite(fid, fcnContentStr);
    fclose(fid);

    % Finally, open the function in the matlab editor.
    edit(char(filePath))
end
