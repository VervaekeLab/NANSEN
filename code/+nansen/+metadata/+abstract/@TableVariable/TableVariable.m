classdef TableVariable
%nansen.metadata.abstract.TableVariable Implement a custom variable type to
%display in a table cell.
%
%   
%   Subclasses must implement a Value and two methods, one for creating a
%   string to be displayed within a cell and one for creating a string to
%   be displayed as a tooltip (getCellDisplayString, getCellTooltipString
%   respectively).

    properties (Abstract)
        Value struct
    end
    
    
    methods (Abstract)
        str = getCellDisplayString(obj)
        str = getCellTooltipString(obj)
    end
    
    methods
        function obj = TableVariable(S)
            obj.Value = S;
        end
    end
    
end