function convertPluginsToSidecars(options)
%convertPluginsToSidecars Generate sidecar JSON files for compat-discovered plugins.
%
%   Scans each plugin registry for specs that were discovered via class
%   introspection (Source == "class") and writes a sidecar JSON file next
%   to the .m file. Existing sidecar files are never overwritten.
%
%   This is a one-time migration tool for transitioning existing plugins to
%   the sidecar-first discovery model.
%
%   Syntax:
%     convertPluginsToSidecars()
%     convertPluginsToSidecars(PluginType='imviewer')
%     convertPluginsToSidecars(DryRun=true)
%
%   Input Arguments:
%     PluginType - Restrict to one type. Default: runs all types. Type: string
%     DryRun     - If true, print planned actions without writing. Default: false
%
%   See also: nansen.plugin.diagnose, nansen.plugin.Registry

    arguments
        options.PluginType (1,1) string  = "all"
        options.DryRun     (1,1) logical = false
    end

    import nansen.plugin.enum.PluginType

    if options.PluginType == "all"
        typesToRun = [PluginType.FileAdapter, PluginType.Action, ...
                      PluginType.TableVariable, PluginType.ImviewerPlugin];
    else
        typesToRun = PluginType(options.PluginType);
    end

    totalWritten = 0;
    totalSkipped = 0;

    for i = 1:numel(typesToRun)
        typeName = char(typesToRun(i));
        try
            registry = nansen.plugin.Registry.getInstance(typesToRun(i));
            specs    = registry.list();
        catch ME
            fprintf('  [%s]  Could not load registry: %s\n', typeName, ME.message)
            continue
        end

        for j = 1:numel(specs)
            spec = specs(j);
            if spec.Source ~= "class"; continue; end
            if isempty(char(spec.SourcePath)); continue; end

            sidecarPath = fullfile(fileparts(char(spec.SourcePath)), ...
                char(registry.SidecarFilename));

            if isfile(sidecarPath)
                totalSkipped = totalSkipped + 1;
                continue
            end

            try
                S = spec.toStruct();
                sidecarStruct = struct('schemaVersion', '1.0', ...
                    'pluginType', char(typeName), ...
                    'plugins',    {{S}});
            catch ME
                fprintf('  [%s]  Could not serialise "%s": %s\n', ...
                    typeName, char(spec.Id), ME.message)
                continue
            end

            if options.DryRun
                fprintf('  [DRY RUN] Would write: %s\n', sidecarPath)
            else
                try
                    fid = fopen(sidecarPath, 'w');
                    if fid == -1
                        fprintf('  [%s]  Cannot write: %s\n', typeName, sidecarPath)
                        continue
                    end
                    fprintf(fid, '%s', jsonencode(sidecarStruct, 'PrettyPrint', true));
                    fclose(fid);
                    fprintf('  [%s]  Written: %s\n', typeName, sidecarPath)
                    totalWritten = totalWritten + 1;
                catch ME
                    fprintf('  [%s]  Write failed for "%s": %s\n', ...
                        typeName, char(spec.Id), ME.message)
                end
            end
        end
    end

    if options.DryRun
        fprintf('\nDry run complete.\n')
    else
        fprintf('\nDone. %d sidecar(s) written, %d already existed (skipped).\n', ...
            totalWritten, totalSkipped)
    end
end
