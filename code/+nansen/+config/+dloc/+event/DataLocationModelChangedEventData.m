classdef (Sealed) DataLocationModelChangedEventData < event.EventData
%DataLocationModelChangedEventData Event data for a saved data location model
%
%   nansen.config.dloc.DataLocationModelApp sends this event data with its
%   DataLocationModelChanged event, after the edited data location model is
%   saved.
%
%   See also nansen.config.dloc.DataLocationModelApp

    properties (SetAccess = immutable)
        % HasMetadataDefinitionChanges - True when the save includes changes
        % made on the "Metadata Initialization" page, which defines how
        % subject IDs, session IDs, dates and times are extracted from the
        % paths of session folders.
        HasMetadataDefinitionChanges (1,1) logical = false
    end

    methods
        function data = DataLocationModelChangedEventData(hasMetadataDefinitionChanges)
            arguments
                hasMetadataDefinitionChanges (1,1) logical = false
            end
            data.HasMetadataDefinitionChanges = hasMetadataDefinitionChanges;
        end
    end
end
