classdef MetaTableFileChangedEventData < event.EventData
%MetaTableFileChangedEventData Event data for external MetaTable changes

    properties
        MetaTable (1,1) nansen.metadata.MetaTable
    end

    methods
        function obj = MetaTableFileChangedEventData(metaTable)
            obj.MetaTable = metaTable;
        end
    end
end
