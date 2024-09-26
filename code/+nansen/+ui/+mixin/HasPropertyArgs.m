classdef HasPropertyArgs < handle
%HasPropertyArgs Method for assigning property values from argument structure
    %   Detailed explanation goes here

    methods (Access = protected)
        function assignPropertyArguments(obj, argumentStructure)
        % assignPropertyArguments - Assign property values from an argument structure
            argumentNames = string(fieldnames(argumentStructure));
            argumentNames = reshape(argumentNames, 1, []); % Ensure row
            for argumentName = argumentNames
                if isprop(obj, argumentName)
                    obj.(argumentName) = argumentStructure.(argumentName);
                else
                    warning('%s is not a settable property for uicontrol of type %s', argumentName, class(obj))
                end
            end
        end
    end
end
