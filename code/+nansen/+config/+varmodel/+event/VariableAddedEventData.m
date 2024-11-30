classdef VariableAddedEventData < event.EventData
    properties
        VariableInfo % Information about the added variable
    end
    
    methods
        function obj = VariableAddedEventData(variableInfo)
            % Constructor for VariableAddedEventData class
            obj.VariableInfo = variableInfo;
        end
    end
end
