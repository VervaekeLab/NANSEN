classdef TableColumnFormatter < handle
%TableColumnFormatter Abstract mixin class for formatting column data.
%
% This class should be inherited by concrete table variable classes which
% should have a custom display of column data.

% Note: Rename to TableColumnRenderer?

    properties (Abstract, Hidden)
        Value       % The data value
    end

    methods (Abstract)
        
        str = getCellDisplayString(obj)

        str = getCellTooltipString(obj)
        
    end

end