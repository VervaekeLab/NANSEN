function issueTable = diagnose(options)
%diagnose Run all plugin registries and report discovery issues.
%
%   Runs each implemented plugin registry and collects warnings and errors
%   reported during sidecar parsing and class introspection. Results are
%   printed to the Command Window.
%
%   Syntax:
%     nansen.plugin.diagnose()
%     nansen.plugin.diagnose(PluginType='imviewer')
%     issueTable = nansen.plugin.diagnose()
%
%   Input Arguments:
%     PluginType - Restrict to a single type. Default: runs all types.
%                  Values: 'fileadapter' | 'action' | 'tablevariable' | 'imviewerplugin'
%
%   Output Arguments:
%     issueTable - MATLAB table of all issues. Only returned if requested.
%
%   See also: nansen.plugin.Registry, nansen.plugin.base.Registry

    arguments
        options.PluginType (1,1) string = "all"
    end

    import nansen.plugin.enum.PluginType

    if options.PluginType == "all"
        typesToRun = [PluginType.FileAdapter, PluginType.Action, ...
                      PluginType.TableVariable, PluginType.ImviewerPlugin];
    else
        typesToRun = PluginType(options.PluginType);
    end

    allIssues = table( ...
        string.empty(0,1), string.empty(0,1), string.empty(0,1), string.empty(0,1), ...
        'VariableNames', {'PluginType', 'Severity', 'Message', 'Source'});

    for i = 1:numel(typesToRun)
        typeName = char(typesToRun(i));
        try
            registry = nansen.plugin.Registry.getInstance(typesToRun(i));
            specs    = registry.list();
            issues   = registry.validate();
        catch ME
            issues = struct('Severity', 'error', 'Message', ME.message, 'Source', '');
        end

        if isempty(issues)
            fprintf('  [%s]  %d specs — no issues\n', typeName, numel(specs))
        else
            for j = 1:numel(issues)
                row = table( ...
                    string(typeName), string(issues(j).Severity), ...
                    string(issues(j).Message), string(issues(j).Source), ...
                    'VariableNames', {'PluginType', 'Severity', 'Message', 'Source'});
                allIssues = [allIssues; row]; %#ok<AGROW>
            end

            errors   = sum(strcmp(allIssues.Severity, 'error'));
            warnings = sum(strcmp(allIssues.Severity, 'warning'));
            fprintf('  [%s]  %d specs — %d error(s), %d warning(s)\n', ...
                typeName, numel(specs), errors, warnings)
        end
    end

    if ~isempty(allIssues)
        fprintf('\nIssue details:\n')
        for i = 1:height(allIssues)
            fprintf('  %s  [%s]  %s\n    Source: %s\n', ...
                upper(char(allIssues.Severity(i))), ...
                char(allIssues.PluginType(i)), ...
                char(allIssues.Message(i)), ...
                char(allIssues.Source(i)))
        end
    else
        fprintf('\nAll registries are healthy.\n')
    end

    issueTable = allIssues;
end
