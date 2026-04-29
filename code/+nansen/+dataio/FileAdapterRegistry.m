classdef FileAdapterRegistry < nansen.plugin.fileadapter.Registry
%FileAdapterRegistry Compatibility alias for nansen.plugin.fileadapter.Registry.

    methods (Static)

        function registry = getInstance(forceRefresh)
        %getInstance Return the shared file adapter registry instance.
            if nargin < 1
                forceRefresh = false;
            end

            registry = nansen.plugin.fileadapter.Registry.getInstance(forceRefresh);
        end

        function entries = listAdapters(forceRefresh)
        %listAdapters Return file adapter registry entries.
            if nargin < 1
                forceRefresh = false;
            end

            registry = nansen.dataio.FileAdapterRegistry.getInstance(forceRefresh);
            entries = registry.listLegacy();
        end

    end

end
