classdef OptionsSet < handle
%OptionsSet Class that represents an options set and associated metadata

% NOT IMPLEMENTED YET : Outline for class representing an Options Set
%
%   [ ] Inherit from struct adapter
%   [ ] Method to update from preset 

    properties
        Name
        Description
        Options
        DateCreatedNum
        DateCreated
        DateModified
        Type                % Preset / custom 
        PresetReference     % For custom options sets
    end

    methods

    end


    % = datestr(t, 'yyyy.mm.dd - HH:MM:SS')



end