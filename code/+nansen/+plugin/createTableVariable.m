function createTableVariable(options)
%createTableVariable Create a new table variable class from a template.
%
%   Syntax:
%     nansen.plugin.createTableVariable()
%     nansen.plugin.createTableVariable(Name='MyVariable')
%     nansen.plugin.createTableVariable(Name='MyVariable', TableType='session')
%
%   Input Arguments:
%     Name      - Class name for the table variable. Prompted if omitted. Type: string
%     TableType - Table type: 'session' (default) or 'subject'. Type: string
%
%   See also: nansen.plugin.createPlugin, nansen.metadata.abstract.TableVariable

    arguments
        options.Name      (1,1) string = ""
        options.TableType (1,1) string = "session"
    end

    options.TableType = lower(options.TableType);
    if ~ismember(options.TableType, ["session", "subject"])
        error('nansen:plugin:createTableVariable:InvalidTableType', ...
            'TableType must be "session" or "subject", got "%s".', options.TableType)
    end

    if options.Name == ""
        answer = inputdlg('Table variable class name:', 'Create Table Variable', 1, {''});
        if isempty(answer) || strcmp(strtrim(answer{1}), ''); return; end
        options.Name = string(strtrim(answer{1}));
    end

    if ~isvarname(char(options.Name))
        error('nansen:plugin:createTableVariable:InvalidName', ...
            '"%s" is not a valid MATLAB identifier.', char(options.Name))
    end

    tableVarRoot  = nansen.plugin.getPluginTargetFolder('tablevariable');
    typeFolder    = fullfile(tableVarRoot, ['+', char(options.TableType)]);
    if ~isfolder(typeFolder); mkdir(typeFolder); end

    targetFile = fullfile(typeFolder, [char(options.Name), '.m']);
    if isfile(targetFile)
        error('nansen:plugin:createTableVariable:FileExists', ...
            'File already exists:\n  %s', targetFile)
    end

    writeTemplate_(targetFile, options.Name);
    edit(targetFile)
end

function writeTemplate_(filePath, name)
    nameStr = char(name);
    content = sprintf([ ...
        'classdef %s < nansen.metadata.abstract.TableVariable\n', ...
        '%%%s Brief description.\n', ...
        '%%\n', ...
        '%%   See also: nansen.metadata.abstract.TableVariable\n', ...
        '\n', ...
        '    properties (Constant)\n', ...
        '        IS_EDITABLE = false\n', ...
        '        DEFAULT_VALUE = ''''\n', ...
        '    end\n', ...
        '\n', ...
        '    methods\n', ...
        '        function obj = %s(value)\n', ...
        '            if nargin < 1; value = ''''; end\n', ...
        '            obj@nansen.metadata.abstract.TableVariable(value);\n', ...
        '        end\n', ...
        '    end\n', ...
        '\n', ...
        'end\n'], nameStr, upper(nameStr), nameStr);

    fid = fopen(filePath, 'w');
    if fid == -1
        error('nansen:plugin:createTableVariable:CannotWrite', ...
            'Cannot write to: %s', filePath)
    end
    fprintf(fid, '%s', content);
    fclose(fid);
end
