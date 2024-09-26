classdef HasUserData < handle
% HasUserData - A class for managing user data and tracking changes.
%
%   This class allows you to manage user data and track changes made to
%   the data. It provides functionality to reset the data to its original
%   state and determine if any modifications have been made.
%
%   Properties:
%       Data    - The user data to be managed.
%       IsDirty - A flag indicating whether the data has been modified
%                 from its original state.
%
%   Methods:
%       HasUserData - Constructor method to create a HasUserData object.
%       resetData - Resets the data to its original state.
%       markClean - Marks the current state of the data as clean.
%
%   Example:
%       % Create a HasUserData object with initial data
%       userData = HasUserData(42);
%
%       % Check if the data has been modified
%       isModified = userData.IsDirty;
%
%       % Reset the data to its original state
%       userData.resetData();
%
%       % Mark the current state of the data as clean
%       userData.markClean();
%
%   Author: Eivind Hennestad
%   Created: 2024-02-14
%   Updated: 2024-02-14

    % Todo:
    %   [ ] Maintain a history of modification to data and provide
    %   undo/redo methods

    properties
        Data % The user data to be managed.
    end

    properties (Dependent, Hidden)
        % IsDirty - A flag indicating whether the data has been modified 
        % from its original state.
        IsDirty 
    end

    properties (Access = private)
        OriginalData % The original state of the data.
    end
    
    events
        % DataChanged - Event that is triggered whenever the Data is
        % modified.
        DataChanged
    end

    methods 
        function obj = HasUserData(data)
            arguments
                data = [];
            end
            [obj.Data, obj.OriginalData] = deal( data );
        end
    end

    methods % Set/get
        function isDirty = get.IsDirty(obj)
            isDirty = ~isequaln(obj.Data, obj.OriginalData);
        end

        function set.Data(obj, newData)
            oldData = obj.Data;
            % Could use the AbortSet attribute, but envision to use this
            % class in situations where data need to be compared using
            % isequaln
            if isequaln(newData, oldData); return; end
            obj.Data = newData;
            if isempty(oldData); obj.OriginalData = newData; end %#ok<MCSUP>
            
            % Todo: Create event data and pass oldData and newData
            obj.notify('DataChanged', event.EventData)
        end
    end

    methods 
        function resetData(obj)
        % resetData - Reset the data to its original state.
            obj.Data = obj.OriginalData;
        end
        
        function markClean(obj)
        % markClean - Update original data to match current data.
            obj.OriginalData = obj.Data;
        end
    end
end