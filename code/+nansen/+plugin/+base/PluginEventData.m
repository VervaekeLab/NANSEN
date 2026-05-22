classdef PluginEventData < event.EventData
%PluginEventData Payload for registry plugin events.
%
%   Carries the affected entry (for PluginAdded and PluginChanged events)
%   and the plugin ID (for PluginRemoved events). Either field may be
%   empty depending on the event type.

    properties (SetAccess = immutable)
        Entry   % Struct with parsed adapter fields (Added / Changed events)
        PluginId (1,1) string = ""  % Adapter name id (Removed events)
    end

    methods
        function obj = PluginEventData(entry, pluginId)
            arguments
                entry   struct = struct.empty
                pluginId (1,1) string = ""
            end
            obj.Entry = entry;
            obj.PluginId = pluginId;
        end
    end
end
