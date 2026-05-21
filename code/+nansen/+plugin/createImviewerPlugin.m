function createImviewerPlugin(options)
%createImviewerPlugin Create a new imviewer plugin class from a template.
%
%   The generated class extends imviewer.ImviewerPlugin and is placed in
%   nansen.plugin.imviewer (the canonical implementation package). An
%   imviewerplugin.plugin.json sidecar file is created alongside the class
%   so it is discoverable via the registry.
%
%   Syntax:
%     nansen.plugin.createImviewerPlugin()
%     nansen.plugin.createImviewerPlugin(Name='MyPlugin')
%     nansen.plugin.createImviewerPlugin(Name='MyPlugin', DisplayName='My Plugin')
%
%   Input Arguments:
%     Name        - Class name (identifier). Prompted if omitted. Type: string
%     DisplayName - Human-readable label. Defaults to Name. Type: string
%
%   See also: nansen.plugin.createPlugin, nansen.plugin.imviewer.Registry

    arguments
        options.Name        (1,1) string = ""
        options.DisplayName (1,1) string = ""
    end

    if options.Name == ""
        answer = inputdlg('Plugin class name:', 'Create Imviewer Plugin', 1, {''});
        if isempty(answer) || strcmp(strtrim(answer{1}), ''); return; end
        options.Name = string(strtrim(answer{1}));
    end

    if ~isvarname(char(options.Name))
        error('nansen:plugin:createImviewerPlugin:InvalidName', ...
            '"%s" is not a valid MATLAB identifier.', char(options.Name))
    end

    if options.DisplayName == ""
        options.DisplayName = options.Name;
    end

    % Target: nansen.plugin.imviewer package (canonical implementation folder)
    thisDir    = fileparts(mfilename('fullpath'));
    codeRoot   = fileparts(thisDir);   % code/
    targetDir  = fullfile(codeRoot, '+nansen', '+plugin', '+imviewer');
    if ~isfolder(targetDir); mkdir(targetDir); end

    classFile   = fullfile(targetDir, [char(options.Name), '.m']);
    sidecarFile = fullfile(targetDir, 'imviewerplugin.plugin.json');

    if isfile(classFile)
        error('nansen:plugin:createImviewerPlugin:FileExists', ...
            'Class file already exists:\n  %s', classFile)
    end

    % Full qualified class name
    qualifiedName = sprintf('nansen.plugin.imviewer.%s', char(options.Name));

    writeClassTemplate_(classFile, options.Name, options.DisplayName);
    appendToSidecar_(sidecarFile, qualifiedName, options.DisplayName);

    % Invalidate the registry singleton so it picks up the new file.
    clear('nansen.plugin.imviewer.Registry')

    edit(classFile)
end

function writeClassTemplate_(filePath, name, displayName)
    nameStr        = char(name);
    displayNameStr = char(displayName);
    content = sprintf([ ...
        'classdef %s < imviewer.ImviewerPlugin\n', ...
        '%%%s %s imviewer plugin.\n', ...
        '%%\n', ...
        '%%   See also: imviewer.ImviewerPlugin, nansen.plugin.imviewer.Registry\n', ...
        '\n', ...
        '    properties (Constant)\n', ...
        '        Name = ''%s''\n', ...
        '    end\n', ...
        '\n', ...
        '    methods\n', ...
        '        function obj = %s(ImviewerApp, varargin)\n', ...
        '            obj@imviewer.ImviewerPlugin(ImviewerApp, varargin{:});\n', ...
        '            %% Initialize plugin here\n', ...
        '        end\n', ...
        '    end\n', ...
        '\n', ...
        'end\n'], nameStr, upper(nameStr), displayNameStr, displayNameStr, nameStr);

    fid = fopen(filePath, 'w');
    if fid == -1
        error('nansen:plugin:createImviewerPlugin:CannotWrite', ...
            'Cannot write to: %s', filePath)
    end
    fprintf(fid, '%s', content);
    fclose(fid);
end

function appendToSidecar_(sidecarFile, qualifiedName, displayName)
    newEntry = struct( ...
        'id',             char(qualifiedName), ...
        'displayName',    char(displayName), ...
        'implementation', struct('language', 'matlab', 'kind', 'class', ...
            'entrypoint', char(qualifiedName)), ...
        'menuLocation',   {{}}, ...
        'iconName',       '', ...
        'shortcutKey',    '');

    if isfile(sidecarFile)
        % Append to existing grouped sidecar
        raw = jsondecode(fileread(sidecarFile));
        if isfield(raw, 'plugins')
            raw.plugins{end+1} = newEntry;
        else
            % Single-entry sidecar — convert to grouped
            raw = struct('schemaVersion', '1.0', ...
                'plugins', {{raw, newEntry}});
        end
    else
        raw = struct('schemaVersion', '1.0', 'plugins', {{newEntry}});
    end

    fid = fopen(sidecarFile, 'w');
    if fid == -1
        error('nansen:plugin:createImviewerPlugin:CannotWrite', ...
            'Cannot write sidecar to: %s', sidecarFile)
    end
    fprintf(fid, '%s', jsonencode(raw, 'PrettyPrint', true));
    fclose(fid);
end
