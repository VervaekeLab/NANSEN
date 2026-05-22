classdef ConcreteRegistry < nansen.plugin.base.Registry
%ConcreteRegistry Test double for nansen.plugin.base.Registry.
%
%   scanSource reads a plugins.mat file from the given directory. Each
%   element in the 'plugins' variable must be a struct with at least a
%   'PluginId' field. The PluginId is used as the primary identifier.

    methods (Access = protected)
        function id = primaryId(~, entry)
            id = string(entry.PluginId);
        end

        function entries = scanSource(~, ~, sourcePath)
            matFile = fullfile(sourcePath, 'plugins.mat');
            if ~isfile(matFile)
                entries = struct('PluginId', {}, 'Source', {});
                return
            end
            loaded = load(matFile, 'plugins');
            entries = loaded.plugins;
        end
    end
end
