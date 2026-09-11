classdef (Sealed) Report < handle
%Report Collects the model elements a conversion did not map, and why
%
%   A handle, so that the helpers of a conversion can add to one report
%   without passing it back.

    properties (SetAccess = private)
        Element (:,1) string = string.empty(0, 1)
        Reason (:,1) string = string.empty(0, 1)
    end

    methods
        function add(obj, element, reason, condition)
        %add Record an element and the reason it was not mapped
        %
        %   report.add(element, reason, condition) records only when
        %   condition is true, so that callers can report conditionally
        %   without wrapping each call in an if block.

            arguments
                obj
                element (1,1) string
                reason (1,1) string
                condition (1,1) logical = true
            end

            if ~condition
                return
            end
            obj.Element(end+1, 1) = element;
            obj.Reason(end+1, 1) = reason;
        end

        function reportTable = toTable(obj)
        %toTable The report as a table with Element and Reason columns
            reportTable = table(obj.Element, obj.Reason, ...
                'VariableNames', {'Element', 'Reason'});
        end
    end
end
