function report = diagnose(varargin)
%diagnose Report plugin discovery and validation issues.
%
%   report = nansen.plugin.diagnose() validates the currently supported
%   plugin registries and returns a struct array with plugin type, severity,
%   message and source path. Without an output argument, issues are printed
%   to the command window.

    if nargin == 0
        pluginTypes = {'module', 'fileadapter', 'action', 'tablevariable'};
    else
        pluginTypes = varargin;
    end

    report = struct('PluginType', {}, 'Severity', {}, ...
        'Message', {}, 'SourcePath', {});

    for i = 1:numel(pluginTypes)
        registry = nansen.plugin.Registry.getInstance(pluginTypes{i}, true);
        issues = registry.validate();

        for j = 1:numel(issues)
            report(end+1) = struct( ... %#ok<AGROW>
                'PluginType', pluginTypes{i}, ...
                'Severity', issues(j).Severity, ...
                'Message', issues(j).Message, ...
                'SourcePath', issues(j).SourcePath);
        end
    end

    if nargout == 0
        printReport(report)
        clear report
    end
end

function printReport(report)
    if isempty(report)
        fprintf('No plugin discovery issues found.\n')
        return
    end

    for i = 1:numel(report)
        fprintf('[%s:%s] %s\n', ...
            report(i).PluginType, report(i).Severity, report(i).Message)
        if ~isempty(report(i).SourcePath)
            fprintf('  %s\n', report(i).SourcePath)
        end
    end
end
