classdef OptionsSet < handle
%OptionsSet Class that represents an options set and associated metadata

% NOT IMPLEMENTED YET : Outline for class representing an Options Set
%
%   [ ] Inherit from struct adapter
%   [ ] Method to update from preset

    properties
        Name
        Description
        Options
    end

    properties (SetAccess = private)
        DateCreatedNum
        DateCreated
        DateModified
        Type                % Preset / custom
        PresetReference     % For custom options sets
    end

    methods

        function obj = OptionSet(name)
            obj.Name = name;
        end
    end

    % = char(datetime(t, 'ConvertFrom', 'datenum'), 'yyyy.MM.dd - HH:mm:ss')
end
