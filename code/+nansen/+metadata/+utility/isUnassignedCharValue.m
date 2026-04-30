function tf = isUnassignedCharValue(inputValue) 
% isUnassignedCharValue Check if a value represents an unassigned character placeholder.
%
%   tf = nansen.metadata.utility.isUnassignedCharValue(inputValue) returns 
%   true if inputValue is a scalar cell array containing one of the 
%   recognized unassigned character placeholders: {'N/A'} or {'<undefined>'}.
%
%   Input:
%       inputValue - Value to test (any type).
%
%   Output:
%       tf - Logical scalar. True if inputValue is {'N/A'} or
%            {'<undefined>'}, false otherwise.
%
%   Examples:
%       nansen.metadata.utility.isUnassignedCharValue({'N/A'})         % returns true
%       nansen.metadata.utility.isUnassignedCharValue({'<undefined>'}) % returns true
%       nansen.metadata.utility.isUnassignedCharValue('N/A')           % returns false (not a cell)
%       nansen.metadata.utility.isUnassignedCharValue({'foo'})         % returns false
%       nansen.metadata.utility.isUnassignedCharValue({2})             % returns false

    arguments
        inputValue
    end

    tf = iscell(inputValue) && isscalar(inputValue) && ischar(inputValue{1}) ...
         && (isequal(inputValue, {'N/A'}) || isequal(inputValue, {'<undefined>'}) || isequal(inputValue, {''}));
end
