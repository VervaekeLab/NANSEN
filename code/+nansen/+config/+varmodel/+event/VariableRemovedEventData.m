classdef VariableRemovedEventData < event.EventData
    properties
        VariableName % Name of the removed variable
    end
    
    methods
        function obj = VariableRemovedEventData(variableName)
            % Constructor for VariableAddedEventData class
            obj.VariableName = variableName;
        end
    end
end
