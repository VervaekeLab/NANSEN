classdef TableColumnFormatter
%TableColumnFormatter Abstract mixin class for formatting column data.
%
%   This class should be inherited by concrete table variable classes which
%   should have a custom display of column data.
%
%   Subclasses must implement two methods, one for creating a string to be 
%   displayed within a cell and one for creating a string to be displayed 
%   as a tooltip (getCellDisplayString, getCellTooltipString respectively).


% Note on implementation:
%   Subclasses should work on vectors of objects, and return cell
%   arrays of formatted strings with one cell for each object. This is
%   preferable in order to increase efficiendy for large tables.

% Note: Rename to TableColumnRenderer?

    properties (Abstract, Hidden)
        Value       % The data value
    end

    methods (Abstract)
        
        str = getCellDisplayString(obj)

        str = getCellTooltipString(obj)
        
    end

end